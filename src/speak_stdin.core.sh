#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function speak_stdin_core () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local TTSUTIL_PATH="$(readlink -m "$BASH_SOURCE"/../..)"
  local -A TTS=()
  source "$TTSUTIL_PATH"/src/cfg.default.rc
  local EXE_NAME="${TTS_EXE_NAME:-${TTS[exe_name]}}"
  local EXE_WINPATH="${TTS_EXE_WINPATH:-${TTS[exe_winpath]}}"
  export WINEPREFIX="${TTS_WPFX:-$TTSUTIL_PATH/wpfx}"
  export WINEARCH=win32
  [ -n "$WINEDEBUG" ] || export WINEDEBUG=fixme-all

  local OPT=
  while true; do
    OPT="$1"
    case "$OPT" in
      --lib )
        echo "E: $FUNCNAME cannot work as --lib because it 'exec's, which $(
        )other servers might require to properly track its process ID." >&2
        return 3;;
      --kill )
        shift
        for OPT in {1..2}; do
          killall -HUP "$EXE_NAME" 2>/dev/null || break
          sleep 1s
        done
        killall -KILL "$EXE_NAME" 2>/dev/null
        ;;
      -- ) shift; break;;
      * ) break;;
    esac
  done

  local EXE_DESTDIR="$WINEPREFIX/dosdevices/$EXE_WINPATH"
  [ -f "$EXE_DESTDIR/$EXE_NAME" ] \
    || cp --verbose --no-clobber --target-directory="$EXE_DESTDIR" \
          -- "$TTSUTIL_PATH/blobs/$EXE_NAME" \
    || return $?

  local INPUT="$(base64 --wrap=252)"
  [ -n "$INPUT" ] || return 2$(echo "E: $FUNCNAME: no input" >&2)
  local END_MARK='</base64>'
  # printf -v END_MARK '\a\v==END==%(%s)T==%s==\f' -1 $$
  # END_MARK=$'\f'
  exec wine "$EXE_WINPATH/$EXE_NAME" < <(
    echo "must set_text until $END_MARK"
    echo "$INPUT"
    echo "$END_MARK"
    echo "must set_text decode base64 utf8"
    printf '%s\n' "$@"
    echo "speak_sync"
    )
  return $?
}









speak_stdin_core "$@"; exit $?
