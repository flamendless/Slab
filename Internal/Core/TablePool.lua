local insert = table.insert
local remove = table.remove

local TablePool = {}
TablePool.__index = TablePool

function TablePool.new()
	return setmetatable({}, TablePool)
end

function TablePool:pop()
	if #self == 0 then
		return {}, true
	end

	return remove(self)
end

function TablePool:pop_clean()
	local res, is_empty = self:pop()

	if is_empty then
		return res
	end

	for k in pairs(res) do
		res[k] = nil
	end

	return res
end

function TablePool:push(t)
	insert(self, t)
end

return TablePool.new
