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

local love = require("love")
local format = string.format
local max = math.max

local Cursor = require(SLAB_PATH .. ".Internal.Core.Cursor")
local DrawCommands = require(SLAB_PATH .. ".Internal.Core.DrawCommands")
local Enums = require(SLAB_PATH .. ".Internal.Core.Enums")
local MenuState = require(SLAB_PATH .. ".Internal.UI.MenuState")
local Mouse = require(SLAB_PATH .. ".Internal.Input.Mouse")
local Style = require(SLAB_PATH .. ".Style")
local Text = require(SLAB_PATH .. ".Internal.UI.Text")
local Window = require(SLAB_PATH .. ".Internal.UI.Window")

local Menu = {}

local instances = {}
local pad = 8
local lpad = 25
local rpad = 70
local check_size = 5
local opened = {good = false}

local TBL_DEF = {Enabled = true}
local TBL_ROUNDING_ON = {2, 2, 2, 2}
local TBL_ROUNDING_OFF = {0, 0, 2, 2}
local TBL_DEF_CM = {
	IsItem = false,
	IsWindow = false,
	Button = 2,
}
local STR_CM = ".ContextMenu"

local function IsItemHovered()
	local x, y, _, h = Cursor.GetItemBounds()
	local mx, my = Window.GetMousePosition()
	return not Window.IsObstructedAtMouse() and
		x < mx and mx < x + Window.GetWidth() and
		y < my and my < y + h
end

local function AlterOptions(opt)
	opt = opt or {}
	opt.Enabled = opt.Enabled or TBL_DEF.Enabled
	opt.IsSelectable = opt.Enabled
	opt.SelectOnHover = opt.Enabled
	opt.Color = opt.Enabled and Style.TextColor or Style.TextDisabledColor
	return opt
end

local function ConstrainPosition(x, y, w, h)
	local ww, wh = love.graphics.getDimensions()
	local res_x, res_y = x, y
	local r = x + w
	local b = y + h
	local ox = r >= ww
	local oy = b >= wh
	local wx = Window.GetBounds()
	res_x = ox and (x - (r - ww)) or res_x
	res_y = oy and (y - h) or res_y
	res_x = ox and (wx - w) or res_x
	res_x = max(res_x, 0)
	res_y = max(res_y, 0)
	return res_x, res_y
end

local function BeginWindow(id, x, y, round_all_corners)
	local instance = instances[id]
	if instance then
		x, y = ConstrainPosition(x, y, instance.W, instance.H)
	end
	Cursor.PushContext()
	Window.Begin(id, {
		X = x, Y = y,
		W = 0, H = 0,
		AllowResize = false, AllowFocus = false,
		Border = 0,
		AutoSizeWindow = true,
		Layer = Enums.layers.context_menu,
		BgColor = Style.MenuColor,
		Rounding = round_all_corners and TBL_ROUNDING_ON or TBL_ROUNDING_OFF,
		NoSavedSettings = true
	})
end

function Menu.BeginMenu(label, opt)
	local res = false
	local x, y = Cursor.GetPosition()
	local is_menu_bar = Window.IsMenuBar()
	local id = format("%s.%s", Window.GetId(), label)
	local win = Window.Top()
	opt = AlterOptions(opt)
	opt.IsSelected = opt.Enabled and win.Selected == id
	if is_menu_bar then
		opt.IsSelectableTextOnly = opt.Enabled
		opt.Pad = pad * 2
	else
		Cursor.SetX(x + lpad)
	end
	local menu_x, menu_y = 0, 0
	-- "Result" may be false if "Enabled" is false. The hovered state is still required
	-- so that will be handled differently.
	res = Text.Begin(label, opt)
	local ix, iy, iw, ih = Cursor.GetItemBounds()

	if is_menu_bar then
		Cursor.SameLine()
		-- Menubar items don"t extend to the width of the window since these items are layed out horizontally. Only
		-- need to perform hover check on item bounds.
		local hovered = Cursor.IsInItemBounds(Window.GetMousePosition())
		if hovered and Mouse.IsClicked(1) then
			if res then
				MenuState.WasOpened = MenuState.IsOpened
				MenuState.IsOpened = not MenuState.IsOpened
				if MenuState.IsOpened then
					MenuState.RequestClose = false
				end
			elseif MenuState.WasOpened then
				MenuState.RequestClose = false
			end
		end

		if MenuState.IsOpened and (not opened.good) and res then
			win.Selected = id
		else
			win.Selected = nil
		end
		menu_x = x
		menu_y = y + Window.GetHeight()
	else
		local wx, _, ww, _ = Window.GetBounds()
		local h = Style.Font:getHeight()
		local tx = wx + ww - h * 0.75
		local ty = y + h * 0.5
		local radius = h * 0.35
		DrawCommands.Triangle("fill", tx, ty, radius, 90, Style.TextColor)
		menu_x = x + ww
		menu_y = y
		win.Selected = res and id or win.Selected
		Window.AddItem(ix, iy, iw + rpad, ih)
		-- Prevent closing the menu window if this item is clicked.
		if IsItemHovered() and Mouse.IsClicked(1) then
			MenuState.RequestClose = false
		end
	end

	res = win.Selected == id
	if res then
		BeginWindow(id, menu_x, menu_y, not is_menu_bar)
	end
	return res
end

function Menu.MenuItem(label, opt)
	opt = AlterOptions(opt)
	Cursor.SetX(Cursor.GetX() + lpad)
	local res = Text.Begin(label, opt)
	local ix, iy, iw, ih = Cursor.GetItemBounds()
	Window.AddItem(ix, iy, iw + rpad, ih)

	if res then
		local win = Window.Top()
		win.Selected = nil
		res = Mouse.IsClicked(1)
		if res and MenuState.WasOpened then
			MenuState.RequestClose = true
		end
	elseif IsItemHovered() and Mouse.IsClicked(1) then
		MenuState.RequestClose = false
	end
	return res
end

function Menu.MenuItemChecked(label, is_checked, opt)
	opt = AlterOptions(opt)
	local x, y = Cursor.GetPosition()
	local res = Menu.MenuItem(label, opt)
	if is_checked then
		local h = Style.Font:getHeight()
		DrawCommands.Check(x + lpad * 0.5, y + h * 0.5, check_size, opt.Color)
	end
	return res
end

function Menu.EndMenu()
	local id = Window.GetId()
	if not instances[id] then
		instances[id] = {}
	end
	local instance = instances[id]
	instance.W = Window.GetWidth()
	instance.H = Window.GetHeight()
	Window.End()
	Cursor.PopContext()
end

function Menu.Pad() return pad end

function Menu.BeginContextMenu(opt)
	opt = opt or TBL_DEF_CM
	opt.IsItem = opt.IsItem or TBL_DEF_CM.IsItem
	opt.IsWindow = opt.IsWindow or TBL_DEF_CM.IsWindow
	opt.Button = opt.Button or TBL_DEF_CM.Button

	local base_id, id
	if opt.IsWindow then
		base_id = Window.GetId()
	elseif opt.IsItem then
		base_id = Window.GetContextHotItem() or Window.GetHotItem()
	end

	if opt.IsItem and Window.GetLastItem() ~= base_id then return false end
	if base_id then id = base_id .. STR_CM end
	if not id then return false end

	if MenuState.IsOpened and opened.good then
		if opened.Id == id then
			BeginWindow(opened.Id, opened.X, opened.Y, true)
			return true
		end
		return false
	end

	local is_opening = false
	if not Window.IsObstructedAtMouse() and
		Window.IsMouseHovered() and
		Mouse.IsClicked(opt.Button) then
		local valid_win = opt.IsWindow and (Window.GetHotItem() == nil)
		local valid_item = opt.IsItem

		if valid_win or valid_item then
			MenuState.IsOpened = true
			is_opening = true
		end
	end

	if is_opening then
		local mx, my = Mouse.Position()
		mx, my = ConstrainPosition(mx, my, 0, 0)
		opened.Id = id
		opened.X = mx
		opened.Y = my
		opened.Win = Window.Top()
		opened.good = true
		Window.SetContextHotItem(opt.IsItem and base_id)
	end
	return false
end

function Menu.EndContextMenu()
	Menu.EndMenu()
end

function Menu.Close()
	MenuState.WasOpened = MenuState.IsOpened
	MenuState.IsOpened = false
	MenuState.RequestClose = false

	if opened.good then
		opened.Win.ContextHotItem = nil
		opened.good = false
	end
end

return Menu
