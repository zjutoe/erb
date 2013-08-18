#!/usr/bin/env lua

function ld_insts(bb, head, tail)
   local s = bb:sub(head, tail)
   -- to match the instrucitons in the BB
   for addr, op, para in s:gmatch("(0x%x+):%s+(%l+)%s+([%w,%-%(%)]*)") do
      --print(addr, op, para)
   end
end

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
   ld_insts(lines, h, t)
   bbnum = bbnum + 1
end

-- for bb in lines:find(bbpattern) do
--    bbnum = bbnum + 1
--    print(bb:sub(1, 13))
-- end
print(bbnum)
