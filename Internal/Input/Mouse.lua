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

local insert = table.insert

local Common = require(SLAB_PATH .. '.Internal.Input.Common')

local Mouse = {}

local State =
{
	X = 0.0,
	Y = 0.0,
	DeltaX = 0.0,
	DeltaY = 0.0,
	AsyncDeltaX = 0.0,
	AsyncDeltaY = 0.0,
	Buttons = {}
}

local Cursors = nil
local CurrentCursor = "arrow"
local PendingCursor = ""
local MouseMovedFn = nil
local MousePressedFn = nil
local MouseReleasedFn = nil
local Events = {}

local function TransformPoint(X,Y)
	return X,Y
end

local function OnMouseMoved(X, Y, DX, DY, IsTouch)
	X, Y = TransformPoint(X, Y)
	State.X = X
	State.Y = Y
	State.AsyncDeltaX = State.AsyncDeltaX + DX
	State.AsyncDeltaY = State.AsyncDeltaY + DY
end

local function PushEvent(Type, X, Y, Button, IsTouch, Presses)
	insert(Events, {
		Type = Type,
		X = X,
		Y = Y,
		Button = Button,
		IsTouch = IsTouch,
		Presses = Presses
	})
end

local function OnMousePressed(X, Y, Button, IsTouch, Presses)
	X, Y = TransformPoint(X, Y)
	PushEvent(Common.Event.Pressed, X, Y, Button, IsTouch, Presses)

	if MousePressedFn ~= nil then
		MousePressedFn(X, Y, Button, IsTouch, Presses)
	end
end

local function OnMouseReleased(X, Y, Button, IsTouch, Presses)
	X, Y = TransformPoint(X, Y)
	PushEvent(Common.Event.Released, X, Y, Button, IsTouch, Presses)

	if MouseReleasedFn ~= nil then
		MouseReleasedFn(X, Y, Button, IsTouch, Presses)
	end
end

local function ProcessEvents()
	State.Buttons = {}

	for I, V in ipairs(Events) do
		if State.Buttons[V.Button] == nil then
			State.Buttons[V.Button] = {}
		end

		local Button = State.Buttons[V.Button]
		Button.Type = V.Type
		Button.IsTouch = V.IsTouch
		Button.Presses = V.Presses
	end

	Events = {}
end

function Mouse.Initialize(TransformPointToSlab, Args)
	TransformPoint = TransformPointToSlab or TransformPoint

	MouseMovedFn = love.handlers['mousemoved']
	MousePressedFn = love.handlers['mousepressed']
	MouseReleasedFn = love.handlers['mousereleased']
	love.handlers['mousemoved'] = OnMouseMoved
	love.handlers['mousepressed'] = OnMousePressed
	love.handlers['mousereleased'] = OnMouseReleased
end

function Mouse.Update()
	ProcessEvents()

	State.DeltaX = State.AsyncDeltaX
	State.DeltaY = State.AsyncDeltaY
	State.AsyncDeltaX = 0
	State.AsyncDeltaY = 0

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

function Mouse.IsDown(Button)
	return love.mouse.isDown(Button)
end

function Mouse.IsClicked(Button)
	local Item = State.Buttons[Button]

	if Item == nil or Item.Presses == 0 then
		return false
	end

	return Item.Type == Common.Event.Pressed
end

function Mouse.IsDoubleClicked(Button)
	local Item = State.Buttons[Button]

	if Item == nil or Item.Presses < 2 then
		return false
	end

	return Item.Type == Common.Event.Pressed and Item.Presses % 2 == 0
end

function Mouse.IsReleased(Button)
	local Item = State.Buttons[Button]

	if Item == nil then
		return false
	end

	return Item.Type == Common.Event.Released
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
	return Mouse.IsDown(Button) and Mouse.HasDelta()
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
