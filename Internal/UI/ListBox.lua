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

local Cursor = require(SLAB_PATH .. '.Internal.Core.Cursor')
local DrawCommands = require(SLAB_PATH .. '.Internal.Core.DrawCommands')
local LayoutManager = require(SLAB_PATH .. '.Internal.UI.LayoutManager')
local Mouse = require(SLAB_PATH .. '.Internal.Input.Mouse')
local Region = require(SLAB_PATH .. '.Internal.UI.Region')
local Stats = require(SLAB_PATH .. '.Internal.Core.Stats')
local Style = require(SLAB_PATH .. '.Style')
local Text = require(SLAB_PATH .. '.Internal.UI.Text')
local Window = require(SLAB_PATH .. '.Internal.UI.Window')

local ListBox = {}
local Instances = {}
local ActiveInstance = nil

local function GetItemInstance(Instance, Id)
	if Instance ~= nil then
		if Instance.Items[Id] == nil then
			local Item = {}
			Item.Id = Id
			Item.X = 0.0
			Item.Y = 0.0
			Item.W = 0.0
			Item.H = 0.0
			Instance.Items[Id] = Item
		end
		return Instance.Items[Id]
	end
	return nil
end

local function GetInstance(Id)
	if Instances[Id] == nil then
		local Instance = {}
		Instance.Id = Id
		Instance.X = 0.0
		Instance.Y = 0.0
		Instance.W = 0.0
		Instance.H = 0.0
		Instance.Items = {}
		Instance.ActiveItem = nil
		Instance.HotItem = nil
		Instance.Selected = false
		Instance.StatHandle = nil
		Instances[Id] = Instance
	end
	return Instances[Id]
end

function ListBox.Begin(Id, Options)
	local StatHandle = Stats.Begin('ListBox', 'Slab')

	Options = Options == nil and {} or Options
	Options.W = Options.W == nil and 150.0 or Options.W
	Options.H = Options.H == nil and 150.0 or Options.H
	Options.Clear = Options.Clear == nil and false or Options.Clear
	Options.Rounding = Options.Rounding == nil and Style.WindowRounding or Options.Rounding

	local Instance = GetInstance(Window.GetItemId(Id))
	local W = Options.W
	local H = Options.H

	if Options.Clear then
		Instance.Items = {}
	end

	W, H = LayoutManager.ComputeSize(W, H)
	LayoutManager.AddControl(W, H)

	local X, Y = Cursor.GetPosition()
	Instance.X = X
	Instance.Y = Y
	Instance.W = W
	Instance.H = H
	Instance.StatHandle = StatHandle
	ActiveInstance = Instance

	Cursor.SetItemBounds(X, Y, W, H)
	Cursor.AdvanceY(0.0)

	Window.AddItem(X, Y, W, H, Instance.Id)

	local IsObstructed = Window.IsObstructedAtMouse()

	local TX, TY = Window.TransformPoint(X, Y)
	local MouseX, MouseY = Window.GetMousePosition()
	Region.Begin(Instance.Id, {
		X = X,
		Y = Y,
		W = W,
		H = H,
		SX = TX,
		SY = TY,
		AutoSizeContent = true,
		NoBackground = true,
		Intersect = true,
		MouseX = MouseX,
		MouseY = MouseY,
		ResetContent = Window.HasResized(),
		IsObstructed = IsObstructed,
		Rounding = Options.Rounding
	})

	Instance.HotItem = nil
	local InRegion = Region.Contains(MouseX, MouseY)
	MouseX, MouseY = Region.InverseTransform(Instance.Id, MouseX, MouseY)
	for K, V in pairs(Instance.Items) do
		if not IsObstructed
			and not Region.IsHoverScrollBar(Instance.Id)
			and V.X <= MouseX and MouseX <= V.X + Instance.W and V.Y <= MouseY and MouseY <= V.Y + V.H
			and InRegion
			then
			Instance.HotItem = V
		end

		if Instance.HotItem == V or V.Selected then
			DrawCommands.Rectangle('fill', V.X, V.Y, Instance.W, V.H, Style.TextHoverBgColor)
		end
	end

	LayoutManager.Begin('Ignore', {Ignore = true})
end

function ListBox.BeginItem(Id, Options)
	Options = Options == nil and {} or Options
	Options.Selected = Options.Selected == nil and false or Options.Selected

	assert(ActiveInstance ~= nil, "Trying to call BeginListBoxItem outside of BeginListBox.")
	assert(ActiveInstance.ActiveItem == nil, 
		"BeginListBoxItem was called for item '" .. (ActiveInstance.ActiveItem ~= nil and ActiveInstance.ActiveItem.Id or "nil") .. 
			"' without a call to EndListBoxItem.")
	local Item = GetItemInstance(ActiveInstance, Id)
	Item.X = ActiveInstance.X
	Item.Y = Cursor.GetY()
	Cursor.SetX(Item.X)
	Cursor.AdvanceX(0.0)
	ActiveInstance.ActiveItem = Item
	ActiveInstance.ActiveItem.Selected = Options.Selected
end

function ListBox.IsItemClicked(Button, IsDoubleClick)
	assert(ActiveInstance ~= nil, "Trying to call IsItemClicked outside of BeginListBox.")
	assert(ActiveInstance.ActiveItem ~= nil, "IsItemClicked was called outside of BeginListBoxItem.")
	if ActiveInstance.HotItem == ActiveInstance.ActiveItem then
		Button = Button == nil and 1 or Button
		if IsDoubleClick then
			return Mouse.IsDoubleClicked(Button)
		else
			return Mouse.IsClicked(Button)
		end
	end
	return false
end

function ListBox.EndItem()
	assert(ActiveInstance ~= nil, "Trying to call BeginListBoxItem outside of BeginListBox.")
	assert(ActiveInstance.ActiveItem ~= nil, "Trying to call EndListBoxItem without calling BeginListBoxItem.")
	local ItemX, ItemY, ItemW, ItemH = Cursor.GetItemBounds()
	ActiveInstance.ActiveItem.W = ItemW
	ActiveInstance.ActiveItem.H = Cursor.GetLineHeight()
	Cursor.SetY(ActiveInstance.ActiveItem.Y + ActiveInstance.ActiveItem.H)
	Cursor.AdvanceY(0.0)
	ActiveInstance.ActiveItem = nil
end

function ListBox.End()
	assert(ActiveInstance ~= nil, "EndListBox was called without calling BeginListBox.")
	Region.End()
	Region.ApplyScissor()

	Cursor.SetItemBounds(ActiveInstance.X, ActiveInstance.Y, ActiveInstance.W, ActiveInstance.H)
	Cursor.SetPosition(ActiveInstance.X, ActiveInstance.Y)
	Cursor.AdvanceY(ActiveInstance.H)

	LayoutManager.End()

	Stats.End(ActiveInstance.StatHandle)

	ActiveInstance = nil
end

return ListBox
