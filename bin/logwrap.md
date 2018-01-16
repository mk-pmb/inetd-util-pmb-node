
logwrap
=======

[`logwrap.sh`](`logwrap.sh`)
detects your `nodejs` or `node` binary and offers some more
features that you can enable by setting these environment variables:


### Space bug

As the manpage of my version of `xinetd` says:
_"There is no way to put a SPACE in an environment variable."_
If yours has the same problem, you can work around this with `LW_ENVDEC`,
but only for vars that don't start with `LW_` or are listed below `LW_ENVDEC`.


### LW_DELAY

First of all, `sleep` a bit.
Meant to slow down rapid server respawns and the resulting syslog flood.
Value can be anything that your `sleep` command would accept, e.g. `30s`.


### LW_UMASK

Invoke the `umask` bash command early, with this argument.
Defaults to `0022`, i.e. let anyone read and execute newly
create files/ directories/ pipes but not modify them.


### LW_FUNC

Run just this one function, instead of the entire logwrap script.
Meant for debugging logwrap itself.


### LW_DUMPENV

Dump some debug info into this file about what the shell context
looks like from inside: environment variables, paths, file descriptors, …

  * If it doesn't start with a slash, `/tmp/` is prefixed.
  * If it ends with a slash, try to create a directory with that name
    (no-op it exists already), then append a probably-unique filename.


### LW_SYSLOG_TAG

Try to redirect all output to syslog, using this tag name.
Only affects output that `LW_STDOUT` and `LW_STDERR` failed to grab.


### LW_STDOUT

  * `.` (U+002E full stop): Try to redirect stdout to stderr.
    (Useful to capture what would have been sent over the network.)
  * anything else: Try to redirect stdout to this file, appending to it.


### LW_STDERR

Try to redirect stderr to this file, appending to it.


### LW_ENVDEC

A colon-separated list of names of `LV_…` vars whose values shall be decoded.
In this list (__NOT__ in the actual environment),
names are case-insensitive and you may omit the leading `LV_`.

The encoded value should be prefixed with a codec name and a colon.
These codecs are supported:

  * `base64`: [RFC 4648](https://tools.ietf.org/html/rfc4648);
    also accepts [`base64url`](https://tools.ietf.org/html/rfc4648#section-5).
    * When using the `base64` utility in your shell to encode values,
      double-check whether you meant to include a final newline in your input.
      Example: `base64 <<<'hello'` &rarr; `aGVsbG8K` &rarr; `"hello\n"`
  * `printf`: Let `bash`'s `printf` render it.
  * `urldecode`: `%hh` hex decoding, using `perl` and a regexp.


### LW_SOURCE_INIT

A colon-separated list of files that logwrap should `source`
(meaning the so-named `bash` command) before it tries to use node.js.

You may want to set this to `/etc/profile` in order to get
your usual env vars, including `NODE_PATH`.

List item magic:
  * A leading `?` marks an item as optional, and the `?` will be removed.
  * A leading `~/` will be replaced with the value of the the `$HOME`
    environment variable and a `/`.
  * If the resulting path is not a file (e.g. because it doesn't exist),
    logwrap will complain and fail – unless the item is optional,
    in which case it will be skipped silently.
  * If the source operation fails, logwrap will complain and fail,
    even for optional items.


### LW_NODEJS_CMD

What command to use to invoke node.js.
Should be something like `nodejs`, `node`,
or an absolute path to your node.js binary.

  * Default: Try to guess, with a fallback of `node`.
  * This program is used for stuff like `LW_CWD_RESOLVE`.

You can use newline characters to sneak arguments in.


### LW_SERVER_CMD

The command to be used for the actual server invocation.
Default: use `LW_NODEJS_CMD`

You can use newline characters to sneak arguments in.


### LW_CWD_RESOLVE

Meant to chdir into some node module's directory.
If you want to chdir here, you'd set this to `inetd-util-pmb/README.md`,
or more reliably, `inetd-util-pmb/package.json`.

Takes a colon-separated list of node module identifiers.
They're each `require.resolve()`d with node, stopping at the first success.
(If none of them resolve, fatal error.)
If the resolved path has any slashes in it, cut at the last slash.
Try to chdir into whatever remains.


### LW_CWD

Try to chdir into whatever this variable's value is.
This happens after `LW_CWD_RESOLVE` so you can refine its result.


### LW_SOURCE_LATE

Like `LW_SOURCE_INIT` but it happens later,
especially after the chdirs,
which may give you better opportunities for some relative paths.


### LW_REQUIRE

Takes a colon-separated list of node module identifiers.
Each of them is given to nodejs via the `-r` option.


### LW_EVAL

Given to nodejs via the `-e` option.


### LW_PVAL

Given to nodejs via the `-p` option.


### LW_SCRIPT

Path to your node script, if you want to run one.

Added to the nodejs command after all the potential `-r`/`-e`/`-p` options.
Also, `--` is added after the script path.


### LW_BASH_REPL

Start a bash(!) REPL (read-eval-print loop)
just before nodejs would be started.

If you have redirected output (normal and/or errors),
remember to watch the destination in addition to your input channel.

The value is expected to be a file system path to an _acceptable REPL input_,
i.e. something that forgets those bytes that have been read from it,
like a named pipe or a character device or a socket.
If it's neither, tries to create a named pipe with that name.

  * `-` is an alias for `/dev/stdin`. This will only work for services with
    `wait=no`, as you'd need a client socket on stdin.

As long as it's (still) an _acceptable REPL input_,
the REPL reads one line from it, then `eval`s it,
unless it's one of these magic commands:

  * `pid`: Show the REPL's process ID.
  * `unrepl` or `Q`: Quit the REPL cleanly, to continue normal operation.
  * `rmrepl` or `Qr`: Like `Q` but try to delete the input pipe.
  * `flinch` or `panic` or `DIE`: Alias for `exit 42`.

If you delete the input while the REPL is still active, it will
remind you to clean up, then
fail, which should make `logwrap` flinch.


### LW_FAIL_BASH

In case your main nodejs command failed, `eval` this in `bash`.
Magic values:

  * `REPL:` + optional path:
    Do the REPL stuff as described for `LW_BASH_REPL`.
    Empty path means to use `LW_BASH_REPL`;
    if that's empty as well, do nothing.



### LW_FAIL_WAIT

In case your main nodejs command failed, take a nap, like `LW_DELAY`.




