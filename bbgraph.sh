mips-linux-gnu-gcc --static foo.c -o foo
qemu-mips -d in_asm foo -D foo.qemu.log
grep IN -B 2 -A 1 foo.qemu.log | grep ^0x | cut -f1 -d: > trace.bb
luajit graph.lua trace.bb
