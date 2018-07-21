#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function sha_gz () {
  local EXE=
  local SHA=
  for EXE in *.exe; do
    SHA="$(sha1sum --binary "$EXE" | grep -oPe '^[0-9a-fA-F]{8}' -m 1)"
    [ -n "$SHA" ] || return 2
    gzip --keep --stdout "$EXE" >"$EXE.$SHA.gz" || return $?
  done
  chmod a-x -- *.gz
  return 0
}










[ "$1" == --lib ] && return 0; sha_gz "$@"; exit $?
