local insert = table.insert
local remove = table.remove

local TablePool = {}
TablePool.__index = TablePool

function TablePool.new()
	return setmetatable({[0] = 0}, TablePool)
end

function TablePool:pop()
	local n = self[0]
	if n == 0 then return {}, true end
	local res = self[n]
	self[n], self[0] = nil, n - 1
	return res
end

function TablePool:pop_clean()
	local res = self:pop()
	for k in pairs(res) do
		res[k] = nil
	end
	return res
end

function TablePool:push(t)
	local n = self[0] + 1
	self[n], self[0] = t, n
end

return TablePool.new
