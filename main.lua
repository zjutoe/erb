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


function main_loop(felf, qemu_bb_log)
   -- init CPUs
   local cpu = require 'cpu.lua'
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
      if cpus then
	 -- get num consective BB's from elf
	 local bbs = bblk.get_bblocks(mem, next_bb_addr, #cpus)
	 -- TODO should have a better schedule algorithm
	 for i, v in ipairs(cpus) do
	    v:try(bbs[i])
	    active_cpus:pushright(v.id)
	 end
      end

      local cid = active_cpus:popleft()
      while cid do
	 -- to follow the real trace, agaist which we should verify the CPUs
	 h, t = lines:find(bbpattern, t-3)
	 if h == nil then break end

	 -- TODO the mem wr insts and their addrs, record them
	 -- TODO the mem rd insts and their addrs, verify them with previously recorded mem wr
	 local rd_insts, wr_insts = rd_wr_insts(lines:sub(h, t))

	 -- TODO implement a mem wr queue, from which the rd could be short-cut

	 -- TODO if all rd is valid, commit the BB in this CPU (id==cid)
	 
	 cid = active_cpus:popleft()
      end

      -- enumerate the active BB's sequentially (following the
      -- original semantic)
      local abbs = active_bbs()
      local clk = abbs[1].len
      for i, v in ipairs(abbs) do
	 -- to follow the real trace, agaist which we should verify the CPUs
	 h, t = lines:find(bbpattern, t-3)
	 if h == nil then break end
	 local bb = qemu_bb(lines, h, t)

	 local c = v.cpu
	 if c:verify(bb) then
	    if c.clk <= clk then
	       c:commit()
	    end
	 else
	    c:discard()
	 end
      end

      next_bb_addr = tonumber(lines:sub(h+3, h+12))
   end	-- while true

end

main_loop()
