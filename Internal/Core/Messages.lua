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

--[[
	The messages system is a system for Slab to notify developers of issues or suggestions on aspects
	of the API. Functions or options may be deprecated or Slab may offer an alternative usage. The system
	is designed to notify the user only once to prevent any repeated output to the console if enabled. This
	system can be enabled at startup and the developer will have the ability to gather the messages to
	be displayed in a control if desired.
--]]

local insert = table.insert

local Messages = {}

local Enabled = true
local Cache = {}

function Messages.Broadcast(Id, Message)
	if not Enabled then
		return
	end

	assert(Id ~= nil, "Id is invalid.")
	assert(type(Id) == 'string', "Id is not a string type.")
	assert(Message ~= nil, "Message is invalid.")
	assert(type(Message) == 'string', "Message is not a string type.")

	if Cache[Id] == nil then
		Cache[Id] = Message
		print(Message)
	end
end

function Messages.Get()
	local Result = {}

	for K, V in pairs(Cache) do
		insert(Result, V)
	end

	return Result
end

function Messages.SetEnabled(InEnabled)
	Enabled = InEnabled
end

return Messages
