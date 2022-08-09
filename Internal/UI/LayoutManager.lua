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

local insert = table.insert
local remove = table.remove
local max = math.max
local min = math.min
local format = string.format

local Cursor = require(SLAB_PATH .. ".Internal.Core.Cursor")
local Enums = require(SLAB_PATH .. ".Internal.Core.Enums")
local Window = require(SLAB_PATH .. ".Internal.UI.Window")

local LayoutManager = {}

local instances, stack = {}, {}
local active

local TBL_EMPTY = {}
local STR_ASSERT_BEGIN = "A valid string Id must be given to BeginLayout!"
local STR_ASSERT_END = "LayoutManager.End was called without a call to LayoutManager.Begin!"
local STR_MSG = "The following layouts have not had EndLayout called:\n"

local function GetWindowBounds()
	local wx, wy, ww, wh = Window.GetBounds(true)
	local border = Window.GetBorder()
	local border2 = border * 2
	wx = wx + border
	wy = wy + border
	ww = ww - border2
	wh = wh - border2
	return wx, wy, ww, wh
end

local function GetRowSize(instance)
	if not instance then return 0, 0 end
	local col = instance.Columns[instance.ColumnNo]
	if col.Rows then
		local row = col.Rows[col.RowNo]
		if row then
			return row.W, row.H
		end
	end
	return 0, 0
end

local function GetRowCursorPos(instance)
	if not instance then return end
	local col = instance.Columns[instance.ColumnNo]
	if col.Rows then
		local row = col.Rows[col.RowNo]
		if row then
			return row.CursorX, row.CursorY
		end
	end
	return nil, nil
end

local function GetLayoutH(instance, include_pad)
	if not instance then return 0 end
	include_pad = include_pad == nil and true or include_pad
	local col = instance.Columns[instance.ColumnNo]
	if col.Rows then
		local h = 0
		for _, v in ipairs(col.Rows) do
			h = h + v.H
			if include_pad then
				h = h + Cursor.PadY()
			end
		end
		return h
	end
	return 0
end

local function GetPreviousRowBottom(instance)
	if not instance then return end
	local col = instance.Columns[instance.ColumnNo]
	if col.Rows and col.RowNo > 1 and col.RowNo <= #col.Rows then
		local row = col.Rows[col.RowNo - 1]
		return row.CursorY + row.H
	end
	return nil
end

local function GetColumnPosition(instance)
	if not instance then return 0, 0 end
	local wx, wy = GetWindowBounds()
	local wl, wt = Window.GetPosition()
	local total_w = 0
	local cx2 = Cursor.PadX() * 2
	for i = 1, instance.ColumnNo - 1 do
		local col = instance.Columns[i]
		total_w = total_w + col.W + cx2
	end
	local ax, ay = instance.X, instance.Y
	local border = Window.GetBorder()
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
	local _, _, ww, wh = GetWindowBounds()
	local count = #instance.Columns
	local cw = ww/count
	local w, h = cw, GetLayoutH(instance)
	if not Window.IsAutoSize() then
		h = wh
		col.W = w
	end
	return w, h
end

local function AddControl(instance, w, h, control_type)
	if not instance then return end
	local row_w, row_h = GetRowSize(instance)
	row_w = row_w == 0 and w or row_w
	row_h = row_h == 0 and h or row_h
	local wx, wy, ww, wh = GetWindowBounds()
	local _, cy = Cursor.GetPosition()
	local x, y = GetRowCursorPos(instance)
	local layout_h = GetLayoutH(instance)
	local prev_row_btn = GetPreviousRowBottom(instance)
	local ax, ay = GetColumnPosition(instance)
	ww, wh = GetColumnSize(instance)
	local col = instance.Columns[instance.ColumnNo]

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
		local new_row = {
			W = 0, H = 0,
			RequestH = 0, MaxH = 0,
			Controls = {}
		}
		insert(col.PendingRows, new_row)
	end

	local pending_row = col.PendingRows[row_num]
	insert(pending_row.Controls, {
		X = Cursor.GetX(), Y = Cursor.GetY(),
		W = w, H = h,
		AlteredSize = col.AlteredSize,
		Type = control_type
	})
	pending_row.W = pending_row.W + w
	pending_row.H = max(pending_row.H, h)
	col.RowNo = row_num + 1
	col.AlteredSize = false
	col.W = max(pending_row.W, col.W)
end

local function GetInstance(id)
	local win_id = Window.GetId()
	local key = format("%s.%s", win_id, id)
	if instances[key] then return instances[key] end
	local instance = {
		Id = id,
		WindowId = win_id,
		AlignX = Enums.align_x.left,
		AlignY = Enums.align_y.top,
		AlignRowY = Enums.align_y.top,
		Ignore = false, ExpandW = false, ExpandH = false,
		X = 0, Y = 0,
		Columns = {}, ColumnNo = 1,
	}
	instances[key] = instance
	return instance
end

function LayoutManager.AddControl(w, h, control_type)
	if (not active) or active.Ignore then return end
	AddControl(active, w, h, control_type)
end

function LayoutManager.ComputeSize(w, h)
	if not active then return w, h end
	local x, y = GetColumnPosition(active)
	local ww, wh = GetColumnSize(active)
	local rw, rh = ww - x, wh - y
	local col = active.Columns[active.ColumnNo]
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
		if layout_h > 0 then
			rh = layout_h
		end
	end

	if active.ExpandW and col.Rows then
		local count, reduce_w, pad = 0, 0, 0
		local row2 = col.Rows[col.RowNo]
		if row2 then
			for _, v in ipairs(row2.Controls) do
				if v.AlteredSize then
					count = count + 1
				else
					reduce_w = reduce_w + v.W
				end
				if #row2.Controls > 1 then
					pad = Cursor.PadX() * (#row2.Controls - 1)
				end
			end
		end
		count = max(count, 1)
		w = (rw - reduce_w - pad)/count
	end

	if active.ExpandH and col.Rows then
		local count, reduce_h, pad, max_row_h = 0, 0, 0, 0
		for i, subrow in ipairs(col.Rows) do
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

function LayoutManager.Begin(id, opt)
	assert(id or type(id) == "string", STR_ASSERT_BEGIN)
	opt = opt or TBL_EMPTY
	local def_align_x = opt.AlignX or Enums.align_x.left
	local def_align_y = opt.AlignY or Enums.align_y.top
	local def_align_row_y = opt.AlignRowY or Enums.align_y.top
	local def_ignore = not not opt.Ignore --default is false
	local def_expand_w = not not opt.ExpandW
	local def_expand_h = not not opt.ExpandH
	local def_ax = not not opt.AnchorX
	local def_ay = opt.AnchorY or true
	local def_columns = opt.Columns or 1
	def_columns = max(def_columns, 1)

	local instance = GetInstance(id)
	instance.AlignX = def_align_x
	instance.AlignY = def_align_y
	instance.AlignRowY = def_align_row_y
	instance.Ignore = def_ignore
	instance.ExpandW = def_expand_w
	instance.ExpandH = def_expand_h
	instance.X, instance.Y = Cursor.GetRelativePosition()
	instance.AnchorX = def_ax
	instance.AnchorY = def_ay

	if def_columns ~= #instance.Columns then
		instance.Columns = {}
		for _ = 1, def_columns do
			local col = {
				PendingRows = {},
				RowNo = 1, W = 0
			}
			insert(instance.Columns, col)
		end
	end

	for _, col in ipairs(instance.Columns) do
		col.PendingRows = {}
		col.RowNo = 1
	end
	insert(stack, 1, instance)
	active = instance
end

function LayoutManager.End()
	assert(active, STR_ASSERT_END)
	for _, col in ipairs(active.Columns) do
		local rows = col.Rows
		col.Rows = col.PendingRows
		col.PendingRows = nil
		if rows and col.Rows and #rows == #col.Rows then
			for i in ipairs(rows) do
				col.Rows[i].MaxH = rows[i].RequestH
			end
		end
	end
	remove(stack, 1)
	active = nil
	if #stack > 0 then
		active = stack[1]
	end
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

function LayoutManager.Validate()
	local msg
	for _, v in ipairs(stack) do
		if not msg then
			msg = STR_MSG
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
