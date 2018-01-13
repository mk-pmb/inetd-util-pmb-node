#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function best_avail_cmd () {
  local CMD=
  for CMD in "$@"; do
    [ -n "$CMD" ] || continue
    which "$CMD" 2>/dev/null | grep -m 1 -qPe '^/' && break
  done
  [ -n "$CMD" ] && echo "$CMD"
  # ^-- so put '' as last arg to not echo anything on failure.
}


[ "$1" == --lib ] && return 0; best_avail_cmd "$@"; exit $?
