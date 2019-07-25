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
local Image = require(SLAB_PATH .. '.Internal.UI.Image')
local LayoutManager = require(SLAB_PATH .. '.Internal.UI.LayoutManager')
local Mouse = require(SLAB_PATH .. '.Internal.Input.Mouse')
local Region = require(SLAB_PATH .. '.Internal.UI.Region')
local Stats = require(SLAB_PATH .. '.Internal.Core.Stats')
local Style = require(SLAB_PATH .. '.Style')
local Text = require(SLAB_PATH .. '.Internal.UI.Text')
local Tooltip = require(SLAB_PATH .. '.Internal.UI.Tooltip')
local Window = require(SLAB_PATH .. '.Internal.UI.Window')

local Tree = {}
local Instances = {}
local Hierarchy = {}

local Radius = 4.0

local function GetInstance(Id)
	if #Hierarchy > 0 then
		local Top = Hierarchy[1]
		Id = Top.Id .. "." .. Id
	end

	if Instances[Id] == nil then
		local Instance = {}
		Instance.X = 0.0
		Instance.Y = 0.0
		Instance.W = 0.0
		Instance.H = 0.0
		Instance.IsOpen = false
		Instance.WasOpen = false
		Instance.Id = Id
		Instance.StatHandle = nil
		Instance.TreeR = 0
		Instance.TreeB = 0
		Instances[Id] = Instance
	end
	return Instances[Id]
end

function Tree.Begin(Id, Options)
	local StatHandle = Stats.Begin('Tree', 'Slab')

	Options = Options == nil and {} or Options
	Options.Label = Options.Label == nil and Id or Options.Label
	Options.Tooltip = Options.Tooltip == nil and "" or Options.Tooltip
	Options.OpenWithHighlight = Options.OpenWithHighlight == nil and true or OpenWithHighlight
	Options.Icon = Options.Icon == nil and nil or Options.Icon
	Options.IconPath = Options.IconPath == nil and nil or Options.IconPath
	Options.IsSelected = Options.IsSelected == nil and false or Options.IsSelected
	Options.IsOpen = Options.IsOpen == nil and false or Options.IsOpen

	local Instance = GetInstance(Id)

	Instance.WasOpen = Instance.IsOpen
	Instance.StatHandle = StatHandle

	local WinItemId = Window.GetItemId(Instance.Id)
	local MouseX, MouseY = Mouse.Position()
	local TMouseX, TMouseY = Region.InverseTransform(nil, MouseX, MouseY)
	local WinX, WinY = Window.GetPosition()
	local WinW, WinH = Window.GetBorderlessSize()
	local IsObstructed = Window.IsObstructedAtMouse() or Region.IsHoverScrollBar()
	local W = Text.GetWidth(Options.Label)
	local H = math.max(Style.Font:getHeight(), Instance.H)
	local Diameter = Radius * 2.0

	if not Options.IsLeaf then
		W = W + Diameter + Radius
	end

	local Icon = Options.Icon
	if Icon == nil then
		Icon = Options.IconPath
	end

	local ImageW, ImageH = Image.GetSize(Icon)
	W = W + ImageW
	H = math.max(H, ImageH)

	WinX = WinX + Window.GetBorder()
	WinY = WinY + Window.GetBorder()

	if #Hierarchy == 0 then
		local ControlW, ControlH = W, H
		if Instance.TreeR > 0 and Instance.TreeB > 0 then
			ControlW = Instance.TreeR - Instance.X
			ControlH = Instance.TreeB - Instance.Y
		end

		LayoutManager.AddControl(ControlW, ControlH)

		Instance.TreeR = 0
		Instance.TreeB = 0
	end

	local X, Y = Cursor.GetPosition()
	local TriX, TriY = X + Radius, Y + H * 0.5

	local IsHot = not IsObstructed and WinX <= TMouseX and TMouseX <= WinX + WinW and Y <= TMouseY and TMouseY <= Y + H and Region.Contains(MouseX, MouseY)

	if IsHot or Options.IsSelected then
		DrawCommands.Rectangle('fill', WinX, Y, WinW, H, Style.TextHoverBgColor)
	end

	if IsHot then
		if Mouse.IsClicked(1) and not Options.IsLeaf and Options.OpenWithHighlight then
			Instance.IsOpen = not Instance.IsOpen
		end
	end

	local IsExpanderClicked = false
	if not Options.IsLeaf then
		if not IsObstructed and X <= TMouseX and TMouseX <= X + Diameter and Y <= TMouseY and TMouseY <= Y + H then
			if Mouse.IsClicked(1) and not Options.OpenWithHighlight then
				Instance.IsOpen = not Instance.IsOpen
				Window.SetHotItem(nil)
				IsExpanderClicked = true
			end
		end

		local Dir = Instance.IsOpen and 180 or 90
		DrawCommands.Triangle('fill', TriX, TriY, Radius, Dir, Style.TextColor)
	end

	if not Instance.IsOpen and Instance.WasOpen then
		Window.ResetContentSize()
		Region.ResetContentSize()
	end

	Cursor.AdvanceX(Diameter)
	Instance.X = X
	Instance.Y = Y
	Instance.W = W
	Instance.H = H

	local CursorX, CursorY = Cursor.GetPosition()

	LayoutManager.Begin('Ignore', {Ignore = true})

	if Options.Icon ~= nil or Options.IconPath ~= nil then
		Image.Begin(Instance.Id .. '_Icon', {
			Image = Options.Icon,
			Path = Options.IconPath
		})

		local ItemX, ItemY, ItemW, ItemH = Cursor.GetItemBounds()
		Instance.H = math.max(Instance.H, ItemH)
		Cursor.SameLine({CenterY = true})
	end

	Text.Begin(Options.Label)

	LayoutManager.End()

	local Root = Instance
	if #Hierarchy > 0 then
		Root = Hierarchy[#Hierarchy]
	end

	local ItemX, ItemY, ItemW, ItemH = Cursor.GetItemBounds()
	Root.TreeR = math.max(Root.TreeR, ItemX + ItemW)
	Root.TreeB = math.max(Root.TreeB, Y + H)

	Cursor.SetY(Instance.Y)
	Cursor.AdvanceY(H)

	if Options.IsOpen then
		Instance.IsOpen = true
	end

	if Instance.IsOpen then
		table.insert(Hierarchy, 1, Instance)
		Cursor.SetX(CursorX)
	else
		Cursor.SetX(X)
	end

	if IsHot then
		Tooltip.Begin(Options.Tooltip)

		if not IsExpanderClicked then
			Window.SetHotItem(WinItemId)
		end
	end

	Window.AddItem(X, Y, (WinX + WinW) - Instance.X, H, WinItemId)

	if not Instance.IsOpen then
		Stats.End(Instance.StatHandle)
	end

	return Instance.IsOpen
end

function Tree.End()
	local StatHandle = Hierarchy[1].StatHandle
	table.remove(Hierarchy, 1)
	local Instance = Hierarchy[1]
	if Instance ~= nil then
		Cursor.SetX(Instance.X)
	else
		Cursor.SetX(Cursor.GetAnchorX())
	end

	Stats.End(StatHandle)
end

return Tree
