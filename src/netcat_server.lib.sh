#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function netcat_server () {
  local LSN_PORT="${TTS[netcat-port]:-0}"
  vengmgr 'lang:*' prepare || return $?
  while true; do
    echo -n 'grace delay: '
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
  echo -n "listening on port $LSN_PORT: "
  local MSG=
  MSG="$(netcat -l "$LSN_PORT")"
  echo -n "received ${#MSG} bytes. "

  local HEAD="$(<<<"$MSG" "${FUNCNAME%__*}"__check_msg_head)"
  local LNG= URL= QRY= RGX=
  if [ -n "$HEAD" ]; then
    MSG="${MSG#*$'\n'}"
    URL="${HEAD#* }"
    URL="${URL% *}"
    QRY="${URL#*\?}"
    [ "$QRY" == "$URL" ] && QRY=
    URL="${URL%%\?*}"
    [[ "$URL" =~ ^/([a-z]+)$ ]] && LNG="${BASH_REMATCH[1]}"
  fi

  if [ -z "$MSG" ]; then
    echo "D: empty message. ignored."
    return 0
  fi

  echo 'gonna stop reading.'
  <<<"$MSG" vengmgr lang:'*' speak_stop || return $?$(
    echo "E: failed to shut up, rv=$?" >&2)

  case "$MSG" in
    *[A-Za-z0-9]* )
      [ -n "$LNG" ] || LNG="$(<<<"$MSG" guess_text_lang)"
      echo "gonna read as lang:$LNG."
      <<<"$MSG" vengmgr lang:"$LNG" speak_stdin || return $?$(
        echo "E: failed to speak, rv=$?" >&2)
      ;;
    * ) echo "D: message with no letters or digits. ignored.";;
  esac
  sleep 2s
  return 0
}


return 0
