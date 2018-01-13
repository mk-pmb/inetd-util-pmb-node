#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function decode_envvars () {
  local VARS=() KEY= VAL= CODEC=
  readarray -t VARS <<<"${LW_ENVDEC//[: ]/$'\n'}"
  for KEY in "${VARS[@]}"; do
    eval VAL='$'"{$KEY}"
    CODEC="${VAL%%:*}"
    [ "$CODEC" == "$VAL" ] && continue
    VAL="${VAL#*:}"
    case "$CODEC" in
      # appended commas are required to preserve trailing newline
      base64 )    VAL="$(unbase64 "$VAL"                    ; echo ,)";;
      printf )    VAL="$(printf "$VAL"                      ; echo ,)";;
      url )       VAL="$(printf '%s' "$VAL" | urldecode     ; echo ,)";;
      * ) CODEC=;;
    esac
    [ -n "$CODEC" ] && VAL="${VAL%,}"
    case "$KEY" in
      KW_* )
        KEY="${KEY#KW_}"
        KEY="${KEY,,}"
        CFG["$KEY"]="$VAL";;
      * )
        eval "$KEY"='$VAL'
        export "$KEY"
        declare -px | grep -Fe "$KEY=" -A 1 >&2
    esac
  done
  if [ "$LW_FUNC" == "$FUNCNAME" ]; then
    declare -pA
  fi
  return 0
}


function unbase64 () {
  # https://tools.ietf.org/html/rfc4648#section-5
  local INPUT="$*"
  INPUT="${INPUT//\-/\+}"
  INPUT="${INPUT//_/\/}"
  local PAD="${#INPUT}"
  let PAD="$PAD % 4"
  [ "$PAD" == 3 ] && INPUT+='='
  [ "$PAD" == 2 ] && INPUT+='=='
  # PAD=1: that's three quaters of a character, aka just plain broken.
  <<<"$INPUT" base64 --decode --ignore-garbage
}


function urldecode () { perl -pe 's~%([0-9a-f]{2})~chr hex $1~sieg'; }


[ "$1" == --lib ] && return 0; decode_envvars "$@"; exit $?
