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

local max = math.max
local insert = table.insert
local remove = table.remove

local Button = require(SLAB_PATH .. '.Internal.UI.Button')
local Cursor = require(SLAB_PATH .. '.Internal.Core.Cursor')
local DrawCommands = require(SLAB_PATH .. '.Internal.Core.DrawCommands')
local Image = require(SLAB_PATH .. '.Internal.UI.Image')
local LayoutManager = require(SLAB_PATH .. '.Internal.UI.LayoutManager')
local Messages = require(SLAB_PATH .. '.Internal.Core.Messages')
local Mouse = require(SLAB_PATH .. '.Internal.Input.Mouse')
local Region = require(SLAB_PATH .. '.Internal.UI.Region')
local Stats = require(SLAB_PATH .. '.Internal.Core.Stats')
local Style = require(SLAB_PATH .. '.Style')
local Text = require(SLAB_PATH .. '.Internal.UI.Text')
local Tooltip = require(SLAB_PATH .. '.Internal.UI.Tooltip')
local Window = require(SLAB_PATH .. '.Internal.UI.Window')
local IdCache = require(SLAB_PATH .. '.Internal.Core.IdCache')

local Tree = {}
local Instances = setmetatable({}, {__mode = "k"})
local Hierarchy = {}

local Radius = 4.0

local idCache = IdCache()
local EMPTY = {}
local IGNORE = { Ignore = true }
local CENTERY = { CenterY = true }
local TRANSPARENT = { 0, 0, 0, 0 }

local function GetInstance(Id)
	local IdString = tostring(Id)

	if #Hierarchy > 0 then
		IdString = idCache:get(Hierarchy[1].Id, IdString)
	end

	if Instances[Id] == nil then
		local Instance = {}
		Instance.X = 0.0
		Instance.Y = 0.0
		Instance.W = 0.0
		Instance.H = 0.0
		Instance.IsOpen = false
		Instance.WasOpen = false
		Instance.Id = IdString
		Instance.StatHandle = nil
		Instance.TreeR = 0
		Instance.TreeB = 0
		Instance.NoSavedSettings = false
		Instances[Id] = Instance
	end
	return Instances[Id]
end

function Tree.Begin(Id, Options)
	local StatHandle = Stats.Begin('Tree', 'Slab')

	local IsTableId = type(Id) == 'table'
	local IdLabel = tostring(Id)

	Options = Options or EMPTY
	local label = Options.Label or IdLabel
	local icon = Options.Icon
	local openWithHighlight = Options.OpenWithHighlight == nil or Options.OpenWithHighlight

	if Options.IconPath ~= nil then
		Messages.Broadcast('Tree.Options.IconPath', "'IconPath' option has been deprecated since v0.8.0. Please use the 'Icon' option.")
	end

	local Instance = nil
	local WinItemId = Window.GetItemId(IdLabel)

	if IsTableId then
		Instance = GetInstance(Id)
	else
		Instance = GetInstance(WinItemId)
	end

	Instance.WasOpen = Instance.IsOpen
	Instance.StatHandle = StatHandle
	Instance.NoSavedSettings = Options.NoSavedSettings or IsTableId

	local MouseX, MouseY = Mouse.Position()
	local TMouseX, TMouseY = Region.InverseTransform(nil, MouseX, MouseY)
	local WinX, WinY = Window.GetPosition()
	local WinW, WinH = Window.GetBorderlessSize()
	local IsObstructed = Window.IsObstructedAtMouse() or Region.IsHoverScrollBar()
	local W = Text.GetWidth(label)
	local H = max(Style.Font:getHeight(), Instance.H)

	if not Options.IsLeaf then
		W = W + H + Radius
	end

	-- Account for icon if one is requested.
	W = icon and W + H or W

	WinX = WinX + Window.GetBorder()
	WinY = WinY + Window.GetBorder()

	if #Hierarchy == 0 then
		local ControlW, ControlH = W, H
		if Instance.TreeR > 0 and Instance.TreeB > 0 then
			ControlW = Instance.TreeR - Instance.X
			ControlH = Instance.TreeB - Instance.Y
		end

		LayoutManager.AddControl(ControlW, ControlH, 'Tree')

		Instance.TreeR = 0
		Instance.TreeB = 0
	end

	local Root = Instance
	if #Hierarchy > 0 then
		Root = Hierarchy[#Hierarchy]
	end

	local X, Y = Cursor.GetPosition()
	if Root ~= Instance then
		X = Root ~= Instance and (Root.X + H * #Hierarchy)
		Cursor.SetX(X)
	end
	local TriX, TriY = X + Radius, Y + H * 0.5

	local IsHot = not IsObstructed and WinX <= TMouseX and TMouseX <= WinX + WinW and Y <= TMouseY and TMouseY <= Y + H and Region.Contains(MouseX, MouseY)

	if IsHot or Options.IsSelected then
		DrawCommands.Rectangle('fill', WinX, Y, WinW, H, Style.TextHoverBgColor)
	end

	if IsHot then
		if Mouse.IsClicked(1) and not Options.IsLeaf and openWithHighlight then
			Instance.IsOpen = not Instance.IsOpen
		end
	end

	local IsExpanderClicked = false
	local ExpandIconOptions = Instance.ExpandIconOptions

	if not Options.IsLeaf then
		-- Render the triangle depending on if the tree item is open/closed.
		local SubX = Instance.IsOpen and 0 or 200
		local SubY = Instance.IsOpen and 100 or 50

		if not ExpandIconOptions then
			ExpandIconOptions = {
				Image = { Path = SLAB_FILE_PATH .. '/Internal/Resources/Textures/Icons.png', SubW = 50, SubH = 50 },
				PadX = 0,
				PadY = 0,
				Color = TRANSPARENT,
				HoverColor = TRANSPARENT,
				PressColor = TRANSPARENT,
				IconId = Instance.Id .. '_Open',
				ExpandId = Instance.Id .. '_Expand',
			}
			Instance.ExpandIconOptions = ExpandIconOptions
		end

		ExpandIconOptions.Image.SubX = SubX
		ExpandIconOptions.Image.SubY = SubY
		ExpandIconOptions.W = H
		ExpandIconOptions.H = H

		if Button.Begin(ExpandIconOptions.ExpandId, ExpandIconOptions) and not openWithHighlight then
			Instance.IsOpen = not Instance.IsOpen
			Window.SetHotItem(nil)
			IsExpanderClicked = true
		end

		Cursor.SameLine()
	else
		-- Advance the cursor for leaf nodes so text aligns with other items that are not leaf nodes.
		Cursor.AdvanceX(H + Cursor.PadX())
	end

	if not Instance.IsOpen and Instance.WasOpen then
		Window.ResetContentSize()
		Region.ResetContentSize()
	end

	Instance.X = X
	Instance.Y = Y
	Instance.W = W
	Instance.H = H

	LayoutManager.Begin('Ignore', IGNORE)

	if icon ~= nil then
		-- Force the icon to be of the same size as the tree item.
		icon.W = H
		icon.H = H
		Image.Begin(ExpandIconOptions.IconId, icon)

		local ItemX, ItemY, ItemW, ItemH = Cursor.GetItemBounds()
		Instance.H = max(Instance.H, ItemH)
		Cursor.SameLine(CENTERY)
	end

	Text.Begin(label)

	LayoutManager.End()

	local ItemX, ItemY, ItemW, ItemH = Cursor.GetItemBounds()
	Root.TreeR = max(Root.TreeR, ItemX + ItemW)
	Root.TreeB = max(Root.TreeB, Y + H)

	Cursor.SetY(Instance.Y)
	Cursor.AdvanceY(H)

	if Instance.IsOpen then
		insert(Hierarchy, 1, Instance)
	end

	if IsHot then
		Tooltip.Begin(Options.Tooltip or "")

		if not IsExpanderClicked then
			Window.SetHotItem(WinItemId)
		end
	end

	-- The size of the item has already been determined by Text.Begin. However, this item's ID needs to be
	-- set as the last item for hot item checks. So the item will be added with zero width and height.
	Window.AddItem(X, Y, 0, 0, WinItemId)

	if not Instance.IsOpen then
		Stats.End(Instance.StatHandle)
	end

	return Instance.IsOpen
end

function Tree.End()
	local StatHandle = Hierarchy[1].StatHandle
	remove(Hierarchy, 1)
	Stats.End(StatHandle)
end

function Tree.Save(Table)
	if Table ~= nil then
		local Settings = {}
		for K, V in ipairs(Instances) do
			if not V.NoSavedSettings then
				Settings[V.Id] = {
					IsOpen = V.IsOpen
				}
			end
		end
		Table['Tree'] = Settings
	end
end

function Tree.Load(Table)
	if Table ~= nil then
		local Settings = Table['Tree']
		if Settings ~= nil then
			for K, V in pairs(Settings) do
				local Instance = GetInstance(K)
				Instance.IsOpen = V.IsOpen
			end
		end
	end
end

function Tree.GetDebugInfo()
	local Result = {}

	for K, V in pairs(Instances) do
		table.insert(Result, tostring(K))
	end

	return Result
end

return Tree
