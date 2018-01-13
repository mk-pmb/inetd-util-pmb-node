#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function bash_repl () {
  local REPL_PIPE="$1"; shift
  [ "$REPL_PIPE" == - ] && REPL_PIPE=/dev/stdin
  bash_repl_valid_input_file "$REPL_PIPE" ] \
    || mkfifo -- "$REPL_PIPE" || return $?$(
    echo "E: Failed to create the REPL input pipe '$REPL_PIPE'." >&2)

  [ -n "$REPL_RETRY_DELAY" ] || local REPL_RETRY_DELAY='10s'
  local REPL_READFAILS=0
  [ "${REPL_MAX_READFAILS:-0}" -gt 0 ] || local REPL_MAX_READFAILS=3

  local REPL_CMD=
  echo "D: Starting REPL#$$ on '$REPL_PIPE'." >&2
  while bash_repl_valid_input_file "$REPL_PIPE"; do
    REPL_CMD=
    case "$REPL_PIPE" in
      /dev/stdin ) read -rs REPL_CMD;;    # cant "<" sockets
      /dev/fd/* ) read -rs -u "${REPL_PIPE#/dev/fd/}" REPL_CMD;;
      * ) read -rs REPL_CMD <"$REPL_PIPE";;
    esac
    if [ -z "$REPL_CMD" ]; then
      let REPL_READFAILS="$REPL_READFAILS+1"
      echo -n "W: Failed to read from REPL#$$ input '$REPL_PIPE'" \
        "had $REPL_READFAILS/$REPL_MAX_READFAILS fails" \
        "(at $(date +'%F %T'), " >&2
      if [ "$REPL_READFAILS" -lt "$REPL_MAX_READFAILS" ]; then
        echo "will retry in $REPL_RETRY_DELAY." >&2
        sleep "$REPL_RETRY_DELAY"
        continue
      fi
      echo "giving up." >&2
      return 8
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
  echo "E: Invalid input file '$REPL_PIPE' for REPL with pid $$." \
    "(If you deleted it, read the README.)" >&2
  return 4
}


function bash_repl_valid_input_file () {
  # Make sure it's something that forgets the bytes that we've consumed.
  [ -r "$1" ] || return 2   # must be readable
  [ -p "$1" ] && return 0   # named pipe is ok
  [ -c "$1" ] && return 0   # character device is ok
  [ -S "$1" ] && return 0   # socket is ok
  return 2  # anything else is probably not a good idea.
}


[ "$1" == --lib ] && return 0; bash_repl "$@"; exit $?
