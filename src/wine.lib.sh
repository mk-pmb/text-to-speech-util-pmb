#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function wineboot_update_disabled () {
  local UPD_FN="$WINEPREFIX"/.update-timestamp
  local UPD_TS="$([ -f "$UPD_FN" ] && head --bytes=16 -- "$UPD_FN")"
  [ "$UPD_TS" == disable ]; return $?
}









[ "$1" == --lib ] && return 0; "$@"; exit $?
