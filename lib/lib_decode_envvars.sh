#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function import_decode_envvars () {
  local VARS=() KEY= VAL= CODEC=

  # first, import all LV_ vars to CFG, so we can unset them.
  for KEY in "${LW_VARNAMES[@]}"; do
    VAL=
    eval VAL='$'"$KEY"
    KEY="${KEY#LW_}"
    KEY="${KEY,,}"
    CFG["$KEY"]="$VAL"
  done

  readarray -t VARS <<<"${LW_ENVDEC//[: ]/$'\n'}"
  for KEY in "${VARS[@]}"; do
    [ -n "$KEY" ] || continue
    KEY="${KEY,,}"
    KEY="${KEY#lw_}"
    VAL="${CFG[$KEY]}"
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
    CFG["$KEY"]="$VAL"
  done
  [ "$LW_FUNC" == "$FUNCNAME" ] && declare -pA
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


[ "$1" == --lib ] && return 0; import_decode_envvars "$@"; exit $?
