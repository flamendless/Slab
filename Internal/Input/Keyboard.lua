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

local insert = table.insert

local Common = require(SLAB_PATH .. ".Internal.Input.Common")
local Stats = require(SLAB_PATH .. ".Internal.Core.Stats")
local Utility = require(SLAB_PATH .. ".Internal.Core.Utility")

local Keyboard = {}

local fn_keypressed, fn_keyreleased
local events, keys = {}, {}

local function PushEvent(ev_type, key, scancode, is_repeat)
	insert(events, {
		type = ev_type,
		key = key,
		scancode = scancode,
		is_repeat = is_repeat,
		frame = Stats.GetFrameNumber(),
	})
end

local function OnKeyPressed(key, scancode, is_repeat)
	PushEvent(Common.Event.Pressed, key, scancode, is_repeat)
	if fn_keypressed then
		fn_keypressed(key, scancode, is_repeat)
	end
end

local function OnKeyReleased(key, scancode)
	PushEvent(Common.Event.Released, key, scancode, false)
	if fn_keyreleased then
		fn_keyreleased(key, scancode)
	end
end

local function ProcessEvents()
	Utility.ClearTable(keys)

	-- Soft keyboards found on mobile/tablet devices will push keypressed/keyreleased events when the user
	-- releases from the pressed key. All released events pushed as the same frame as the pressed events will be
	-- pushed to the events table for the next frame to process.
	local next_events = {}
	for i, v in ipairs(events) do
		if not keys[v.scancode] then
			keys[v.scancode] = {}
		end
		local key = keys[v.scancode]

		if Utility.IsMobile() and v.type == Common.Event.Released and key.frame == v.frame then
			v.frame = v.frame + 1
			insert(next_events, v)
		else
			key.type = v.type
			key.key = v.key
			key.scancode = v.scancode
			key.is_repeat = v.is_repeat
			key.frame = v.frame
		end
	end
	events = next_events
end

function Keyboard.Initialize(args)
	fn_keypressed = love.handlers.keypressed
	fn_keyreleased = love.handlers.keyreleased
	love.handlers.keypressed = OnKeyPressed
	love.handlers.keyreleased = OnKeyReleased
end

function Keyboard.Update()
	ProcessEvents()
end

function Keyboard.IsPressed(key)
	local item = keys[key]
	if not item then return false end
	return item.type == Common.Event.Pressed
end

function Keyboard.IsReleased(key)
	local item = keys[key]
	if not item then return false end
	return item.type == Common.Event.Released
end

function Keyboard.IsDown(key)
	return love.keyboard.isScancodeDown(key)
end

return Keyboard
