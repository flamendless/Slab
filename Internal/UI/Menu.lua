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

local insert = table.insert
local remove = table.remove
local max = math.max

local Cursor = require(SLAB_PATH .. '.Internal.Core.Cursor')
local DrawCommands = require(SLAB_PATH .. '.Internal.Core.DrawCommands')
local MenuState = require(SLAB_PATH .. '.Internal.UI.MenuState')
local Mouse = require(SLAB_PATH .. '.Internal.Input.Mouse')
local Style = require(SLAB_PATH .. '.Style')
local Text = require(SLAB_PATH .. '.Internal.UI.Text')
local Window = require(SLAB_PATH .. '.Internal.UI.Window')

local Menu = {}
local Instances = {}

local Pad = 8.0
local LeftPad = 25.0
local RightPad = 70.0
local CheckSize = 5.0
local OpenedContextMenu = nil
local CursorStack = {}

local function ConstrainPosition(X, Y, W, H)
	local ResultX, ResultY = X, Y

	local Right = X + W
	local Bottom = Y + H
	local OffsetX = Right >= love.graphics.getWidth()
	local OffsetY = Bottom >= love.graphics.getHeight()

	if OffsetX then
		ResultX = X - (Right - love.graphics.getWidth())
	end

	if OffsetY then
		ResultY = Y - H
	end

	local WinX, WinY, WinW, WinH = Window.GetBounds()
	if OffsetX then
		ResultX = WinX - W
	end

	ResultX = max(ResultX, 0.0)
	ResultY = max(ResultY, 0.0)

	return ResultX, ResultY
end

local function BeginWindow(Id, X, Y)
	local Instance = Instances[Id]
	if Instance ~= nil then
		X, Y = ConstrainPosition(X, Y, Instance.W, Instance.H)
	end

	Window.Begin(Id,
	{
		X = X,
		Y = Y,
		W = 0.0,
		H = 0.0,
		AllowResize = false,
		AllowFocus = false,
		Border = 0.0,
		AutoSizeWindow = true,
		Layer = 'ContextMenu',
		BgColor = Style.MenuColor,
		Rounding = {0, 0, 2, 2},
		NoSavedSettings = true
	})
end

function Menu.BeginMenu(Label)
	local Result = false
	local X, Y = Cursor.GetPosition()
	local IsMenuBar = Window.IsMenuBar()
	local Id = Window.GetId() .. "." .. Label
	local Win = Window.Top()

	local Options = {IsSelectable = true, SelectOnHover = true, IsSelected = Win.Selected == Id}

	if IsMenuBar then
		Options.IsSelectableTextOnly = true
		Options.Pad = Pad * 2
	else
		Cursor.SetX(X + LeftPad)
	end

	local MenuX = 0.0
	local MenuY = 0.0

	Result = Text.Begin(Label, Options)
	local ItemX, ItemY, ItemW, ItemH = Cursor.GetItemBounds()
	if IsMenuBar then
		Cursor.SameLine()

		if Result then
			if Mouse.IsClicked(1) then
				MenuState.WasOpened = MenuState.IsOpened
				MenuState.IsOpened = not MenuState.IsOpened
			end
		end

		if MenuState.IsOpened then
			MenuState.RequestClose = Mouse.IsClicked(1) and MenuState.WasOpened
			
			if Result then
				Win.Selected = Id
			end
		else
			Win.Selected = nil
		end

		MenuX = X
		MenuY = Y + Window.GetHeight()
	else
		local WinX, WinY, WinW, WinH = Window.GetBounds()
		local H = Style.Font:getHeight()
		local TriX = WinX + WinW - H * 0.75
		local TriY = Y + H * 0.5
		local Radius = H * 0.35
		DrawCommands.Triangle('fill', TriX, TriY, Radius, 90, Style.TextColor)

		MenuX = X + WinW
		MenuY = Y

		if Result then
			Win.Selected = Id
		end

		Window.AddItem(ItemX, ItemY, ItemW + RightPad, ItemH)
	end

	Result = Win.Selected == Id

	if Result then
		local CursorX, CursorY = Cursor.GetPosition()
		insert(CursorStack, 1, {X = CursorX, Y = CursorY})

		BeginWindow(Id, MenuX, MenuY)
	end

	return Result
end

function Menu.MenuItem(Label)
	Cursor.SetX(Cursor.GetX() + LeftPad)
	local Result = Text.Begin(Label, {IsSelectable = true, SelectOnHover = true})
	local ItemX, ItemY, ItemW, ItemH = Cursor.GetItemBounds()
	Window.AddItem(ItemX, ItemY, ItemW + RightPad, ItemH)

	if Result then
		local Win = Window.Top()
		Win.Selected = nil

		Result = Mouse.IsClicked(1)
		if Result then
			MenuState.IsOpened = false
		end
	end

	return Result
end

function Menu.MenuItemChecked(Label, IsChecked)
	local X, Y = Cursor.GetPosition()
	local Result = Menu.MenuItem(Label)

	if IsChecked then
		local H = Style.Font:getHeight()
		DrawCommands.Check(X + LeftPad * 0.5, Y + H * 0.5, CheckSize, Style.TextColor)
	end

	return Result
end

function Menu.Separator()
	local Ctx = Context.Top()
	if Ctx.Type == 'Menu' then
		local Item = GetItem("Sep_" .. Ctx.Data.SeparatorId)
		Item.IsSeparator = true
		Ctx.Data.SeparatorId = Ctx.Data.SeparatorId + 1
	end
end

function Menu.EndMenu()
	local Id = Window.GetId()
	if Instances[Id] == nil then
		Instances[Id] = {}
	end
	Instances[Id].W = Window.GetWidth()
	Instances[Id].H = Window.GetHeight()

	Window.End()

	if #CursorStack > 0 then
		local Top = CursorStack[1]
		Cursor.SetPosition(Top.X, Top.Y)
		remove(CursorStack, 1)
	end
end

function Menu.Pad()
	return Pad
end

function Menu.BeginContextMenu(Options)
	Options = Options == nil and {} or Options

	local BaseId = nil
	local Id = nil
	if Options.IsWindow then
		BaseId = Window.GetId()
	elseif Options.IsItem then
		BaseId = Window.GetContextHotItem()
		if BaseId == nil then
			BaseId = Window.GetHotItem()
		end
	end

	if Options.IsItem and Window.GetLastItem() ~= BaseId then
		return false
	end

	if BaseId ~= nil then
		Id = BaseId .. '.ContextMenu'
	end

	if Id == nil then
		return false
	end

	if MenuState.IsOpened and OpenedContextMenu ~= nil then
		if OpenedContextMenu.Id == Id then
			local CursorX, CursorY = Cursor.GetPosition()
			insert(CursorStack, 1, {X = CursorX, Y = CursorY})
			BeginWindow(OpenedContextMenu.Id, OpenedContextMenu.X, OpenedContextMenu.Y)
			return true
		end
		return false
	end

	local IsOpening = false
	if not Window.IsObstructedAtMouse() and Window.IsMouseHovered() and Mouse.IsClicked(2) then
		local IsValidWindow = Options.IsWindow and Window.GetHotItem() == nil
		local IsValidItem = Options.IsItem

		if IsValidWindow or IsValidItem then
			MenuState.IsOpened = true
			IsOpening = true
		end
	end

	if IsOpening then
		local X, Y = Mouse.Position()
		X, Y = ConstrainPosition(X, Y, 0.0, 0.0)
		OpenedContextMenu = {Id = Id, X = X, Y = Y, Win = Window.Top()}
		Window.SetContextHotItem(Options.IsItem and BaseId or nil)
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

	if OpenedContextMenu ~= nil then
		OpenedContextMenu.Win.ContextHotItem = nil
		OpenedContextMenu = nil
	end
end

return Menu
