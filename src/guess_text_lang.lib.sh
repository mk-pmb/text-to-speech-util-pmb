#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-

function guess_text_lang () {
  local OPT="$1"
  local LANGS="${TTS[langs]}"
  local TL="$(aspell-guess-lang "$LANGS" - | sed -nre '
    s~^.*\t([A-Za-z_-]+)$~\1~p;q')"
  [ -n "$TL" ] || return 3$(
    echo "E: $FUNCNAME: failed to detect language" >&2)
  case "$OPT" in
    =* )
      OPT="${OPT#=}"
      TTS["${OPT:-lang}"]="$TL"
      return 0;;
  esac
  echo "$TL"
}

[ "$1" == --lib ] && return 0; guess_text_lang "$@"; exit $?
