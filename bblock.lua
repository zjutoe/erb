local print = print
local string = string
local pairs = pairs
local bit = require("bit")


module(...)

local _m = {}

function init()
   local m = {}
   for k, v in pairs(_m) do
      m[k] = v
   end
   return m
end

-- d[i:j]
function bit.sub(d, i, j)
   return bit.rshift(bit.lshift(d, 31-i), 31-i+j)
end

function is_branch(inst)
   local op = bit.sub(inst, 31, 26)

   local bnj = {
      [0x04] = true,		-- BEQ, B
      [0x14] = true,		-- BEQL
      [0x07] = true,		-- BGTZ
      [0x17] = true,		-- BGTZL
      [0x06] = true,		-- BLEZ
      [0x16] = true,		-- BLEZL
      [0x05] = true,		-- BNE
      [0x15] = true,		-- BNEL
      [0x02] = true,		-- J
      [0x03] = true,		-- JAL
   }

   -- op == 0x01, i.e. REGIMM
   local bnj_regimm = {
      [0x01] = true,		-- BGEZ
      [0x11] = true,		-- BGEZAL, BAL
      [0x13] = true,		-- BGEZLL
      [0x03] = true,		-- BGEZL
      [0x00] = true,		-- BLTZ
      [0x10] = true,		-- BLTZAL
      [0x12] = true,		-- BLTZALL
      [0x02] = true,		-- BLTZL
   }

   -- op == 0x00, i.e. SPECIAL
   local bnj_special = {
      [0x09] = true,		-- JALR, JALR.HB
      [0x08] = true,		-- JR, JR.HB
   }

   if bnj[op] then
      return true
   elseif op == 0x01 then
      local rt = bit.sub(inst, 20, 16)
      if bnj_regimm[rt] then
	 return true
      end
   elseif op == 0x00 then
      local func = bit.sub(inst, 5, 0)
      if bnj_special[func] then
	 return true
      end
   end

   return false
end

-- branch prediction
-- inst: must be a branch or jump instruction
function bpredict(self, inst)   
   return nil
end

-- form a basic block
-- 
function bblock(mem, addr)
   local blk = {}
   blk.addr = addr
   print(string.format('bblk 0x%x', addr))

   local inst
   repeat
      inst = mem:rd(addr)
      blk[addr] = inst
      print('', string.format("0x%x 0x%x", addr, blk[addr]))
      addr = addr + 4
   until not (inst and not is_branch(inst))
   blk.tail = addr		-- the delay slot already included
   blk[addr] = mem:rd(addr)
   print('', string.format("0x%x 0x%x", addr, blk[addr]))
   
   blk.target = bpredict(inst)	-- next bblock

   return blk
end

function _m.reg_rds(bblk)
   
end

function _m.get_bblocks(mem, addr, num)
   local i
   local bbs = {}
   local h = addr
   for i=1, num do
      local b = bblock(mem, h)
      if b then
	 h = b.tail + 4		-- now we don't have branch prediction, just fall through
	 bbs[i] = b
      else
	 break
      end
   end

   return bbs
end

