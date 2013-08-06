local loadelf = require 'luaelf/loadelf'
local bit = require "bit"
local elf = loadelf.init()
local mem = elf.load(arg[1])

function mem.rd(self, addr)
   local v0 = self[addr]   or 0
   local v1 = self[addr+1] or 0
   local v2 = self[addr+2] or 0
   local v3 = self[addr+3] or 0
   if addr % 4 == 0 then
      -- FIXME is it faster to use bit ops?
      return v0 * 2^24 + v1 * 2^16 + v2 * 2^8 + v3
   else
      return nil		-- FIXME raise an exception?
   end
end

dofile("bblock.lua")

-- local bb0 = get_bblock(mem, 0x400220)
-- local bb1 = get_bblock(mem, 0x40022c)
-- local bb2 = get_bblock(mem, 0x400430)
-- print(string.format("%08x - %08x", bb0.addr, tonumber(bb0.tail)))
-- print(string.format("%08x - %08x", bb1.addr, tonumber(bb1.tail)))
-- print(string.format("%08x - %08x", bb2.addr, tonumber(bb2.tail)))

local next_bblock = {}

function train(next_bblock, b0, b1)
   next_bblock[b0.addr] = b1.addr
end

--train(next_bblock, bb0, bb1)
--train(next_bblock, bb1, bb2)

-- for k, v in pairs(next_bblock) do
--    print(string.format("%08x -> %08x", k, v))
-- end

local trace = assert(io.open(arg[2], "r"))

local i, j = trace:read("*number", "*number")
while j do
   local bbi = get_bblock(mem, i)
   local bbj = get_bblock(mem, j)
   train(next_bblock, bbi, bbj)
   i = j
   j = trace:read("*number")
end 

for k, v in pairs(next_bblock) do
   print(string.format("0x%08x -> 0x%08x", k, v))
end
