#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function fifo_repl () {
  local REPL_PIPE="$1"; shift
  [ -p "$REPL_PIPE" ] || [ -c "$REPL_PIPE" ] || \
    mkfifo -- "$REPL_PIPE" || return $?
  local REPL_CMD=
  local REPL_RETRY='20s'
  while [ -p "$REPL_PIPE" ] || [ -c "$REPL_PIPE" ]; do
    if ! read -rs REPL_CMD <"$REPL_PIPE"; then
      echo "W: Failed to read from REPL input '$REPL_PIPE'," \
        "will retry in $REPL_RETRY." >&2
      sleep "$REPL_RETRY"
      continue
    fi
    REPL_CMD="${REPL_CMD%$'\r'}"
    case "$REPL_CMD" in
      pid ) echo "REPL pid = $$";;
      unrepl | Q ) return 0;;
      rmrepl | Qr )
        rm -- "$REPL_PIPE"
        return 0;;
      panic | flinch | DIE ) exit 42;;
      * ) eval "$REPL_CMD";;
    esac
  done
  echo "E: REPL input '$REPL_PIPE' is not a" \
    "named pipe or character device." \
    "(If you deleted it, read the README.)" >&2
  return 4
}


[ "$1" == --lib ] && return 0; fifo_repl "$@"; exit $?
