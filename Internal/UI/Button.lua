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

local Pad = 10.0
local MinWidth = 75.0
local Radius = 8.0
local ClickedId = nil

function Button.Begin(Label, Options)
	local StatHandle = Stats.Begin('Button', 'Slab')

	Options = Options == nil and {} or Options
	Options.Tooltip = Options.Tooltip == nil and "" or Options.Tooltip
	Options.Rounding = Options.Rounding == nil and Style.ButtonRounding or Options.Rounding
	Options.Invisible = Options.Invisible == nil and false or Options.Invisible
	Options.W = Options.W == nil and nil or Options.W
	Options.H = Options.H == nil and nil or Options.H
	Options.Disabled = Options.Disabled == nil and false or Options.Disabled
	Options.Image = Options.Image or nil
	Options.Color = Options.Color or Style.ButtonColor
	Options.HoverColor = Options.HoverColor or Style.ButtonHoveredColor
	Options.PressColor = Options.PressColor or Style.ButtonPressedColor
	Options.PadX = Options.PadX or Pad * 2.0
	Options.PadY = Options.PadY or Pad * 0.5

	local Id = Window.GetItemId(Label)
	local W, H = Button.GetSize(Label)
	local LabelW = Style.Font:getWidth(Label)
	local FontHeight = Style.Font:getHeight()
	local TextColor = Options.Disabled and Style.ButtonDisabledTextColor or nil

	-- If a valid image was specified, then adjust the button size to match the requested image size. Also takes into account any sub UVs.
	local ImageW, ImageH = W, H
	if Options.Image ~= nil then
		local Object = Options.Image.Image and Options.Image.Image or Options.Image.Path
		ImageW, ImageH = Image.GetSize(Object)

		ImageW = Options.Image.SubW or ImageW
		ImageH = Options.Image.SubH or ImageH

		ImageW = Options.W or ImageW
		ImageH = Options.H or ImageH

		Options.Image.W = ImageW
		Options.Image.H = ImageH

		if ImageW > 0 and ImageH > 0 then
			W = ImageW + Options.PadX
			H = ImageH + Options.PadY
		end
	end

	W = Options.W or W
	H = Options.H or H

	W, H = LayoutManager.ComputeSize(W, H)
	LayoutManager.AddControl(W, H, 'Button')

	local X, Y = Cursor.GetPosition()

	local Result = false
	local Color = Options.Color

	local MouseX, MouseY = Window.GetMousePosition()
	if not Window.IsObstructedAtMouse() and X <= MouseX and MouseX <= X + W and Y <= MouseY and MouseY <= Y + H then
		Tooltip.Begin(Options.Tooltip)
		Window.SetHotItem(Id)

		if not Options.Disabled then
			if not Utility.IsMobile() then
				Color = Options.HoverColor
			end

			if ClickedId == Id then
				Color = Options.PressColor
			end

			if Mouse.IsClicked(1) then
				ClickedId = Id
			end

			if Mouse.IsReleased(1) and ClickedId == Id then
				Result = true
				ClickedId = nil
			end
		end
	end

	local LabelX = X + (W * 0.5) - (LabelW * 0.5)

	if not Options.Invisible then
		-- Draw the background.
		DrawCommands.Rectangle('fill', X, Y, W, H, Color, Options.Rounding)

		-- Draw the label or image. The layout of this control was already computed above. Ignore when adding sub-controls
		-- such as text or an image.
		local CursorX, CursorY = Cursor.GetPosition()
		LayoutManager.Begin('Ignore', {Ignore = true})
		if Options.Image ~= nil then
			Cursor.SetX(X + W * 0.5 - ImageW * 0.5)
			Cursor.SetY(Y + H * 0.5 - ImageH * 0.5)
			Image.Begin(Id .. '_Image', Options.Image)
		else
			Cursor.SetX(floor(LabelX))
			Cursor.SetY(floor(Y + (H * 0.5) - (FontHeight * 0.5)))
			Text.Begin(Label, {Color = TextColor})
		end
		LayoutManager.End()

		Cursor.SetPosition(CursorX, CursorY)
	end

	Cursor.SetItemBounds(X, Y, W, H)
	Cursor.AdvanceY(H)

	Window.AddItem(X, Y, W, H, Id)

	Stats.End(StatHandle)

	return Result
end

function Button.BeginRadio(Label, Options)
	local StatHandle = Stats.Begin('RadioButton', 'Slab')

	Label = Label == nil and "" or Label

	Options = Options == nil and {} or Options
	Options.Index = Options.Index == nil and 0 or Options.Index
	Options.SelectedIndex = Options.SelectedIndex == nil and 0 or Options.SelectedIndex
	Options.Tooltip = Options.Tooltip == nil and "" or Options.Tooltip

	local Result = false
	local Id = Window.GetItemId(Label)
	local W, H = Radius * 2.0, Radius * 2.0
	local IsObstructed = Window.IsObstructedAtMouse()
	local Color = Style.ButtonColor
	local MouseX, MouseY = Window.GetMousePosition()

	if Label ~= "" then
		local TextW, TextH = Text.GetSize(Label)
		W = W + Cursor.PadX() + TextW
		H = max(H, TextH)
	end

	LayoutManager.AddControl(W, H, 'Radio')

	local X, Y = Cursor.GetPosition()
	local CenterX, CenterY = X + Radius, Y + Radius
	local DX = MouseX - CenterX
	local DY = MouseY - CenterY
	local HoveredButton = not IsObstructed and (DX * DX) + (DY * DY) <= Radius * Radius
	if HoveredButton then
		Color = Style.ButtonHoveredColor

		if ClickedId == Id then
			Color = Style.ButtonPressedColor
		end

		if Mouse.IsClicked(1) then
			ClickedId = Id
		end

		if Mouse.IsReleased(1) and ClickedId == Id then
			Result = true
			ClickedId = nil
		end
	end

	DrawCommands.Circle('fill', CenterX, CenterY, Radius, Color)

	if Options.Index > 0 and Options.Index == Options.SelectedIndex then
		DrawCommands.Circle('fill', CenterX, CenterY, Radius * 0.7, Style.RadioButtonSelectedColor)
	end

	if Label ~= "" then
		local CursorY = Cursor.GetY()
		Cursor.AdvanceX(Radius * 2.0)
		LayoutManager.Begin('Ignore', {Ignore = true})
		Text.Begin(Label)
		LayoutManager.End()
		Cursor.SetY(CursorY)
	end

	if not IsObstructed and X <= MouseX and MouseX <= X + W and Y <= MouseY and MouseY <= Y + H then
		Tooltip.Begin(Options.Tooltip)
		Window.SetHotItem(Id)
	end

	Cursor.SetItemBounds(X, Y, W, H)
	Cursor.AdvanceY(H)

	Window.AddItem(X, Y, W, H)

	Stats.End(StatHandle)

	return Result
end

function Button.GetSize(Label)
	local W = Style.Font:getWidth(Label)
	local H = Style.Font:getHeight()
	return max(W, MinWidth) + Pad * 2.0, H + Pad * 0.5
end

function Button.ClearClicked()
	ClickedId = nil
end

return Button
