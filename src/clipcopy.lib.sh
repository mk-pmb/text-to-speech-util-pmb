#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-

function clipcopy () {
  local CLIP_BACKUP="$(xsel --clipboard --output | base64)"
  local CLIP_TEXT=
  local CLIP_TIMEOUT=2
  SECONDS=0
  echo | xsel --clipboard --input
  while [ -z "$CLIP_TEXT" -a $SECONDS -le $CLIP_TIMEOUT ]; do
    sleep 0.2s
    # ^-- If the sleeps seem to fail when testing from a terminal,
    #     and therefor too many Ctrl+c appear, it might be that
    #     each of them killed a sleep.
    xdotool key --clearmodifiers Ctrl+c
    sleep 0.2s
    CLIP_TEXT="$(xsel --clipboard --output)"
  done
  <<<"$CLIP_BACKUP" base64 --decode | xsel --clipboard --input

  [ -n "$CLIP_TEXT" ] || return 2
  echo "$CLIP_TEXT"
  return 0
}


function clipcopy_read () {
  grab_text clipcopy && setvoice _guess && pipe_text speak_stdin "$@"
  return $?
}


[ "$1" == --lib ] && return 0; clipcopy "$@"; exit $?
