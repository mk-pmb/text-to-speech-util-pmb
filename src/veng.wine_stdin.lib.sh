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

  [ -d "$WPFX" ] || return 3$(
    echo "E$LOG_PFX wine prefix seems to not be a directory: $WPFX" >&2)
  local WARCH="${TTS[$ENGINE:warch]:-win32}"

  veng_wine_stdin__exec wineboot -u &
  # update the wpfx sync to avoid conflicts and repeated effort by multiple
  # vengs using the same wpfx trying to update it in parallel.
  wait $! || return $?

  local WINE_CMD=( exec wine "${TTS[$ENGINE:exe]}" )
  local WINE_STDIN_FD=
  exec {WINE_STDIN_FD}> >(veng_wine_stdin__exec "${WINE_CMD[@]}" "$@")
  WINE_PID=$!
  echo "I$LOG_PFX fd $WINE_STDIN_FD = wine pid $WINE_PID display=$DISPLAY"
  TTS["$VOICE":wine_fd]="$WINE_STDIN_FD"
  TTS["$VOICE":wine_pid]="$WINE_PID"
  TTS["$VOICE":wine_cnt]=0
  if [ -n "${VWS_INIT[*]}" ]; then
    printf '%s\n' "${VWS_INIT[@]}" >&"${TTS[$VOICE:wine_fd]}"
    sleep 1s  # win race condition
  fi
}


function veng_wine_stdin__exec () {
  export WINEPREFIX="$WPFX"
  export WINEARCH="$WARCH"
  local VOICE="$VOICE"
  local WINEDEBUG="$WINEDEBUG"
  local DLLOVR="$WINEDLLOVERRIDES"
  [ -n "$WINEDEBUG" ] || WINEDEBUG=fixme-all
  local STOPWATCH=
  local PRE_EVAL="$VWS_PREWINE_EVAL"

  case "$1" in
    wineboot )
      VOICE+=" ($1)"
      STOPWATCH='updating the wine prefix'
      PRE_EVAL="$VWS_PREWINEBOOT_EVAL"
      DLLOVR+=";mscoree,mshtml="
      WINEDEBUG+=",err-winediag"
      export DISPLAY=
      grep -qxFe '"ShowCrashDialog"=dword:00000000' -- "$WPFX"/user.reg \
        || echo "H: voice '$VOICE':" \
          "consider disabling the GUI crash dialog." \
          "(util/wine/disable_gui_crash_dialog.reg)" \
          >&2
      ;;
  esac

  export WINEDEBUG
  export WINEDLLOVERRIDES="${DLLOVR#;}"
  exec &> >(sed -re 's~^~D: voice '"'$VOICE'"': ~')
  if [ -n "$STOPWATCH" ]; then
    printf '%(%T)T start %s.\n' -1 "$STOPWATCH"
    SECONDS=0
  fi
  eval "$PRE_EVAL"
  cd "${VWS_PRE_CHDIR:-/}" || return $?
  "$@"
  local RV=$?
  if [ -n "$STOPWATCH" ]; then
    printf '%(%T)T done  %s after %s sec, rv=%s.\n' -1 \
      "$STOPWATCH" "$SECONDS" "$RV"
  fi

  case "$RV:$1" in
    0:exec ) RV+=' (?!)';;
  esac
  [ "$RV" == 0 ] || echo "E: failed to exec $*: rv=$RV" >&2
  return "$RV"
}


function veng_wine_stdin__base64 () {
  # base64: to shield against wine trying to be clever and translating
  # UTF-8 to MSDOS ASCII
  local VOICE="$1"; shift
  local LOG_PFX=": voice '$VOICE', using engine '$ENGINE':"
  local WINE_FD="${TTS[$VOICE:wine_fd]}"
  [ "${WINE_FD:-0}" -ge 1 ] || return 4$(echo "E$LOG_PFX: no wine_fd yet" >&2)
  local INPUT="$(base64 --wrap=252)"
  [ -n "$INPUT" ] || return 2$(echo "E$LOG_PFX: no input" >&2)
  local MSG_CNT="${TTS[$VOICE:wine_cnt]}"
  let MSG_CNT="$MSG_CNT+1"
  TTS["$VOICE":wine_cnt]="$MSG_CNT"
  ( [ -n "${VWS_HEAD[*]}" ] && printf '%s\n' "${VWS_HEAD[@]}"
    echo "$INPUT"
    [ -n "${VWS_TAIL[*]}" ] && printf '%s\n' "${VWS_TAIL[@]}"
  ) >&"${TTS[$VOICE:wine_fd]}"
}


return 0
