local trace = assert(io.open(arg[1], "r"))

-- the graph stores the relationship between the BBs. This is a
-- directional graph, with the BBs as nodes, and execution flow
-- between BBs as edges
local g = {}

local h0, t0 = trace:read("*number", "*number")

if h0 and t0 then
   local h1, t1 = trace:read("*number", "*number")
   while h1 and t1 do
      local k = h0 .. ' -> ' .. h1
      if g[k] then
	 g[k] = g[k] + 1 
      else
	 g[k] = 1 
      end
      h0, t0 = h1, t1
      h1, t1 = trace:read("*number", "*number")
   end   
end

for k, v in pairs(g) do
   print(k, v)
end
