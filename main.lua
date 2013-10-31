local bit = require("bit")

function bit.sub(d, i, j)
   return bit.rshift(bit.lshift(d, 31-i), 31-i+j)
end

-- local D = print
function D(...)
end

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
   -- D('ss_reg_v', reg_h, bblk:sub(reg_h+3, reg_h+11))
   return tonumber(bblk:sub(reg_h+3, reg_h+11), 16)
end

-- next instruction from the singlestep trace
local function ss_next_inst(sslog, h, pc)
   -- D(string.format('searching for 0x%x ... ', pc))

   local in_asm = "\nIN: .-\n0x.-\n\n"
   local h, t = sslog:find(in_asm, h)
   local h0

   while h do
      -- h = h - 2075
      h0 = h - 2014
      D(string.format("checking %x %x:", h, t), sslog:sub(h+6, h+15))
      -- found the corresponding instruction instance in single-step trace
      if (pc == nil) or (tonumber(sslog:sub(h+3, h+12)) == pc) then break end
      -- h, t = sslog:find(bbpattern, t-3)
      h, t = sslog:find(in_asm, t)
   end
   D('Ding!\n')
   D(sslog:sub(h0, t))
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
      D('cpu', v, 'bblock', string.format("0x%x", bbs[i].addr))
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

function main_loop(felf, qemu_ss_log)
   
   -- init the elf loader and bblock parser
   local loadelf = require 'luaelf/loadelf'
   local elf = loadelf.init()
   local mem = elf.load(felf)
   local bblock = require ("bblock")
   local bblk = bblock.init()
   local next_bb_addr = mem.e_entry	-- the execution entry address

   local f_ss_log = io.input(qemu_ss_log)
   local sslog = f_ss_log:read("*all")   
   local hss = 0
   local tss = 0

   local List = require('list')
   local active_cpus = List.init()

   local mem_access_cnt = 0
   
   local finish = false
   while not finish do
      local cpus = CPU:idle_cpus()
      D(#cpus, "CPUs are idle")

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
      local bkbb = hss
      
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
	 D('reg_in')
	 for k, v in pairs(reg_in or {}) do
	    D('    ', k, v)
	 end
	 D('reg_out')
	 for k, v in pairs(reg_out or {}) do
	    D('    ', k, v)
	 end
	 D('memio')
	 for k, v in ipairs(memio or {}) do
	    D('    ', k, v.base, v.offset)
	 end


	 if reg_dependent(reg_out_accum, reg_in) then
	    D("reg dep detected, abort CPU", cid)
	    reg_dep = true
	    CPU[cid].busy = false
	    break
	 end
	 
	 local steer, mem_dep = false, false
	 local mem_out = {}
	 local pc = bb.addr
	 local pcss

	 local bki = hss
	 hss, tss, pcss = ss_next_i(sslog, hss)
	 while hss do
	    -- TODO validate_inst(sslog, hss, tss, pcss, pc)
	    
	    -- this means a branch happens, i.e. the last bblk is done
	    if pcss ~= pc then	       
	       next_bb_addr = pcss -- steer to the right direction
	       hss = bki	   -- back off one instruction
	       steer = true
	       D(string.format("%x ~= %x, steer to %x", pcss, pc, next_bb_addr))
	       break
	    end

	    -- FIXME we assume the BB will not read and write to the
	    -- same address, therefore each read should be considered
	    -- as read from outside. But this may be false in theory.
	    local v = memio[pcss]
	    if v then
	       local base = ss_regv(sslog, bki, v.base)
	       local a = base + v.offset
	       D(string.format('%x(%d) %x', v.offset, v.base, a), v.io)

	       if v.io == 'i' then
		  -- speculative load conflicts with previous (in this
		  -- round) committed store
		  if mem_out_accum[a] then
		     hss = bkbb -- back off one bblk
		     mem_dep = true
		     D("mem dependency detected")
		     break
		  else
		     mem_access_cnt = mem_access_cnt + 1
		     print(string.format("%d 0 %x 4 d%d", cid, a, mem_access_cnt))
		  end
	       else
		  mem_out[a] = true
	       end
	    end

	    -- the last inst of this bb is done
	    if pc == bb.tail then break end

	    -- proceed to the next inst in this bb
	    pc = pc + 4
	    bki = hss		-- in case we need to back off 
	    hss, tss, pcss = ss_next_i(sslog, hss)

	    if pcss then
	       D(string.format('pc=%x, pcss=%x', pc, pcss))
	    end
	 end  -- hss

	 CPU[cid].busy = false

	 -- cannot commit
	 if mem_dep or steer then break end

	 -- speculation succeeds, to commit the reg and mem output
	 -- (i.e. write & store)
	 for k, v in pairs(reg_out) do reg_out_accum[k] = v end
	 for k, v in pairs(mem_out) do 
	    mem_out_accum[k] = v 
	    mem_access_cnt = mem_access_cnt + 1
	    print(string.format("%d 1 %x 4 d%d", cid, k, mem_access_cnt))
	 end

	 -- TODO count the clocks, see how much performance we
	 -- accelerated
	 D(string.format("0x%x", bb.addr), 'commit on CPU', cid)
	 D('----------------------------')

	 if not hss then
	    D("finish")
	    finish = true 
	 end
	 
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

	 bkbb = hss
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

main_loop(arg[1], arg[2])
--main_loop('test/hello-mips.S', 'test/qemu-ss.log')
