--[[

MIT License

Copyright (c) 2019-2021 Love2D Community <love2d.org>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

--]]

local love = require("love")
local insert = table.insert
local max = math.max
local format = string.format

local Utility = require(SLAB_PATH .. ".Internal.Core.Utility")

local Stats = {}

local data, pending = {}, {}
local enabled = false
local q_enabled, q_disable = false, false
local id = 1
local q_flush = false
local frame_n = 0

local function GetCategory(category)
	assert(category ~= nil, "Nil category given to Stats system.")
	assert(category ~= "", "Empty category given to Stats system.")
	assert(type(category) == "string", "Category given is not of type string. Type given is '" .. type(category) .. "'.")
	if not data[category] then
		data[category] = {}
	end
	return data[category]
end

local function ResetCategory(instance)
	if not instance then return end
	for _, v in pairs(instance) do
		v.last_time = v.time
		v.last_call_count = v.call_count
		v.max_time = max(v.max_time, v.time)
		v.time = 0
		v.call_count = 0
	end
end

local function GetItem(name, category)
	assert(name ~= nil, "Nil name given to Stats system.")
	assert(name ~= "", "Empty name given to Stats system.")

	local cat = GetCategory(category)
	if not cat[name] then
		cat[name] = {
			time = 0,
			max_time = 0,
			call_count = 0,
			last_time = 0,
			last_call_count = 0,
		}
	end
	return cat[name]
end

function Stats.Begin(name, category)
	if not enabled then return end
	local handle = id
	id = id + 1
	local instance = {start_time = love.timer.getTime(), name = name, category = category}
	pending[handle] = instance
	return handle
end

function Stats.End(handle)
	if not enabled then return end
	assert(handle ~= nil, "Nil handle given to Stats.End.")
	local instance = pending[handle]
	assert(instance ~= nil, "Invalid handle given to Stats.End.")
	pending[handle] = nil
	local elapsed = love.timer.getTime() - instance.start_time
	local item = GetItem(instance.name, instance.category)
	item.call_count = item.call_count + 1
	item.time = item.time + elapsed
end

local C_NONE = 0
function Stats.GetTime(name, category)
	if not enabled then return C_NONE end
	local item = GetItem(name, category)
	return item.time > C_NONE and item.time or item.last_time
end

function Stats.GetMaxTime(name, category)
	if not enabled then return C_NONE end
	local item = GetItem(name, category)
	return item.max_time
end

function Stats.GetCallCount(name, category)
	if not enabled then return C_NONE end
	local item = GetItem(name, category)
	return item.call_count > 0 and item.call_count or item.last_call_count
end

function Stats.Reset(strict)
	frame_n = frame_n + 1

	if q_enabled then
		enabled = true
		q_enabled = false
	end

	if q_disable then
		enabled = false
		q_disable = false
	end

	if q_flush then
		Utility.ClearTable(data)
		Utility.ClearTable(pending)
		id = 1
		q_flush = false
	end

	if not enabled then return end

	if strict then
		local message
		for _, v in pairs(pending) do
			if not message then
				message = "Stats.End were not called for the given stats: \n"
			end
			message = format("%s\t%s in %s\n", message, tostring(v.name), tostring(v.category))
		end
		assert(message == nil, message)
	end

	for _, v in pairs(data) do
		ResetCategory(v)
	end
end

function Stats.SetEnabled(is_enabled)
	q_enabled = is_enabled
	if not q_enabled then
		q_disable = true
	end
end

function Stats.IsEnabled()
	return enabled
end

function Stats.GetCategories()
	local res = {}
	for k in pairs(data) do
		insert(res, k)
	end
	return res
end

function Stats.GetItems(category)
	local res = {}
	local instance = GetCategory(category)
	for k in pairs(instance) do
		insert(res, k)
	end
	return res
end

function Stats.Flush()
	q_flush = true
end

function Stats.GetFrameNumber()
	return frame_n
end

return Stats
