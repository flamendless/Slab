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

local Cursor = require(SLAB_PATH .. '.Internal.Core.Cursor')
local DrawCommands = require(SLAB_PATH .. '.Internal.Core.DrawCommands')
local Image = require(SLAB_PATH .. '.Internal.UI.Image')
local LayoutManager = require(SLAB_PATH .. '.Internal.UI.LayoutManager')
local Mouse = require(SLAB_PATH .. '.Internal.Input.Mouse')
local Stats = require(SLAB_PATH .. '.Internal.Core.Stats')
local Style = require(SLAB_PATH .. '.Style')
local Text = require(SLAB_PATH .. '.Internal.UI.Text')
local Tooltip = require(SLAB_PATH .. '.Internal.UI.Tooltip')
local Utility = require(SLAB_PATH .. '.Internal.Core.Utility')
local Window = require(SLAB_PATH .. '.Internal.UI.Window')

local Button = {}

local PAD = 10.0
local MINWIDTH = 75.0
local RADIUS = 8.0
local EMPTY = {}
local IGNORE = { Ignore = true }

local clickedId = nil
local labelColor = {}

function Button.Begin(label, options)
	local statHandle = Stats.Begin('Button', 'Slab')

	options = options or EMPTY
	local width, height = options.W, options.H
	local disabled = options.Disabled
	local image = options.Image
	local color = options.Color or Style.ButtonColor
	local hoverColor = options.HoverColor or Style.ButtonHoveredColor
	local pressColor = options.PressColor or Style.ButtonPressedColor
	local padX = options.PadX or PAD * 2.0
	local padY = options.PadY or PAD * 0.5
	local vLines = options.VLines or 1

	if options.Active then
		color = pressColor
	end

	local id = Window.GetItemId(label)
	local w, h = Button.GetSize(label)
	h = h * vLines

	-- If a valid image was specified, then adjust the button size to match the requested image size. Also takes into account any sub UVs.
	local imageW, imageH = w, h
	if image ~= nil then
		imageW, imageH = Image.GetSize(image.Image or image.Path)

		imageW = image.SubW or imageW
		imageH = image.SubH or imageH

		imageW = width or imageW
		imageH = height or imageH

		image.W = imageW
		image.H = imageH

		if imageW > 0 and imageH > 0 then
			w = imageW + padX
			h = imageH + padY
		end
	end

	w, h = LayoutManager.ComputeSize(width or w, height or h)
	LayoutManager.AddControl(w, h, 'Button')

	local x, y = Cursor.GetPosition()

	local result = false

	do
		local mouseX, mouseY = Window.GetMousePosition()
		if not Window.IsObstructedAtMouse() and x <= mouseX and mouseX <= x + w and y <= mouseY and mouseY <= y + h then
			Tooltip.Begin(options.Tooltip or "")
			Window.SetHotItem(id)

			if not disabled then
				if not Utility.IsMobile() then
					color = hoverColor
				end

				if clickedId == id then
					color = pressColor
				end

				if Mouse.IsClicked(1) then
					clickedId = id
				end

				if Mouse.IsReleased(1) and clickedId == id then
					result = true
					clickedId = nil
				end
			end
		end
	end

	if not options.Invisible then
		-- Draw the background.
		DrawCommands.Rectangle('fill', x, y, w, h, color, options.Rounding or Style.ButtonRounding)

		-- Draw the label or image. The layout of this control was already computed above. Ignore when adding sub-controls
		-- such as text or an image.
		local cursorX, cursorY = Cursor.GetPosition()
		LayoutManager.Begin('Ignore', IGNORE)
		if image ~= nil then
			Cursor.SetX(x + w * 0.5 - imageW * 0.5)
			Cursor.SetY(y + h * 0.5 - imageH * 0.5)
			Image.Begin(id .. '_Image', image)
		else
			local labelX = x + (w * 0.5) - (Style.Font:getWidth(label) * 0.5)
			local fontHeight = Style.Font:getHeight() * vLines
			Cursor.SetX(floor(labelX))
			Cursor.SetY(floor(y + (h * 0.5) - (fontHeight * 0.5)))
			labelColor.color = disabled and Style.ButtonDisabledTextColor or nil
			Text.Begin(label, labelColor)
		end
		LayoutManager.End()

		Cursor.SetPosition(cursorX, cursorY)
	end

	Cursor.SetItemBounds(x, y, w, h)
	Cursor.AdvanceY(h)

	Window.AddItem(x, y, w, h, id)

	Stats.End(statHandle)

	return result
end

function Button.BeginRadio(label, options)
	local statHandle = Stats.Begin('RadioButton', 'Slab')

	label = label or ""

	options = options or EMPTY
	local index = options.Index or 0
	local selectedIndex = options.SelectedIndex or 0

	local result = false
	local id = Window.GetItemId(label)
	local w, h = RADIUS * 2.0, RADIUS * 2.0
	local isObstructed = Window.IsObstructedAtMouse()
	local color = Style.ButtonColor
	local mouseX, mouseY = Window.GetMousePosition()

	if label ~= "" then
		local TextW, TextH = Text.GetSize(label)
		w = w + Cursor.PadX() + TextW
		h = max(h, TextH)
	end

	LayoutManager.AddControl(w, h, 'Radio')

	local x, y = Cursor.GetPosition()
	local centerX, centerY = x + RADIUS, y + RADIUS
	local dx = mouseX - centerX
	local dy = mouseY - centerY
	if not isObstructed and (dx * dx) + (dy * dy) <= RADIUS * RADIUS then
		color = Style.ButtonHoveredColor

		if clickedId == id then
			color = Style.ButtonPressedColor
		end

		if Mouse.IsClicked(1) then
			clickedId = id
		end

		if Mouse.IsReleased(1) and clickedId == id then
			result = true
			clickedId = nil
		end
	end

	DrawCommands.Circle('fill', centerX, centerY, RADIUS, color)

	if index > 0 and index == selectedIndex then
		DrawCommands.Circle('fill', centerX, centerY, RADIUS * 0.7, Style.RadioButtonSelectedColor)
	end

	if label ~= "" then
		local cursorY = Cursor.GetY()
		Cursor.AdvanceX(RADIUS * 2.0)
		LayoutManager.Begin('Ignore', IGNORE)
		Text.Begin(label)
		LayoutManager.End()
		Cursor.SetY(cursorY)
	end

	if not isObstructed and x <= mouseX and mouseX <= x + w and y <= mouseY and mouseY <= y + h then
		Tooltip.Begin(options.Tooltip or "")
		Window.SetHotItem(id)
	end

	Cursor.SetItemBounds(x, y, w, h)
	Cursor.AdvanceY(h)

	Window.AddItem(x, y, w, h)

	Stats.End(statHandle)

	return result
end

function Button.GetSize(label)
	local w = Style.Font:getWidth(label)
	local h = Style.Font:getHeight()
	return max(w, MINWIDTH) + PAD * 2.0, h + PAD * 0.5
end

function Button.ClearClicked()
	clickedId = nil
end

return Button
