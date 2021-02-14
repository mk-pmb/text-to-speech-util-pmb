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
  local LIST=( "$@" ) ADD=() SCRIPTS=()
  local ARG=
  if [ "$*" == --guess ]; then
    ARG="${TTS[refine:default_dirs]}"
    [ -n "$ARG" ] || ARG="${TTS[cfgdir]}/refine/by_lang"
    case "$ARG" in
      '~'/* ) LIST=( "$HOME${ARG:1}" );;
      /* | .* ) LIST=( "$ARG" );;
      * ) readarray -t LIST <<<"${ARG//${ARG:0:1}/$'\n'}";;
    esac
  fi
  for ARG in "${LIST[@]}"; do
    [ -n "$ARG" ] || continue
    LIST=(
      -L    # follow symlinks

      "${ARG%/}/${TTS[lang]}/"
      "${ARG%/}/common/"

      -maxdepth 1
      -type f
      '(' -false
        -o -name '*.js'
        -o -name '*.sed'
      ')'
      -printf '%f\t%p\n'
    )
    readarray -t ADD < <(find "${LIST[@]}" | LANG=C sort -V | cut -sf 2-)
    SCRIPTS+=( "${ADD[@]}" )
  done
  "${FUNCNAME%__*}" "${SCRIPTS[@]}"
  return $?
}










return 0
