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



function elf_bbs(elf, h, num)
   
end

local is_ld_op = {
   [0x20]  = true, -- do_lb,		-- load byte  
   [0x24]  = true, -- do_lbu,		-- load byte unsigned  
   [0x21]  = true, -- do_lh,		--   
   [0x25]  = true, -- do_lhu,		--   
   [0x0F]  = true, -- do_lui,		-- load upper immediate  
   [0x23]  = true, -- do_lw,		-- load word  
   [0x31]  = true, -- do_LWC1,		-- load word  to Float Point TODO ...
}

function is_ld_inst(inst)
   local op = bit.sub(inst, 31, 26)
   -- if is_ld_op[op] then return true else return false end
   return is_ld_op[op] and true or false
end


local is_st_op = {
   [0x28]  = true, -- do_sb,		-- store byte  
   [0x29]  = true, -- do_sh,		--   
   [0x2B]  = true, -- do_sw,		-- store word  
   [0x39]  = true, -- do_SWC1,		-- store word with Float Point TODO ...
}

function is_st_inst(inst)
   local op = bit.sub(inst, 31, 26)
   -- if is_ld_op[op] then return true else return false end
   return is_st_op[op] and true or false
end

function ld_st_insts(bblock)
   local ld = {}
   local st = {}
   ipattern = "\n0x%x%x%x%x%x%x%x%x:"
   for inst in bblock:gmatch(ipattern) do
      local i = tonumber(inst)
      if is_ld_inst(i) then
	 ld[#ld+1] = i
      elseif is_st_inst(inst) then
	 st[#st+1] = i
      end
   end

   return ld, st
end


function main_loop(felf, qemu_bb_log)
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
   local lines = f_bb_log:read("*all")
   bbpattern = "pc=.-pc="
   local h
   local t = 4			-- 4-3=1, it's the pre-offset for the 2nd "pc=" in the bbpattern

   local List = require('list')
   local active_cpus = List.init()
   
   while true do
      local cpus = CPU:idle_cpus()
      print(#cpus, "CPUs are idle")
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

      local steer = false
      local cid = active_cpus:popleft()
      while cid do
	 -- to follow the real trace, agaist which we should verify the CPUs
	 local h0, t0 = h, t
	 h, t = lines:find(bbpattern, t-3)
	 if h == nil then break end
	 local addr = tonumber(lines:sub(h+3, h+12))
	 print('validating', string.format("0x%x", addr))
	 
	 local bblk = CPU[cid].run
	 
	 if addr ~= bblk.addr then	    
	    -- the speculation went a wrong direction
	    next_bb_addr = tonumber(lines:sub(h+3, h+12)) -- steer to the right direction
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

	 --[[ FIXME temprarily disable the block below
	 -- TODO the mem wr insts and their addrs, record them
	 -- TODO the mem rd insts and their addrs, verify them with previously recorded mem wr
	 local ld_insts, st_insts = ld_st_insts(lines:sub(h, t))

	 -- TODO implement a mem wr queue, from which the rd could be short-cut

	 -- TODO if all rd is valid, commit the BB in this CPU (id==cid)
	 local invalid = false
	 for k, v in ipairs(ld_insts) do
	    local addr = ld_addr(v)
	    if pending_st[addr] then
	       invalid = true
	    end
	 end
	 if invalid then
	    rollback(cid)
	 else
	    for k, v in ipairs(st_insts) do
	       local addr = st_addr(v)
	       pending_st[addr] = true
	    end
	    -- TODO record the clocks of thie bblock
	 end
	 --]]
	 
	 cid = active_cpus:popleft()
      end  -- while cid

      if not steer then next_bb_addr = tonumber(lines:sub(h+3, h+12)) end
   end	-- while true

end

main_loop(arg[1], arg[2])

