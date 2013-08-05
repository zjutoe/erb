local loadelf = require 'luaelf/loadelf'
local elf = loadelf.init()
local mem = elf.load(arg[1])

function mem.rd(self, addr)
   local v0 = self[addr]   or 0
   local v1 = self[addr+1] or 0
   local v2 = self[addr+2] or 0
   local v3 = self[addr+3] or 0
   if addr % 4 == 0 then
      -- TODO use ffi.bit to accelerate
      return v0 * 2^24 + v1 * 2^16 + v2 * 2^8 + v3
   else
      return nil		-- FIXME raise an exception?
   end
end

dofile("bblock.lua")

local bb0 = get_bblock(mem, 0x400220)
local bb1 = get_bblock(mem, 0x40022c)
print(string.format("%08x", tonumber(bb0.tail)))
print(string.format("%08x", tonumber(bb1.tail)))

