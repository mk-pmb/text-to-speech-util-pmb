#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function tts_chain () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local INVOKED_AS="$(basename -- "$0" .sh)"
  local TTSU_PATH="$(readlink -m -- "$BASH_SOURCE"/..)"
  # cd "$TTSU_PATH" || return $?

  local -A TTS=(
    [progname]="$(basename -- "$TTSU_PATH")"
    )
  local ITEM=
  for ITEM in "$TTSU_PATH"/src/*.lib.sh; do
    source -- "$ITEM" --lib || return $?
  done
  cfg_read_rc_files || return $?

  local PRE_CMD=()
  local INVO="$INVOKED_AS"
  INVO="${INVO#tts-}"
  INVO="${INVO%-pmb}"
  case "$INVO" in
    ncsrv ) PRE_CMD=( netcat_server );;
  esac

  local CMD=()
  for ITEM in "${PRE_CMD[@]}" "$@" :; do
    case "$ITEM" in
      : )
        if [ -n "${CMD[*]}" ]; then
          ITEM="$TTSU_PATH/src/${CMD[0]}.sh"
          [ -x "$ITEM" ] && CMD[0]="$ITEM"
          "${CMD[@]}" || return $?
        fi
        CMD=();;
      * ) CMD+=( "$ITEM" );;
    esac
  done
}


function grab_text () {
  if [ "$1" == --refine ]; then
    # Feed old text to command that produces the new text. Example:
    #   tts-util-pmb grab_text dummytext : pipe_text nl \
    #     : grab_text --refine sort : pipe_text nl
    shift
    exec <<<"${TTS[text]}"
  fi
  local ERRLV=E
  case "$1" in
    --maybe ) ERRLV=W; shift;;
    --literal ) shift; printf -v TTS[text] -- '%s\n' "$@"; return $?;;
  esac
  local TX=     # <-- pre-declare because "local" determines $?, whereas…
  TX="$("$@")"  # <-- a simple assignment transports $?.
  local RV="$?"
  if [ "$RV" != 0 ]; then
    echo "$ERRLV: rv=$RV from $*" >&2
    [ "$ERRLV" == W ] && return 0
    return "$RV"
  elif [ -z "$TX" ]; then
    echo "$ERRLV: no output from $*" >&2
    [ "$ERRLV" == W ] && return 0
    return 2
  fi
  TTS[text]="$TX"
}


function pipe_text () {
  <<<"${TTS[text]}" "$@"; return $?
}










tts_chain "$@"; exit $?
