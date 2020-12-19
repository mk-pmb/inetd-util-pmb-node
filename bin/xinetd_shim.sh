#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-

function xinetd_shim () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local -A CFG=( [file]="$1" ); shift
  [ -f "${CFG[file]}" ] || return 3$(
    echo "E: cannot find config file: ${CFG[file]:-(none)}" >&2)
  local SET_ENV=()
  eval "$(sed -nrf <(echo '
    s~\x27~\x27\\\x27\x27~g
    s~$~\x27~
    s!^\s+([a-z_]+)\s+=\s+!CFG[\1]=\x27!p
    /^\s+env\s\+=\s+/{
      s!^[^=]+=\s+!!
      /^LSN_ADDR=/d
      /^LSN_PORT=/d
      s!$! )!
      s!^!SET_ENV+=( \x27!p
    }
    ') -- "${CFG[file]}")"
  # local -p
  SET_ENV+=( "LSN_PORT=${CFG[port]}" )
  local SU_CMD=(
    sudo
    --user="${CFG[user]}"
    --set-home
    env - "${SET_ENV[@]}"
    "${CFG[server]}" ${CFG[server_args]}
    )
  echo -n "D: gonna exec:" >&2
  printf ' ‹%s›' "${SU_CMD[@]}" >&2
  echo >&2
  exec "${SU_CMD[@]}" || return $?
}

xinetd_shim "$@"; exit $?
