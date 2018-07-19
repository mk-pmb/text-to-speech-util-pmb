#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-

function veng_ms_sapi_v11__prepare () {
  local VOICE="$1"
  local VWS_INIT=(
    "must voice select id ${TTS[$VOICE:voice]}"
    "must voice rate ${TTS[$VOICE:speed]}"
    )
  veng_wine_stdin__prepare "$@"; return $?
}

function veng_ms_sapi_v11__speak_stdin () {
  local END_MARK='</base64>'
  local VWS_HEAD=(
    "speak stop"
    "must set_text until $END_MARK"
    )
  local VWS_TAIL=(
    "$END_MARK"
    "must set_text decode base64 utf8"
    "speak start"
    )
  veng_wine_stdin__base64 "$@"; return $?
}

function veng_ms_sapi_v11__speak_stop () {
  <<<'speak stop' veng_wine_stdin__raw "$@"; return $?
}

function veng_ms_sapi_v11__release () {
  veng_wine_stdin__"${FUNCNAME#*__}" "$@"; return $?
}

return 0
