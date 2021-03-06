#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-

function veng_logox4__prepare () {
  local VOICE="$1"
  veng_wine_stdin__prepare "$VOICE" --check-alive && return 0
  local WPFX="${TTS[logox4:wpfx]}"
  local LIC="${TTS[logox4:lickey]}"
  [ -n "$LIC" ] || LIC="$LOGOX_LICKEY"
  [ -n "$LIC" ] || LIC="$WPFX/license.logox4.txt"
  [ "${LIC:0:1}" == / ] && LIC="$(grep -oPe '^\w\S+' -m 1 -- "$LIC" \
      || echo "E: no license key found in $LIC" >&2)"
  if [ -n "$LIC" ]; then
    echo "I: logox license key: ${LIC:0:5}…×${#LIC}"
  else
    echo "W: no logox license key?" >&2
  fi
  local LOGOX_LICKEY="$LIC"
  local VWS_PREWINE_EVAL='export LOGOX_LICKEY'
  local VWS_INIT=()
  local LGX_VOICE_OPTS=(
    font_alias
    vol_db
    speed_pr
    pitch_hz
    inton_pr
    rough_hz
    )
  local OPT=
  for OPT in "${LGX_VOICE_OPTS[@]}"; do
    VWS_INIT+=( ".$OPT" "${TTS[$VOICE:$OPT]}" )
  done
  veng_wine_stdin__prepare "$@"; return $?
}

function veng_logox4__speak_stdin () {
  local VWS_HEAD=( .stop .clear )
  local VWS_TAIL=( .base64utf8 .speak .clear )
  veng_wine_stdin__base64 "$@"; return $?
}

function veng_logox4__speak_stop () {
  <<<'.stop' veng_wine_stdin__raw "$@"; return $?
}

function veng_logox4__release () {
  veng_wine_stdin__"${FUNCNAME#*__}" "$@"; return $?
}

return 0
