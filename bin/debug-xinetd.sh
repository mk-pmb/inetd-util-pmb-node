#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-

function debug_xinetd () {
  local PRE_SEL="${1:-h}"; shift
  [ -n "$LOGFN" ] || local LOGFN="$HOME/xinetd.debug.log"

  local SELFPATH="$(readlink -m "$BASH_SOURCE"/..)"
  local PSCOLS=1-
  local KILLALL=
  local SEL=
  local HELP_HINT=
  while true; do
    if [ -n "$PRE_SEL" ]; then
      SEL="${PRE_SEL:0:1}"
      PRE_SEL="${PRE_SEL:1}"
    fi
    KILLALL=
    case "$SEL" in
    h ) <<<'list debug commands'
      echo "H: available commands:"
      local -fp "${FUNCNAME[0]}" | sed -nrf "$SELFPATH/help_hints.sed"
      [ "$*" == --help ] && return 0
      ;;
    d ) <<<"
        run xinetd in debug mode.
        stop with [enter] or a debug command.
        "
      enum_xinetd_procs --stop
      if ps --no-headers -w -o user,pid,args -C xinetd; then
        echo "E: flinching: some earlier xinetd is still alive" >&2
      else
        socat EXEC:'sudo xinetd -d',pty,ctty,setsid STDOUT \
          | "$SELFPATH"/unclutter-xinetd-debug-log.sed | tee -- "$LOGFN" &
      fi
      KILLALL=XD
      ;;
    l ) <<<'show log'
      less -S -- "$LOGFN";;
    S ) <<<'stop xinetd-related processes'
      enum_xinetd_procs --stop;;
    p ) <<<'enumerate xinetd-related processes'
      enum_xinetd_procs;;
    t ) <<<'show xinetd-related processes as a tree'
      xinetd_procs_tree;;
    N ) <<<'show nodejs-related processes as a tree'
      xinetd_procs_tree 'node,nodejs';;
    q ) <<<'quit debugging'
      return 0;;
    R ) <<<'restart regular xinetd service, then quit debugging.'
      sudo service xinetd restart
      return 0;;
    * )
      echo "E: unknown command: '$SEL'" >&2
      PRE_SEL="h$PRE_SEL"
      continue;;
    esac

    [ -n "$PRE_SEL" ] || read -r -p '> ' SEL || SEL=q
    case "$KILLALL" in
      XD ) enum_xinetd_procs --stop;;
    esac
    wait
  done

  return 0
}


function psl () {   # ps list
  ps who user,pid,sid,args "$@" | tr -s ' ' ' ' | cut -d ' ' -f "$PSCOLS"
  return ${PIPESTATUS[0]}
}


function xinetd_procs_tree () {
  local CMDNAME="${1:-xinetd}"
  local XD_PIDS=( $( ps ho pid -C "$CMDNAME" ) )
  local OPT=(
    --arguments
    --long
    --ascii
    --show-pids
    --show-pgids
    # --show-parents
    --uid-changes
    --numeric-sort
    )
  local ITEM=
  for ITEM in "${XD_PIDS[@]}"; do
    pstree "${OPT[@]}" "$ITEM"
  done
}


function psnc () {   # ps numbers, comma-separated
  local PSL="$(ps ho "$@" | tr -cd '0-9\n')"
  [ -n "$PSL" ] || return 2
  echo "${PSL//$'\n'/,}"
}


function enum_xinetd_procs () {
  local XD_PIDS="$(psnc pid -C xinetd)"
  [ -n "$XD_PIDS" ] || return 2$(
    echo 'W: cannot find any running xinetd process' >&2)
  echo "xinetd instances: ${XD_PIDS//,/ }"
  local PS_COLS='user,pid,ppid,sid,args'
  ps who "$PS_COLS" --pid "$XD_PIDS"
  echo -n 'services:'
  local SVC_PIDS="$(psnc pid --ppid "$XD_PIDS")"
  if [ -n "$SVC_PIDS" ]; then
    echo " ${SVC_PIDS//,/ }"
    ps who "$PS_COLS" --pid "$SVC_PIDS"
  else
    echo " (none)"
  fi
  if [ "$1" == --stop ]; then
    if [ -n "$XD_PIDS" ]; then
      echo -n 'stop xinetd instances: '
      sudo service xinetd stop
      hupkill "$XD_PIDS"
    fi
    if [ -n "$SVC_PIDS" ]; then
      echo -n 'stop services: '
      hupkill "$SVC_PIDS"
      SVC_PIDS="$(psnc pid --sid "$SVC_PIDS")"
    fi
    if [ -n "$SVC_PIDS" ]; then
      echo -n 'stop stubborn services offspring: '
      hupkill "$SVC_PIDS"
    fi
  fi
}


function hupkill () {
  local STILL_ALIVE="$1"
  [ -n "$STILL_ALIVE" ] || return 0
  local CTD=
  for SIGNAL in HUP TERM KILL ''; do
    if [ -n "$CTD" ]; then
      echo -n count-down
      [ -n "$SIGNAL" ] && echo -n " for $SIGNAL"
      echo -n ':'
      while [ "$CTD" -gt 0 ]; do
        echo -n " $CTD…"
        sleep 1s
        let CTD="$CTD-1"
        STILL_ALIVE="$(psnc pid --pid "$STILL_ALIVE")"
        if [ -z "$STILL_ALIVE" ]; then
          echo ' all dead.'
          return 0
        fi
      done
      echo
    fi
    CTD=5
    echo -n "sending $SIGNAL signal to $STILL_ALIVE: "
    sudo kill -"$SIGNAL" ${STILL_ALIVE//,/ }
  done
  echo "survivors: $STILL_ALIVE"
}
















debug_xinetd "$@"; exit $?
