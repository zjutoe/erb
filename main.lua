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
   if r == 34 then		-- HI
      return tonumber(bblk:sub(17, 26), 16)
   elseif r == 35 then		-- LO
      return tonumber(bblk:sub(31, 40), 16)
   end
   
   local init = 60		-- where GPR00 begins
   local stride1 = 54		-- a line with 4 registers
   local lead = 7		-- 'GPR00: '
   local stride2 = 12		-- width of a register

   local reg_h = init + math.floor(r/4) * stride1 + lead + (r%4 * stride2)
   return tonumber(bblk:sub(reg_h+3, reg_h+11), 16)
end


local mips = require('mips')
local isa = mips.init()

function main_loop(felf, qemu_bb_log, qemu_ss_log)
   -- init CPUs
   local cpu = require 'cpu'
   local CPU = cpu.init(4)
   
   -- init the elf loader and bblock parser
   local loadelf = require 'luaelf/loadelf'
   local elf = loadelf.init()
   local mem = elf.load(felf)
   local bblock = require ("bblock")
   local bblk = bblock.init()
   local next_bb_addr = mem.e_entry	-- the execution entry address

   local f_bb_log = io.input(qemu_bb_log)
   local bblog = f_bb_log:read("*all")
   bbpattern = "pc=.-pc="
   local h
   local t = 4			-- 4-3=1, it's the pre-offset for the 2nd "pc=" in the bbpattern

   local f_ss_log = io.input(qemu_ss_log)
   local sslog = f_ss_log:read("*all")   
   local hss
   local tss = 4

   local List = require('list')
   local active_cpus = List.init()
   
   while true do
      local cpus = CPU:idle_cpus()
      print(#cpus, "CPUs are idle")
      -- TODO for each idle, we could schedule more than one
      -- consective bblks into it if those bblks are reg rd/wr
      -- dependent
      if cpus then
	 -- get num consective BB's from elf
	 local bbs = bblk.get_bblocks(mem, next_bb_addr, #cpus)
	 -- TODO should have a better schedule algorithm
	 for i, v in ipairs(cpus) do
	    print('cpu', v, 'bblock', string.format("0x%x", bbs[i].addr))
	    CPU:try(v, bbs[i])
	    active_cpus:pushright(v)
	 end
      end

      local reg_out_accum = {}
      local steer = false
      local cid = active_cpus:popleft()
      while cid do
	 -- to follow the real trace, agaist which we should verify the CPUs
	 local h0, t0 = h, t
	 h, t = bblog:find(bbpattern, t-3)
	 if h == nil then break end
	 local addr = tonumber(bblog:sub(h+3, h+12))
	 print('validating', string.format("0x%x", addr))
	 
	 local bblk = CPU[cid].run
	 
	 -- FIXME need to compare bblk.tail too
	 if addr ~= bblk.addr then	    
	    -- the speculation went a wrong direction
	    next_bb_addr = tonumber(bblog:sub(h+3, h+12)) -- steer to the right direction
	    steer = true
	    print("wrong branch speculation, steer to", string.format("0x%x", next_bb_addr))

	    h, t = h0, t0	-- backoff the trace for 1 bblock
	    CPU[cid].busy = false -- directly discard the bblock in the cpu
	    cid = active_cpus:popleft()
	    while cid do
	       CPU[cid].busy = false -- directly discard the bblock in the cpu
	       cid = active_cpus:popleft()
	    end
	    break
	 end

	 -- TODO: 1. validate the register reads; 2. validate the
	 -- memory reads. If the register reads are all correct, then
	 -- the memory read addresses are correct, upon which we only
	 -- need to worry about the memory read value, i.e. just need
	 -- to worry about RAW confliction. In a word, if 1 fails,
	 -- then the speculation fails, otherwise we continue to check
	 -- 2.
	 local reg_dep = false
	 local mem_dep = false		    

	 local reg_in, reg_out, memio = isa.reg_mem_rw(bblk)
	 for k, v in pairs(reg_in) do
	    if reg_out_accum[v] then
	       reg_dep = true
	       break
	    end
	 end

	 -- now the speculative reg reads are successful, which
	 -- garantee the mem read addresses are correct. we will
	 -- further verify the speculative mem read by comparing
	 -- the read addresses against previous writes
	 if not reg_dep then
	    -- go thru the mem i/o sequentially
	    for i, v in ipairs(memio) do
	       hss, tss = sslog:find(bbpattern, tss-3)
	       if hss == nil then break end
	       
	       while hss do
		  -- found the corresponding instruction instance in single-step trace
		  if tonumber(sslog:sub(hss+3, hss+12)) == v.pc then
		     local base = ss_reg_v(sslog:sub(hss, tss), v.base)
		     local a = base + v.offset

		     if v.io == 'i' then
			-- speculative load conflicts with previous committed store
			if mem_out_accm[a] then
			   mem_dep = true
			   break
			end
		     else
			mem_out[a] = true
		     end
		     
		     -- only break this level of loop when corresponding inst is found
		     break 
		  end  -- if 
	       end  -- while hss
	    end  -- for i, v in ipairs(memio) 
	 end  -- if not reg_dep

	 -- speculation succeeds, to commit the reg and mem output
	 -- (i.e. write & store)
	 if not (reg_dep or mem_dep) then
	    for k, v in pairs(reg_out) do
	       reg_out_accum[k] = v
	    end
	    for k, v in pairs(mem_out) do
	       mem_out_accum[k] = v
	    end

	    -- TODO count the clocks, see how much performance we
	    -- accelerated
	    print(bblk.addr, 'commit on CPU', cid)
	 end	 

	 -- commit or discard, we'll release this CPU	 
	 CPU[cid].busy = false

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
      end  -- while cid

      if not steer then next_bb_addr = tonumber(bblog:sub(h+3, h+12)) end
   end	-- while true

end

-- main_loop(arg[1], arg[2], arg[3])
main_loop('test/hello-mips.S', 'test/qemu-bb.log', 'test/qemu.log')
