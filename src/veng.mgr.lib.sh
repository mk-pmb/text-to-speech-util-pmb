#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-

function vengmgr () {
  local VOICE="$1"; shift
  case "$VOICE" in
    'lang:*' )
      for VOICE in $(cfg_each_lang); do
        "$FUNCNAME" lang:"$VOICE" "$@" || return $?
      done
      return 0;;
    lang:* )
      [ -n "${TTS[$VOICE]}" ] || return 3$(
        echo "E: no voice configured for '$VOICE'" >&2)
      VOICE="${TTS[$VOICE]}";;
  esac
  case "$VOICE" in
    '' )
      echo "E: no voice name given" >&2
      return 2;;
    *:* )
      echo "E: unsupported prefix in voice name: $VOICE" >&2
      return 2;;
  esac
  local ENG="${TTS[$VOICE:engine]}"
  local ACTION="$1"; shift
  veng_"$ENG"__"$ACTION" "$VOICE" "$@"; return $?
}

return 0
