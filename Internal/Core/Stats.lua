--[[

MIT License

Copyright (c) 2019 Mitchell Davis <coding.jackalope@gmail.com>

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

local Data = {}
local Stack = {}
local Enabled = false
local QueueEnabled = false

local function CreateCategory(Category)
	if Data[Category] == nil then
		local Instance = {}
		Instance.StartTime = 0.0
		Instance.Time = 0.0
		Instance.CallCount = 0
		Instance.LastTime = 0.0
		Instance.LastCallCount = 0.0
		Data[Category] = Instance
	end

	return Data[Category]
end

function Stats.Begin(Category)
	if not Enabled then
		return
	end

	local Instance = CreateCategory(Category)

	Instance.StartTime = love.timer.getTime()
	Instance.CallCount = Instance.CallCount + 1
end

function Stats.End(Category)
	if not Enabled then
		return
	end

	local Instance = Data[Category]
	assert(Instance ~= nil, "Tried to call Stats.End without properly calling Stats.Begin for category '" .. Category .. "'.")

	Instance.Time = Instance.Time + (love.timer.getTime() - Instance.StartTime)
end

function Stats.Push(Category)
	if not Enabled then
		return
	end

	local Instance = CreateCategory(Category)
	Instance.CallCount = Instance.CallCount + 1

	local Item = {}
	Item.Category = Category
	Item.StartTime = love.timer.getTime()

	table.insert(Stack, 1, Item)
end

function Stats.Pop()
	if not Enabled then
		return
	end

	assert(#Stack > 0, "Unable to pop stat. No stats were pushed to the stack!")

	local Item = Stack[1]
	local Instance = Data[Item.Category]

	assert(Instance ~= nil, "Tried to call Stats.Pop without properly calling Stats.Push for category '" .. Item.Category .. "'.")

	Instance.Time = Instance.Time + (love.timer.getTime() - Item.StartTime)

	table.remove(Stack, 1)
end

function Stats.GetTime(Category, Last)
	if not Enabled then
		return 0.0
	end

	local Instance = Data[Category]
	if Instance == nil then
		return 0.0
	end

	return Last and Instance.LastTime or Instance.Time
end

function Stats.GetCallCount(Category, Last)
	if not Enabled then
		return 0
	end

	local Instance = Data[Category]
	if Instance == nil then
		return 0
	end
	
	return Last and Instance.LastCallCount or Instance.CallCount
end

function Stats.Reset()
	if QueueEnabled then
		Enabled = true
		QueueEnabled = false
	end

	if not Enabled then
		return
	end

	if #Stack > 0 then
		assert(false, "Stats stack is not empty! Stack item '" .. Stack[1].Category .. "' was not popped!")
	end

	for K, V in pairs(Data) do
		V.LastTime = V.Time
		V.LastCallCount = V.CallCount
		V.CallCount = 0
		V.Time = 0.0
	end
end

function Stats.SetEnabled(IsEnabled)
	QueueEnabled = IsEnabled
end

return Stats
