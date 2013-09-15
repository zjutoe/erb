local bit = require("bit")

function bit.sub(d, i, j)
   return bit.rshift(bit.lshift(d, 31-i), 31-i+j)
end


-- main loop logic:

-- try_bb()
-- 1. for reg rd inst, record the read value
-- 2. for mem rd inst, record the mem addr ad read value
-- 3. for reg write inst, hold the write till commit
-- 4. for mem write inst, hold the write till commit

-- verify_bb()
-- 1. check for reg/mem read integraty

-- run_bb()
-- 1. count the insts number

-- commit_bb()
-- 1. commit the reg/mem write



-- -- TODO move to mips.lua
-- local is_ld_op = {
--    [0x20]  = true, -- do_lb,		-- load byte  
--    [0x24]  = true, -- do_lbu,		-- load byte unsigned  
--    [0x21]  = true, -- do_lh,		--   
--    [0x25]  = true, -- do_lhu,		--   
--    [0x0F]  = true, -- do_lui,		-- load upper immediate  
--    [0x23]  = true, -- do_lw,		-- load word  
--    [0x31]  = true, -- do_LWC1,		-- load word  to Float Point TODO ...
-- }

-- function is_ld_inst(inst)
--    local op = bit.sub(inst, 31, 26)
--    -- if is_ld_op[op] then return true else return false end
--    return is_ld_op[op] and true or false
-- end


-- local is_st_op = {
--    [0x28]  = true, -- do_sb,		-- store byte  
--    [0x29]  = true, -- do_sh,		--   
--    [0x2B]  = true, -- do_sw,		-- store word  
--    [0x39]  = true, -- do_SWC1,		-- store word with Float Point TODO ...
-- }

-- function is_st_inst(inst)
--    local op = bit.sub(inst, 31, 26)
--    -- if is_ld_op[op] then return true else return false end
--    return is_st_op[op] and true or false
-- end

-- function ld_st_insts(bblock)
--    local ld = {}
--    local st = {}
--    ipattern = "\n0x%x%x%x%x%x%x%x%x:"
--    for inst in bblock:gmatch(ipattern) do
--       local i = tonumber(inst)
--       if is_ld_inst(i) then
-- 	 ld[#ld+1] = i
--       elseif is_st_inst(inst) then
-- 	 st[#st+1] = i
--       end
--    end

--    return ld, st
-- end


local function ss_reg_v(bblk, r)
   -- print('ss_reg_v', bblk:sub(4, 13), r)
   if r == 34 then		-- HI
      return tonumber(bblk:sub(17, 26), 16)
   elseif r == 35 then		-- LO
      return tonumber(bblk:sub(31, 40), 16)
   end
   
   local init = 1		-- where GPR00 begins
   local stride1 = 55		-- a line with 4 registers
   local lead = 7		-- 'GPR00: '
   local stride2 = 12		-- width of a register

   local reg_h = init + math.floor(r/4) * stride1 + lead + (r%4 * stride2)
   -- print('ss_reg_v', reg_h, bblk:sub(reg_h+3, reg_h+11))
   return tonumber(bblk:sub(reg_h+3, reg_h+11), 16)
end

-- next instruction from the singlestep trace
local function ss_next_inst(sslog, h, pc)
   -- print(string.format('searching for 0x%x ... ', pc))

   local in_asm = "\nIN: .-\n0x.-\n\n"
   local h, t = sslog:find(in_asm, h)
   local h0

   while h do
      -- h = h - 2075
      h0 = h - 2014
      print(string.format("checking %x %x:", h, t), sslog:sub(h+6, h+15))
      -- found the corresponding instruction instance in single-step trace
      if (pc == nil) or (tonumber(sslog:sub(h+3, h+12)) == pc) then break end
      -- h, t = sslog:find(bbpattern, t-3)
      h, t = sslog:find(in_asm, t)
   end
   print('Ding!\n')
   print(sslog:sub(h0, t))
   return h0, h, t
end

local mips_reg_name = {
   [0] = 'r0',
   [1] = 'at',
   [2] = 'v0',
   [3] = 'v1',
   [4] = 'a0',
   [5] = 'a1',
   [6] = 'a2',
   [7] = 'a3',

   [8] = 't0',
   [9] = 't1',
   [10] = 't2',
   [11] = 't3',
   [12] = 't4',
   [13] = 't5',
   [14] = 't6',
   [15] = 't7',

   [16] = 's0',
   [17] = 's1',
   [18] = 's2',
   [19] = 's3',
   [20] = 's4',
   [21] = 's5',
   [22] = 's6',
   [23] = 's7',

   [24] = 't8',
   [25] = 't9',
   [26] = 'k0',
   [27] = 'k1',

   [28] = 'gp',
   [29] = 'sp',
   [30] = 's8',
   [31] = 'ra',
}


local function ss_regv(sslog, b, r)
   if r == 34 then
      local h, t = sslog:find("HI=0x%x%x%x%x%x%x%x%x", b)
      return tonumber(sslog:sub(h+5, t), 16)
   elseif r == 35 then
      local h, t = sslog:find("LO=0x%x%x%x%x%x%x%x%x", b)
      return tonumber(sslog:sub(h+5, t), 16)
   else
      local regname = mips_reg_name[r]
      if regname then
	 local h, t = sslog:find(regname .. " %x%x%x%x%x%x%x%x", b)
	 return tonumber(sslog:sub(t-8, t), 16)
      end
   end
end

local function ss_next_i(sslog, b)
   local in_asm = "\n0x%x%x%x%x%x%x%x%x"
   local i, j = sslog:find(in_asm, b)
   if not i then return nil end
   return i+1, j, tonumber(sslog:sub(i+1, j))
end

-- init CPUs
local libcpu = require 'cpu'
local CPU = libcpu.init(4)

local function bb_try(cpus, mem, bblk, next_bb_addr)
   -- get num consective BB's from elf
   local bbs = bblk.get_bblocks(mem, next_bb_addr, #cpus)
   -- TODO should have a better schedule algorithm
   for i, v in ipairs(cpus) do
      print('cpu', v, 'bblock', string.format("0x%x", bbs[i].addr))
      CPU:try(v, bbs[i])
   end
end

local function reg_dependent(reg_out_accum, reg_in)
   for k, v in pairs(reg_in) do
      if reg_out_accum[v] then return true end
   end
   return false
end

local mips = require('mips')
local isa = mips.init()

function main_loop(felf, qemu_bb_log, qemu_ss_log)
   
   -- init the elf loader and bblock parser
   local loadelf = require 'luaelf/loadelf'
   local elf = loadelf.init()
   local mem = elf.load(felf)
   local bblock = require ("bblock")
   local bblk = bblock.init()
   local next_bb_addr = mem.e_entry	-- the execution entry address

   local f_bb_log = io.input(qemu_bb_log)
   local bblog = f_bb_log:read("*all")
   local bbpattern = "pc=.-pc="
   local in_asm = "\nIN: .-\n0x.-\n\n"
   local h
   local t = 4			-- 4-3=1, it's the pre-offset for the 2nd "pc=" in the bbpattern

   local f_ss_log = io.input(qemu_ss_log)
   local sslog = f_ss_log:read("*all")   
   local hss = 0
   local tss = 0

   local List = require('list')
   local active_cpus = List.init()
   
   local finish = false
   while not finish do
      local cpus = CPU:idle_cpus()
      print(#cpus, "CPUs are idle")

      -- hss, tss, pcss = ss_next_i(sslog, tss)
	 
      -- TODO for each idle cpu, we could schedule more than one
      -- consective bblks into it if those bblks are reg rd/wr
      -- dependent
      if cpus then
	 bb_try(cpus, mem, bblk, next_bb_addr)
	 for i, v in ipairs(cpus) do
	    active_cpus:pushright(v)
	 end
      end

      local reg_out_accum = {}
      local mem_out_accum = {}

      -- in case the speculation fails, back off sslog to this postion
      local h0 = hss
      
      -- verify the bblks on the CPUs
      local cid = active_cpus:popleft()
      while cid and not finish do
	 local bb = CPU[cid].run

	 -- The idea: 1. validate the register reads; 2. validate the
	 -- memory reads. If the register reads are all correct, then
	 -- the memory read addresses are correct, upon which we only
	 -- need to worry about the memory read value, i.e. just need
	 -- to worry about RAW confliction. In a word, if 1 fails,
	 -- then the speculation fails, otherwise we continue to check
	 -- 2.

	 local reg_in, reg_out, memio = isa.reg_mem_rw(bb)
	 if reg_dependent(reg_out_accum, reg_in) then
	    reg_dep = true
	    CPU[cid].busy = false
	    break
	 end
	 
	 local steer, mem_dep = false, false
	 local mem_out = {}
	 local pc = bb.addr
	 local pcss

	 local h1 = hss
	 hss, tss, pcss = ss_next_i(sslog, hss)
	 while hss do
	    -- TODO validate_inst(sslog, hss, tss, pcss, pc)

	    -- this means a branch happens, i.e. the last bblk is done
	    if pcss ~= pc then	       
	       next_bb_addr = pcss -- steer to the right direction
	       hss = h1		   -- back off one instruction
	       steer = true
	       print(string.format("%x ~= %x, steer to %x", pcss, pc, next_bb_addr))
	       break
	    end

	    local v = memio[pcss]
	    if v then
	       local base = ss_regv(sslog:sub(hss0, tss), h0, v.base)
	       local a = base + v.offset

	       if v.io == 'i' then
		  -- speculative load conflicts with previous committed store
		  if mem_out_accum[a] then
		     hss = h0 -- back off one bblk
		     mem_dep = true
		     print("mem dependency")
		     break
		  end
	       else
		  mem_out[a] = true
	       end
	    end

	    -- the last inst of this bb is done
	    if pc == bb.tail then break end

	    -- proceed to the next inst in this bb
	    pc = pc + 4
	    h1 = hss		-- in case we need to back off 
	    hss, tss, pcss = ss_next_i(sslog, hss)

	    if pcss then
	       print(string.format('pc=%x, pcss=%x', pc, pcss))
	    end
	 end  -- hss

	 --[[
	 if steer then
	    -- the speculation went a wrong direction
	    print("wrong branch speculation, steer to", string.format("0x%x", next_bb_addr))
	    print('----------------------------')
	 elseif mem_dep then
	    print("mem dependency")
	    print('----------------------------')
	    break
	 end
	 --]]

	 CPU[cid].busy = false

	 -- cannot commit
	 if mem_dep then break end

	 -- speculation succeeds, to commit the reg and mem output
	 -- (i.e. write & store)
	 for k, v in pairs(reg_out) do reg_out_accum[k] = v end
	 for k, v in pairs(mem_out) do mem_out_accum[k] = v end

	 -- TODO count the clocks, see how much performance we
	 -- accelerated
	 print(string.format("0x%x", bb.addr), 'commit on CPU', cid)
	 print('----------------------------')

	 -- discard following CPUs, but should commit this one
	 if steer then break end
	 
	 -- TODO: treat the bblock as a blackbox, actually we don't
	 -- care whether the input is correct, what we care is its
	 -- output. E.g. sometimes some insts will read some value,
	 -- but never really use them, then such read is effectively
	 -- nil, and even speculative execution of such insts fail, it
	 -- doesn't matter. BUT, unless re-run the bblock with correct
	 -- input and compare the output, we will never know wehther
	 -- the output matters or not. How to make use of this
	 -- feature?


	 -- TODO: adjust the dependency analysis strategy: 1. examine
	 -- the register rd/wr deps, if conflicts exist, do not
	 -- parallelize, but issue to the same core (as long as no
	 -- intermediate bblocks are already scheduled to other
	 -- cores); 2. only after step 1 that we will examine mem
	 -- ld/st conflicts to validate speculation, i.e. we only
	 -- speculate regarding mem rd/st (for those the addr we can't
	 -- decide before running)
	 
	 cid = active_cpus:popleft()
      end  -- while cid and not finish do

      -- discard the rest bblks 
      cid = active_cpus:popleft()
      while cid do
	 CPU[cid].busy = false
	 cid = active_cpus:popleft()
      end

      -- if not steer then next_bb_addr = tonumber(bblog:sub(h+3, h+12)) end
   end	-- while true

end

-- main_loop(arg[1], arg[2], arg[3])
main_loop('test/hello-mips.S', 'test/qemu-bb.log', 'test/qemu-ss.log')
