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

local Common = require(SLAB_PATH .. '.Internal.Input.Common')
local Stats = require(SLAB_PATH .. '.Internal.Core.Stats')
local Utility = require(SLAB_PATH .. '.Internal.Core.Utility')

local Keyboard = {}

local KeyPressedFn = nil
local KeyReleasedFn = nil
local Events = {}
local Keys = {}

local function PushEvent(Type, Key, Scancode, IsRepeat)
	insert(Events, {
		Type = Type,
		Key = Key,
		Scancode = Scancode,
		IsRepeat = IsRepeat,
		Frame = Stats.GetFrameNumber()
	})
end

local function OnKeyPressed(Key, Scancode, IsRepeat)
	PushEvent(Common.Event.Pressed, Key, Scancode, IsRepeat)

	if KeyPressedFn ~= nil then
		KeyPressedFn(Key, Scancode, IsRepeat)
	end
end

local function OnKeyReleased(Key, Scancode)
	PushEvent(Common.Event.Released, Key, Scancode, false)

	if KeyReleasedFn ~= nil then
		KeyReleasedFn(Key, Scancode)
	end
end

local function ProcessEvents()
	Keys = {}

	-- Soft keyboards found on mobile/tablet devices will push keypressed/keyreleased events when the user
	-- releases from the pressed key. All released events pushed as the same frame as the pressed events will be
	-- pushed to the events table for the next frame to process.
	local NextEvents = {}

	for I, V in ipairs(Events) do
		if Keys[V.Scancode] == nil then
			Keys[V.Scancode] = {}
		end

		local Key = Keys[V.Scancode]

		if Utility.IsMobile() and V.Type == Common.Event.Released and Key.Frame == V.Frame then
			V.Frame = V.Frame + 1
			insert(NextEvents, V)
		else
			Key.Type = V.Type
			Key.Key = V.Key
			Key.Scancode = V.Scancode
			Key.IsRepeat = V.IsRepeat
			Key.Frame = V.Frame
		end
	end

	Events = NextEvents
end

Keyboard.OnKeyPressed = OnKeyPressed;
Keyboard.OnKeyReleased = OnKeyReleased;

function Keyboard.Initialize(Args, dontInterceptEventHandlers)
	if not dontInterceptEventHandlers then
		KeyPressedFn = love.handlers['keypressed']
		KeyReleasedFn = love.handlers['keyreleased']
		love.handlers['keypressed'] = OnKeyPressed
		love.handlers['keyreleased'] = OnKeyReleased
	end
end

function Keyboard.Update()
	ProcessEvents()
end

function Keyboard.IsPressed(Key)
	local Item = Keys[Key]

	if Item == nil then
		return false
	end

	return Item.Type == Common.Event.Pressed
end

function Keyboard.IsReleased(Key)
	local Item = Keys[Key]

	if Item == nil then
		return false
	end

	return Item.Type == Common.Event.Released
end

function Keyboard.IsDown(Key)
	return love.keyboard.isScancodeDown(Key)
end

return Keyboard
