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

function CheckBox.Begin(Enabled, Label, Options)
	local StatHandle = Stats.Begin('CheckBox', 'Slab')

	Label = Label == nil and "" or Label

	Options = Options == nil and {} or Options
	Options.Tooltip = Options.Tooltip == nil and "" or Options.Tooltip
	Options.Id = Options.Id == nil and Label or Options.Id
	Options.Rounding = Options.Rounding == nil and Style.CheckBoxRounding or Options.Rounding
	Options.Size = Options.Size == nil and 16 or Options.Size

	local Id = Window.GetItemId(Options.Id and Options.Id or ('_' .. Label .. '_CheckBox'))
	local BoxW, BoxH = Options.Size, Options.Size
	local TextW, TextH = Text.GetSize(Label)
	local W = BoxW + Cursor.PadX() + 2.0 + TextW
	local H = max(BoxH, TextH)
	local Radius = Options.Size * 0.5

	LayoutManager.AddControl(W, H)

	local Result = false
	local Color = Style.ButtonColor

	local X, Y = Cursor.GetPosition()
	local MouseX, MouseY = Window.GetMousePosition()
	local IsObstructed = Window.IsObstructedAtMouse()
	if not IsObstructed and X <= MouseX and MouseX <= X + BoxW and Y <= MouseY and MouseY <= Y + BoxH then
		Color = Style.ButtonHoveredColor

		if Mouse.IsPressed(1) then
			Color = Style.ButtonPressedColor
		elseif Mouse.IsReleased(1) then
			Result = true
		end
	end

	DrawCommands.Rectangle('fill', X, Y, BoxW, BoxH, Color, Options.Rounding)
	if Enabled then
		DrawCommands.Cross(X + Radius, Y + Radius, Radius - 1.0, Style.CheckBoxSelectedColor)
	end
	if Label ~= "" then
		local CursorY = Cursor.GetY()
		Cursor.AdvanceX(BoxW + 2.0)
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

	Window.AddItem(X, Y, W, H, Id)

	Stats.End(StatHandle)

	return Result
end

return CheckBox
