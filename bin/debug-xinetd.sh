#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-

function debug_xinetd () {
  [ -n "$LOGFN" ] || local LOGFN="$HOME/xinetd.debug.log"

  sudo service xinetd stop
  sudo killall xinetd
  socat EXEC:'sudo xinetd -d',pty,ctty,setsid STDOUT | tee -- "$LOGFN" &

  head -n 1 >/dev/null
  sudo killall xinetd
  wait

  less -S -- "$LOGFN"
  return 0
}

debug_xinetd "$@"; exit $?
