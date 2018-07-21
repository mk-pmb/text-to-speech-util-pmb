#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-

function vengmgr () {
  local VOICE="$1"; shift
  case "$VOICE" in
    'lang:*' )
      local RV=0
      for VOICE in $(cfg_each_lang); do
        VOICE="${TTS[lang:$VOICE]}"
        "$FUNCNAME" "$VOICE" "$@" && continue
        echo "E: $FUNCNAME: voice '$VOICE': failed to $1, rv=$?" >&2
        let RV="$RV+1"
      done
      return "$RV";;
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
  case "$ACTION" in
    up-down-test )
      veng_"$ENG"__prepare "$VOICE" || return $?
      veng_"$ENG"__release "$VOICE" --wait || return $?
      return 0;;
  esac
  veng_"$ENG"__"$ACTION" "$VOICE" "$@"; return $?
}

return 0
