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

local min = math.min
local max = math.max

local Cursor = require(SLAB_PATH .. '.Internal.Core.Cursor')
local DrawCommands = require(SLAB_PATH .. '.Internal.Core.DrawCommands')
local Input = require(SLAB_PATH .. '.Internal.UI.Input')
local LayoutManager = require(SLAB_PATH .. '.Internal.UI.LayoutManager')
local Mouse = require(SLAB_PATH .. '.Internal.Input.Mouse')
local Region = require(SLAB_PATH .. '.Internal.UI.Region')
local Stats = require(SLAB_PATH .. '.Internal.Core.Stats')
local Style = require(SLAB_PATH .. '.Style')
local Tooltip = require(SLAB_PATH .. '.Internal.UI.Tooltip')
local Window = require(SLAB_PATH .. '.Internal.UI.Window')

local ComboBox = {}
local Instances = {}
local Active = nil

local MIN_WIDTH = 150.0
local MIN_HEIGHT = 150.0

local function GetInstance(Id)
	if Instances[Id] == nil then
		local Instance = {}
		Instance.IsOpen = false
		Instance.WasOpened = false
		Instance.WinW = 0.0
		Instance.WinH = 0.0
		Instance.StatHandle = nil
		Instances[Id] = Instance
	end
	return Instances[Id]
end

function ComboBox.Begin(Id, Options)
	local StatHandle = Stats.Begin('ComboBox', 'Slab')

	Options = Options ~= nil and Options or {}
	Options.Tooltip = Options.Tooltip == nil and "" or Options.Tooltip
	Options.W = Options.W == nil and MIN_WIDTH or Options.W
	Options.WinH = Options.WinH == nil and MIN_HEIGHT or Options.WinH
	Options.Selected = Options.Selected == nil and "" or Options.Selected
	Options.Rounding = Options.Rounding == nil and Style.ComboBoxRounding or Options.Rounding

	local Instance = GetInstance(Id)
	local WinItemId = Window.GetItemId(Id)
	local W = Options.W
	local H = Style.Font:getHeight()

	W = LayoutManager.ComputeSize(W, H)
	LayoutManager.AddControl(W, H)

	local X, Y = Cursor.GetPosition()
	local Radius = H * 0.35
	local InputBgColor = Style.ComboBoxColor
	local DropDownW = Radius * 4.0
	local DropDownX = X + W - DropDownW
	local DropDownColor = Style.ComboBoxDropDownColor

	local InputRounding = {Options.Rounding, 0, 0, Options.Rounding}
	local DropDownRounding = {0, Options.Rounding, Options.Rounding, 0}

	Instance.X = X
	Instance.Y = Y
	Instance.W = W
	Instance.H = H
	Instance.WinH = min(Instance.WinH, Options.WinH)
	Instance.StatHandle = StatHandle

	local MouseX, MouseY = Window.GetMousePosition()
	local MouseClicked = Mouse.IsClicked(1)

	Instance.WasOpened = Instance.IsOpen

	local IsObstructed = Window.IsObstructedAtMouse()
	local Hovered = not IsObstructed and X <= MouseX and MouseX <= X + W and Y <= MouseY and MouseY <= Y + H

	if Hovered then
		InputBgColor = Style.ComboBoxHoveredColor
		DropDownColor = Style.ComboBoxDropDownHoveredColor

		if MouseClicked then
			Instance.IsOpen = not Instance.IsOpen

			if Instance.IsOpen then
				Window.SetStackLock(Id .. '_combobox')
			end
		end
	end

	LayoutManager.Begin('Ignore', {Ignore = true})
	Input.Begin(Id .. '_Input', {
		ReadOnly = true,
		Text = Options.Selected,
		Align = 'left',
		W = max(W - DropDownW, DropDownW),
		H = H,
		BgColor = InputBgColor,
		Rounding = InputRounding
	})
	LayoutManager.End()

	Cursor.SameLine()

	DrawCommands.Rectangle('fill', DropDownX, Y, DropDownW, H, DropDownColor, DropDownRounding)
	DrawCommands.Triangle('fill', DropDownX + Radius * 2.0, Y + H - Radius * 1.35, Radius, 180, Style.ComboBoxArrowColor)

	Cursor.SetItemBounds(X, Y, W, H)
	Cursor.AdvanceY(H)

	if Hovered then
		Tooltip.Begin(Options.Tooltip)
		Window.SetHotItem(WinItemId)
	end

	Window.AddItem(X, Y, W, H, WinItemId)

	local WinX, WinY = Window.TransformPoint(X, Y)

	if Instance.IsOpen then
		LayoutManager.Begin('ComboBox', {Ignore = true})
		Window.Begin(Id .. '_combobox',
		{
			X = WinX - 1.0,
			Y = WinY + H,
			W = max(W, Instance.WinW),
			H = Instance.WinH,
			AllowResize = false,
			AutoSizeWindow = false,
			AllowFocus = false,
			Layer = Window.GetLayer(),
			AutoSizeContent = true,
			NoSavedSettings = true
		})
		Active = Instance
	else
		Stats.End(Instance.StatHandle)
	end

	return Instance.IsOpen
end

function ComboBox.End()
	local Y = 0.0
	local H = 0.0
	local StatHandle = nil

	if Active ~= nil then
		Cursor.SetItemBounds(Active.X, Active.Y, Active.W, Active.H)
		Y, H = Active.Y, Active.H
		local ContentW, ContentH = Window.GetContentSize()
		Active.WinH = ContentH
		Active.WinW = max(ContentW, Active.W)
		StatHandle = Active.StatHandle
		if Mouse.IsClicked(1) and Active.WasOpened and not Region.IsHoverScrollBar(Window.GetId()) then
			Active.IsOpen = false
			Active = nil
			Window.SetStackLock(nil)
		end
	end

	Window.End()
	DrawCommands.SetLayer('Normal')
	LayoutManager.End()

	if Y ~= 0.0 and H ~= 0.0 then
		Cursor.SetY(Y)
		Cursor.AdvanceY(H)
	end

	Stats.End(StatHandle)
end

return ComboBox
