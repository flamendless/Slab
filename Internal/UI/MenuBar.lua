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

local Cursor = require(SLAB_PATH .. ".Internal.Core.Cursor")
local DrawCommands = require(SLAB_PATH .. ".Internal.Core.DrawCommands")
local Menu = require(SLAB_PATH .. ".Internal.UI.Menu")
local MenuState = require(SLAB_PATH .. ".Internal.UI.MenuState")
local Style = require(SLAB_PATH .. ".Style")
local Window = require(SLAB_PATH .. ".Internal.UI.Window")

local MenuBar = {}
local Instances = {}

local function GetInstance()
	local Win = Window.Top()
	if Instances[Win] == nil then
		local Instance = {}
		Instance.Selected = nil
		Instance.Id = Win.Id .. '_MenuBar'
		Instances[Win] = Instance
	end
	return Instances[Win]
end

function MenuBar.Begin(IsMainMenuBar)
	local X, Y = Cursor.GetPosition()
	local WinX, WinY, WinW, WinH = Window.GetBounds()
	local Instance = GetInstance()

	if not MenuState.IsOpened then
		Instance.Selected = nil
	end

	if IsMainMenuBar then
		MenuState.MainMenuBarH = Style.Font:getHeight()
	end

	Window.Begin(Instance.Id,
	{
		X = X,
		Y = Y,
		W = WinW,
		H = Style.Font:getHeight(),
		AllowResize = false,
		AllowFocus = false,
		Border = 0.0,
		BgColor = Style.MenuColor,
		NoOutline = true,
		IsMenuBar = true,
		AutoSizeWindow = false,
		AutoSizeContent = false,
		Layer = IsMainMenuBar and 'MainMenuBar' or nil,
		Rounding = 0.0,
		NoSavedSettings = true
	})

	Cursor.AdvanceX(4.0)

	return true
end

function MenuBar.End()
	Window.End()
end

function MenuBar.Clear()
	for I, V in ipairs(Instances) do
		V.Selected = nil
	end
end

return MenuBar
