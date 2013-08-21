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

function next_bb_to_try()
   
end

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

      local bb2 = elf_bb(elf, h, t)
      local cpu = idle_cpu()
      while cpu do
	 cpu:try(bb2)
	 bb2 = elf_bb(elf, 
	 cpu = idle_cpu()
      end
      
      -- print(lines:sub(h, h+12))
      local ins = insts_ld(lines, h, t-3)
      addrs_ld(ins)
   end
   

      while idle_cpus() > 0 then
	 try_bb()
      end
      proceed_cpus()
      local bb = bb_from_leading_cpu()
      local spec = verify_bb(bb)
      if spec == false then      
	 -- speculation failed
	 try_bb(bb)		-- ?
      end
      commit_bb(bb)

end

main_loop()
