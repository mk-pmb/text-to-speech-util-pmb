#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function netcat_send () {
  local DEST_HOST="${1:-localhost}"; shift
  local DEST_DOMAIN="${TTS[netcat-domain]}"
  case "$DEST_HOST" in
    .* )
      DEST_DOMAIN="$DEST_HOST"
      DEST_HOST="$1"; shift
      ;;
  esac
  local DEST_PORT="${1:-${TTS[netcat-port]}}"; shift
  [ -n "$HOSTNAME" ] || local HOSTNAME="$(hostname --short)"

  case "$DEST_HOST" in
    '~/'* ) DEST_HOST="$HOME${DEST_HOST:1}";;
  esac
  case "$DEST_HOST" in
    */* ) DEST_HOST="$(grep -xPe '[A-Za-z0-9_\.:\-]+' -m 1 -- "$DEST_HOST")";;
  esac
  case "$DEST_HOST" in
    *.* | *:* ) ;;
    *[a-z]* ) DEST_HOST+="$DEST_DOMAIN";;
  esac
  case "$DEST_HOST" in
    "$HOSTNAME".local | \
    "$HOSTNAME" )
      # Don't involve avahi unless we have to.
      # Also fixes issues with number-suffixed avahi hostnames.
      DEST_HOST='127.0.0.1';;
  esac
  [ -n "$DEST_HOST" ] || return 5$(echo "E: no destination host given" >&2)

  local NC_CMD=(
    netcat
    -w "${TTS[netcat-timeout]:-5}"
    -q "${TTS[netcat-grace]:-1}"
    "$DEST_HOST" "$DEST_PORT"
    )
  [ "${DEBUGLEVEL:-0}" -ge 2 ] && echo "D: netcat cmd: ${NC_CMD[*]}" >&2
  "${NC_CMD[@]}"
  return $?
}










[ "$1" == --lib ] && return 0; netcat_send "$@"; exit $?
