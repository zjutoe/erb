#!/usr/bin/env lua

local ops_ld = {
   lb  = 1,  
   lbu = 1,
   lh  = 1,
   lhu = 1,
   ll  = 1,
   lw  = 1,
   lwl = 1,
   lwr = 1,
}

local R = {}

function insts_ld(bb, head, tail)
   local t = {}
   local s = bb:sub(head, tail)
   -- to match the instrucitons in the BB
   for addr, op, para in s:gmatch("(0x%x+):%s+(%w+)%s*([%w,%-%(%)%$]*)\n") do
      -- print(addr, op, para)
      if ops_ld[op] then
	 t[addr] = {op=op, para=para}
      end
   end

   return t
end

function addrs_ld(t)
   local ret = {}
   for addr, inst in pairs(t) do
      local op, para = inst.op, inst.para
      local rt, offset, base = para:match("(%w+),(%-*%d+)%((%w+)%)")
      -- print(addr, op, rt, offset, base)
      ret[#ret ＋ 1] ＝ tonumber(offset) + R[base]
   end

   return ret
end

-- TODO: for each BB, save the GPR values in R, or try to retrieve the
-- GPR values on demand according to the addrs of the ld insts

function main()

   -- local BUFSIZE = 2^13
   local f = io.input(arg[1])
   local bbnum = 0
   -- while true do
   --    -- 8K
   --    -- open input file
   --    -- char, line, and word counts
   --    local lines, rest = f:read(BUFSIZE, "*line")
   --    if not lines then break end
   --    if rest then lines = lines .. rest .. "\n" end
   
   --    bbpattern = "pc=.-\n\n"
   
   --    for bb in lines:gmatch(bbpattern) do
   --       bbnum = bbnum + 1
   --       -- print(bb)
   --    end
   
   -- end


   local lines = f:read("*all")

   bbpattern = "pc=.-pc="
   local h, t
   t = 4
   while true do
      h, t = lines:find(bbpattern, t-3)
      if h == nil then break end
      -- print(lines:sub(h, h+12))
      local ins = insts_ld(lines, h, t-3)
      addrs_ld(ins)
      bbnum = bbnum + 1
   end

   -- for bb in lines:find(bbpattern) do
   --    bbnum = bbnum + 1
   --    print(bb:sub(1, 13))
   -- end
   --print(bbnum)   
end

main()
