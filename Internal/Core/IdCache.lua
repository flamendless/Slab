local format = string.format

local IdCache = {}

IdCache.__index = IdCache

function IdCache.new()
	return setmetatable({
		__ids = {}
	}, IdCache)
end

function IdCache:get(parent_id, id)
	local p = self.__ids[parent_id]
	local res_id = p and p[id]
	if res_id then return res_id end
	res_id = format("%s.%s", parent_id, id)
	if p then
		p[id] = res_id
	else
		self.__ids[parent_id] = {[id] = resultId}
	end
	return res_id
end

return IdCache.new
