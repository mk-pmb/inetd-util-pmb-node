#!/bin/sed -nurf
# -*- coding: UTF-8, tab-width: 2 -*-

: retry
s~\r~~g
s~^([0-9]{1,2})/([0-9]{1,2})/([0-9]{1,2})@([0-9]{2}):([0-9]{2}):([0-9]{2}): |$\
  ~\1\r0\2\r0\3-\4\5\6 ~
s~\r0?([0-9]{2})~\1~g
s~\r~~g

s~^(\S+ )DEBUG: [0-9]+ ~\1~
/^\S+ \{handle_includedir\} Reading included configuration file: /{
  s~^(\S+ )[^:]+: (/etc/xinetd\.d/)~\1read_config: ~
  s~ \[line=[0-9]+\]$~~
  s~^(\S+ read_config: )(\S+ )\[file=(\S+)\]$~\1\2@ \3~
}

/^(\S+ )\{remove_disabled_services\} removing /{
  : more_disservices
    N
    s~(^(\S+ )|\n\S+: DEBUG: [0-9]+ )\{(remove_disabled_services|$\
      )\} removing ~\r\2\3: ~g
    s~^\r~~
    s~\r\S+~\r,~g
  /\n/!b more_disservices
  s~(\S+)\r, \1\r?~\1 ×2~g
  s~\r~®~g
}

/^\tEnvironment (additions|strings):/{
  s~$~\tsnip. use a bash repl if you're interested.~
  p
  : ignore_env_line
    n
    /^\t{2}/!b retry
  b ignore_env_line
}


/^\tEnvironment strings:/{
  : more_env
    p;n
    /^\t{2}/!b retry
    # s~^(\t{2}LS_COLORS=)(\S+
    s~^(\t{2}.{40})(.{50})~\1\n\2~
    /\n/{
      s~[^\n]{0,40}$~\n&~
      s~\n[^\n]*\n~ […] ~
    }
  b more_env
}






: print
p

: end
