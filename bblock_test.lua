require("bblock")

local bblk = bblock.init()

function test(fbin)
   local loadelf = require 'luaelf/loadelf'
   local elf = loadelf.init()
   local mem = elf.load(fbin)

   local bbs = bblk.get_bblocks(mem, mem.e_entry, 3)
   for k, v in pairs(bbs) do
      print(string.format("%x %x", v.addr, v.tail))
   end

   local bbs = bblk.get_bblocks(mem, 0x00400430, 3)
   for k, v in pairs(bbs) do
      print(string.format("%x %x", v.addr, v.tail))
   end

end

test(arg[1])
