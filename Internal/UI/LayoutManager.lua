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
local insert = table.insert
local remove = table.remove
local max = math.max
local min = math.min
local format = string.format

local Cursor = require(SLAB_PATH .. ".Internal.Core.Cursor")
local Enums = require(SLAB_PATH .. ".Internal.Core.Enums")
local Utility = require(SLAB_PATH .. ".Internal.Core.Utility")
local Window = require(SLAB_PATH .. ".Internal.UI.Window")

local LayoutManager = {}

local instances, stack = {}, {}
local active

local function GetWindowBounds()
	local wx, wy, ww, wh = Window.GetBounds(true)
	local border = Window.GetBorder()
	wx = wx + border
	wy = wy + border
	ww = ww - border * 2
	wh = wh - border * 2
	return wx, wy, ww, wh
end

local function GetRowSize(instance)
	if not instance then return 0, 0 end
	local col = instance.Columns[instance.ColumnNo]
	if not col then return 0, 0 end
	if not col.Rows then return 0, 0 end
	local row = col.Rows[col.RowNo]
	if not row then return 0, 0 end
	return row.W, row.H
end

local function GetRowCursorPos(instance)
	if not instance then return end
	local col = instance.Columns[instance.ColumnNo]
	if not col then return end
	if not col.Rows then return end
	local row = col.Rows[col.RowNo]
	if not row then return end
	return row.CursorX, row.CursorY
end

local function GetLayoutH(instance, include_pad)
	if not instance then return 0 end
	local col = instance.Columns[instance.ColumnNo]
	if not col then return 0 end
	if not col.Rows then return 0 end
	include_pad = include_pad == nil and true or include_pad
	local h = 0
	for _, v in ipairs(col.Rows) do
		h = h + v.H
		if include_pad then
			h = h + Cursor.PadY()
		end
	end
	return h
end

local function GetPreviousRowBottom(instance)
	if not instance then return end
	local col = instance.Columns[instance.ColumnNo]
	if not col then return end
	if (not col.Rows) or (col.RowNo <= 1) or (col.RowNo > #col.Rows) then
		return
	end
	local row = col.Rows[col.RowNo - 1]
	local y = row.CursorY
	local h = row.H
	return y + h
end

local function GetColumnPosition(instance)
	if not instance then return 0, 0 end
	local wx, wy = GetWindowBounds()
	local wl, wt = Window.GetPosition()
	local total_w = 0
	local pad_x = Cursor.PadX() * 2
	for i = 1, instance.ColumnNo - 1, 1 do
		local col = instance.Columns[i]
		total_w = total_w + col.W + pad_x
	end
	local border = Window.GetBorder()
	local ax, ay = instance.X, instance.Y
	if not instance.AnchorX then
		ax = wx - wl - border
	end
	if not instance.AnchorY then
		ay = wy - wt - border
	end
	return ax + total_w, ay
end

local function GetColumnSize(instance)
	if not instance then return 0, 0 end
	local col = instance.Columns[instance.ColumnNo]
	if not col then return 0, 0 end
	local ww, wh = select(3, GetWindowBounds())
	local count = #instance.Columns
	local col_w = ww/count
	local w, h = col_w, GetLayoutH(instance)
	if not Window.IsAutoSize() then
		h = wh
		col.W = w
	end
	return w, h
end

local function AddControl(instance, w, h, control_type)
	if not instance then return end
	local row_w, row_h = GetRowSize(instance)
	local wx, wy = GetWindowBounds()
	local _, cy = Cursor.GetPosition()
	local x, y = GetRowCursorPos(instance)
	local layout_h = GetLayoutH(instance)
	local prev_row_btn = GetPreviousRowBottom(instance)
	local ax, ay = GetColumnPosition(instance)
	ww, wh = GetColumnSize(instance)
	local col = instance.Columns[instance.ColumnNo]
	if not col then return end
	row_w = row_w == 0 and w or row_w
	row_h = row_h == 0 and h or row_h

	if not x then
		if instance.AlignX == Enums.align_x.center then
			x = max(ww * 0.5 - row_w * 0.5 + ax, ax)
		elseif instance.AlignX == Enums.align_x.right then
			local right = ww - row_w
			if not Window.IsAutoSize() then
				right = right + Window.GetBorder()
			end
			x = max(right, ax)
		else
			x = ax
		end
	end

	if not y then
		if prev_row_btn then
			y = prev_row_btn + Cursor.PadY()
		else
			local region_h = wy + wh - cy
			if instance.AlignY == Enums.align_y.center then
				y = max(region_h * 0.5 - layout_h * 0.5 + ay, ay)
			elseif instance.AlignY == Enums.align_y.bottom then
				y = max(wh - layout_h, ay)
			else
				y = ay
			end
		end
	end

	local border = Window.GetBorder()
	Cursor.SetX(wx + x - border)
	Cursor.SetY(wy + y - border)
	if h < row_h then
		if instance.AlignRowY == Enums.align_y.center then
			Cursor.SetY(wy + y + row_h * 0.5 - h * 0.5)
		elseif instance.AlignRowY == Enums.align_y.bottom then
			Cursor.SetY(wy + y + row_h - h)
		end
	end
	local row_num = col.RowNo
	if col.Rows then
		local row = col.Rows[row_num]
		if row then
			row.CursorX = x + w + Cursor.PadX()
			row.CursorY = y
		end
	end

	if not col.PendingRows[row_num] then
		local row = {
			CursorX = nil,
			CursorY = nil,
			W = 0, H = 0,
			RequestH = 0, MaxH = 0,
			Controls = {}
		}
		insert(col.PendingRows, row)
	end

	local row = col.PendingRows[row_num]
	insert(row.Controls, {
			X = Cursor.GetX(),
			Y = Cursor.GetY(),
			W = w, H = h,
			AlteredSize = col.AlteredSize,
			Type = control_type
	})
	row.W = row.W + w
	row.H = max(row.H, h)
	col.RowNo = row_num + 1
	col.AlteredSize = false
	col.W = max(row.W, col.W)
end

local function GetInstance(id)
	local win_id = Window.GetId()
	local key = win_id .. "." .. id
	if  instances[key] then return instances[key] end
	local instance = {
		Id = id,
		WindowId = win_id,
		AlignX = Enums.align_x.left,
		AlignY = Enums.align_y.top,
		AlignRowY = Enums.align_y.top,
		Ignore = false,
		ExpandW = false, ExpandH = false,
		X = 0, Y = 0,
		Columns = {}, ColumnNo = 1,
	}
	instances[key] = instance
	return instance
end

function LayoutManager.AddControl(w, h, control_type)
	if not active or active.Ignore then return end
	AddControl(active, w, h, control_type)
end

function LayoutManager.ComputeSize(w, h)
	if not active then return w, h end
	local x, y = GetColumnPosition(active)
	local ww, wh = GetColumnSize(active)
	local rw = ww - x
	local rh = wh - y
	local col = active.Columns[active.ColumnNo]
	if not col then return w, h end
	rw = (not active.AnchorX) and ww or rw
	rh = (not active.AnchorY) and rh or rh
	-- Retrieve the calculated row width. This information is stored in the "PendingRows"
	-- field of the active column. This information is updated in the "AddControl" function.
	local row
	local rem_w = ww
	if col.PendingRows then
		row = col.PendingRows[col.RowNo]
		if row then
			rem_w = ww - row.W
		end
	end
	w = min(w, rem_w)
	if Window.IsAutoSize() then
		local layout_h = GetLayoutH(active, false)
		rh = layout_h > 0 and layout_h or rh
	end

	if active.ExpandW and col.Rows then
		local count, reduce_w, pad = 0, 0, 0
		local row = col.Rows[col.RowNo]
		if row then
			for _, v in ipairs(row.Controls) do
				if v.AlteredSize then
					count = count + 1
				else
					reduce_w = reduce_w + v.W
				end
				if #row.Controls > 1 then
					pad = Cursor.PadX() * (#row.Controls - 1)
				end
			end
		end
		count = max(count, 1)
		w = (rw - reduce_w - pad)/count
	end

	if active.ExpandH and col.Rows then
		local count, reduce_h, pad, max_row_h = 0, 0, 0, 0
		for i, subrow in ipairs(row.Rows) do
			local is_size_alt = false
			if i == col.RowNo then
				max_row_h = subrow.MaxH
				subrow.RequestH = max(subrow.RequestH, h)
			end
			for _, control in ipairs(subrow.Controls) do
				if control.AlteredSize and not is_size_alt then
					count = count + 1
					is_size_alt = true
				end
			end
			if not is_size_alt then
				reduce_h = reduce_h + subrow.H
			end
		end

		if #col.Rows > 1 then
			pad = Cursor.PadY() * (#col.Rows - 1)
		end
		count = max(count, 1)
		rh = max(rh - reduce_h - pad, 0)
		h = max(rh/count, h)
		h = max(h, max_row_h)
	end
	col.AlteredSize = active.ExpandH or active.ExpandH
	return w, h
end

local TBL_DEF = {
	AlignX = Enums.align_x.left,
	AlignY = Enums.align_y.top,
	AlignRowY = Enums.align_y.top,
	Ignore = false,
	ExpandW = false, ExpandH = false,
	AnchorX = false, AnchorY = true,
	Columns = {},
	ColumnNo = 1,
}
local err_begin = "A valid string Id must be given to BeginLayout!"
local err_end = "LayoutManager.End was called without a call to LayoutManager.Begin!"

function LayoutManager.Begin(id, opt)
	assert(id or type(id) == "string", err_begin)

	opt = opt or TBL_DEF
	opt.AlignX = opt.AlignX or TBL_DEF.AlignX
	opt.AlignY = opt.AlignY or TBL_DEF.AlignY
	opt.AlignRowY = opt.AlignRowY or TBL_DEF.AlignRowY
	opt.Ignore = opt.Ignore or TBL_DEF.Ignore
	opt.ExpandW = opt.ExpandW or TBL_DEF.ExpandW
	opt.ExpandH = opt.ExpandH or TBL_DEF.ExpandH
	opt.AnchorX = opt.AnchorX or TBL_DEF.AnchorX
	opt.AnchorY = opt.AnchorY or TBL_DEF.AnchorY
	opt.Columns = opt.Columns or TBL_DEF.Columns
	opt.ColumnNo = opt.ColumnNo and max(opt.ColumnNo, 1) or 1

	local instance = GetInstance(id)
	instance.AlignX = opt.AlignX
	instance.AlignY = opt.AlignY
	instance.AlignRowY = opt.AlignRowY
	instance.Ignore = opt.Ignore
	instance.ExpandW = opt.ExpandW
	instance.ExpandH = opt.ExpandH
	instance.X, instance.Y = Cursor.GetRelativePosition()
	instance.AnchorX = opt.AnchorX
	instance.AnchorY = opt.AnchorY

	if opt.Columns ~= #instance.Columns then
		Utility.ClearTable(instance.Columns, ipairs)
		for col in ipairs(opt.Columns) do
			local col = {
				PendingRows = {},
				RowNo = 1, W = 0
			}
			insert(instance.Columns, col)
		end
	end

	for _, col in ipairs(instance.Columns) do
		Utility.ClearTable(col.PendingRows, ipairs)
		col.RowNo = 1
	end
	insert(stack, 1, instance)
	active = instance
end

function LayoutManager.End()
	assert(active, err_end)
	for _, col in ipairs(active.Columns) do
		local rows = col.Rows
		col.Rows = col.PendingRows
		Utility.ClearTable(col.PendingRows, ipairs)
		if rows and col.Rows and #rows == #col.Rows then
			for i, v in ipairs(rows) do
				col.Rows[i].MaxH = rows[i].RequestH
			end
		end
	end
	remove(stack, 1)
	active = stack[1]
end

function LayoutManager.SameLine(opt)
	Cursor.SameLine(opt)
	if not active then return end
	local col = active.Columns[active.ColumnNo]
	col.RowNo = max(col.RowNo - 1, 1)
end

function LayoutManager.NewLine()
	if active then
		AddControl(active, 0, Cursor.GetNewLineSize(), "NewLine")
	end
	Cursor.NewLine()
end

function LayoutManager.SetColumn(index)
	if not active then return end
	index = max(index, 1)
	index = min(index, #active.Columns)
	active.ColumnNo = index
end

function LayoutManager.GetActiveSize()
	if active then return GetColumnSize(active) end
	return select(3, GetWindowBounds())
end

function LayoutManager.GetCurrentColumnIndex()
	if not active then return 0 end
	return active.ColumnNo
end

local str_msg = "The following layouts have not had EndLayout called:\n"
function LayoutManager.Validate()
	local msg
	for _, v in ipairs(stack) do
		if not msg then
			msg = str_msg
		end
		msg = format("%s '%s' in window '%s'\n", msg, v.Id, v.WindowId)
	end
	assert(msg == nil, msg)
end

--[[
	This function will return a map of table names with their debug information.
--]]
function LayoutManager.GetDebugInfo()
	local res = {}
	for k, v in pairs(instances) do
		local info = {}
		insert(info, "X: " .. v.X)
		insert(info, "Y: " .. v.Y)
		insert(info, "AlignX: " .. v.AlignX)
		insert(info, "AlignY: " .. v.AlignY)
		insert(info, "AlignRowY: " .. v.AlignRowY)
		insert(info, "Ignore: " .. tostring(v.Ignore))
		insert(info, "ExpandW: " .. tostring(v.ExpandW))
		insert(info, "ExpandH: " .. tostring(v.ExpandH))
		insert(info, "Columns: " .. #v.Columns)

		for col_n, col in ipairs(v.Columns) do
			insert(info, format("    %d: W: %d Rows: %d",
				col_n, col.W, (col.Rows and #col.Rows or 0)))

			if col.Rows then
				for row_n, row in ipairs(col.Rows) do
					insert(info, format("        %d: W: %d H: %d Controls: %d",
						row_n, row.W, row.H, (row.Controls and #row.Controls or 0)))

					if row.Controls then
						for control_n, control in pairs(row.Controls) do
							insert(info, format("            %d: W: %d H: %d Type: %s",
								control_n, control.W, control.H, tostring(control.Type)))
						end
					end
				end
			end
		end

		res[k] = info
	end
	return res
end

return LayoutManager
