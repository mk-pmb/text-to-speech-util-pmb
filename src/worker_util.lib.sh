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
  local FN="$1" OPT=",$2,"
  [ -n "$FN" ] || return 0
  FN="${FN//%(LOG_PID)S/$LOG_PID}"
  FN="${FN//%(PID)S/$$}"

  case "$FN" in
    *'%(PGID)S'* )
      local PGID="$(worker_util__getpgid)"
      FN="${FN//%(PGID)S/$PGID}";;
  esac

  case "$FN" in
    '~/'* ) FN="$HOME${FN:1}";;
  esac
  [[ "$OPT" == *,noprintf,* ]] || printf -v FN "$FN"
  [ -n "$FN" ] || return 3$(
    echo "E: failed to determine filename from pattern" >&2)
  echo "$FN"
}


function worker_util__maybe_redir_all_output_to_logfile () {
  [ -n "$LOG_PID" ] || local LOG_PID=$$
  [ -n "$PGID" ] || local PGID="$(worker_util__getpgid)"
  local LOG_FN_PAT="$(worker_util__render_filename_template "$1" noprintf)"
  [ -n "$LOG_FN_PAT" ] || return 0
  worker_util__logfile_reopen_once || return $?
  exec &>> >(worker_util__logfile_reopen_copyloop) || return $?
}


function worker_util__logfile_reopen_once () {
  local LOG_FN=
  printf -v LOG_FN "$LOG_FN_PAT"
  [ -n "$LOG_FN" ] || return 3$(echo 'E: empty logfile filename' >&2)
  mkdir --parents -- "$(dirname -- "$LOG_FN")"
  exec &>>"$LOG_FN" || return $?
  [ -s "$LOG_FN" ] || echo "pgid $PGID pid $$: Log (re)start," \
    "log pid: ${LOG_PID:-not set}, log pgid: ${LOG_PGID:-not set}"
}


function worker_util__logfile_reopen_copyloop () {
  local REOPENER_PID=$$
  local REOPEN_SEC="${TTS[logfile-reopen-sec]:-10}"
  local REOPEN_MAX_LN="${TTS[logfile-reopen-lines]:-50}"
  local REOPEN_RMN_LN=0
  local RD_BUF= RD_RV= AT_START_OF_LINE=+
  while true; do
    IFS= read -r -n 1 RD_BUF
    RD_RV=$?
    case "$RD_RV" in
      0 ) ;;
      1 ) # eof
        kill -0 "$LOG_PID" &>/dev/null || return 0$(
          echo "D: log copyloop terminating: no more input" \
            "and log pid $LOG_PID died" >&2)
        sleep 0.1s
        continue;;
      * )
        echo "E: log copyloop terminating: input error $RD_RV" >&2
        return 8;;
    esac

    if [ -n "$RD_BUF" ]; then
      # We just read something other than a newline
      if [ -n "$AT_START_OF_LINE" ]; then
        [ -n "$REOPEN_SEC" -a "$SECONDS" -ge "$REOPEN_SEC" ] && REOPEN_RMN_LN=0
        if [ "$REOPEN_RMN_LN" -lt 1 ]; then
          SECONDS=0
          REOPEN_RMN_LN="$REOPEN_MAX_LN"
          worker_util__logfile_reopen_once
        fi
        printf '%(%y%m%d-%H%M%S)T ' -1
        AT_START_OF_LINE=
      fi
      echo -n "$RD_BUF"
      continue
    fi

    # We just read a newline
    [ -n "$AT_START_OF_LINE" ] && continue
    echo
    AT_START_OF_LINE=+
    (( REOPEN_RMN_LN -= 1 ))
  done
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
