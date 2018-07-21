#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function veng_wine_stdin__prepare () {
  local VOICE="$1"; shift
  local ENGINE="${TTS[$VOICE:engine]}"
  local WPFX="${TTS[$ENGINE:wpfx]}"
  local LOG_PFX=": voice '$VOICE', using engine '$ENGINE':"

  local WINE_PID="${TTS[$VOICE:wine_pid]}"
  if [ -n "$WINE_PID" ]; then
    kill -0 "$WINE_PID" &>/dev/null && return 0
    local MSG_CNT="${TTS[$VOICE:wine_cnt]}"
    echo "I$LOG_PFX child $WINE_PID finished after $MSG_CNT texts."
    [ "$MSG_CNT" -ge 1 ] || return 4$(
      echo "E$LOG_PFX It quit w/o reading anything? probably a crash." >&2)
  fi

  [ "$1" == --check-alive ] && return 2

  [ -d "$WPFX" ] || return 3$(
    echo "E$LOG_PFX wine prefix seems to not be a directory: $WPFX" >&2)
  local WARCH="${TTS[$ENGINE:warch]:-win32}"

  printf 'I%s %(%T)T gonna update the wine prefix.\n' "$LOG_PFX" -1
  veng_wine_stdin__exec --wineboot-update &
  # update the wpfx sync to avoid conflicts and repeated effort by multiple
  # vengs using the same wpfx trying to update it in parallel.
  wait $! || return $?

  local WINE_CMD=( wine "${TTS[$ENGINE:exe]}" )
  local WINE_STDIN_FD=
  exec {WINE_STDIN_FD}> >(veng_wine_stdin__exec "${WINE_CMD[@]}" "$@")
  WINE_PID=$!
  echo "I$LOG_PFX fd $WINE_STDIN_FD = wine pid $WINE_PID"
  TTS["$VOICE":wine_fd]="$WINE_STDIN_FD"
  TTS["$VOICE":wine_pid]="$WINE_PID"
  TTS["$VOICE":wine_cnt]=0

  local PIPE_INIT=()
  local TX="${TTS[$VOICE:pipe_init_pre]}"
  [ -n "$TX" ] && PIPE_INIT+=( "$TX" )
  PIPE_INIT+=( "${VWS_INIT[@]}" )
  TX="${TTS[$VOICE:pipe_init_post]}"
  [ -n "$TX" ] && PIPE_INIT+=( "$TX" )
  if [ -n "${PIPE_INIT[*]}" ]; then
    printf '%s\n' "${PIPE_INIT[@]}" >&"${TTS[$VOICE:wine_fd]}"
    sleep "${TTS[$VOICE:pipe_init_delay]:-1s}" # win race condition
  fi
}


function veng_wine_stdin__exec () {
  local WINECMD=( "$@" )
  export WINEPREFIX="$WPFX"
  export WINEARCH="$WARCH"
  local VOICE="$VOICE"
  local WINEDEBUG="$WINEDEBUG"
  local DLLOVR="$WINEDLLOVERRIDES"
  [ -n "$WINEDEBUG" ] || WINEDEBUG=fixme-all
  local PRE_EVAL="$VWS_PREWINE_EVAL"

  case "$1" in
    --wineboot-update )
      VOICE+=" (wineboot)"
      wineboot_update_disabled && return 0$(
        echo "D: voice '$VOICE': skip: .update-timestamp set to 'disable'" >&2)
      WINECMD=(
        "$WPFX"/wineboot-update-fixed{,.sh,.pl,.py}
        wineboot-update-fixed
      )
      WINECMD=( "$(which "${WINECMD[@]}" |& grep -Pe '^/' -m 1 \
        || echo wineboot)" --update )
      PRE_EVAL="$VWS_PREWINEBOOT_EVAL"
      grep -qxFe '"ShowCrashDialog"=dword:00000000' -- "$WPFX"/user.reg \
        || echo "H: voice '$VOICE':" \
          "consider disabling the GUI crash dialog." \
          "(util/wine/disable_gui_crash_dialog.reg)" \
          >&2
      ;;
  esac

  export WINEDEBUG
  export WINEDLLOVERRIDES="${DLLOVR#;}"
  exec &> >(sed -ure "s~^~D: voice '$VOICE': ~")
  eval "$PRE_EVAL"
  cd "${VWS_PRE_CHDIR:-/}" || return $?
  exec "${WINECMD[@]}"
  echo "E: failed to exec ${WINECMD[*]}: rv=$RV" >&2
  return 3
}


function veng_wine_stdin__raw () {
  local VOICE="$1"; shift
  local LOG_PFX=": voice '$VOICE':"
  local INPUT="$(cat)"
  [ -n "$INPUT" ] || return 2$(echo "E$LOG_PFX: no input" >&2)
  local WINE_FD="${TTS[$VOICE:wine_fd]}"
  [ "${WINE_FD:-0}" -ge 1 ] || return 4$(echo "E$LOG_PFX: no wine_fd yet" >&2)
  local MSG_CNT="${TTS[$VOICE:wine_cnt]}"
  let MSG_CNT="$MSG_CNT+1"
  TTS["$VOICE":wine_cnt]="$MSG_CNT"
  local PIPE_FD="${TTS[$VOICE:wine_fd]}"
  ( [ -z "${VWS_HEAD[*]}" ] || printf '%s\n' "${VWS_HEAD[@]}"
    echo "$INPUT"
    [ -z "${VWS_TAIL[*]}" ] || printf '%s\n' "${VWS_TAIL[@]}"
    true
  ) >&"$PIPE_FD" || return $?$(
    echo "E: $FUNCNAME: failed to write to FD $PIPE_FD" >&2)
  return 0
}


function veng_wine_stdin__base64 () {
  # base64: to shield against wine trying to be clever and translating
  # UTF-8 to MSDOS ASCII
  base64 --wrap=252 | veng_wine_stdin__raw "$@"
}


function veng_wine_stdin__release () {
  local VOICE="$1"; shift
  local OPT="$1"; shift
  local PIPE_FD="${TTS[$VOICE:wine_fd]}"
  if [ -n "$PIPE_FD" ]; then
    echo "I: releasing voice '$VOICE'."
    exec {PIPE_FD}>&- || return $?
    TTS["$VOICE:wine_fd"]=
  fi
  case "$OPT" in
    --wait )
      local WINE_PID="${TTS[$VOICE:wine_pid]}"
      if [ -n "$WINE_PID" ] && kill -0 "$WINE_PID" &>/dev/null; then
        echo "I: voice '$VOICE': waiting for engine to quit… (pid=$WINE_PID)"
        # ps --no-headers -o user,pid,ppid,args "$WINE_PID" "$BASHPID"
        while kill -0 "$WINE_PID" &>/dev/null; do sleep 0.5s; done
      fi
      TTS["$VOICE:wine_pid"]=
      ;;
  esac
}


return 0
