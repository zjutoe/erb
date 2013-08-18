#!/usr/bin/env lua

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
   bbnum = bbnum + 1
end

-- for bb in lines:find(bbpattern) do
--    bbnum = bbnum + 1
--    print(bb:sub(1, 13))
-- end
print(bbnum)
