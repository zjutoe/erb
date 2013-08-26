local List = require('list')

local l = List.init()
-- local l = List.new()
l:pushright(1)
l:pushright(2)
print(l:popleft())
print(l:popleft())
