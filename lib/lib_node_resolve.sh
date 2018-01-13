#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function node_resolve () {
  local RESO='require.resolve(process.argv[1])'
  local NAMES=()
  readarray -t NAMES <<<"${*//[: ]/$'\n'}"
  local PKG=
  for PKG in "${NAMES[@]}"; do
    [ -n "$PKG" ] || continue
    "$NODEJS_CMD" -p "$RESO" -- "$PKG" 2>/dev/null && return 0
  done
  return 2
}


[ "$1" == --lib ] && return 0; node_resolve "$@"; exit $?
