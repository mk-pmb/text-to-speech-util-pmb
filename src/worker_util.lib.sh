#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function worker_util__maybe_redir_all_output_to_logfile () {
  local LOG_FN="$1"
  [ -n "$LOG_FN" ] || return 0
  LOG_FN="${LOG_FN//%(LOG_PID)S/$LOG_PID}"
  LOG_FN="${LOG_FN//%(PID)S/$$}"
  printf -v LOG_FN "$LOG_FN"
  case "$LOG_FN" in
    '~/'* ) LOG_FN="$HOME${LOG_FN:1}";;
  esac
  mkdir --parents -- "$(dirname -- "$LOG_FN")"
  exec &>>"$LOG_FN" || return $?
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









return 0
