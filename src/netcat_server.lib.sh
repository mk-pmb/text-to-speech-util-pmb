#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function netcat_server () {
  local TASK="${1:-start}"; shift

  local QUIT_CMD="${TTS[ncsrv-quit-cmd]:-<<!ncsrv>>quit}"
  local LSN_PORT="${TTS[netcat-port]:-0}"
  local NCSRV_PID=$$

  local MUTEX_FILE="${TTS[ncsrv-pid-mutex]}"
  local MUTEX_CMD=( true )
  if [ -n "$MUTEX_FILE" ]; then
    MUTEX_FILE="$(worker_util__render_filename_template "$MUTEX_FILE"
      )" || return $?
    MUTEX_CMD=( worker_util__lockfile_action "$MUTEX_FILE" )
  fi

  "${FUNCNAME}__${TASK}" "$@"
  return $?
}


function netcat_server__find_server_pid () {
  NCSRV_PID="$(cat -- "$MUTEX_FILE")"
  case "$NCSRV_PID" in
    '' ) echo "E: Empty pid file: $MUTEX_FILE" >&2; return 3;;
    *[^0-9]* ) echo "E: Non-digit(s) in pid file: $MUTEX_FILE" >&2; return 3;;
  esac
  echo "D: server pid: $NCSRV_PID" >&2
}


function netcat_server__stop () {
  netcat_server__find_server_pid || return $?
  kill -0 "$NCSRV_PID" &>/dev/null \
    || echo "W: no such process: pid $NCSRV_PID" >&2
  echo "D: send quit command:"
  netcat_send__raw <<<"$QUIT_CMD"

  echo 'D: wait for server shutdown:'
  local WAIT= SURV=
  for WAIT in {1..10}; do
    sleep 0.5s
    if kill -0 "$NCSRV_PID" &>/dev/null; then
      echo -n ' …'
    else
      echo "D: pid $NCSRV_PID disappeared."
      break
    fi
  done

  local MUTEX_PID="$(ps ho comm,pid -"$NCSRV_PID" \
    | grep -xPe 'lockfile-touch\s+\d+' | grep -oPe '\d+$')"
  if [ -n "$MUTEX_PID" ]; then
    kill -HUP "$MUTEX_PID" &>/dev/null
  else
    echo "W: failed to detect mutex pid" >&2
  fi

  echo 'D: wait for log loop shutdown:'
  for WAIT in {1..10}; do
    sleep 1s
    SURV="$(ps o user,pid,args -"$NCSRV_PID")"
    if [[ "$SURV" == *$'\n'* ]]; then
      echo -n ' …'
    else
      echo
      echo 'D: No surviving processes.'
      return 0
    fi
  done
  echo 'E: giving up. Surviving processes:' >&2
  echo "$SURV" >&2
}


function netcat_server__kill () {
  local SIG="$1"
  netcat_server__find_server_pid || return $?
  SIG="${SIG#SIG}"
  SIG="SIG${SIG:-HUP}"
  echo "D: Sending $SIG to process group $NCSRV_PID:"
  kill -"$SIG" -"$NCSRV_PID"
  echo 'D: Surviving processes:'
  ps o user,pid,args -"$NCSRV_PID"
  return 0
}


function netcat_server__start () {
  exec </dev/null
  local LOG_PID=$$ LOG_PGID="$(worker_util__getpgid)"
  if [ "$LOG_PGID" != "$$" ]; then
    # We don't have our own process group. Try to break free:
    echo "exec setsid $TTSU_PATH/chain.sh netcat_server <$*>"
    setsid "$TTSU_PATH/chain.sh" netcat_server & disown $!
    return 0
  fi

  TTS[ncsrv-msgnum]=0
  cd / || return $?

  worker_util__ensure_pgroup_leader || return $?

  [ -z "$MUTEX_FILE" ] || "${MUTEX_CMD[@]}" create || return $?$(
    echo "H: To stop a running instance, run: tts-ncsrv-pmb stop" >&2
    echo "E: failed to create pidfile $MUTEX_FILE" >&2)

  # Only create a log file if we have a mutex, because it's not worth
  # littering small files for just the mutex error message.
  local LOG_FN="${TTS[ncsrv-logfile]}"
  worker_util__maybe_redir_all_output_to_logfile "$LOG_FN" || return $?
  worker_util__self_limit 'netcat-' || return $?

  local MUTEX_TOUCHER=
  if [ -n "$MUTEX_FILE" ]; then
    "${MUTEX_CMD[@]}" touch &
    MUTEX_TOUCHER=$!
  fi

  vengmgr 'lang:*' prepare || return $?
  local RMN_TURNS="${TTS[ncsrv-max-turns]}"
  local SRV_FAIL_RV=
  while [ -z "$SRV_FAIL_RV" ]; do
    if [ -z "$RMN_TURNS" ]; then
      true
    elif [ "$RMN_TURNS" -ge 1 ]; then
      (( RMN_TURNS -= 1 ))
    else
      break
    fi
    "${MUTEX_CMD[@]}" check "$MUTEX_TOUCHER" || break
    netcat_server__one_turn || SRV_FAIL_RV=$?
  done

  "${MUTEX_CMD[@]}" remove "$MUTEX_TOUCHER" || return $?
  return "${SRV_FAIL_RV:-0}"
}


function netcat_server__check_msg_head () {
  local HEAD="$(head --bytes=128)"
  HEAD="${HEAD%%$'\n'*}"
  HEAD="${HEAD%$'\r'}"
  local RGX='^SPEAK .* NOT/HTTP$'
  [[ "$HEAD" =~ $RGX ]] || return $?
  echo "$HEAD"
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

  case "$MSG" in
    "$QUIT_CMD" )
      echo 'D: received quit command.'
      RMN_TURNS=0
      return 0;;
  esac

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
    #    echo "D: message head: URL='$URL', QRY='$QRY', LNG='$LNG'" >&2
    #  else
    #    echo "D: head-less message" >&2
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
}






return 0
