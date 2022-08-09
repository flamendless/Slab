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
local max = math.max
local insert = table.insert
local remove = table.remove

local Button = require(SLAB_PATH .. ".Internal.UI.Button")
local Cursor = require(SLAB_PATH .. ".Internal.Core.Cursor")
local DrawCommands = require(SLAB_PATH .. ".Internal.Core.DrawCommands")
local Enums = require(SLAB_PATH .. ".Internal.Core.Enums")
local Image = require(SLAB_PATH .. ".Internal.UI.Image")
local LayoutManager = require(SLAB_PATH .. ".Internal.UI.LayoutManager")
local Mouse = require(SLAB_PATH .. ".Internal.Input.Mouse")
local Region = require(SLAB_PATH .. ".Internal.UI.Region")
local Stats = require(SLAB_PATH .. ".Internal.Core.Stats")
local Style = require(SLAB_PATH .. ".Style")
local Text = require(SLAB_PATH .. ".Internal.UI.Text")
local Tooltip = require(SLAB_PATH .. ".Internal.UI.Tooltip")
local Window = require(SLAB_PATH .. ".Internal.UI.Window")

local Tree = {}
local instances = setmetatable({}, {__mode = "k"})
local hierarchy = {}
local radius = 4
local STR_SLAB = "Slab"
local STR_TABLE = "table"

local function GetInstance(id)
	local str_id = type(id) == STR_TABLE and tostring(id) or id
	if #hierarchy > 0 then
		local top = hierarchy[1]
		str_id = top.Id .. "." .. str_id
	end

	if not instances[id] then
		instances[id] = {
			X = 0, Y = 0,
			W = 0, H = 0,
			IsOpen = false,
			WasOpen = false,
			Id = str_id,
			TreeR = 0, TreeB = 0,
			NoSavedSettings = false,
		}
	end
	return instances[id]
end

local IMG_PATH = SLAB_FILE_PATH .. "/Internal/Resources/Textures/Icons.png"
local TBL_NO_COLOR = {0, 0, 0, 0}
local TBL_IGNORE = {Ignore = true}
local TBL_CENTER_Y = {CenterY = true}
local TBL_EMPTY = {}

function Tree.Begin(id, opt)
	opt = opt or TBL_EMPTY
	local stat_handle = Stats.Begin(Enums.widget.tree, STR_SLAB)
	local is_table_id = type(id) == STR_TABLE
	local id_label = is_table_id and tostring(id) or id
	local def_label = opt.Label or id_label
	local def_tooltip = opt.Tooltip or id_label
	local def_open_with_h = (not opt.OpenWithHighlight) and true or opt.OpenWithHighlight
	local def_icon = opt.Icon
	local def_is_sel = not not opt.IsSelected
	local def_no_save = (not opt.NoSavedSettings) and is_table_id or
		(opt.NoSavedSettings and not is_table_id)
	local def_is_leaf = opt.IsLeaf
	local instance
	local win_item_id = Window.GetItemId(id_label)
	instance = is_table_id and GetInstance(id) or GetInstance(win_item_id)
	instance.WasOpen = instance.IsOpen
	instance.StatHandle = stat_handle
	instance.NoSavedSettings = def_no_save

	local mx, my = Mouse.Position()
	local tmx, tmy = Region.InverseTransform(nil, mx, my)
	local wx, _ = Window.GetPosition()
	local ww = Window.GetBorderlessSize()
	local is_obstructed = Window.IsObstructedAtMouse() or Region.IsHoverScrollBar()
	local w = Text.GetWidth(def_label)
	local h = max(Style.Font:getHeight(), instance.H)
	w = (not def_is_leaf) and (w + h + radius) or w

	-- Account for icon if one is requested.
	w = def_icon and w + h or w

	local border = Window.GetBorder()
	wx = wx + border

	if #hierarchy == 0 then
		local cw, ch = w, h
		if instance.TreeR > 0 and instance.TreeB > 0 then
			cw = instance.TreeR - instance.X
			ch = instance.TreeB - instance.Y
		end
		LayoutManager.AddControl(cw, ch, Enums.widget.tree)
		instance.TreeR, instance.TreeB = 0, 0
	end

	local root = instance
	if #hierarchy > 0 then
		root = hierarchy[#hierarchy]
	end

	local x, y = Cursor.GetPosition()
	if root ~= instance then
		x = root.X + h * #hierarchy
		Cursor.SetX(x)
	end
	local is_hot = not is_obstructed and wx <= tmx and tmx <= wx + ww and
		y <= tmy and tmy <= y + h and Region.Contains(mx, my)

	if is_hot or def_is_sel then
		DrawCommands.Rectangle("fill", wx, y, ww, h, Style.TextHoverBgColor)
	end

	if is_hot and Mouse.IsClicked(1) and not def_is_leaf and def_open_with_h then
		instance.IsOpen = not instance.IsOpen
	end

	local is_exp_clicked = false
	if not def_is_leaf then
		-- Render the triangle depending on if the tree item is open/closed.
		local sx = instance.IsOpen and 0 or 200
		local sy = instance.IsOpen and 100 or 50
		local exp_icon_opt = {
			Image = {Path = IMG_PATH, SubX = sx, SubY = sy, SubW = 50, SubH = 50},
			W = h, H = h,
			PadX = 0, PadY = 0,
			Color = TBL_NO_COLOR,
			HoverColor = TBL_NO_COLOR,
			PressColor = TBL_NO_COLOR,
		}

		if Button.Begin(instance.Id .. "_Expand", exp_icon_opt) and
			not def_open_with_h then
			instance.IsOpen = not instance.IsOpen
			Window.SetHotItem()
			is_exp_clicked = true
		end
		Cursor.SameLine()
	else
		-- Advance the cursor for leaf nodes so text aligns with other items that are not leaf nodes.
		Cursor.AdvanceX(h + Cursor.PadX())
	end

	if not instance.IsOpen and instance.WasOpen then
		Window.ResetContentSize()
		Region.ResetContentSize()
	end

	instance.X, instance.Y = x, y
	instance.W, instance.H = w, h
	LayoutManager.Begin("Ignore", TBL_IGNORE)
	local ix, _, iw, ih = Cursor.GetItemBounds()

	if def_icon then
		-- Force the icon to be of the same size as the tree item.
		def_icon.W, def_icon.H = h, h
		Image.Begin(instance.Id .. "_Icon", def_icon)
		instance.H = max(instance.H, ih)
		Cursor.SameLine(TBL_CENTER_Y)
	end

	Text.Begin(def_label)
	LayoutManager.End()
	root.TreeR = max(root.TreeR, ix + iw)
	root.TreeB = max(root.TreeB, y + h)
	Cursor.SetY(instance.Y)
	Cursor.AdvanceY(h)

	if instance.IsOpen then
		insert(hierarchy, 1, instance)
	end

	if is_hot then
		Tooltip.Begin(def_tooltip)
		if not is_exp_clicked then
			Window.SetHotItem(win_item_id)
		end
	end

	-- The size of the item has already been determined by Text.Begin. However, this item"s ID needs to be
	-- set as the last item for hot item checks. So the item will be added with zero width and height.
	Window.AddItem(x, y, 0, 0, win_item_id)
	if not instance.IsOpen then
		Stats.End(instance.StatHandle)
	end
	return instance.IsOpen
end

function Tree.End()
	local stat_handle = hierarchy[1].StatHandle
	remove(hierarchy, 1)
	Stats.End(stat_handle)
end

function Tree.Save(tbl)
	if not tbl then return end
	local settings = {}
	for _, v in ipairs(instances) do
		if not v.NoSavedSettings then
			settings[v.Id] = {IsOpen = v.IsOpen}
		end
	end
	tbl[Enums.widget.tree] = settings
end

function Tree.Load(tbl)
	if not tbl then return end
	local settings = tbl[Enums.widget.tree]
	if not settings then return end
	for k, v in pairs(settings) do
		local instance = GetInstance(k)
		instance.IsOpen = v.IsOpen
	end
end

function Tree.GetDebugInfo()
	local res = {}
	for k in pairs(instances) do
		insert(res, tostring(k))
	end
	return res
end

return Tree
