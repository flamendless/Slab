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

local max = math.max

local Cursor = require(SLAB_PATH .. '.Internal.Core.Cursor')
local DrawCommands = require(SLAB_PATH .. '.Internal.Core.DrawCommands')
local LayoutManager = require(SLAB_PATH .. '.Internal.UI.LayoutManager')
local Mouse = require(SLAB_PATH .. '.Internal.Input.Mouse')
local Stats = require(SLAB_PATH .. '.Internal.Core.Stats')
local Style = require(SLAB_PATH .. '.Style')
local Text = require(SLAB_PATH .. '.Internal.UI.Text')
local Tooltip = require(SLAB_PATH .. '.Internal.UI.Tooltip')
local Window = require(SLAB_PATH .. '.Internal.UI.Window')

local CheckBox = {}
local EMPTY = {}
local IGNORE = { Ignore = true }
local labelColor = {}

function CheckBox.Begin(checked, label, options)
	local statHandle = Stats.Begin('CheckBox', 'Slab')

	label = label or ""

	options = options or EMPTY
	local id = options.Id or label
	local rounding = options.Rounding or Style.CheckBoxRounding
	local size = options.Size or Style.Font:getHeight()
	local disabled = options.Disabled

	local itemId = Window.GetItemId(id)
	local boxW, boxH = size, size
	local textW, textH = Text.GetSize(label)
	local w = boxW + Cursor.PadX() + 2.0 + textW
	local h = max(boxH, textH)
	local radius = size * 0.5

	LayoutManager.AddControl(w, h, 'CheckBox')

	local result = false
	local color = disabled and Style.CheckBoxDisabledColor or Style.ButtonColor

	local x, y = Cursor.GetPosition()
	local mouseX, mouseY = Window.GetMousePosition()
	local isObstructed = Window.IsObstructedAtMouse()
	if not isObstructed and not disabled and x <= mouseX and mouseX <= x + w and y <= mouseY and mouseY <= y + h then
		color = Style.ButtonHoveredColor

		if Mouse.IsDown(1) then
			color = Style.ButtonPressedColor
		elseif Mouse.IsReleased(1) then
			result = true
		end
	end

	DrawCommands.Rectangle('fill', x, y, boxW, boxH, color, rounding)
	if checked then
		DrawCommands.Cross(x + radius, y + radius, radius - 1.0, Style.CheckBoxSelectedColor)
	end
	if label ~= "" then
		local cursorY = Cursor.GetY()
		Cursor.AdvanceX(boxW + 2.0)
		LayoutManager.Begin('Ignore', IGNORE)
		labelColor.Color = disabled and Style.TextDisabledColor or nil
		Text.Begin(label, labelColor)
		LayoutManager.End()
		Cursor.SetY(cursorY)
	end

	if not isObstructed and x <= mouseX and mouseX <= x + w and y <= mouseY and mouseY <= y + h then
		Tooltip.Begin(options.Tooltip or "")
		Window.SetHotItem(itemId)
	end

	Cursor.SetItemBounds(x, y, w, h)
	Cursor.AdvanceY(h)

	Window.AddItem(x, y, w, h, itemId)

	Stats.End(statHandle)

	return result
end

return CheckBox
