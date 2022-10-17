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

local floor = math.floor
local max = math.max

local Cursor = require(SLAB_PATH .. ".Internal.Core.Cursor")
local DrawCommands = require(SLAB_PATH .. ".Internal.Core.DrawCommands")
local Image = require(SLAB_PATH .. ".Internal.UI.Image")
local LayoutManager = require(SLAB_PATH .. ".Internal.UI.LayoutManager")
local Mouse = require(SLAB_PATH .. ".Internal.Input.Mouse")
local Stats = require(SLAB_PATH .. ".Internal.Core.Stats")
local Style = require(SLAB_PATH .. ".Style")
local Text = require(SLAB_PATH .. ".Internal.UI.Text")
local Tooltip = require(SLAB_PATH .. ".Internal.UI.Tooltip")
local Utility = require(SLAB_PATH .. ".Internal.Core.Utility")
local Window = require(SLAB_PATH .. ".Internal.UI.Window")

local Button = {}

local PAD, RAD = 10, 8
local RAD2 = RAD * 2
local RAD_INNER = RAD * 0.7
local DIAMETER = RAD * RAD
local MIN_WIDTH = 75
local clicked_id
local label_color = {}
local TBL_EMPTY = {}
local TBL_IGNORE = {Ignore = true}
local EMPTY_STR = ""

function Button.Begin(label, opt)
	local stat_handle = Stats.Begin("Button", "Slab")
	opt = opt or TBL_EMPTY

	local width, height = opt.W, opt.H
	local disabled = opt.Disabled
	local image = opt.Image
	local color = opt.Color or Style.ButtonColor
	local hover_color = opt.HoverColor or Style.ButtonHoveredColor
	local press_color = opt.PressColor or Style.ButtonPressedColor
	local pad_x = opt.PadX or PAD * 2
	local pad_y = opt.PadY or PAD * 0.5
	local vlines = opt.VLines or 1

	label = opt.Label or label

	local id = Window.GetItemId(label)
	local w, h = Button.GetSize(label)
	h = h * vlines

	local image_w, image_h = w, h
	if image then
		image_w, image_h = Image.GetSize(image.Image or image.Path)
		image_w = image.SubW or image_w
		image_h = image.SubH or image_h
		image_w = width or image_w
		image_h = height or image_h
		image.w = image_w
		image.h = image_h
		if image_w > 0 and image_h > 0 then
			w = image_w + pad_x
			h = image_h + pad_y
		end
	end

	w, h = LayoutManager.ComputeSize(width or w, height or h)
	LayoutManager.AddControl(w, h, "Button")

	local x, y = Cursor.GetPosition()
	local res = false

	local mx, my = Window.GetMousePosition()
	if not Window.IsObstructedAtMouse() and
		x <= mx and mx <= x + w and
		y <= my and my <= y + h then
		Tooltip.Begin(opt.Tooltip or EMPTY_STR)
		Window.SetHotItem(id)

		if not disabled then
			if not Utility.IsMobile() then
				color = hover_color
			end
			if clicked_id == id then
				color = press_color
			end
			if Mouse.IsClicked(1) then
				clicked_id = id
			end
			if Mouse.IsReleased(1) and clicked_id == id then
				res = true
				clicked_id = nil
			end
		end
	end

	if not opt.Invisible then
		-- Draw the background.
		DrawCommands.Rectangle("fill", x, y, w, h, color, opt.Rounding or Style.ButtonRounding)

		-- Draw the label or image. The layout of this control was already computed above. Ignore when adding sub-controls
		-- such as text or an image.
		local cx, cy = Cursor.GetPosition()
		LayoutManager.Begin("Ignore", TBL_IGNORE)
		if image then
			local new_cx = x + w * 0.5 - image_w * 0.5
			local new_cy = y + h * 0.5 - image_h * 0.5
			Cursor.SetPosition(new_cx, new_cy)
			Image.Begin(id .. "_Image", image)
		else
			local label_x = floor(x + (w * 0.5) - (Style.Font:getWidth(label) * 0.5))
			local font_h = Style.Font:getHeight() * vlines
			local new_cy = floor(y + (h * 0.5) - (font_h * 0.5))
			Cursor.SetPosition(label_x, new_cy)
			label_color.color = disabled and Style.ButtonDisabledTextColor
			Text.Begin(label, label_color)
		end
		LayoutManager.End()
		Cursor.SetPosition(cx, cy)
	end

	Cursor.SetItemBounds(x, y, w, h)
	Cursor.AdvanceY(h)
	Window.AddItem(x, y, w, h, id)
	Stats.End(stat_handle)
	return res
end

function Button.BeginRadio(label, selected, opt)
	local stat_handle = Stats.Begin("RadioButton", "Slab")
	label = label or EMPTY_STR
	opt = opt or TBL_EMPTY
	selected = selected or 0
	local index = opt.Index or 0
	local res = false
	local id = Window.GetItemId(label)
	local w, h = RAD2, RAD2
	local is_obstructed = Window.IsObstructedAtMouse()
	local color = Style.ButtonColor
	local mx, my = Window.GetMousePosition()

	if label ~= EMPTY_STR then
		local tw, th = Text.GetSize(label)
		w = w + Cursor.PadX() + tw
		h = max(h, th)
	end
	LayoutManager.AddControl(w, h, "Radio")

	local x, y = Cursor.GetPosition()
	local cx, cy = x + RAD, y + RAD
	local dx, dy = mx - cx, my - cy
	if not is_obstructed and (dx * dx) + (dy * dy) <= DIAMETER then
		color = Style.ButtonHoveredColor
		if clicked_id == id then
			color = Style.ButtonPressedColor
		end
		if Mouse.IsClicked(1) then
			clicked_id = id
		end
		if Mouse.IsReleased(1) and clicked_id == id then
			res = true
			clicked_id = nil
		end
	end
	DrawCommands.Circle("fill", cx, cy, RAD, color)

	if index > 0 and index == selected then
		DrawCommands.Circle("fill", cx, cy, RAD_INNER, Style.RadioButtonSelectedColor)
	end

	if label ~= EMPTY_STR then
		local cy2 = Cursor.GetY()
		Cursor.AdvanceX(RAD2)
		LayoutManager.Begin("Ignore", TBL_IGNORE)
		Text.Begin(label)
		LayoutManager.End()
		Cursor.SetY(cy2)
	end

	if not is_obstructed and x <= mx and mx <= x + w and y <= my and my <= y + h then
		Tooltip.Begin(opt.Tooltip or EMPTY_STR)
		Window.SetHotItem(id)
	end

	Cursor.SetItemBounds(x, y, w, h)
	Cursor.AdvanceY(h)
	Window.AddItem(x, y, w, h)
	Stats.End(stat_handle)
	return res
end

function Button.GetSize(label)
	local w = Style.Font:getWidth(label)
	local h = Style.Font:getHeight()
	return max(w, MIN_WIDTH) + PAD * 2, h + PAD * 0.5
end

function Button.ClearClicked()
	clicked_id = nil
end

return Button
