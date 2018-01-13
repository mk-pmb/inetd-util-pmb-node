#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function logwrap () {
  local -A CFG=()
  local SELFPATH="$(readlink -m "$BASH_SOURCE"/..)"
  local LIST=() ITEM= KEY= VAL=
  for ITEM in "$SELFPATH"/../lib/lib_*.sh; do
    source "$ITEM" --lib || return $?
  done

  local LW_VARNAMES=( $(env | grep -oPe '^LW_\w+=' \
    | tr -d '=' | LANG=C sort -Vu) )

  [ -n "$USER" ] || USER="$(whoami)"
  [ -n "$LW_DELAY" ] && sleep "$LW_DELAY"
  [ -n "$LW_UMASK" ] && umask "${LW_UMASK:-0022}"
  if [ -n "$LW_FUNC" ]; then "$LW_FUNC" "$@"; return $?; fi

  if [ -n "$LW_DUMPENV" ]; then
    [ "${LW_DUMPENV:0:1}" == / ] || LW_DUMPENV="/tmp/$LW_DUMPENV"
    case "$LW_DUMPENV" in
      */ )
        mkdir --parents -- "$LW_DUMPENV" 2>/dev/null
        LW_DUMPENV+="$USER.$$.dbg";;
    esac
    logwrap_debug >"$LW_DUMPENV" 2>&1
  fi

  if [ -n "$LW_SYSLOG_TAG" ]; then
    LW_SYSLOG_TAG= "$FUNCNAME" "$@" |& logger --tag "$LW_SYSLOG_TAG"
    return "${PIPESTATUS[0]}"
  fi

  [ -z "${LW_STDERR%.}" ] || exec 2>>"$LW_STDERR" || return $?
  [ -z "$LW_STDOUT" ] || exec 1>>"$LW_STDOUT" || return $?
  [ "$LW_STDERR" == . ] && exec 2>&1

  local NODEJS_BIN=
  for NODEJS_BIN in "$LW_NODEJS" /usr/bin/node{js,}; do
    [ -x "$NODEJS_BIN" ] && break
  done

  # ===== switch to CFG[] ===== ===== ===== ===== ===== #
  decode_envvars
  unset -v LW_DUMMY "${LW_VARNAMES[@]}"

  readarray -t LIST <<<"${CFG[source]//[: ]/$'\n'}"
  for ITEM in "${LIST[@]}"; do
    [ -n "$ITEM" ] || continue
    source "$ITEM"
  done

  if [ -n "${CFG[cwd_resolve]}" ]; then
    CFG[cwd_resolve]="$(node_resolve "${CFG[cwd_resolve]}")"
    [ -n "${CFG[cwd_resolve]}" ] || return $?$(
      echo "E: Unable to resolve any of LW_CWD_RESOLVE. cwd is $PWD" >&2)
    CFG[cwd_resolve]="${CFG[cwd_resolve]}%/*}"
    cd -- "${CFG[cwd_resolve]}" || return $?$(echo "H: cwd is $PWD" >&2)
    # you can still refine this path with LW_CWD
  fi
  [ -z "${CFG[cwd]}" ] || cd -- "${CFG[cwd]}" || return $?$(
    echo "H: cwd is $PWD" >&2)

  local NODE_ARGS=()

  if [ -n "${CFG[require]}" ]; then
    readarray -t LIST <<<$'-r\n'"${CFG[require]}//[: ]/$'\n-r\n'}"
    for ITEM in "${LIST[@]}"; do
      [ -n "$ITEM" ] || continue
      NODE_ARGS+=( -r "$ITEM" )
    done
  fi

  [ -n "${CFG[eval]}" ] && NODE_ARGS+=( -e "${CFG[eval]}" )
  [ -n "${CFG[pval]}" ] && NODE_ARGS+=( -p "${CFG[eval]}" )
  [ "${CFG[script]:0:1}" == : ] && CFG[script]="$(
    node_resolve "${CFG[script]}")"
  [ -n "${CFG[script]}" ] && NODE_ARGS+=( "${CFG[script]}" -- )

  local NODE_CMD=( env
    # printf '‹%s› '
    "$NODEJS_BIN" "${NODE_ARGS[@]}" "$@"
    )

  [ -z "${CFG[repl}" ] || fifo_repl "${CFG[repl}" || return $?

  "${NODE_CMD[@]}"
  local NODE_RV=$?

  if [ "$NODE_RV" != 0 ]; then
    case "${CFG[fail_bash]}" in
      '' ) ;;
      REPL:* )
        VAL="${REPL#*:}"
        [ -n "$VAL" ] || VAL="${CFG[repl}"
        [ -z "$VAL" ] || fifo_repl "$VAL" || return $?
        ;;
      * ) eval "${CFG[fail_bash]}";;
    esac
    [ -z "${CFG[fail_wait]}" ] || sleep "${CFG[fail_wait]}"
  fi

  return $NODE_RV
}


function logwrap_debug () {
  echo "lang='$LANG' language='$LANGUAGE'"
  echo "LW_ vars: ${LW_VARNAMES[*]}"
  export LANG{,UAGE}=en_US.UTF-8
  local CHAP=logwrap_debug_chapter
  $CHAP id
  $CHAP pwd
  $CHAP ps -u
  $CHAP ls -Fgov /proc/$$/fd
  $CHAP env
  echo
  echo "=== end of debug info ==="
}


function logwrap_debug_chapter () {
  echo
  echo "=== $* ==="
  "$@"
}










logwrap "$@"; exit $?
