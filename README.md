erb
===

Extended Reorder Buffer

The current output is memory load/store trace, which can be fed to the
Dinero IV cache simulator
(http://pages.cs.wisc.edu/~markhill/DineroIV/).

usage
=====

* get the luaelf

  check out from (git@github.com:zjutoe/luaelf.git), put it in the
  current folder

* setup the environment

   $ source setenv.sh

* run the main.lua with luajit

   $ luajit main.lua

Tips
====

* to get a full trace dump from Qemu execution

  $ qemu-mips -singlestep -d a.out

  Then examine the qemu.misp.log in the current dir.
