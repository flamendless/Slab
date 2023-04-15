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

local EMPTY = {}
local IGNORE = { Ignore = true }
local inputRounding = { 0, 0, 0, 0 }
local dropDownRounding = { 0, 0, 0, 0}

local function GetInstance(id)
	if Instances[id] == nil then
		local instance = {
			IsOpen = false,
			WasOpened = false,
			WinW = 0.0,
			WinH = 0.0,
			StatHandle = nil,
			InputId = id .. '_Input',
			WinId = id .. '_combobox',

			InputOptions = {
				ReadOnly = true,
				Align = 'left',
				Rounding = inputRounding,
			},

			WindowOptions = {
				AllowResize = false,
				AutoSizeWindow = false,
				AllowFocus = false,
				AutoSizeContent = true,
				NoSavedSettings = true,
			}
		}
		Instances[id] = instance
	end
	return Instances[id]
end

function ComboBox.Begin(id, options)
	local StatHandle = Stats.Begin('ComboBox', 'Slab')

	options = options or EMPTY
	local w = options.W or MIN_WIDTH
	local winH = options.WinH or MIN_HEIGHT
	local selected = options.Selected or ""
	local rounding = options.Rounding or Style.ComboBoxRounding

	local instance = GetInstance(id)
	local winItemId = Window.GetItemId(id)
	local h = Style.Font:getHeight()

	w = LayoutManager.ComputeSize(w, h)
	LayoutManager.AddControl(w, h, 'ComboBox')

	local x, y = Cursor.GetPosition()
	local radius = h * 0.35
	local inputBgColor = Style.ComboBoxColor
	local dropDownW = radius * 4.0
	local dropDownX = x + w - dropDownW
	local dropDownColor = Style.ComboBoxDropDownColor

	inputRounding[1], inputRounding[4] = rounding, rounding
	dropDownRounding[2], dropDownRounding[3] = rounding, rounding

	instance.X = x
	instance.Y = y
	instance.W = w
	instance.H = h
	instance.WinH = min(instance.WinH, winH)
	instance.StatHandle = StatHandle

	local mouseX, mouseY = Window.GetMousePosition()

	instance.WasOpened = instance.IsOpen

	local hovered = not Window.IsObstructedAtMouse() and x <= mouseX and mouseX <= x + w and y <= mouseY and mouseY <= y + h

	if hovered then
		inputBgColor = Style.ComboBoxHoveredColor
		dropDownColor = Style.ComboBoxDropDownHoveredColor

		if Mouse.IsClicked(1) then
			instance.IsOpen = not instance.IsOpen

			if instance.IsOpen then
				Window.SetStackLock(instance.WinId)
			end
		end
	end

	do
		LayoutManager.Begin('Ignore', IGNORE)
		local inputOpts = instance.InputOptions
		inputOpts.Text = selected
		inputOpts.W = max(w - dropDownW, dropDownW)
		inputOpts.H = h
		inputOpts.BgColor = inputBgColor
		Input.Begin(instance.InputId, inputOpts)
		LayoutManager.End()
	end

	Cursor.SameLine()

	DrawCommands.Rectangle('fill', dropDownX, y, dropDownW, h, dropDownColor, dropDownRounding)
	DrawCommands.Triangle('fill', dropDownX + radius * 2.0, y + h - radius * 1.35, radius, 180, Style.ComboBoxArrowColor)

	Cursor.SetItemBounds(x, y, w, h)
	Cursor.AdvanceY(h)

	if hovered then
		Tooltip.Begin(options.Tooltip or "")
		Window.SetHotItem(winItemId)
	end

	Window.AddItem(x, y, w, h, winItemId)

	local winX, winY = Window.TransformPoint(x, y)

	if instance.IsOpen then
		LayoutManager.Begin('ComboBox', IGNORE)
		local winOpts = instance.WindowOptions

		winOpts.X = winX - 1.0
		winOpts.Y = winY + h
		winOpts.W = max(w, instance.WinW)
		winOpts.H = instance.WinH
		winOpts.Layer = Window.GetLayer()
		winOpts.ContentW = max(w, instance.WinW)
		winOpts.Border = 4

		Window.Begin(instance.WinId, winOpts)
		Active = instance
	else
		Stats.End(instance.StatHandle)
	end

	return instance.IsOpen
end

function ComboBox.End()
	local y, h = 0, 0
	local statHandle = Active and Active.StatHandle or nil

	if Active ~= nil then
		Cursor.SetItemBounds(Active.X, Active.Y, Active.W, Active.H)
		y, h = Active.Y, Active.H
		local contentW, contentH = Window.GetContentSize()
		Active.WinH = contentH
		Active.WinW = max(contentW, Active.W)
		if Mouse.IsClicked(1) and Active.WasOpened and not Region.IsHoverScrollBar(Window.GetId()) then
			Active.IsOpen = false
			Active = nil
			Window.SetStackLock(nil)
		end
	end

	Window.End()
	DrawCommands.SetLayer('Normal')
	LayoutManager.End()

	if y ~= 0 and h ~= 0 then
		Cursor.SetY(y)
		Cursor.AdvanceY(h)
	end

	Stats.End(statHandle)
end

return ComboBox
