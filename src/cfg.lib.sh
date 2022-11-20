#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function cfg () {
  local KEYS=( "$@" )
  [ -n "$*" ] || readarray -t KEYS < <(
    printf '%s\n' "${!TTS[@]}" | LANG=C sort)
  local KEY=
  local VAL=
  for KEY in "${KEYS[@]}"; do
    case "$KEY" in
      *=* )
        VAL="${KEY#*=}"
        KEY="${KEY%%=*}"
        TTS["$KEY"]="$VAL"
        ;;
      * )
        VAL="${TTS[$KEY]}"
        case "$KEY" in
          text ) VAL="…(${#VAL})";;
        esac
        printf '[%s]=%s\n' "$KEY" "$VAL"
        ;;
    esac
  done
}


function cfg_each_lang () {
  local TTS_LANGS=()
  readarray -t TTS_LANGS < <(<<<"${TTS[langs]}" grep -oPe '\w+')
  [ -n "${TTS_LANGS[0]}" ] || return 4$(echo "E: no languages configured" >&2)
  if [ -z "$*" ]; then
    echo "${TTS_LANGS[*]}"
    return 0
  fi
  local TTS_LANG=
  for TTS_LANG in "${TTS_LANGS[@]}"; do
    "$@" "$TTS_LANG" || return $?
  done
}


function cfg_read_rc_files () {
  local CFGD= PROG="${TTS[progname]}"
  for CFGD in "$PROG" 'speech-util-pmb' "$PROG"; do
    CFGD="$HOME/.config/$CFGD"
    [ -f "$CFGD/tts-util.rc" ] && break
    # ^-- Check most specific directories first, giving them a chance to
    #     seize authority. If none did, repeat PROG to make it win weakly.
  done
  TTS[cfgdir]="$CFGD"

  local CFG_FILES=(
    "$TTSU_PATH"/src/cfg.default.rc
    "$CFGD"/*.rc
    )
  local ITEM=
  for ITEM in "${CFG_FILES[@]}"; do
    [ -f "$ITEM" ] || continue
    in_func source -- "$ITEM" || return $?
  done
}


[ "$1" == --lib ] && return 0; cfg "$@"; exit $?
