
Debugging xinetd
----------------

You might have noticed that `xinetd -d` (its debug mode) is very reluctant
to write its messages to stdout, because if your screen isn't big enough
or you're too slow to read all its messages, you're just not worth using it,
or so it seems. Since I'm one of the unworthy myself, I've made us a crutch
that allows us to redirect its output into a debug log file:

  * [`debug-xinetd.sh`](debug-xinetd.sh)

When you've had enough, press

  * Ctrl+C to quit the debug script and have `xinetd` run havoc all it wants
  * or Enter to have the debug script kill `xinetd` and quit cleanly. ;-)




