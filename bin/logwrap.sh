#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function logwrap_failwait () {
  local SELFPATH="$(readlink -m -- "$BASH_SOURCE"/..)"
  local -A CFG=()
  CFG[fail_wait]="$LW_FAIL_WAIT"
  local FAIL_WAIT="$LW_FAIL_WAIT"

  logwrap_core "$@"
  local CORE_RV=$?
  [ "$CORE_RV" == 0 ] && FAIL_WAIT=

  if [ -n "$FAIL_WAIT" ]; then
    echo "W: core failed (rv=$CORE_RV)," \
      "gonna LW_FAIL_WAIT for $FAIL_WAIT (now: $(date +'%F %T'))" >&2
    sleep "$FAIL_WAIT"
    echo "D: awoke from LW_FAIL_WAIT at $(date +'%F %T')" >&2
  fi

  return $CORE_RV
}


function logwrap_core () {
  cd / || return $?$(echo "E: Failed to chdir to /. Flinching." >&2)

  local LIST=() ITEM= KEY= VAL=
  [ -n "$USER" ] || USER="$(whoami)"
  [ -n "$LW_DELAY" ] && sleep "$LW_DELAY"
  [ -n "$LW_UMASK" ] && umask "${LW_UMASK:-0022}"

  for ITEM in "$SELFPATH"/../lib/lib_*.sh; do
    source "$ITEM" --lib || return $?$(
      echo "E: Failed to source '$ITEM'" >&2)
  done

  local LW_VARNAMES=( $(env | grep -oPe '^LW_\w+=' \
    | tr -d '=' | LANG=C sort -Vu) )

  if [ -n "$LW_FUNC" ]; then
    "$LW_FUNC" "$@"
    VAL="$?"
    echo "D: LW_FUNC rv=$VAL" >&2
    return $VAL
  fi

  if [ -n "$LW_DUMPENV" ]; then
    [ "${LW_DUMPENV:0:1}" == / ] || LW_DUMPENV="/tmp/$LW_DUMPENV"
    case "$LW_DUMPENV" in
      */ )
        mkdir --parents -- "$LW_DUMPENV" 2>/dev/null
        LW_DUMPENV+="$USER.$$.dbg";;
    esac
    case ",$LW_DUMPENV_FLAGS," in
      *,append,* ) ;;
      * ) >"$LW_DUMPENV";;
    esac
    logwrap_debug &>>"$LW_DUMPENV"
  fi

  if [ -n "$LW_SYSLOG_TAG" ]; then
    FAIL_WAIT=    # disable the outer fail_wait
    LW_DUMPENV_FLAGS=append \
      LW_SYSLOG_TAGGED="$LW_SYSLOG_TAG" LW_SYSLOG_TAG= \
      LW_DELAYED="$LW_DELAY" LW_DELAY= \
      logwrap_failwait "$@" |& logger --tag "$LW_SYSLOG_TAG"
    return "${PIPESTATUS[0]}"
  fi

  [ -z "${LW_STDOUT%.}" ] || exec 1>>"$LW_STDOUT" || return $?$(
    echo "E: Failed to redirect stdout to '$LW_STDOUT'." >&2)
  [ -z "$LW_STDERR" ] || exec 2>>"$LW_STDERR" || return $?$(
    echo "E: Failed to redirect stderr to '$LW_STDERR'." >&2)
  [ "$LW_STDOUT" != . ] || exec 1>&2 || return $?$(
    echo "E: Failed to redirect stdout to stderr. (Bug?)" >&2)

  # ===== switch to CFG[] ===== ===== ===== ===== ===== #
  import_decode_envvars || return $?$(
    echo "E: Failed to import_decode_envvars" >&2)
  unset -v LW_DUMMY "${LW_VARNAMES[@]}"

  multisource "${CFG[source_init]}" || return $?

  local NODE_PATH="${CFG[node_path_prio]}:$NODE_PATH:${CFG[node_path]}"
  NODE_PATH="${NODE_PATH#:}"
  NODE_PATH="${NODE_PATH%:}"
  export NODE_PATH

  local NODEJS_CMD=()
  readarray -t NODEJS_CMD <<<"${CFG[nodejs_cmd]}"
  [ -n "${NODEJS_CMD[*]}" ] || NODEJS_CMD=( "$(
    best_avail_cmd node{js,} )" )

  logwrap_cwd_resolve || return $?
  [ -z "${CFG[cwd]}" ] || cd -- "${CFG[cwd]}" || return $?$(
    echo "H: cwd is $PWD" >&2)

  local SRV_ARGS=()

  if [ -n "${CFG[require]}" ]; then
    readarray -t LIST <<<$'-r\n'"${CFG[require]}//[: ]/$'\n-r\n'}"
    for ITEM in "${LIST[@]}"; do
      [ -n "$ITEM" ] || continue
      SRV_ARGS+=( -r "$ITEM" )
    done
  fi

  [ -n "${CFG[eval]}" ] && SRV_ARGS+=( -e "${CFG[eval]}" )
  [ -n "${CFG[pval]}" ] && SRV_ARGS+=( -p "${CFG[pval]}" )

  logwrap_parse_script_opt || return $?
  [ -n "${CFG[script]}" ] && SRV_ARGS+=( "${CFG[script]}" -- )

  local SRV_CMD=()
  readarray -t SRV_CMD <<<"${CFG[server_cmd]}"
  [ -n "${SRV_CMD[*]}" ] || SRV_CMD=( "${NODEJS_CMD[@]}" )
  [ "${SRV_CMD[*]}" == / ] && SRV_CMD=()
  # SRV_CMD=( printf '‹%s›\n' "${SRV_CMD[@]}" )

  multisource "${CFG[source_late]}" || return $?

  if [ -n "${CFG[dumpenv]}" ]; then
    (
      echo
      echo "=== state before possible early REPL ==="
      local -p | LANG=C sort -V
      echo "=== end of state dump ==="
    ) >>"${CFG[dumpenv]}"
  fi

  [ -z "${CFG[bash_repl]}" ] || bash_repl "${CFG[bash_repl]}" || return $?$(
    echo "E: Early REPL failed, rv=$?." >&2)

  "${SRV_CMD[@]}" "${SRV_ARGS[@]}" "$@"
  local SRV_RV=$?

  if [ "$SRV_RV" != 0 ]; then
    VAL="${CFG[fail_bash]}"
    case "$VAL" in
      '' ) ;;
      REPL:* )
        VAL="${VAL#*:}"
        [ -n "$VAL" ] || VAL="${CFG[bash_repl]}"
        [ -z "$VAL" ] || bash_repl "$VAL" || return $?$(
          echo "E: Late REPL failed." >&2)
        ;;
      * ) eval "$VAL";;
    esac
  fi

  return $SRV_RV
}


function logwrap_cwd_resolve () {
  local CWR="${CFG[cwd_resolve]}"
  [ -n "$CWR" ] || return 0
  local RESO=
  RESO="$(node_resolve "$CWR")"
  [ -n "$RESO" ] || return $?$(
    echo "E: Unable to resolve any of LW_CWD_RESOLVE = '$CWR'." \
      "cwd is '$PWD', NODE_PATH is '$NODE_PATH'." >&2)
  RESO="$(dirname -- "$RESO")"
  cd -- "$RESO" || return $?$(echo "H: cwd is $PWD" >&2)
  # you can still refine this path with LW_CWD
}


function partree { pstree --show-p{arent,id}s --long --uid-changes $$; }


function logwrap_debug () {
  echo "lang='$LANG' language='$LANGUAGE'"
  echo "LW_ vars: ${LW_VARNAMES[*]}"
  echo

  echo '=== config: ==='
  echo "keys: ${!CFG[*]}"
  local KEY=
  for KEY in "${!CFG[@]}"; do
    printf '%q = %q\n' "$KEY" "${CFG[$KEY]}"
  done
  echo

  export LANG{,UAGE}=en_US.UTF-8
  local CHAP=logwrap_debug_chapter
  $CHAP id
  $CHAP pwd
  $CHAP ps -u
  $CHAP partree
  $CHAP ls -Fgov /proc/$$/fd
  $CHAP "$( best_avail_cmd env{-sorted,} )"
  echo
  echo "=== end of debug info ==="
}


function logwrap_debug_chapter () {
  echo
  echo "=== $* ==="
  "$@"
}


function logwrap_parse_script_opt () {
  # See logwrap.md for syntax.
  local CANDIDATES="${CFG[script]}|"
  [ -n "$CANDIDATES" ] || return 0
  CANDIDATES="${CANDIDATES//'|'/ }"
  CANDIDATES="${CANDIDATES//$'\n'/ }"

  local ITEM= ORIG= OPPORTUNISTIC=
  while [ -n "$CANDIDATES" ]; do
    ITEM="${CANDIDATES%% *}"
    CANDIDATES="${CANDIDATES#* }"
    [ -n "$ITEM" ] || continue
    ORIG="$ITEM"
    OPPORTUNISTIC="${ITEM:0:1}"
    [ "$OPPORTUNISTIC" == '?' ] || OPPORTUNISTIC=
    ITEM="${ITEM#'?'}"
    [ "${ITEM:0:1}" == : ] && ITEM="$(node_resolve "${ITEM:1}")"
    if [ -f "$ITEM" ]; then
      CFG[script]="$ITEM"
      return 0
    fi
    [ -n "$OPPORTUNISTIC" ] && continue
    [ "$ITEM" == "$ORIG" ] || ITEM+="' <- originally: '$ORIG"
    echo E: "Script candidate entry does not point to a file: '$ITEM'" >&2
    return 4
  done
  echo E: 'Cannot determine script to run: No more candidate entries.' >&2
  return 4
}


















logwrap_failwait "$@"; exit $?
