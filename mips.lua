local bit    = require("bit")
local ipairs = ipairs
local pairs  = pairs

local print = print
local string = string

module(...)

local _m = {}

function init()
   local m = {}
   for k, v in pairs(_m) do
      m[k] = v
   end

   return m   
end

function bit.sub(d, i, j)
   return bit.rshift(bit.lshift(d, 31-i), 31-i+j)
end

-- function dec_op(inst)
--    -- 1111 1100 0000 0000 0000 0000 0000 0000, 31:26
--    return bit.rshift( bit.band(inst, 0xFC000000), 26)
-- end

-- function dec_rs(inst)
--    -- 0000 0011 1110 0000 0000 0000 0000 0000, 25:21
--    return bit.rshift( bit.band(inst, 0x03E00000), 21)
-- end

-- function dec_rt(inst)
--    -- 0000 0000 0001 1111 0000 0000 0000 0000, 20:16
--    return bit.rshift( bit.band(inst, 0x001F0000), 16)
-- end

-- function dec_rd(inst)
--    -- 0000 0000 0000 0000 1111 1000 0000 0000, 15:11
--    return bit.rshift( bit.band(inst, 0x0000F800), 11)
-- end

local function decode(inst)
   local   op  = bit.sub(inst, 31, 26)
   local   rs  = bit.sub(inst, 25, 21)
   local   rt  = bit.sub(inst, 20, 16)
   local   rd  = bit.sub(inst, 15, 11)
   local   sa  = bit.sub(inst, 10, 6)
   local func  = bit.sub(inst, 5, 0)
   local  imm  = bit.sub(inst, 15, 0)

   return op, rs, rt, rd, sa, func, imm
end


local rtype = {
   -- key: inst[5:0], i.e. func
   [0x20] = true, -- do_add,	       -- add signed (with overflow) 
   [0x21] = true, -- do_addu,	       -- add unsigned 
   [0x24] = true, -- do_and,	       -- bitwise and 
   [0x25] = true, -- do_or,	       -- bitwise or 
   [0x2A] = true, -- do_slt,	       -- set on less than (signed) 
   [0x2B] = true, -- do_sltu,	       -- set on less than immediate (signed) 
   [0x22] = true, -- do_sub,	       -- sub signed 
   [0x23] = true, -- do_subu,	       -- sub unsigned    
   [0x26] = true, -- do_xor,	       -- bitwise exclusive or    

   [0x00] = true, -- do_sll,	       -- shift left logical  -- [0x00] = true, -- do_noop, noop is "SLL $0 $0 0"
   [0x04] = true, -- do_sllv,	       -- shift left logical variable 
   [0x03] = true, -- do_sra,	       -- shift right arithmetic 
   [0x02] = true, -- do_srl,	       -- shift right logic  
   [0x06] = true, -- do_srlv,	       -- shift right logical variable 

   [0x08] = true, -- do_jr,	       -- jump register
}

local special = {		-- special insts except the normal r-type
   -- key: inst[5:0], i.e. func
   
   [0x1A] = true,  --  do_div,	       -- divide signed 
   [0x1B] = true,  --  do_divu,	       -- divide unsigned 

   [0x10] = true,  --  do_mfhi,	       -- move from HI 
   [0x12] = true,  --  do_mflo,	       -- move from LO 
   [0x11] = true,  --  do_mthi,	       -- move to HI
   [0x13] = true,  --  do_mtlo,	       -- move to LO

   [0x18] = true,  --  do_mult,	       -- multiply signed 
   [0x19] = true,  --  do_multu,	       -- multiply unsigned
   
   -- we don't care the rest
   [0x09] = true,  --  do_jalr,	       -- jump and link register.
   [0x0C] = true,  --  do_syscall,     -- system call
}

local itype = {
   [0x08]  = true,  --  do_addi,	-- add immediate with overflow  
   [0x09]  = true,  --  do_addiu,	-- add immediate no overflow  
   [0x0C]  = true,  --  do_andi,	-- bitwise and immediate  
   [0x0D]  = true,  --  do_ori,		-- bitwise or immediate  
   [0x0E]  = true,  --  do_xori,	-- bitwise exclusive or immediate  

   [0x0A]  = true,  --  do_slti,	-- set on less than immediate  
   [0x0B]  = true,  --  do_sltiu,	-- set on less than immediate unsigned  FIXME WTF?

   [0x0F]  = true,  --  do_lui,		-- load upper immediate  
}

local ltype = {
   [0x20]  = true,  --  do_lb,		-- load byte  
   [0x24]  = true,  --  do_lbu,		-- load byte unsigned  
   [0x21]  = true,  --  do_lh,		--   
   [0x25]  = true,  --  do_lhu,		--   
   [0x23]  = true,  --  do_lw,		-- load word  
   [0x31]  = true,  --  do_LWC1,		-- load word  to Float Point TODO ...
}

local stype = {
   [0x28]  = true,  --  do_sb,		-- store byte  
   [0x29]  = true,  --  do_sh,		--   
   [0x2B]  = true,  --  do_sw,		-- store word  
   [0x39]  = true,  --  do_SWC1,	-- store word with Float Point TODO ...
}


-- we don't care about B or J inst, as its result is handled by branch
-- prediction, including the RA value
local bztype = {   
   -- key: [20:16], i.e. rt
   [0x01] = true, -- do_bgez,	-- fmt=0x01, BGEZ, branch on >= 0
   [0x11] = true, -- do_bgezal,	-- fmt=0x11, BGEZAL, BGEZ and link
   [0x00] = true, -- do_bltz,	-- fmt=0x00, BLTZ, branch on < 0
   [0x10] = true, -- BZ_BLTZAL,	-- fmt=0x10, BLTZAL, BLTZ and link
}

local btype = {
   [0x04]  = true,  --  do_beq,		-- branch on equal
   [0x14]  = true,  --  do_beql,	-- branch on equal likely
   [0x07]  = true,  --  do_bgtz,	-- branch if $s > 0 ($zero)
   [0x17]  = true,  --  do_bgtzl,	-- branch if $s > 0 ($zero) likely
   [0x06]  = true,  --  do_blez,	-- branch if $s <= 0 ($zero)
   [0x16]  = true,  --  do_blezl,	-- branch if $s <= 0 ($zero) likely
   [0x05]  = true,  --  do_bne,		-- branch if $s != $t
   [0x15]  = true,  --  do_bnel,	-- branch if $s != $t   likely
}

local jtype = {
   [0x02]  = true,  --  do_j,		-- jump  
   [0x03]  = true,  --  do_jal,		-- jump and link  
}


local special2 = {		-- op = 0x1C
   -- key: inst[5:0], i.e. func
   
   [0x02]  = true, --  do_mul,		-- Multiply word to GPR, NOTE: not MULT
   [0x00]  = true, --  do_madd,		-- Multiply and Add Word to Hi,Lo
}

local special3 = {		-- op == 0x1F
   -- key: inst[5:0], i.e. func
   [0x0]   = true,  --  do_ext,		-- Extract Bit Field
   [0x04]  = true,  --  do_ins,		-- Inset Bit Field
}


function _m.reg_mem_rw(bblk)
   local read = {}
   local write = {}
   local memio = {}

   local HI, LO = 34, 35

   function add_read(...)
      for _, v in ipairs(...) do
	 -- we only track reads from outside this bblk
	 if not write[v] then read[v] = true end
      end
   end

   function add_write(...)
      for _, v in ipairs(...) do
	 write[v] = true
      end
   end

   print(string.format("examine reg mem I/O 0x%x -> 0x%x", bblk.addr, bblk.tail))
   
   for addr=bblk.addr, bblk.tail, 4 do
      local inst = bblk[addr]
      print(string.format('    0x%x 0x%x', addr, inst))
      local op, rs, rt, rd, sa, func, imm = decode(inst)

      if op == 0 then
	 if rtype[func] then
	    -- op rd, rs, rt
	    add_read{rs, rt}
	    add_write{rd}

	 elseif special[func] then
	    if func == 0x1A or func == 0x1B or func == 0x18 or func == 0x19 then -- div or mult	       
	       add_read{rs, rt}
	       add_write{HI, LO}
	       
	    elseif func == 0x10 then -- mfhi
	       add_read{HI}
	       add_write{rs}
	       
	    elseif func == 0x12 then -- mflo
	       add_read{LO}
	       add_write{rs}

	    elseif func == 0x11 then -- mthi
	       add_read{rs}
	       add_write{HI}
	       
	    elseif func == 0x13 then -- mtlo
	       add_read{rs}
	       add_write{LO}

	    elseif not (func == 0x09 or func == 0x0C) then -- jalr, syscall
	       error("invalid instruction", string.format("0x%x", inst))
	    end
	 end

      elseif op == 1 then
	 if bztype[rt] then
	    -- we don't care about B or J inst, as its result is handled by branch
	    -- prediction, including the RA value
	 else
	    error("invalid instruction", string.format("0x%x", inst))
	 end

      elseif itype[op] then
	 add_read{rs}
	 add_write{rt}
	 
      elseif ltype[op] then
	 add_read{rs}
	 add_write{rt}
	 memio[#memio + 1] = {pc=addr, io='i', base=rs, offset=imm}

      elseif stype[op] then
	 add_read{rs, rt}
	 memio[#memio + 1] = {pc=addr, io='o', base=rs, offset=imm}

      elseif op == 0x1C then	-- SPECIAL2
	 if special2[func] then
	    if func == 0x02 then -- mul, multiply word to GPR
	       add_read{rs, rt}
	       add_write{rd}
	    elseif func == 0x00 then
	       add_read{rs, rt, HI, LO}
	       add_write{HI, LO}
	    end
	 else
	    error("invalid instruction", string.format("0x%x", inst))
	 end

      elseif btype[op] or jtype[op] then
	 -- we don't care about B or J inst, as its result is handled by branch
	 -- prediction, including the RA value
	 --nil
      end
   end  -- for addr=bblk.addr, bblk.tail, 4 do 

   -- the register $zero is always 0, never changes
   read[0], write[0] = nil, nil
   return read, write, memio
end

