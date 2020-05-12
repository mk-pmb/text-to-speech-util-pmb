#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function netcat_server () {
  local LSN_PORT="${TTS[netcat-port]:-0}"
  TTS[ncsrv-pid]=$$
  TTS[ncsrv-msgnum]=0
  exec </dev/null
  cd / || return $?

  worker_util__ensure_pgroup_leader || return $?
  local LOG_PID=$$ LOG_PGID=$$
  local LOG_FN="${TTS[ncsrv-logfile]}"
  worker_util__maybe_redir_all_output_to_logfile "$LOG_FN" || return $?

  worker_util__self_limit netcat- || return $?
  vengmgr 'lang:*' prepare || return $?
  while true; do
    netcat_server__one_turn || return $?
  done
}


function netcat_server__check_msg_head () {
  local HEAD="$(head --bytes=128)"
  HEAD="${HEAD%%$'\n'*}"
  HEAD="${HEAD%$'\r'}"
  <<<"$HEAD" grep -xPe 'SPEAK .* NOT/HTTP'
  return $?
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
  worker_util__maybe_redir_all_output_to_logfile "$LOG_FN" || return $?

  printf '%(%T)T %s' -1 'D: grace delay: '
  sleep "${TTS[ncsrv-turn-delay]:-1s}" || return $?

  vengmgr 'lang:*' prepare || return $?
  local NCSRV_PID="${TTS[ncsrv-pid]}"
  let TTS[ncsrv-msgnum]="${TTS[ncsrv-msgnum]}+1"

  printf '%(%T)T ' -1
  echo -n "tts-ncsrv pid $NCSRV_PID "
  echo -n "listening on port $LSN_PORT for msg #${TTS[ncsrv-msgnum]}, "
  local MSG= LSN_FD= NCLSN_PID=
  exec {LSN_FD}< <(exec netcat -dl "$LSN_PORT"); NCLSN_PID=$!
  echo -n "nc pid $NCLSN_PID: "

  local LSN_TMO="${TTS[ncsrv-listen-timeout]// /}"
  local TMO_CMD=()
  [ -n "$LSN_TMO" ] && TMO_CMD=( timeout "$LSN_TMO" )
  local MSG="$("${TMO_CMD[@]}" cat <&"$LSN_FD")"
  kill -HUP "$NCLSN_PID" 2>/dev/null
  exec {LSN_FD}<&-
  printf '%(%T)T %s' -1 "received ${#MSG} bytes. "

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
          printf '%(%T)T W: language "%s" requested but not configured.'$(
            )' Will try to guess instead.\n' -1 "$LNG" >&2
          LNG=;;
      esac
    fi
  fi

  if [ -z "$MSG" ]; then
    printf '%(%T)T D: empty message. ignored.\n' -1
    return 0
  fi

  printf '%(%T)T D: gonna stop reading.\n'
  <<<"$MSG" vengmgr lang:'*' speak_stop || return $?$(
    printf '%(%T)T E: failed to shut up, rv=%s\n' -1 "$?" >&2)

  case "$MSG" in
    *[A-Za-z0-9]* )
      [ -n "$LNG" ] || LNG="$(<<<"$MSG" guess_text_lang)"
      printf '%(%T)T D: gonna read as lang:%s.\n' -1 "$LNG"
      <<<"$MSG" vengmgr lang:"$LNG" speak_stdin || return $?$(
        printf "%(%T)T E: failed to speak, rv=$?\n" -1 >&2)
      ;;
    * ) printf '%(%T)T D: message with no letters or digits. ignored.\n' -1;;
  esac
  sleep 2s
  return 0
}






return 0
