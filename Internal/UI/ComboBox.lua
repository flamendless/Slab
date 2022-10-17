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
local Enums = require(SLAB_PATH .. '.Internal.Core.Enums')
local Input = require(SLAB_PATH .. '.Internal.UI.Input')
local LayoutManager = require(SLAB_PATH .. '.Internal.UI.LayoutManager')
local Mouse = require(SLAB_PATH .. '.Internal.Input.Mouse')
local Region = require(SLAB_PATH .. '.Internal.UI.Region')
local Stats = require(SLAB_PATH .. '.Internal.Core.Stats')
local Style = require(SLAB_PATH .. '.Style')
local Tooltip = require(SLAB_PATH .. '.Internal.UI.Tooltip')
local Window = require(SLAB_PATH .. '.Internal.UI.Window')

local ComboBox = {}

local instances = {}
local active
local MIN_WIDTH = 150
local MIN_HEIGHT = 150
local STR_EMPTY = ""
local TBL_EMPTY = {}
local TBL_IGNORE = {Ignore = true}
local input_rounding = {0, 0, 0, 0}
local dd_rounding = {0, 0, 0, 0}

local function GetInstance(id)
	if not instances[id] then
		local instance = {
			IsOpen = false,
			WasOpened = false,
			WinW = 0,
			WinH = 0,
			StatHandle = nil,
			InputId = id .. "_Input",
			WinId = id .. "_combobox",

			InputOptions = {
				ReadOnly = true,
				Align = "left",
				Rounding = input_rounding,
			},

			WindowOptions = {
				AllowResize = false,
				AutoSizeWindow = false,
				AllowFocus = false,
				AutoSizeContent = true,
				NoSavedSettings = true,
			}
		}
		instances[id] = instance
	end
	return instances[id]
end

function ComboBox.Begin(id, selected, opt)
	assert(type(selected) == "string", "selected must be of type string")
	local stat_handle = Stats.Begin("ComboBox", "Slab")
	opt = opt or TBL_EMPTY
	selected = selected or STR_EMPTY
	local tooltip = opt.Tooltip or STR_EMPTY
	local w = opt.W or MIN_WIDTH
	local wh = opt.WinH or MIN_HEIGHT
	local rounding = opt.Rounding or Style.ComboBoxRounding
	local instance = GetInstance(id)
	local win_item_id = Window.GetItemId(id)
	local h = Style.Font:getHeight()
	w = LayoutManager.ComputeSize(w, h)
	LayoutManager.AddControl(w, h, "ComboBox")
	local x, y = Cursor.GetPosition()
	local radius = h * 0.35
	local input_bg_color = Style.ComboBoxColor
	local ddw = radius * 4
	local ddx = x + w - ddw
	local dd_color = Style.ComboBoxDropDownColor
	input_rounding[1], input_rounding[4] = rounding, rounding
	dd_rounding[1], dd_rounding[4] = rounding, rounding
	instance.X, instance.Y = x, y
	instance.W, instance.H = w, h
	instance.WinH = min(instance.WinH, wh)
	instance.StatHandle = stat_handle

	local mx, my = Window.GetMousePosition()
	instance.WasOpened = instance.IsOpen
	local hovered = not Window.IsObstructedAtMouse() and
		x <= mx and mx <= x + w and
		y <= my and my <= y + h

	if hovered then
		input_bg_color = Style.ComboBoxHoveredColor
		dd_color = Style.ComboBoxDropDownHoveredColor
		if Mouse.IsClicked(1) then
			instance.IsOpen = not instance.IsOpen
			if instance.IsOpen then
				Window.SetStackLock(instance.WinId)
			end
		end
	end

	LayoutManager.Begin("Ignore", TBL_IGNORE)
	local input_opt = instance.InputOptions
	input_opt.Text = selected
	input_opt.W = max(w - ddw, ddw)
	input_opt.H = h
	input_opt.BgColor = input_bg_color
	Input.Begin(instance.InputId, input_opt)
	LayoutManager.End()
	Cursor.SameLine()
	DrawCommands.Rectangle("fill", ddx, y, ddw, h, dd_color, dd_rounding)
	DrawCommands.Triangle("fill", ddx + radius * 2, y + h - radius * 1.35,
		radius, 180, Style.ComboBoxArrowColor)
	Cursor.SetItemBounds(x, y, w, h)
	Cursor.AdvanceY(h)

	if hovered then
		Tooltip.Begin(tooltip)
		Window.SetHotItem(win_item_id)
	end

	Window.AddItem(x, y, w, h, win_item_id)
	local wx, wy = Window.TransformPoint(x, y)

	if instance.IsOpen then
		LayoutManager.Begin("ComboBox", TBL_IGNORE)
		local win_opt = instance.WindowOptions
		win_opt.X = wx - 1
		win_opt.Y = wy - h
		win_opt.W = max(w, instance.WinH)
		win_opt.H = instance.WinH
		win_opt.Layer = Window.GetLayer()
		win_opt.ContentW = max(w, instance.WinW)
		Window.Begin(instance.WinId, win_opt)
		active = instance
	else
		Stats.End(instance.StatHandle)
	end
	return instance.IsOpen
end

function ComboBox.End()
	local y, h = 0, 0
	local stat_handle = active and active.StatHandle
	if active then
		Cursor.SetItemBounds(active.X, active.Y, active.W, active.H)
		y, h = active.Y, active.H
		local cw, ch = Window.GetContentSize()
		active.WinW = max(cw, active.W)
		active.WinH = ch

		if Mouse.IsClicked(1) and active.WasOpened and
			not Region.IsHoverScrollBar(Window.GetId()) then
			active.IsOpen = false
			active = nil
			Window.SetStackLock()
		end
	end

	Window.End()
	DrawCommands.SetLayer(Enums.layers.normal)
	LayoutManager.End()

	if y ~= 0 and h ~= 0 then
		Cursor.SetY(y)
		Cursor.AdvanceY(h)
	end

	Stats.End(stat_handle)
end

return ComboBox
