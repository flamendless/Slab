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
local EMPTY = {}
local IGNORE = { Ignore = true }

local function GetItemInstance(instance, id)
	if not instance then
		return
	end

	if instance.Items[id] == nil then
		instance.Items[id] = {
			Id = id,
			X = 0,
			Y = 0,
			W = 0,
			H = 0,
		}
	end
	return instance.Items[id]
end

local function GetInstance(id)
	if Instances[id] == nil then
		Instances[id] = {
			Id = id,
			X = 0,
			Y = 0,
			W = 0,
			H = 0,
			Items = {},
			ActiveItem = nil,
			HotItem = nil,
			Selected = false,
			StatHandle = nil,
			Region = {
				AutoSizeContent = true,
				Intersect = true,
			},
		}
	end
	return Instances[id]
end

function ListBox.Begin(id, options)
	local statHandle = Stats.Begin('ListBox', 'Slab')

	options = options or EMPTY
	local w = options.W or 150
	local h = options.H or 150
	local rounding = options.Rounding or Style.WindowRounding
	local bgColor = options.BgColor or Style.ListBoxBgColor

	local instance = GetInstance(Window.GetItemId(id))

	if options.Clear then
		for i = 1, #instance.Items do
			instance.Items[i] = nil
		end
	end

	w, h = LayoutManager.ComputeSize(w, h)
	LayoutManager.AddControl(w, h, 'ListBox')

	do
		local remainingW, remainingH = Window.GetRemainingSize()
		if options.StretchW then
			w = remainingW
		end

		if options.StretchH then
			h = remainingH
		end
	end

	local x, y = Cursor.GetPosition()
	instance.X = x
	instance.Y = y
	instance.W = w
	instance.H = h
	instance.StatHandle = statHandle
	ActiveInstance = instance

	Cursor.SetItemBounds(x, y, w, h)
	Cursor.AdvanceY(0)

	Window.AddItem(x, y, w, h, instance.Id)

	local isObstructed = Window.IsObstructedAtMouse()

	local mouseX, mouseY = Window.GetMousePosition()
	do
		local tx, ty = Window.TransformPoint(x, y)
		local region = instance.Region
		region.X = x
		region.Y = y
		region.W = w
		region.H = h
		region.SX = tx
		region.SY = ty
		region.BgColor = bgColor
		region.MouseX = mouseX
		region.MouseY = mouseY
		region.ResetContent = Window.HasResized()
		region.IsObstructed = isObstructed
		region.Rounding = rounding
		Region.Begin(instance.Id, region)
	end

	instance.HotItem = nil
	mouseX, mouseY = Region.InverseTransform(instance.Id, mouseX, mouseY)
	for k, v in pairs(instance.Items) do
		if not isObstructed
			and not Region.IsHoverScrollBar(instance.Id)
			and v.X <= mouseX and mouseX <= v.X + instance.W and v.Y <= mouseY and mouseY <= v.Y + v.H
			and Region.Contains(mouseX, mouseY)
			then
			instance.HotItem = v
		end

		if instance.HotItem == v or v.Selected then
			DrawCommands.Rectangle('fill', v.X, v.Y, instance.W, v.H, Style.TextHoverBgColor)
		end
	end

	LayoutManager.Begin('Ignore', IGNORE)
end

function ListBox.BeginItem(id, options)
	options = options or EMPTY

	assert(ActiveInstance ~= nil, "Trying to call BeginListBoxItem outside of BeginListBox.")
	if ActiveInstance.ActiveItem ~= nil then
		error(("BeginListBoxItem was called for item '%s' without a call to EndListBoxItem."):format(
			ActiveInstance.ActiveItem.Id or "nil"
		))
	end
	local item = GetItemInstance(ActiveInstance, id)
	item.X = ActiveInstance.X
	item.Y = Cursor.GetY()
	Cursor.SetX(item.X)
	Cursor.AdvanceX(0)
	ActiveInstance.ActiveItem = item
	ActiveInstance.ActiveItem.Selected = options.Selected
end

function ListBox.IsItemClicked(button, isDoubleClick)
	assert(ActiveInstance ~= nil, "Trying to call IsItemClicked outside of BeginListBox.")
	assert(ActiveInstance.ActiveItem ~= nil, "IsItemClicked was called outside of BeginListBoxItem.")
	if ActiveInstance.HotItem ~= ActiveInstance.ActiveItem then
		return false
	end

	button = button or 1
	if isDoubleClick then
		return Mouse.IsDoubleClicked(button)
	else
		return Mouse.IsClicked(button)
	end
end

function ListBox.EndItem()
	assert(ActiveInstance ~= nil, "Trying to call BeginListBoxItem outside of BeginListBox.")
	assert(ActiveInstance.ActiveItem ~= nil, "Trying to call EndListBoxItem without calling BeginListBoxItem.")
	local itemX, itemY, itemW, itemH = Cursor.GetItemBounds()
	ActiveInstance.ActiveItem.W = itemW
	ActiveInstance.ActiveItem.H = Cursor.GetLineHeight()
	Cursor.SetY(ActiveInstance.ActiveItem.Y + ActiveInstance.ActiveItem.H)
	Cursor.AdvanceY(0)
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
