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


function netcat_server__one_turn () {
  vengmgr 'lang:*' prepare || return $?
  echo -n "listening on port $LSN_PORT: "
  local MSG=
  MSG="$(netcat -l "$LSN_PORT")"
  echo -n "received ${#MSG} bytes. "

  local LNG=
  local RGX='^SPEAK /([a-z]+) NOT/HTTP\r?\n'
  if [[ "${MSG:0:64}" =~ $RGX ]]; then
    LNG="${BASH_REMATCH[1]}"
    MSG="${MSG#*$'\n'}"
  fi

  case "$MSG" in
    '' ) ;;
    *[A-Za-z0-9]* )
      [ -n "$LNG" ] || LNG="$(<<<"$MSG" guess_text_lang)"
      echo "gonna read as lang:$LNG."
      <<<"$MSG" vengmgr lang:"$LNG" speak_stdin || return $?$(
        echo "E: failed to speak, rv=$?" >&2)
      ;;
    * )
      echo "gonna stop reading"
      <<<"$MSG" vengmgr lang:'*' speak_stop || return $?$(
        echo "E: failed to shut up, rv=$?" >&2)
      ;;
  esac
  return 0
}


return 0
