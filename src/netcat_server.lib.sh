#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function netcat_server () {
  local LSN_PORT="${TTS[netcat-port]:-0}"
  vengmgr 'lang:*' prepare || return $?
  TTS[ncsrv-pid]=$$
  TTS[ncsrv-msgnum]=0
  while true; do
    printf '%(%T)T %s' -1 'D: grace delay: '
    sleep 2
    netcat_server__one_turn || return $?
  done
  return 0
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
  vengmgr 'lang:*' prepare || return $?
  local NCSRV_PID="${TTS[ncsrv-pid]}"
  let TTS[ncsrv-msgnum]="${TTS[ncsrv-msgnum]}+1"

  printf '%(%T)T ' -1
  echo -n "tts-ncsrv pid $NCSRV_PID "
  echo -n "listening on port $LSN_PORT for msg #${TTS[ncsrv-msgnum]}: "
  local MSG=
  MSG="$(netcat -l "$LSN_PORT")"
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
