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

local Mouse = {}

local State =
{
	Button = {},
	WasButton = {},
	ClickTime = {},
	LastClickTime = {},
	X = 0.0,
	Y = 0.0,
	DeltaX = 0.0,
	DeltaY = 0.0
}

local Cursors = nil
local DoubleClickTime = 0.25
local CurrentCursor = "arrow"
local PendingCursor = ""

local function UpdateClickTime(Button)
	if Mouse.IsClicked(Button) then
		State.LastClickTime[Button] = State.ClickTime[Button]
		State.ClickTime[Button] = love.timer.getTime()
	end
end

function Mouse.Update()
	local LastX, LastY = State.X, State.Y
	State.X, State.Y = love.mouse.getPosition()
	State.DeltaX, State.DeltaY = State.X - LastX, State.Y - LastY
	local Button1 = love.mouse.isDown(1)
	local Button2 = love.mouse.isDown(2)
	local Button3 = love.mouse.isDown(3)
	State.WasButton[1] = State.Button[1]
	State.WasButton[2] = State.Button[2]
	State.WasButton[3] = State.Button[3]
	State.Button[1] = Button1
	State.Button[2] = Button2
	State.Button[3] = Button3

	UpdateClickTime(1)
	UpdateClickTime(2)
	UpdateClickTime(3)

	if Cursors == nil then
		Cursors = {}
		Cursors.Arrow = love.mouse.getSystemCursor('arrow')
		Cursors.SizeWE = love.mouse.getSystemCursor('sizewe')
		Cursors.SizeNS = love.mouse.getSystemCursor('sizens')
		Cursors.SizeNESW = love.mouse.getSystemCursor('sizenesw')
		Cursors.SizeNWSE = love.mouse.getSystemCursor('sizenwse')
		Cursors.IBeam = love.mouse.getSystemCursor('ibeam')
		Cursors.Hand = love.mouse.getSystemCursor('hand')
	end

	Mouse.SetCursor('arrow')
end

function Mouse.IsPressed(Button)
	return State.Button[Button]
end

function Mouse.IsClicked(Button)
	return State.Button[Button] and not State.WasButton[Button]
end

function Mouse.IsDoubleClicked(Button)
	if Mouse.IsClicked(Button) and State.LastClickTime[Button] ~= nil then
		return love.timer.getTime() - State.LastClickTime[Button] <= DoubleClickTime
	end
	return false
end

function Mouse.IsReleased(Button)
	return not State.Button[Button] and State.WasButton[Button]
end

function Mouse.Position()
	return State.X, State.Y
end

function Mouse.HasDelta()
	return State.DeltaX ~= 0.0 or State.DeltaY ~= 0.0
end

function Mouse.GetDelta()
	return State.DeltaX, State.DeltaY
end

function Mouse.IsDragging(Button)
	return Mouse.IsPressed(Button) and Mouse.HasDelta()
end

function Mouse.SetCursor(Type)
	if Cursors == nil then
		return
	end

	PendingCursor = Type
end

function Mouse.UpdateCursor()
	if PendingCursor ~= "" and PendingCursor ~= CurrentCursor then
		CurrentCursor = PendingCursor
		PendingCursor = ""

		local Type = CurrentCursor
		if Type == 'arrow' then
			love.mouse.setCursor(Cursors.Arrow)
		elseif Type == 'sizewe' then
			love.mouse.setCursor(Cursors.SizeWE)
		elseif Type == 'sizens' then
			love.mouse.setCursor(Cursors.SizeNS)
		elseif Type == 'sizenesw' then
			love.mouse.setCursor(Cursors.SizeNESW)
		elseif Type == 'sizenwse' then
			love.mouse.setCursor(Cursors.SizeNWSE)
		elseif Type == 'ibeam' then
			love.mouse.setCursor(Cursors.IBeam)
		elseif Type == 'hand' then
			love.mouse.setCursor(Cursors.Hand)
		end
	end
end

return Mouse
