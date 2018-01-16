#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function multisource () {
  local SRCS=() SRC=
  readarray -t SRCS <<<"${*//[: ]/$'\n'}"
  local NONFILE=
  for SRC in "${SRCS[@]}"; do
    NONFILE=fail
    case "$SRC" in
      '?'* ) NONFILE=skip; SRC="${SRC:1}";;
      '' ) continue;;
    esac
    case "$SRC" in
      '~'/* ) SRC="$HOME/${SRC#*/}";;
    esac
    if [ ! -f "$SRC" ]; then
      [ "$NONFILE" == skip ] && continue
      echo "E: Won't source non-file '$SRC'" >&2
      return 3
    fi
    source "$SRC" || return $?$(echo "E: Failed to source '$SRC'" >&2)
  done
  return 0
}


[ "$1" == --lib ] && return 0; multisource "$@"; exit $?
