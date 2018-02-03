#!/bin/sed -nurf
# -*- coding: UTF-8, tab-width: 2 -*-

/^\s+esac$/q

# /\)/{=;N;p;b}

/\)\s*$/{
  s~['"]+~~g
  N
}
s~^\s+(\S+)\s*\)\s+<{3}\s*(['"])~\a\2\1 ~
/^\a/{
  s~^\a~~
  : line_cont
  /['"];?$/!{
    N
    s~\n\s+~ ~
    b line_cont
  }
  s~['"]\s*;\s*?$~~
  s~^['"](\S+)\s+~H:   \1 = ~
  p
}
