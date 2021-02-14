#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function str_util__ltrim () {
  local CHARS="$1"
  local INPUT="$(cat; echo :)"
  # ^-- unfortunately, I couldn't find any way to convince bash's
  #     "read" command to save leading newlines into the var.
  #     <<<$'\na' read -d '' -rs -N 2 INPUT; echo "<$INPUT> ${#INPUT}"
  #     --> <a> 1
  INPUT="${INPUT%:}"
  while true; do case "$CHARS" in
    *"${INPUT:0:1}"* ) INPUT="${INPUT:1}";;
    * ) break;;
  esac; done
  echo -n "$INPUT"
}


function str_util__call_with_split_args () {
  local SEP="$1"; shift
  local ARGS=( "$1" ); shift
  if [ -z "$SEP" ]; then
    SEP="${ARGS[0]:0:1}"
    ARGS[0]="${ARGS[0]:1}"
  fi
  readarray -t ARGS <<<"${ARGS[0]//$SEP/$'\n'}"
  "$@" "${ARGS[@]}" || return $?
}









return 0
