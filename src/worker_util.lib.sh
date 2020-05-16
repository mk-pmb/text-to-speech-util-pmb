#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function worker_util__getpgid () {
  local PGID="$(ps ho pgid $$)"
  PGID="${PGID//[^0-9]/}"
  [ -n "$PGID" ] && echo "$PGID"; return $?
}


function worker_util__lockfile_action () {
  local LOCK_FN="$1"; shift
  local ACTION="$1"; shift
  local KILL_TOUCHER=
  local LK_OPT='--use-pid'
  case "$ACTION" in
    create )
      mkdir --parents -- "$(dirname -- "$LOCK_FN")"
      LK_OPT+=' --retry 0';;
    touch ) LK_OPT=;;
    remove ) LK_OPT=; KILL_TOUCHER='HUP';;
    check ) KILL_TOUCHER=0;;
  esac
  [ -z "$KILL_TOUCHER" ] || kill -"$KILL_TOUCHER" -- "${1:-NO_TOUCHER_PID}" \
    || return 3$(echo "E: failed to $ACTION lockfile toucher" >&2)
  lockfile-"$ACTION" --verbose $LK_OPT --lock-name "$LOCK_FN" || return $?
}


function worker_util__render_filename_template () {
  local FN="$1"
  [ -n "$FN" ] || return 0
  FN="${FN//%(LOG_PID)S/$LOG_PID}"
  FN="${FN//%(PID)S/$$}"

  case "$FN" in
    *'%(PGID)S'* )
      local PGID="$(worker_util__getpgid)"
      FN="${FN//%(PGID)S/$PGID}";;
  esac

  printf -v FN "$FN"
  case "$FN" in
    '~/'* ) FN="$HOME${FN:1}";;
  esac
  echo "$FN"
}


function worker_util__maybe_redir_all_output_to_logfile () {
  local LOG_FN="$(worker_util__render_filename_template "$1")"
  [ -n "$LOG_FN" ] || return 0
  mkdir --parents -- "$(dirname -- "$LOG_FN")"
  exec &>>"$LOG_FN" || return $?
  printf '%(%F %T)T pgid %s pid %s: Log (re)start' -1 "$$" "$PGID"
  echo ", log pid: ${LOG_PID:-not set}, log pgid: ${LOG_PGID:-not set}"
}


function worker_util__self_limit () {
  local CFG_PREFIX="$1"

  local ADJ="${TTS[${CFG_PREFIX}oom-score-adjust]}"
  # Valid range is -1000..+1000.
  # Use a high value to have your TTS killed first in case of OOM.
  ADJ="${ADJ#+}"
  [ -z "$ADJ" ] || echo "$ADJ" >/proc/$$/oom_score_adj || return $?

  local ADJ="${TTS[${CFG_PREFIX}renice]}"
  [ -z "$ADJ" ] || renice --priority "$ADJ" --pid $$ || return $?

  local ADJ="${TTS[${CFG_PREFIX}ulimit]}"
  [ -z "$ADJ" ] || ulimit $ADJ || return $?
}


function worker_util__ensure_pgroup_leader () {
  local PGPS="$(ps o pid,ppid,pgid,comm -$$)"
  local VERIFY='
    s~\s+~ ~g
    1{/^ ?PID /d}
    s~^ ?'"$$ $PPID $$"' .*$~self~
    s~^ ?[0-9]+ '"$$ $$"' ps$~ps~
    '
  VERIFY="$(<<<"$PGPS" sed -re "$VERIFY")"
  case "$VERIFY" in
    $'self\nps' | $'ps\nself' ) ;;
    * )
      echo "W: Process group for pid $$ consists of:" >&2
      <<<"$PGPS" sed -re 's~^~W:  ~' >&2
      echo "E: Found unexpected process(es) in our (pid $$) process group!" >&2
      return 4;;
  esac
}









return 0
