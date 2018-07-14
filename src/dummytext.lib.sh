#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function dummytext () {
  local TX_LANG="$1"; shift
  case "$TX_LANG" in
    demo )
      TX_LANG="$1"; shift
      grab_text dummytext "$TX_LANG" && setvoice _guess \
        && pipe_text nl -ba && pipe_text speak_stdin "$@"
      return $?;;
  esac
  [ -n "$TX_LANG" ] || TX_LANG="$LANGUAGE"

  local TX="$(LANGUAGE="$TX_LANG" man --help | LANG=C sed -re '
    :read_all
    $!{N;b read_all}
    s~\n {8,}~ ~g
    ' | sed -nre '
    s~\t~    ~g
    s~\[~~g
    s~\]~~g
    s~\b[A-Z]{3,}\b~\L&\E~g
    s~\(s\)([^A-Za-z]|$)~\1~g
    s~^ {2}(-[A-Za-z], |)-{2}([a-z-]{2,})(=\S+|)\s{3,}(\S)~\2\t\U\4\E~p
    ' | LANG=C sort)"

  local EXCERPT=(
    all
    debug
    default
    encoding
    locale
    pager
    prompt
    )
  [ "$2" == +all ] || TX="$(<<<"$TX" LANG=C grep -Fe "$(
    printf '%s\t\n' "${EXCERPT[@]}")" | cut -sf 2-)"

  <<<"$TX" LANG=C sed -re 's~$~.~'
  return 0
}










[ "$1" == --lib ] && return 0; dummytext "$@"; exit $?
