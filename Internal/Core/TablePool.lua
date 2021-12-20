local insert = table.insert

local TablePool = {}
TablePool.__index = TablePool

function TablePool:pull()
	local count = #self
	if count == 0 then return {} end

	local result = self[count]
	self[count] = nil
	return result
end

function TablePool:pullClean()
	local count = #self
	if count == 0 then return {} end

	local result = self[count]
	self[count] = nil

	for k in pairs(result) do
		result[k] = nil
	end
	return result
end

function TablePool:push(t)
	insert(self, t)
end

return function()
	return setmetatable({}, TablePool)
end
