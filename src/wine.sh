#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-

function tts_wine () {
  local TTS_DIR="$(readlink -m "$BASH_SOURCE"/../..)"
  local WINEPREFIX="$TTS_WPFX"
  [ -n "$WINEPREFIX" ] || WINEPREFIX="$TTS_WPFX"
  [ -n "$WINEPREFIX" ] || WINEPREFIX="$TTS_DIR/wpfx"
  [ -d "$WINEPREFIX" ] || return 3$(
    echo "E: configured WINEPREFIX '$WINEPREFIX' must be a directory." >&2)
  export WINEPREFIX

  local CMD=( bash )
  [ -n "$*" ] && CMD=( wine )

  local PRE=()
  case "$1" in
    +xvfb )
      shift
      exec xvfb-run --server-args='-screen 0 800x600x24' "$BASH_SOURCE" \
        +xvfb-prepare "$@"
      return $?;;
    +xvfb-prepare )
      shift
      xsetroot -solid navy
      ;;
  esac
  case "$DISPLAY" in
    :*[0-9].0 ) export DISPLAY="${DISPLAY%.0}";;
  esac

  local debian_chroot="$debian_chroot"
  if [ -z "$debian_chroot" ]; then
    debian_chroot="tts-wine X${DISPLAY:-=nope}"
  fi
  [ -n "$WINEARCH" ] || export WINEARCH=win32
  [ -n "$WINEDEBUG" ] || export WINEDEBUG=fixme-all

  export debian_chroot
  exec "${PRE[@]}" "${CMD[@]}" "$@"
}


function screenspy () {
}







tts_wine "$@"; exit $?
