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

function main_loop()
   local f_bb_log = io.input("qemu_bb.log")
   local lines = f_bb_log:read("*all")
   bbpattern = "pc=.-pc="
   local h
   local t = 4
   while true do
      h, t = lines:find(bbpattern, t-3)
      if h == nil then break end
      local bb = qemu_bb(lines, h, t)

      local num = idle_cpu_num()
      if num > 0 then
	 -- get num consective BB's from elf
	 local bbs = elf_bbs(elf, h, num)
	 local cpus = idle_cpus()
	 -- TODO should have a better schedule algorithm
	 for i, v in ipairs(cpus) do
	    v:try(bbs[i])
	 end
      end

      -- enumerate the active BB's sequentially (following the
      -- original semantic)
      local abbs = active_bbs()
      local clk = abbs[1].len
      for i, v in ipairs(abbs) do
	 local c = v.cpu
	 if c:verify() then
	    if c.clk <= clk then
	       c:commit()
	    end
	 else
	    c:discard()
	 end
      end

   end				-- while true

end

main_loop()
