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

local Cursor = require(SLAB_PATH .. ".Internal.Core.Cursor")
local DrawCommands = require(SLAB_PATH .. ".Internal.Core.DrawCommands")
local MenuState = require(SLAB_PATH .. ".Internal.UI.MenuState")
local Style = require(SLAB_PATH .. ".Style")
local Window = require(SLAB_PATH .. ".Internal.UI.Window")

local MenuBar = {}
local instances = {}

local function GetInstance()
	local win = Window.Top()
	if not instances[win] then
		instances[win] = {Id = win.Id .. "_MenuBar"}
	end
	return instances[win]
end

function MenuBar.Begin(is_main_menu_bar)
	local x, y = Cursor.GetPosition()
	local ww = select(3, Window.GetBounds())
	local instance = GetInstance()
	if not MenuState.IsOpened then
		instance.Selected = nil
	end
	local fh = Style.Font:getHeight()
	MenuState.MainMenuBarH = is_main_menu_bar and fh
	Window.Begin(instance.Id, {
		X = x, Y = y,
		W = ww, H = fh,
		AllowResize = false,
		AllowFocus = false,
		Border = 0,
		BgColor = Style.MenuColor,
		NoOutline = true,
		IsMenuBar = true,
		AutoSizeWindow = false,
		AutoSizeContent = false,
		Layer = is_main_menu_bar and DrawCommands.layers.main_menu_bar,
		Rounding = 0,
		NoSavedSettings = true
	})
	Cursor.AdvanceX(4)
	return true
end

function MenuBar.End()
	Window.End()
end

function MenuBar.Clear()
	for _, v in ipairs(instances) do
		v.Selected = nil
	end
end

return MenuBar
