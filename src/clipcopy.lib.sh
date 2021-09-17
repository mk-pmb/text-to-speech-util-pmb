#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-

function clipcopy () {
  # Determine active program in order to decide how to extract text:
  local AWIN_WID="$(xdotool getactivewindow)"
  local AWIN_PID="$(xdotool getwindowpid "$AWIN_WID")"
  local AWIN_CLS="$(wmctrl -xl | grep -oPe '^(\S+\s+){3}' \
    | sed -nre 's~\s+$~~;s~^0x0*'"$(printf %x "$AWIN_WID")"' +\S+ ~~p')"
  local AWIN_PROG=
  # [ -z "$AWIN_PID" ] || AWIN_PROG="$(ps ho comm "$AWIN_PID")"
  # enus gxmessage "$(local -p)"
  case "$AWIN_CLS" in
    dillo.Dillo | \
    __middle_click_paste_style__ ) LANG=C xsel --output --primary; return $?;;
  esac

  local CLIP_BACKUP="$(xsel --clipboard --output | base64)"
  local CLIP_TEXT=
  local CLIP_TIMEOUT=2
  SECONDS=0
  xsel --clipboard --clear >/dev/null
  # ^-- 2018-09-15: Discovered that the occasional duplicate output stems
  #   from xsel printing the old contents, sometimes here, sometimes
  #   further down when we restore the backup.
  #   Observed on Ubuntu trusty with Xfce 4.10, albeit the xsel man page
  #   says this shouldn't happen if any I/O options are given.

  while [ -z "$CLIP_TEXT" -a $SECONDS -le $CLIP_TIMEOUT ]; do
    # wait a bit for the previous clipboard operation to finish, hopefully:
    sleep 0.2s
    # ^-- If you're using Ctrl+c as the copy key combo, and the sleeps
    #     seem to fail when testing from a terminal, it might be that
    #     each of them killed a sleep.
    xdotool key --clearmodifiers Ctrl+Insert
    sleep 0.2s
    CLIP_TEXT="$(xsel --clipboard --output)"
  done
  xsel --clipboard --input < <(<<<"$CLIP_BACKUP" base64 --decode
    ) >/dev/null # work-around, see above

  [ -n "$CLIP_TEXT" ] || return 2
  echo "$CLIP_TEXT"
  return 0
}


function clipcopy_read () {
  grab_text clipcopy && setvoice _guess && pipe_text speak_stdin "$@"
  return $?
}


[ "$1" == --lib ] && return 0; clipcopy "$@"; exit $?
