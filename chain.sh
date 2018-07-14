#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function tts_chain () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local SELFPATH="$(readlink -m "$BASH_SOURCE"/..)"
  # cd "$SELFPATH" || return $?
  local APP_NAME="$(basename "$SELFPATH")"

  local -A TTS=()
  local ITEM=
  for ITEM in "$SELFPATH"/src/*.lib.sh; do
    source "$ITEM" --lib || return $?
  done
  local CFG_PATHS=(
    "$SELFPATH"/src/cfg.default.rc
    "$HOME/.config/speech-util-pmb/tts-util.rc"
    "$HOME/.config/$APP_NAME"/*.rc
    )
  for ITEM in "${CFG_PATHS[@]}"; do
    [ -f "$ITEM" ] || continue
    source "$ITEM" || return $?
  done

  local CMD=()
  for ITEM in "$@" :; do
    case "$ITEM" in
      : )
        [ -n "${CMD[*]}" ] || return 0
        ITEM="$SELFPATH/src/${CMD[0]}.sh"
        [ -x "$ITEM" ] && CMD[0]="$ITEM"
        "${CMD[@]}" || return $?
        CMD=();;
      * ) CMD+=( "$ITEM" );;
    esac
  done
  return 0
}


function grab_text () {
  local TX="$("$@")"
  [ -n "$TX" ] || return 2$(echo "E: $FUNCNAME: no output from $*" >&2)
  TTS[text]="$TX"
}


function pipe_text () {
  <<<"${TTS[text]}" "$@"; return $?
}










tts_chain "$@"; exit $?
