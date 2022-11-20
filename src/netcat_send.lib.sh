#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function netcat_send__raw () {
  local DEST=
  DEST="$("${FUNCNAME%__*}"__find_dest "$@")" || return $?
  local NC_CMD=(
    netcat
    -w "${TTS[netcat-timeout]:-5}"
    -q "${TTS[netcat-grace]:-1}"
    )
  [ "${DEBUGLEVEL:-0}" -ge 4 ] && NC_CMD=( time "${NC_CMD[@]}" -vvv )
  NC_CMD+=( "${DEST% *}" "${DEST##* }" )
  [ "${DEBUGLEVEL:-0}" -ge 2 ] && echo "D: netcat cmd: ${NC_CMD[*]}" >&2
  # exec < <(tee -- "$HOME/$FUNCNAME.$(date +%H%M%S).$$.txt")
  [ "${DEBUGLEVEL:-0}" -ge 6 ] && exec < <(tee -- /dev/stderr)
  "${NC_CMD[@]}"
  return $?
}


function netcat_send__with_lang () {
  local INPUT="${TTS[text]}"
  local HEAD="$(<<<"$INPUT" netcat_server__check_msg_head)"
  if [ -z "$HEAD" ]; then
    local LNG="${TTS[lang]:-unknown}"
    INPUT="SPEAK /$LNG NOT/HTTP"$'\r\n\r\n'"$INPUT"
  fi
  <<<"$INPUT" "${FUNCNAME%__*}"__raw "$@"
  return $?
}


function netcat_send__find_dest () {
  local DEST_HOST="${1:-localhost}"; shift
  local DEST_DOMAIN="${TTS[netcat-domain]}"
  case "$DEST_HOST" in
    :* ) DEST_HOST="${TTS[netcat-dest$DEST_HOST]}";;
  esac
  case "$DEST_HOST" in
    .*:* )
      # e.g. .local:~/.config/bluetooth/headphones.host
      DEST_DOMAIN="${DEST_HOST%%:*}"
      DEST_HOST="${DEST_HOST#*:}"
      ;;
    .* )
      DEST_DOMAIN="$DEST_HOST"
      DEST_HOST="$1"; shift
      ;;
  esac
  local DEST_PORT="$1"; shift
  if [ -z "$DEST_PORT" ]; then
    DEST_PORT="${DEST_HOST##*:}"
    case "$DEST_PORT" in
      *[^0-9]* ) DEST_PORT=;;
      *[0-9]* ) DEST_HOST="${DEST_HOST%:*}";;
    esac
  fi
  [ -n "$DEST_PORT" ] || DEST_PORT="${TTS[netcat-port]}"
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

  echo "$DEST_HOST $DEST_PORT"
}


function netcat_grab_refine_send () {
  local DEST_SPEC="$1"; shift
  local DEST_ADDR="$(netcat_send__find_dest "$DEST_SPEC")"
  [ -n "$DEST_ADDR" ] || return 4$(
    echo "E: $FUNCNAME: Cannot resolve destination: ${DEST_SPEC:-(empty)}" >&2)
  dbgp 4 "D: $FUNCNAME: gonna grab:"
  grab_text "$@" || return $?
  dbgp 4 "D: $FUNCNAME: stash head:"
  netcat_server__stash_msg_head \
    refine_text_by_scripts__langdirs --guess || return $?
  dbgp 4 "D: $FUNCNAME: gonna send:"
  netcat_send__with_lang "${DEST_ADDR% *}" "${DEST_ADDR##* }" || return $?
  dbgp 4 "D: $FUNCNAME: done."
}










[ "$1" == --lib ] && return 0; netcat_send__cli_not_impl "$@"; exit $?
