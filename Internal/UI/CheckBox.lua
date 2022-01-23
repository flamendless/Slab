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

local Cursor = require(SLAB_PATH .. ".Internal.Core.Cursor")
local DrawCommands = require(SLAB_PATH .. ".Internal.Core.DrawCommands")
local LayoutManager = require(SLAB_PATH .. ".Internal.UI.LayoutManager")
local Mouse = require(SLAB_PATH .. ".Internal.Input.Mouse")
local Stats = require(SLAB_PATH .. ".Internal.Core.Stats")
local Style = require(SLAB_PATH .. ".Style")
local Text = require(SLAB_PATH .. ".Internal.UI.Text")
local Tooltip = require(SLAB_PATH .. ".Internal.UI.Tooltip")
local Window = require(SLAB_PATH .. ".Internal.UI.Window")

local CheckBox = {}

local STR_EMPTY = ""
local TBL_EMPTY = {}
local TBL_IGNORE = {ignore = true}
local label_color = {}

function CheckBox.Begin(enabled, label, opt)
	local stat_handle = Stats.Begin("CheckBox", "Slab")
	label = label or STR_EMPTY
	opt = opt or TBL_EMPTY
	local id = opt.Id or label
	local rounding = opt.Rounding or Style.CheckBoxRounding
	local size = opt.Size or 16
	local disabled = opt.Disabled
	local item_id = Window.GetItemId(id)
	local bw, bh = size, size
	local tw, th = Text.GetSize(label)
	local w = bw + Cursor.PadX() + 2 + tw
	local h = max(bh, th)
	local radius = size * 0.5
	LayoutManager.AddControl(w, h, "CheckBox")
	local res = false
	local color = disabled and Style.CheckBoxDisabledColor or Style.ButtonColor
	local x, y = Cursor.GetPosition()
	local mx, my = Window.GetMousePosition()
	local is_obstructed = Window.IsObstructedAtMouse()

	if not is_obstructed and not disabled and
		x <= mx and mx <= x + bw and
		y <= my and my <= y + bh then
		color = Style.ButtonHoveredColor
		if Mouse.IsDown(1) then
			color = Style.ButtonPressedColor
		elseif Mouse.IsReleased(1) then
			res = true
		end
	end

	DrawCommands.Rectangle("fill", x, y, bw, bh, color, rounding)
	if checked then
		DrawCommands.Cross(x + radius, y + radius, radius - 1, Style.CheckBoxSelectedColor)
	end

	if label ~= STR_EMPTY then
		local cy = Cursor.GetY()
		Cursor.AdvanceX(bw + 2)
		LayoutManager.Begin("Ignore", TBL_IGNORE)
		label_color.Color = disabled and Style.TextDisabledColor
		Text.Begin(label, label_color)
		LayoutManager.End()
		Cursor.SetY(cy)
	end

	if not is_obstructed and x <= mx and mx <= x + w and y <= my and my <= y + h then
		Tooltip.Begin(opt.Tooltip or STR_EMPTY)
		Window.SetHotItem(item_id)
	end

	Cursor.SetItemBounds(x, y, w, h)
	Cursor.AdvanceY(h)
	Window.AddItem(x, y, w, h, item_id)
	Stats.End(stat_handle)
	return res
end

return CheckBox
