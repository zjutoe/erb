local bit = require("bit")

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
function bpredict(inst)
   return nil
end

-- form a basic block
-- 
function get_bblock(mem, addr)
   local inst = mem:rd(addr)
   while not is_branch(inst) do
      addr = addr + 4
      inst = mem:rd(addr)
   end

   local target = bpredict(inst)
   local blk = {}
   blk.addr = addr
   blk.tail = addr + 4		-- include the delay slot
   blk.target = target		-- next bblock

   return blk
end
