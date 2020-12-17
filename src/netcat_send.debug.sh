#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-

function ncsend () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local DEST_HOST="$1"; shift
  local DEST_PORT="$1"; shift
  local LNG="$1"; shift
  local MSG="SPEAK /$LNG NOT/HTTP"$'\n\n'"$*"
  <<<"$MSG" netcat -q 2 -vvvv "$DEST_HOST" "$DEST_PORT"
}

ncsend "$@"; exit $?
