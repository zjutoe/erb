local pairs  = pairs
local ipairs = ipairs

module(...)

local _m = {}

function init(num)
   local m = {}
   for k, v in pairs(_m) do
      m[k] = v
   end

   for i=1, num do
      local c = {}
      c.id = i
      c.busy = false
      m[i] = c
   end

   return m
end


function _m.idle_cpus(self)
   local cpus = {}
   for i, v in ipairs(self) do
      if not v.busy then 
	 cpus[#cpus + 1] = v 
      end
   end
   -- if #cpus > 0 then return cpus else return nil end
   return #cpus > 0 and cpus or nil
end

function _m.try(cpu, bblock)
   cpu.run = bblock
end
