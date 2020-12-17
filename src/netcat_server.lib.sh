#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function netcat_server () {
  exec </dev/null

  local LOG_PID=$$ LOG_PGID="$(worker_util__getpgid)"
  if [ "$LOG_PGID" != "$$" ]; then
    # We don't have our own process group. Try to break free:
    echo "exec setsid $TTSU_PATH/chain.sh netcat_server <$*>"
    setsid "$TTSU_PATH/chain.sh" netcat_server & disown $!
    return 0
  fi

  local LSN_PORT="${TTS[netcat-port]:-0}"
  TTS[ncsrv-pid]=$$
  TTS[ncsrv-msgnum]=0
  cd / || return $?

  worker_util__ensure_pgroup_leader || return $?

  local MUTEX_FILE="${TTS[ncsrv-pid-mutex]}"
  local MUTEX_TOUCHER=
  local MUTEX_CMD=( true )
  if [ -n "$MUTEX_FILE" ]; then
    MUTEX_FILE="$(worker_util__render_filename_template "$MUTEX_FILE"
      )" || return $?
    MUTEX_CMD=( worker_util__lockfile_action "$MUTEX_FILE" )
    "${MUTEX_CMD[@]}" create || return $?$(
      echo "E: failed to create pidfile $MUTEX_FILE" >&2)
  fi

  local LOG_FN="${TTS[ncsrv-logfile]}"
  worker_util__maybe_redir_all_output_to_logfile "$LOG_FN" || return $?
  worker_util__self_limit 'netcat-' || return $?

  if [ -n "$MUTEX_FILE" ]; then
    "${MUTEX_CMD[@]}" touch &
    MUTEX_TOUCHER=$!
  fi

  vengmgr 'lang:*' prepare || return $?
  while true; do
    "${MUTEX_CMD[@]}" check "$MUTEX_TOUCHER" || break
    netcat_server__one_turn || return $?
  done
  "${MUTEX_CMD[@]}" remove "$MUTEX_TOUCHER" || return $?
}


function netcat_server__check_msg_head () {
  local HEAD="$(head --bytes=128)"
  HEAD="${HEAD%%$'\n'*}"
  HEAD="${HEAD%$'\r'}"
  local RGX='^SPEAK .* NOT/HTTP$'
  [[ "$HEAD" =~ $RGX ]] || return $?
}


function netcat_server__stash_msg_head () {
  local HEAD="$(<<<"${TTS[text]}" "${FUNCNAME%__*}"__check_msg_head)"
  [ -n "$HEAD" ] && TTS[text]="${TTS[text]#*$'\n'}"
  "$@"
  local RV=$?
  [ -n "$HEAD" ] && TTS[text]="$HEAD"$'\n'"${TTS[text]}"
  return "$RV"
}


function netcat_server__one_turn () {
  printf '%(%T)T %s' -1 'D: grace delay: '
  sleep "${TTS[ncsrv-turn-delay]:-1s}" || return $?

  vengmgr 'lang:*' prepare || return $?
  local NCSRV_PID="${TTS[ncsrv-pid]}"
  let TTS[ncsrv-msgnum]="${TTS[ncsrv-msgnum]}+1"

  echo -n "tts-ncsrv pid $NCSRV_PID "
  echo -n "listening on port $LSN_PORT for msg #${TTS[ncsrv-msgnum]}, "
  local MSG= LSN_FD= NCLSN_PID=
  exec {LSN_FD}< <(
    LANG=C PORT="$LSN_PORT" sh -c 'echo $$; exec 2>&1; exec netcat -dl "$PORT"'
    echo -e "\arv=$?")
  read -ru "$LSN_FD" NCLSN_PID
  echo "netcat pid $NCLSN_PID:"

  local LSN_TMO="${TTS[ncsrv-listen-timeout]// /}"
  local TMO_CMD=()
  [ -n "$LSN_TMO" ] && TMO_CMD=( timeout "$LSN_TMO" )
  local MSG="$("${TMO_CMD[@]}" cat <&"$LSN_FD")"
  local READ_RV=$?
  kill -HUP "$NCLSN_PID" 2>/dev/null
  exec {LSN_FD}<&-
  echo "read rv=$READ_RV, received ${#MSG} bytes. "
  if [ "$READ_RV" != 0 ]; then
    echo "skipping due to read failure."
    return 0
  fi

  local NCLSN_RV=$'\a''rv=([0-9]+)$'
  if [[ "$MSG" =~ $NCLSN_RV ]]; then
    NCLSN_RV="${BASH_REMATCH[1]}"
    MSG="${MSG%$'\a'*}"
    MSG="${MSG%$'\n'}"
  else
    echo "E: failed to detect return value of netcat subshell" >&2
    return 8
  fi

  if [ "$NCLSN_RV" != 0 ]; then
    MSG="${MSG#netcat: }"
    echo "W: netcat failed: rv=$NCLSN_RV, message: '$MSG'" >&2
    case "${MSG,,}" in
      'address already in use' )
        MSG="${TTS[ncsrv-port-unavail-retry]}"
        if [ -n "$MSG" ]; then
          case "$MSG" in
            *[0-9] ) MSG+='s';;   # for nicer display message
          esac
          echo "D: gonna retry listening in $MSG"
          sleep "$MSG" && return 0
        fi;;
    esac
    return "$NCLSN_RV"
  fi

  local DEBUGDUMP_BFN="$HOME/.cache/var/debug/tts-ncsrv"
  [ -d "$DEBUGDUMP_BFN" ] && DEBUGDUMP_BFN+="/$(date +%y%m%d)-$NCSRV_PID"
  if [ -d "$DEBUGDUMP_BFN" ]; then
    DEBUGDUMP_BFN+="/$(date +%H%M%S)-${TTS[ncsrv-msgnum]}"
    echo "D: debug dump bfn: $DEBUGDUMP_BFN" >&2
  else
    DEBUGDUMP_BFN=
  fi
  [ -z "$DEBUGDUMP_BFN" ] || echo "$MSG" >"$DEBUGDUMP_BFN".rcv

  local HEAD="$(<<<"$MSG" "${FUNCNAME%__*}"__check_msg_head)"
  local LNG= URL= QRY= RGX=
  if [ -n "$HEAD" ]; then
    MSG="${MSG#*$'\n'}"
    URL="${HEAD#* }"
    URL="${URL% *}"
    QRY="${URL#*\?}"
    [ "$QRY" == "$URL" ] && QRY=
    URL="${URL%%\?*}"
    if [[ "$URL" =~ ^/([a-z]+)$ ]]; then
      LNG="${BASH_REMATCH[1]}"
      case ",${TTS[langs]}," in
        *",$LNG,"* ) ;;
        * )
          echo "W: language '$LNG' requested but not configured." \
            "Will try to guess instead." >&2
          LNG=;;
      esac
    fi
  fi

  if [ -z "$MSG" ]; then
    echo "D: empty message. ignored."
    return 0
  fi

  echo "D: gonna stop reading."
  <<<"$MSG" vengmgr lang:'*' speak_stop || return $?$(
    echo "E: failed to shut up, rv=$?" >&2)

  case "$MSG" in
    *[A-Za-z0-9]* )
      [ -n "$LNG" ] || LNG="$(<<<"$MSG" guess_text_lang)"
      echo "D: gonna read as lang:$LNG."
      <<<"$MSG" vengmgr lang:"$LNG" speak_stdin || return $?$(
        echo "E: failed to speak, rv=$?" >&2)
      ;;
    * ) echo "D: message with no letters or digits. ignored.";;
  esac
  sleep 2s
  return 0
}






return 0
