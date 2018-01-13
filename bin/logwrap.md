﻿
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

Try to redirect stdout to this file, appending to it.

### LW_STDERR

  * `.` (U+002E full stop): Try to redirect stderr to stdout.
  * anything else: Try to redirect stderr to this file, appending to it.

### LW_ENVDEC

A colon-separated list of names of envvars whose values shall be decoded.

  * Variable names are verbatim, so remember to write the `LW_`
    prefix if you mean it.

The encoded value should be prefixed with a codec name and a colon.
These codecs are supported:

  * `base64`: [RFC 4648](https://tools.ietf.org/html/rfc4648);
    also accepts [`base64url`](https://tools.ietf.org/html/rfc4648#section-5).
    * When using the `base64` utility in your shell to encode values,
      double-check whether you meant to include a final newline in your input.
      Example: `base64 <<<'hello'` &rarr; `aGVsbG8K` &rarr; `"hello\n"`
  * `printf`: Let `bash`'s `printf` render it.
  * `urldecode`: `%hh` hex decoding, using `perl` and a regexp.

### LW_SOURCE

A colon-separated list of files that logwrap should `source`
(meaning the so-named `bash` command).
You'll most likely want to either not set it, or set it to `/etc/profile`.

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

### LW_REPL

Start a bash(!) REPL (read-eval-print loop)
just before nodejs would be started.

The value is expected to be a file system path to an _acceptable REPL input_,
i.e. a named pipe or a character device.
If it's neither, tries to create a named pipe with that name.
(You may want `LW_UMASK=0000` for insecure but easy debugging.)

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
    Do the REPL thing described above. The colon is mandatory.
    If you manage to put a space after the colon, it will be part of the path.
    If the path is empty, the one from `LW_REPL` is used.
    If that's empty as well, no REPL for you.


### LW_FAIL_WAIT

In case your main nodejs command failed, take a nap, like `LW_DELAY`.



