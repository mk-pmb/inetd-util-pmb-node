
<!--#echo json="package.json" key="name" underline="=" -->
inetd-util-pmb
==============
<!--/#echo -->

<!--#echo json="package.json" key="description" -->
Scripts to help run (and debug) programs via (x)inetd socket activation.
Optimized for Node.js but also works with Perl, Python, mostly anything.
<!--/#echo -->


Socket activation
-----------------

Annoyed of systemd for having to use two separate files
(`.socket` and `.service`)?
Or jealous that your Ubuntu Precise or Trusty doesn't yet support systemd?

Just use `xinetd`.
Although many bad tutorials claim you couldn't use `wait=yes` with TCP,
indeed you can.
What makes those authors think it doesn't work is that your server doesn't
get a peer socket as stdio, but instead gets the server socket as stdin –
exactly what your script's `net.Server` wants to listen on!

As for debugging, `xinetd` isn't as helpful as it could be, though.
The scripts in this package aim to help with that.



Setup
-----

All examples assume that you install this package into a directory
`/usr/lib/node_modules/inetd-util-pmb`. A symlink is fine, too.



Getting started
---------------

If you're new to `xinetd`, start with the included example service:

  1. Copy [`docs/example/hello_nodejs_world`](docs/example/hello_nodejs_world)
      to `/etc/xinetd.d`
  1. Open the copy in your favorite editor.
  1. Run `bin/debug-xinetd.sh` in one terminal,
  1. and `rlwrap netcat -vvvv localhost 1336` in another one.
  1. After very few seconds, you should be greeted with `Hello Node.js World!`
  1. In the xinetd debug terminal, press Enter to stop it,
      then `q` to quit the log viewer (`less`).
  1. Future versions may even come with an example service that
      uses socket activation.


Scripts
-------

  * [`debug-xinetd`](bin/debug-xinetd.md):
    Capture output from `xinetd -d`, then help kill it.
  * [`logwrap`](bin/logwrap.md):
    Run and debug node scripts inside a `xinetd` service.





Known issues
------------

* Needs more/better tests and docs.




&nbsp;


License
-------
<!--#echo json="package.json" key=".license" -->
ISC
<!--/#echo -->
