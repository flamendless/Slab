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

local Common = require(SLAB_PATH .. ".Internal.Input.Common")
local DrawCommands = require(SLAB_PATH .. ".Internal.Core.DrawCommands")
local Enums = require(SLAB_PATH .. ".Internal.Core.Enums")
local TablePool = require(SLAB_PATH .. ".Internal.Core.TablePool")

local Mouse = {}

local state = {
	x = 0, y = 0, dx = 0, dy = 0,
	async_dx = 0, async_dy = 0,
	buttons = {},
}

local EMPTY_STR = ""
local system_cursors = {
	arrow = "arrow",
	sizewe = "sizewe",
	sizens = "sizens",
	sizenesw = "sizenesw",
	sizenwse = "sizenwse",
	ibeam = "ibeam",
	hand = "hand",
}
local cursors
local current_cursor = "arrow"
local pending_cursor = EMPTY_STR
local fn_mouse_moved, fn_mouse_pressed, fn_mouse_released
local events = {}
local pool = TablePool.new()

-- Custom cursors allow the developer to override any specific system cursor used. This system will also
-- allow developers to set an empty image to hide the cursor for specific states, such as mouse resize.
-- For more information, refer to the SetCustomCursor/ClearCustomCursor functions.
local custom_cursors = {}

local function TransformPoint(x, y)
	return x, y
end

local function OnMouseMoved(x, y, dx, dy, is_touch)
	x, y = TransformPoint(x, y)
	state.x, state.y = x, y
	state.async_dx = state.async_dx + dx
	state.async_dy = state.async_dy + dy

	if fn_mouse_moved then
		fn_mouse_moved(x, y, dx, dy, is_touch)
	end
end

local function PushEvent(ev_type, x, y, button, is_touch, presses)
	local ev = pool:pop()
	ev.type = ev_type
	ev.x, ev.y = x, y
	ev.button = button
	ev.is_touch = is_touch
	ev.presses = presses
	insert(events, 1, ev)
end

local function OnMousePressed(x, y, button, is_touch, presses)
	x, y = TransformPoint(x, y)
	PushEvent(Common.Event.Pressed, x, y, button, is_touch, presses)

	if fn_mouse_pressed then
		fn_mouse_pressed(x, y, button, is_touch, presses)
	end
end

local function OnMouseReleased(x, y, button, is_touch, presses)
	x, y = TransformPoint(x, y)
	PushEvent(Common.Event.Released, x, y, button, is_touch, presses)

	if fn_mouse_released then
		fn_mouse_released(x, y, button, is_touch, presses)
	end
end

local function ProcessEvents()
	for _, v in pairs(state.buttons) do
		v.type = Common.Event.None
	end

	local was_pressed = false

	for i = #events, 1, -1 do
		local ev = events[i]

		if ev.type == Common.Event.Released and was_pressed then
			break
		end

		was_pressed = ev.type == Common.Event.Pressed

		local buttons = state.buttons
		local ev_btn = ev.button
		if buttons[ev_btn] == nil then
			buttons[ev_btn] = {}
		end

		local button = buttons[ev_btn]
		button.type = ev.type
		button.is_touch = ev.is_touch
		button.presses = ev.presses
		pool:push(ev)
		events[i] = nil
	end
end

function Mouse.Initialize(Args)
	TransformPoint = Args.TransformPointToSlab or TransformPoint

	local handlers = love.handlers
	fn_mouse_moved = handlers.mousemoved
	fn_mouse_pressed = handlers.mousepressed
	fn_mouse_released = handlers.mousereleased

	love.handlers.mousemoved = OnMouseMoved
	love.handlers.mousepressed = OnMousePressed
	love.handlers.mousereleased = OnMouseReleased
end

function Mouse.Update()
	ProcessEvents()

	state.dx, state.dy = state.async_dx, state.async_dy
	state.async_dx, state.async_dy = 0, 0

	if not cursors then
		cursors = {}
		for k in pairs(system_cursors) do
			cursors[k] = love.mouse.getSystemCursor(k)
		end
	end

	Mouse.SetCursor("arrow")
end

function Mouse.Draw()
	Mouse.UpdateCursor()

	local custom_cursor = custom_cursors[current_cursor]
	if custom_cursor then
		DrawCommands.SetLayer(Enums.layers.mouse)
		DrawCommands.Begin()

		if custom_cursor.quad then
			local x, y, w, h = custom_cursor.quad:getViewport()
			DrawCommands.SubImage(state.x, state.y, custom_cursor.image, x, y, w, h)
		else
			DrawCommands.Image(state.x, state.y, custom_cursor.image)
		end

		DrawCommands.End()
	end
end

function Mouse.IsDown(button)
	return love.mouse.isDown(button)
end

function Mouse.IsClicked(button)
	local item = state.buttons[button]

	if (not item) or (item.presses == 0) then
		return false
	end

	return item.type == Common.Event.Pressed
end

function Mouse.IsDoubleClicked(button)
	local item = state.buttons[button]

	if (not item) or item.presses < 2 then
		return false
	end

	return (item.type == Common.Event.Pressed) and (item.presses % 2 == 0)
end

function Mouse.IsReleased(button)
	local item = state.buttons[button]

	if not item then
		return false
	end

	return item.type == Common.Event.Released
end

function Mouse.Position()
	return state.x, state.y
end

function Mouse.HasDelta()
	return state.dx ~= 0 or state.dy ~= 0
end

function Mouse.GetDelta()
	return state.dx, state.dy
end

function Mouse.IsDragging(button)
	return Mouse.IsDown(button) and Mouse.HasDelta()
end

function Mouse.SetCursor(type)
	if not cursors then
		return
	end

	pending_cursor = type
end

function Mouse.UpdateCursor()
	if (pending_cursor ~= EMPTY_STR) and (pending_cursor ~= custom_cursor) then
		custom_cursor = pending_cursor
		pending_cursor = EMPTY_STR

		if custom_cursors[custom_cursor] then
			love.mouse.setVisible(false)
		else
			love.mouse.setVisible(true)
			local current = current_cursor
			love.mouse.setCursor(cursors[current])
		end
	end
end

function Mouse.SetCustomCursor(type, image, quad)
	-- If no image is supplied, then create a 1x1 image with no alpha. This is a way to disable certain system cursors.
	if not image then
		local data = love.image.newImageData(1, 1)
		image = love.graphics.newImage(data)
	end

	if not custom_cursors[type] then
		custom_cursors[type] = {}
	end

	custom_cursors[type].image = image
	custom_cursors[type].quad = quad
	pending_cursor = current_cursor
	current_cursor = EMPTY_STR
end

function Mouse.ClearCustomCursor(type)
	custom_cursors[type] = nil
	pending_cursor = current_cursor
	current_cursor = EMPTY_STR
end

return Mouse
