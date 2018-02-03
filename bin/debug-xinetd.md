
Debugging xinetd
----------------

You might have noticed that `xinetd -d` (its debug mode) is very reluctant
to write its messages to stdout, because if your screen isn't big enough
or you're too slow to read all its messages, you're just not worth using it,
or so it seems. Since I'm one of the unworthy myself, I've made us a crutch
that allows us to redirect its output into a debug log file:

  * [`debug-xinetd.sh`](debug-xinetd.sh)

It greets you with a list of available commands.
The most important one is "d", which starts a debug session in background.

  * The debug mode xinetd instance will be stopped as soon as you
    supply another command. (Or just press Enter.)
  * Depending on your terminal size, its output will probably flood away
    the command list and the input prompt.
    Nonetheless, the prompt will be waiting for your next command.





