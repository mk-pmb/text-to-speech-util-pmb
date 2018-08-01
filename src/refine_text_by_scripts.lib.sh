#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-

function refine_text_by_scripts () {
  local ARG=
  local HOW=()
  while [ "$#" -ge 1 ]; do
    ARG="$1"; shift
    [ -f "$ARG" ] || continue
    HOW=( "$ARG" )
    if [ -x "$ARG" ]; then
      case "$ARG" in
        */* ) ;;
        * ) HOW=( "./$ARG" );;
      esac
    else
      case "$ARG" in
        *.sed ) HOW=( sed -rf "$ARG" );;
        *.js ) HOW=( nodejs "$ARG" );;
      esac
    fi
    LANG=C grab_text --refine --maybe "${HOW[@]}"
  done
  return 0
}


function refine_text_by_scripts__langdirs () {
  [ -n "${TTS[lang]}" ] || pipe_text guess_text_lang =
  local FIND_OPT=()
  local ITEM=
  for ITEM in "$@"; do
    FIND_OPT+=(
      "${ITEM%/}/${TTS[lang]}/"
      "${ITEM%/}/common/"
      )
  done
  FIND_OPT+=(
    -maxdepth 1
    -type f
    '(' -false
      -o -name '*.js'
      -o -name '*.sed'
    ')'
    -printf '%f\t%p\n'
  )
  local SCRIPTS=()
  readarray -t SCRIPTS < <(find "${FIND_OPT[@]}" | LANG=C sort -V | cut -sf 2-)
  "${FUNCNAME%__*}" "${SCRIPTS[@]}"
  return $?
}










return 0
