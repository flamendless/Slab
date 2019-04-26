--[[

MIT License

Copyright (c) 2019 Mitchell Davis <coding.jackalope@gmail.com>

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

local Cursor = require(SLAB_PATH .. '.Internal.Core.Cursor')
local DrawCommands = require(SLAB_PATH .. '.Internal.Core.DrawCommands')
local Mouse = require(SLAB_PATH .. '.Internal.Input.Mouse')
local Stats = require(SLAB_PATH .. '.Internal.Core.Stats')
local Style = require(SLAB_PATH .. '.Style')
local Text = require(SLAB_PATH .. '.Internal.UI.Text')
local Tooltip = require(SLAB_PATH .. '.Internal.UI.Tooltip')
local Window = require(SLAB_PATH .. '.Internal.UI.Window')

local CheckBox = {}

local Radius = 8.0

function CheckBox.Begin(Enabled, Label, Options)
	Stats.Begin('CheckBox')

	Options = Options == nil and {} or Options
	Options.Tooltip = Options.Tooltip == nil and "" or Options.Tooltip
	Options.Id = Options.Id == nil and Label or Options.Id
	Options.Rounding = Options.Rounding == nil and Style.CheckBoxRounding or Options.Rounding

	local Id = Window.GetItemId(Options.Id and Options.Id or ('_' .. Label .. '_CheckBox'))
	local X, Y = Cursor.GetPosition()
	local W = Radius * 2.0
	local H = Radius * 2.0

	local Result = false
	local Color = Style.ButtonColor

	local MouseX, MouseY = Window.GetMousePosition()
	local IsObstructed = Window.IsObstructedAtMouse()
	if not IsObstructed and X <= MouseX and MouseX <= X + W and Y <= MouseY and MouseY <= Y + H then
		Color = Style.ButtonHoveredColor

		if Mouse.IsPressed(1) then
			Color = Style.ButtonPressedColor
		elseif Mouse.IsReleased(1) then
			Result = true
		end
	end

	DrawCommands.Rectangle('fill', X, Y, W, H, Color, Options.Rounding)
	if Enabled then
		DrawCommands.Cross(X + Radius, Y + Radius, Radius - 1.0, Style.CheckBoxSelectedColor)
	end
	if Label ~= nil and Label ~= "" then
		Cursor.AdvanceX(W + 2.0)
		Text.Begin(Label)

		local ItemX, ItemY, ItemW, ItemH = Cursor.GetItemBounds()
		W = ItemX + ItemW - X
	else
		Cursor.SetItemBounds(X, Y, W, H)
		Cursor.AdvanceY(H)
	end

	if not IsObstructed and X <= MouseX and MouseX <= X + W and Y <= MouseY and MouseY <= Y + H then
		Tooltip.Begin(Options.Tooltip)
		Window.SetHotItem(Id)
	end

	Window.AddItem(X, Y, W, H, Id)

	Stats.End('CheckBox')

	return Result
end

return CheckBox
