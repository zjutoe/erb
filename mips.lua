local bit = require("bit")

function bit.sub(d, i, j)
   return bit.rshift(bit.lshift(d, 31-i), 31-i+j)
end

function dec_op(inst)
   -- 1111 1100 0000 0000 0000 0000 0000 0000, 31:26
   return bit.rshift( bit.band(inst, 0xFC000000), 26)
end

function dec_rs(inst)
   -- 0000 0011 1110 0000 0000 0000 0000 0000, 25:21
   return bit.rshift( bit.band(inst, 0x03E00000), 21)
end

function dec_rt(inst)
   -- 0000 0000 0001 1111 0000 0000 0000 0000, 20:16
   return bit.rshift( bit.band(inst, 0x001F0000), 16)
end

function dec_rd(inst)
   -- 0000 0000 0000 0000 1111 1000 0000 0000, 15:11
   return bit.rshift( bit.band(inst, 0x0000F800), 11)
end


local function decode(inst)
   local  op = bit.sub(inst, 31, 26)
   local  rs = bit.sub(inst, 25, 21)
   local  rt = bit.sub(inst, 20, 16)
   local  rd = bit.sub(inst, 15, 11)
   local  sa = bit.sub(inst, 10, 6)
   local fun = bit.sub(inst, 5, 0)
   local imm = bit.sub(inst, 15, 0)

   return op, rs, rt, rd, sa, fun, imm
end


local rtype1 = {
   [0x20] = true, -- do_add,	       -- add signed (with overflow) 
   [0x21] = true, -- do_addu,	       -- add unsigned 
   [0x24] = true, -- do_and,	       -- bitwise and 
   [0x25] = true, -- do_or,	       -- bitwise or 
   [0x2A] = true, -- do_slt,	       -- set on less than (signed) 
   [0x2B] = true, -- do_sltu,	       -- set on less than immediate (signed) 
   [0x22] = true, -- do_sub,	       -- sub signed 
   [0x23] = true, -- do_subu,	       -- sub unsigned    
   [0x26] = true, -- do_xor,	       -- bitwise exclusive or    
}

local rtype2 = {
   [0x00] = true, -- do_sll,	       -- shift left logical  -- [0x00] = true, -- do_noop, noop is "SLL $0 $0 0"
   [0x04] = true, -- do_sllv,	       -- shift left logical variable 
   [0x03] = true, -- do_sra,	       -- shift right arithmetic 
   [0x02] = true, -- do_srl,	       -- shift right logic  
   [0x06] = true, -- do_srlv,	       -- shift right logical variable 
}

function reg_rds(bblk)
   local rd = {}
   local wr = {}
   for addr=bblk.addr, bblk.tail, 4 do
      local inst = bblk[addr]
      local op, rs, rt, rd, sa, fun, imm = decode(inst)
      if rtype1[op] then
	 -- op rd, rs, rt
	 if not wr[rs] then rd[rs] = true end -- we only track reads from outside this bblk
	 if not wr[rt] then rd[rt] = true end
	 wr[rd] = true
      else
      end      
   end
end

local inst_handle_rtype = {
   [0x20] = do_add,	       -- add signed (with overflow) 
   [0x21] = do_addu,	       -- add unsigned 
   [0x24] = do_and,	       -- bitwise and 
   [0x1A] = do_div,	       -- divide signed 
   [0x1B] = do_divu,	       -- divide unsigned 
   [0x10] = do_mfhi,	       -- move from HI 
   [0x12] = do_mflo,	       -- move from LO 
   [0x18] = do_mult,	       -- multiply signed 
   [0x19] = do_multu,	       -- multiply unsigned 
   [0x25] = do_or,	       -- bitwise or 
   [0x2A] = do_slt,	       -- set on less than (signed) 
   [0x2B] = do_sltu,	       -- set on less than immediate (signed) 
   [0x00] = do_sll,	       -- shift left logical  -- [0x00] = do_noop, noop is "SLL $0 $0 0"
   [0x04] = do_sllv,	       -- shift left logical variable 
   [0x03] = do_sra,	       -- shift right arithmetic 
   [0x02] = do_srl,	       -- shift right logic  
   [0x06] = do_srlv,	       -- shift right logical variable 
   [0x22] = do_sub,	       -- sub signed 
   [0x23] = do_subu,	       -- sub unsigned    
   [0x26] = do_xor,	       -- bitwise exclusive or 
   [0x08] = do_jr,	       -- jump register
   [0x09] = do_jalr,	       -- jump and link register
   [0x0C] = do_syscall, -- system call FIXME system call is not R-type in theory?
}

local inst_handle_bz = {
   
   [0x01] = do_bgez,	-- fmt=0x01, BGEZ, branch on >= 0
   [0x11] = do_bgezal,	-- fmt=0x11, BGEZAL, BGEZ and link
   [0x00] = do_bltz,	-- fmt=0x00, BLTZ, branch on < 0
   [0x10] = BZ_BLTZAL,	-- fmt=0x10, BLTZAL, BLTZ and link
}

local inst_handle = {
   [0x08]  = do_addi,		-- add immediate with overflow  
   [0x09]  = do_addiu,		-- add immediate no overflow  
   [0x0C]  = do_andi,		-- bitwise and immediate  
   [0x0D]  = do_ori,		-- bitwise or immediate  
   [0x0E]  = do_xori,		-- bitwise exclusive or immediate  

   [0x0A]  = do_slti,	      -- set on less than immediate  
   [0x0B]  = do_sltiu,	      -- set on less than immediate unsigned  FIXME WTF?

   [0x04]  = do_beq,		-- branch on equal  

   [0x07]  = do_bgtz,		-- branch if $s > 0  
   [0x06]  = do_blez,		-- branch if $s <= 0  
   [0x05]  = do_bne,		-- branch if $s != $t  
   [0x1F]  = do_ins,		-- Inset Bit Field
   [0x02]  = do_j,		-- jump  
   [0x03]  = do_jal,		-- jump and link  

   [0x20]  = do_lb,		-- load byte  
   [0x24]  = do_lbu,		-- load byte unsigned  
   [0x21]  = do_lh,		--   
   [0x25]  = do_lhu,		--   
   [0x0F]  = do_lui,		-- load upper immediate  
   [0x23]  = do_lw,		-- load word  
   [0x31]  = do_LWC1,		-- load word  to Float Point TODO ...
   [0x28]  = do_sb,		-- store byte  
   [0x29]  = do_sh,		--   
   [0x2B]  = do_sw,		-- store word  
   [0x39]  = do_SWC1,		-- store word with Float Point TODO ...

   [0x1c]  = do_mul,		-- Multiply word to GPR, NOTE: not MULT
}

