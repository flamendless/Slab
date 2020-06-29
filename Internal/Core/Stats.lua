--[[

MIT License

Copyright (c) 2019-2020 Mitchell Davis <coding.jackalope@gmail.com>

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

local Stats = {}

local insert = table.insert
local max = math.max

local Data = {}
local Pending = {}
local Enabled = false
local QueueEnabled = false
local QueueDisable = false
local Id = 1
local QueueFlush = false
local FrameNumber = 0

local function GetCategory(Category)
	assert(Category ~= nil, "Nil category given to Stats system.")
	assert(Category ~= '', "Empty category given to Stats system.")
	assert(type(Category) == 'string', "Category given is not of type string. Type given is '" .. type(Category) .. "'.")

	if Data[Category] == nil then
		Data[Category] = {}
	end

	return Data[Category]
end

local function ResetCategory(Category)
	local Instance = Data[Category]

	if Instance ~= nil then
		for K, V in pairs(Instance) do
			V.LastTime = V.Time
			V.LastCallCount = V.CallCount
			V.MaxTime = max(V.MaxTime, V.Time)
			V.Time = 0.0
			V.CallCount = 0
		end
	end
end

local function GetItem(Name, Category)
	assert(Name ~= nil, "Nil name given to Stats system.")
	assert(Name ~= '', "Empty name given to Stats system.")

	local Cat = GetCategory(Category)

	if Cat[Name] == nil then
		local Instance = {}
		Instance.Time = 0.0
		Instance.MaxTime = 0.0
		Instance.CallCount = 0
		Instance.LastTime = 0.0
		Instance.LastCallCount = 0.0
		Cat[Name] = Instance
	end

	return Cat[Name]
end

function Stats.Begin(Name, Category)
	if not Enabled then
		return
	end

	local Handle = Id
	Id = Id + 1

	local Instance = {StartTime = love.timer.getTime(), Name = Name, Category = Category}
	Pending[Handle] = Instance

	return Handle
end

function Stats.End(Handle)
	if not Enabled then
		return
	end

	assert(Handle ~= nil, "Nil handle given to Stats.End.")

	local Instance = Pending[Handle]
	assert(Instance ~= nil, "Invalid handle given to Stats.End.")
	Pending[Handle] = nil

	local Elapsed = love.timer.getTime() - Instance.StartTime

	local Item = GetItem(Instance.Name, Instance.Category)
	Item.CallCount = Item.CallCount + 1
	Item.Time = Item.Time + Elapsed
end

function Stats.GetTime(Name, Category)
	if not Enabled then
		return 0.0
	end

	local Item = GetItem(Name, Category)

	return Item.Time > 0.0 and Item.Time or Item.LastTime
end

function Stats.GetMaxTime(Name, Category)
	if not Enabled then
		return 0.0
	end

	local Item = GetItem(Name, Category)

	return Item.MaxTime
end

function Stats.GetCallCount(Name, Category)
	if not Enabled then
		return 0
	end

	local Item = GetItem(Name, Category)
	
	return Item.CallCount > 0 and Item.CallCount or Item.LastCallCount
end

function Stats.Reset()
	FrameNumber = FrameNumber + 1

	if QueueEnabled then
		Enabled = true
		QueueEnabled = false
	end

	if QueueDisable then
		Enabled = false
		QueueDisable = false
	end

	if QueueFlush then
		Data = {}
		Pending = {}
		Id = 1
		QueueFlush = false
	end

	if not Enabled then
		return
	end

	local Message = nil
	for K, V in pairs(Pending) do
		if Message == nil then
			Message = "Stats.End were not called for the given stats: \n"
		end

		Message = Message .. "\t" .. tostring(V.Name) .. " in " .. tostring(V.Category) .. "\n"
	end

	assert(Message == nil, Message)

	for K, V in pairs(Data) do
		ResetCategory(K)
	end
end

function Stats.SetEnabled(IsEnabled)
	QueueEnabled = IsEnabled

	if not QueueEnabled then
		QueueDisable = true
	end
end

function Stats.IsEnabled()
	return Enabled
end

function Stats.GetCategories()
	local Result = {}

	for K, V in pairs(Data) do
		insert(Result, K)
	end

	return Result
end

function Stats.GetItems(Category)
	local Result = {}

	local Instance = GetCategory(Category)

	for K, V in pairs(Instance) do
		insert(Result, K)
	end

	return Result
end

function Stats.Flush()
	QueueFlush = true
end

function Stats.GetFrameNumber()
	return FrameNumber
end

return Stats
