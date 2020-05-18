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

local Keyboard = {}

local insert = table.insert

local State =
{
	Pressed = {},
	WasPressed = {},
	LastPressed = nil,
	PressedTime = 0.0,
	ShouldRepeat = false
}

local RepeatDelay = 0.6
local RepeatTime = 0.075

local function InsertKey(Key)
	if State.Pressed[Key] == nil then
		State.Pressed[Key] = love.keyboard.isDown(Key)
		State.WasPressed[Key] = false
	end
end

function Keyboard.Update()
	for K, V in pairs(State.Pressed) do
		State.WasPressed[K] = State.Pressed[K]
		State.Pressed[K] = love.keyboard.isDown(K)

		if Keyboard.IsPressed(K) then
			State.LastPressed = K
			State.PressedTime = love.timer.getTime()
		end
	end

	if State.LastPressed ~= nil then
		if not Keyboard.IsDown(State.LastPressed) then
			State.LastPressed = nil
			State.ShouldRepeat = false
		end

		local Elapsed = love.timer.getTime() - State.PressedTime
		local Reset = false

		if not State.ShouldRepeat then
			if Elapsed >= RepeatDelay then
				Reset = true
				State.ShouldRepeat = true
			end
		else
			if Elapsed >= RepeatTime then
				Reset = true
			end
		end

		if Reset then
			State.PressedTime = love.timer.getTime()
			State.Pressed[State.LastPressed] = false
			State.WasPressed[State.LastPressed] = false
		end
	end
end

function Keyboard.IsPressed(Key, CancelRepeat)
	InsertKey(Key)
	if Key == State.LastPressed and CancelRepeat then
		State.LastPressed = nil
	end
	return State.Pressed[Key] and not State.WasPressed[Key]
end

function Keyboard.IsReleased(Key)
	InsertKey(Key)
	return not State.Pressed[Key] and State.WasPressed[Key]
end

function Keyboard.IsDown(Key)
	InsertKey(Key)
	return State.Pressed[Key] or love.keyboard.isDown(Key)
end

function Keyboard.Keys()
	local Result = {}

	for K, V in pairs(State.Pressed) do
		insert(Result, K)
	end

	return Result
end

return Keyboard
