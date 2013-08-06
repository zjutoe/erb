grep IN -A 1 /tmp/qemu.log | grep ^0x | cut -f1 -d: > trace.bb
