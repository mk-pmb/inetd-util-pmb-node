#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function logwrap () {
  local -A CFG=()
  local LIST=() ITEM= KEY= VAL=
  [ -n "$USER" ] || USER="$(whoami)"
  [ -n "$LW_DELAY" ] && sleep "$LW_DELAY"
  [ -n "$LW_UMASK" ] && umask "${LW_UMASK:-0022}"

  local SELFPATH="$(readlink -m "$BASH_SOURCE"/..)"
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
    LW_DUMPENV_FLAGS=append \
      LW_SYSLOG_TAG= \
      "$FUNCNAME" "$@" |& logger --tag "$LW_SYSLOG_TAG"
    return "${PIPESTATUS[0]}"
  fi

  [ -z "${LW_STDOUT%.}" ] || exec 1>>"$LW_STDOUT" || return $?$(
    echo "E: Failed to redirect stdout to '$LW_STDOUT'." >&2)
  [ -z "$LW_STDERR" ] || exec 2>>"$LW_STDERR" || return $?$(
    echo "E: Failed to redirect stderr to '$LW_STDERR'." >&2)
  [ "$LW_STDOUT" != . ] || exec 1>&2 || return $?$(
    echo "E: Failed to redirect stdout to stderr. (Bug?)" >&2)

  local NODEJS_CMD="$( best_avail_cmd node{js,} )"

  # ===== switch to CFG[] ===== ===== ===== ===== ===== #
  import_decode_envvars || return $?$(
    echo "E: Failed to import_decode_envvars" >&2)
  unset -v LW_DUMMY "${LW_VARNAMES[@]}"

  readarray -t LIST <<<"${CFG[source]//[: ]/$'\n'}"
  for ITEM in "${LIST[@]}"; do
    [ -n "$ITEM" ] || continue
    source "$ITEM" || return $?$(
      echo "E: Failed to source '$ITEM'" >&2)
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
  [ "${CFG[script]:0:1}" == : ] && CFG[script]="$(
    node_resolve "${CFG[script]}")"
  [ -n "${CFG[script]}" ] && SRV_ARGS+=( "${CFG[script]}" -- )

  local SRV_CMD=()
  readarray -t SRV_CMD <<<"${CFG[srv_prog]:-$NODEJS_CMD}"
  # SRV_CMD=( printf '‹%s›\n' "${SRV_CMD[@]}" )

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

    VAL="${CFG[fail_wait]}"
    if [ -n "$VAL" ]; then
      echo "W: server failed (rv=$SRV_RV)," \
        "gonna LW_FAIL_WAIT for $VAL (now: $(date +'%F %T'))" >&2
      sleep "$VAL"
      echo "D: awoke from LW_FAIL_WAIT at $(date +'%F %T')" >&2
    fi
  fi

  return $SRV_RV
}


function partree { pstree --show-p{arent,id}s --long --uid-changes $$; }


function logwrap_debug () {
  echo "lang='$LANG' language='$LANGUAGE'"
  echo "LW_ vars: ${LW_VARNAMES[*]}"
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










logwrap "$@"; exit $?
