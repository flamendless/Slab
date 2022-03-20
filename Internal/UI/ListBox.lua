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

local Cursor = require(SLAB_PATH .. ".Internal.Core.Cursor")
local DrawCommands = require(SLAB_PATH .. ".Internal.Core.DrawCommands")
local LayoutManager = require(SLAB_PATH .. ".Internal.UI.LayoutManager")
local Mouse = require(SLAB_PATH .. ".Internal.Input.Mouse")
local Region = require(SLAB_PATH .. ".Internal.UI.Region")
local Stats = require(SLAB_PATH .. ".Internal.Core.Stats")
local Style = require(SLAB_PATH .. ".Style")
local Utility = require(SLAB_PATH .. ".Internal.Core.Utility")
local Window = require(SLAB_PATH .. ".Internal.UI.Window")

local ListBox = {}
local instances = {}
local active

local function GetItemInstance(instance, id)
	if not instance then return end
	if not instance.Items[id] then
		local item = {
			Id = id,
			X = 0, Y = 0,
			W = 0, H = 0,
		}
		instance.Items[id] = item
	end
	return instance.Items[id]
end

local function GetInstance(id)
	if  instances[id] then return instances[id] end
	local instance = {
		Id = id,
		X = 0, Y = 0,
		W = 0, H = 0,
		Items = {},
		Selected = false
	}
	instances[id] = instance
	return instance
end

local TBL_DEF = {
	W = 150,
	H = 150,
	Clear = false,
	Rounding = Style.WindowRounding,
	StretchW = false,
	StretchH = false,
}
local TBL_IGNORE = {Ignore = true}

function ListBox.Begin(id, opt)
	local stat_handle = Stats.Begin("ListBox", "Slab")
	opt = opt or TBL_DEF
	opt.W = opt.W or TBL_DEF.W
	opt.H = opt.H or TBL_DEF.H
	opt.Clear = opt.Clear or TBL_DEF.Clear
	opt.Rounding = opt.Rounding or TBL_DEF.Rounding
	opt.StretchW = opt.StretchW or TBL_DEF.StretchW
	opt.StretchH = opt.StretchH or TBL_DEF.StretchH

	local instance = GetInstance(Window.GetItemId(id))
	if opt.Clear then
		Utility.ClearTable(instance.Items)
	end
	local w, h = LayoutManager.ComputeSize(opt.W, opt.H)
	LayoutManager.AddControl(w, h, "ListBox")
	local rem_w, rem_h = Window.GetRemainingSize()
	w = opt.StretchW and rem_w or w
	h = opt.StretchH and rem_h or h
	local x, y = Cursor.GetPosition()
	instance.X = x
	instance.Y = y
	instance.W = w
	instance.H = h
	instance.StatHandle = stat_handle
	active = instance
	Cursor.SetItemBounds(x, y, w, h)
	Cursor.AdvanceY(0)
	Window.AddItem(x, y, w, h, instance.Id)
	local is_obstructed = Window.IsObstructedAtMouse()
	local tx, ty = Window.TransformPoint(x, y)
	local mx, my = Window.GetMousePosition()
	Region.Begin(instance.Id, {
		X = x,
		Y = y,
		W = w,
		H = h,
		SX = tx,
		SY = ty,
		AutoSizeContent = true,
		NoBackground = true,
		Intersect = true,
		MouseX = mx,
		MouseY = my,
		ResetContent = Window.HasResized(),
		IsObstructed = is_obstructed,
		Rounding = opt.Rounding
	})
	instance.HotItem = nil
	local in_region = Region.Contains(mx, my)
	mx, my = Region.InverseTransform(instance.Id, mx, my)
	for _, v in pairs(instance.Items) do
		if not is_obstructed
			and not Region.IsHoverScrollBar(instance.Id)
			and v.X <= mx and mx <= v.X + instance.W and v.Y <= my and my <= v.Y + v.H
			and in_region then
			instance.HotItem = v
		end

		if instance.HotItem == v or v.Selected then
			DrawCommands.Rectangle("fill", v.X, v.Y, instance.W, v.H, Style.TextHoverBgColor)
		end
	end

	LayoutManager.Begin("Ignore", TBL_IGNORE)
end

local err_nil_active = "Trying to call BeginListBoxItem outside of BeginListBox."
local err_nil_active_item = "Begin was called for item '%s' without a call to EndListBoxItem"
function ListBox.BeginItem(id, opt)
	assert(active, err_nil_active)
	if not active.ActiveItem then error(format(err_nil_active_item, active.ActiveItem or "nil")) end
	local item = GetItemInstance(active, id)
	item.X = active.X
	item.Y = Cursor.GetY()
	Cursor.SetX(item.X)
	Cursor.AdvanceX(0.0)
	active.ActiveItem = item
	active.ActiveItem.Selected = not not (opt and opt.Selected) --defaulf is false
end

local err_item_clicked = "Trying to call IsItemClicked outside of BeginListBox."
local err_item_clicked2 = "IsItemClicked was called outside of BeginListBoxItem."
function ListBox.IsItemClicked(btn, is_double_clicked)
	assert(active ~= nil, err_item_clicked)
	assert(active.ActiveItem, err_item_clicked2)
	if active.ActiveItem ~= active.ActiveItem then return false end
	btn = btn or 1
	if is_double_clicked then return Mouse.IsDoubleClicked(btn) end
	return Mouse.IsClicked(btn)
end

local err_end = "Trying to call BeginListBoxItem outside of BeginListBox."
local err_end2 = "Trying to call BeginListBoxItem outside of BeginListBox."
function ListBox.EndItem()
	assert(active, err_end)
	assert(active.ActiveItem, err_end2)
	local w = select(3, Cursor.GetItemBounds())
	local item = active.ActiveItem
	item.W = w
	item.H = Cursor.GetLineHeight()
	Cursor.SetY(item.Y + item.H)
	Cursor.AdvanceY(0)
	active.ActiveItem = nil
end

local err_end3 = "EndListBox was called without calling BeginListBox."
function ListBox.End()
	assert(active, err_end3)
	Region.End()
	Region.ApplyScissor()
	Cursor.SetItemBounds(active.X, active.Y, active.W, active.H)
	Cursor.SetPosition(active.X, active.Y)
	Cursor.AdvanceY(active.H)
	LayoutManager.End()
	Stats.End(active.StatHandle)
	active = nil
end

return ListBox
