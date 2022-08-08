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
local UTF8 = require("utf8")

local abs = math.abs
local insert = table.insert
local min = math.min
local max = math.max
local floor = math.floor
local huge = math.huge
local gsub = string.gsub
local sub = string.sub
local match = string.match
local byte = string.byte
local find = string.find
local format = string.format
local rep = string.rep

local Cursor = require(SLAB_PATH .. ".Internal.Core.Cursor")
local DrawCommands = require(SLAB_PATH .. ".Internal.Core.DrawCommands")
local Enums = require(SLAB_PATH .. ".Internal.Core.Enums")
local FileSystem = require(SLAB_PATH .. ".Internal.Core.FileSystem")
local Keyboard = require(SLAB_PATH .. ".Internal.Input.Keyboard")
local LayoutManager = require(SLAB_PATH .. ".Internal.UI.LayoutManager")
local Mouse = require(SLAB_PATH .. ".Internal.Input.Mouse")
local Region = require(SLAB_PATH .. ".Internal.UI.Region")
local Stats = require(SLAB_PATH .. ".Internal.Core.Stats")
local Style = require(SLAB_PATH .. ".Style")
local Text = require(SLAB_PATH .. ".Internal.UI.Text")
local Tooltip = require(SLAB_PATH .. ".Internal.UI.Tooltip")
local Utility = require(SLAB_PATH .. ".Internal.Core.Utility")
local Window = require(SLAB_PATH .. ".Internal.UI.Window")

local Input = {}

local instances = {}
local focused, last_focused
local tc_pos, tc_pos_line, tc_pos_line_max = 0, 0, 0
local tc_pos_line_n = 1
local tc_anchor, tc_alpha = -1, 0
local fade_in, drag_select, focus_to_next = true, false, false
local last_text = ""
local pad = Region.GetScrollPad() + Region.GetScrollBarSize()
local pending_focus
local pc_pos, pc_col, pc_line = -1, -1, -1
local is_sliding = false
local drag_dt = 0
local MIN_WIDTH = 150
local DEF_PW_CHAR = "*"
local STR_0, STR_DOT = "0", "."
local TBL_TEXT = {AddItem = false, Color = nil}

local function SanitizeText(data)
	if not data then return nil, false end
	local count
	data, count = gsub(data, "\r", "")
	return data, count > 0
end

local function GetDisplayCharacter(data, pos)
	local res = ""
	if data and pos > 0 and pos < #data then
		local offset = UTF8.offset(data, -1, pos + 1)
		res = sub(data, offset, pos)
		res = not res and "nil" or res
	end
	if res == "\n" then
		res = "\\n"
	end
	return res
end

local STR_REG = "[%z\1-\127\194-\244%s\n][\128-\191]*"

local function GetCharacter(data, index, forward)
	local res
	if forward then
		local str_sub = sub(data, index + 1)
		res = match(str_sub, STR_REG)
	else
		local str_sub = sub(data, 1, index)
		res = match(str_sub, STR_REG)
	end
	return res
end

local function UpdateMultiLinePosition(instance)
	if not instance then return end
	if instance.Lines then
		local count, start, found = 0, 0, false
		for i, v in ipairs(instance.Lines) do
			local length = #v
			count = count + length
			if tc_pos < count then
				tc_pos_line = tc_pos - start
				tc_pos_line = i
				found = true
				break
			end
			start = start + length
		end

		if not found then
			tc_pos_line = #instance.Lines[#instance.Lines]
			tc_pos_line_n = #instance.Lines
		end
	else
		tc_pos_line = tc_pos
		tc_pos_line_n = 1
	end
	tc_pos_line_max = tc_pos_line
end

local MIN_B, MAX_B = 127, 191
local function ValidateTextCursorPos(instance)
	if not instance then return end
	local old = tc_pos
	local b = byte(sub(instance.Text, tc_pos, tc_pos))
	-- This is a continuation byte. Check next byte to see if it is an ASCII character or
	-- the beginning of a UTF8 character.
	if not (byte and byte > MIN_B) then return end
	local next_b = byte(sub(instance.Text, tc_pos + 1, tc_pos + 1))
	if not (next_b and next_b > MIN_B and next_b < MAX_B) then return end

	while byte > MIN_B and byte < MAX_B do
		tc_pos = tc_pos - 1
		b = byte(sub(instance.Text, tc_pos, tc_pos))
	end

	if tc_pos < old or b >= MAX_B then
		tc_pos = tc_pos - 1
		UpdateMultiLinePosition(instance)
	end
end

local function MoveToHome(instance)
	if not instance then return end
	if instance.Lines and tc_pos_line_n > 1 then
		tc_pos_line = 0
		local count, start = 0, 0
		for i, v in ipairs(instance.Lines) do
			local len_v = #v
			count = count + len_v
			if i == tc_pos_line_n then
				tc_pos = start
				break
			end
			start = start + len_v
		end
	else
		tc_pos = 0
	end
	UpdateMultiLinePosition(instance)
end

local function MoveToEnd(instance)
	if not instance then return end
	if instance.Lines then
		local count = 0
		for i, v in ipairs(instance.Lines) do
			local len_v = #v
			count = count + len_v
			if i == tc_pos_line_n then
				tc_pos = count - 1
				if i == #instance.Lines then
					tc_pos = count
				end
				break
			end
		end
	else
		tc_pos = #instance.Text
	end
	UpdateMultiLinePosition(instance)
end

local STR_EMPTY = ""
local function ValidateNumber(instance)
	if not (instance and instance.NumbersOnly and instance.Text ~= STR_EMPTY) then
		return false
	end
	local len_text = #instance.Text
	if sub(instance.Text, len_text, len_text) == "." then return end
	local v = tonumber(instance.Text) or 0
	local old = v
	if instance.MinNumber then
		v = max(v, instance.MinNumber)
	end
	if instance.MaxNumber then
		v = min(v, instance.MaxNumber)
	end
	instance.Text = tostring(v)
	return old ~= v
end

local function GetAlignmentOffset(instance)
	local offset = 6
	if not instance then return offset end
	if instance.Align == "center" then
		local tw = Text.GetWidth(instance.Text)
		offset = (instance.W * 0.5) - (tw * 0.5)
	end
	return offset
end

local function GetSelection(instance)
	if not (instance and tc_anchor >= 0 and tc_anchor ~= tc_pos) then return STR_EMPTY end
	local v_min = min(tc_anchor, tc_pos) + 1
	local v_max = max(tc_anchor, tc_pos)
	return sub(instance.Text, v_min, v_max)
end

local function MoveCursorVertical(instance, move_down)
	if not (instance and instance.Lines) then return end
	local old_ln = tc_pos_line_n
	if move_down then
		tc_pos_line_n = min(tc_pos_line_n + 1, #instance.Lines)
	else
		tc_pos_line_n = max(1, tc_pos_line_n - 1)
	end
	local line = instance.Lines[tc_pos_line_n]
	if old_ln == tc_pos_line_n then
		tc_pos_line = move_down and #line or 0
	else
		local len_line = #line
		if tc_pos_line_n == #instance.Lines and tc_pos_line >= len_line then
			tc_pos_line = len_line
		else
			tc_pos_line = min(len_line, tc_pos_line_max + 1)
			local ch = GetCharacter(line, tc_pos_line)
			if ch then
				tc_pos_line = tc_pos_line - #ch
			end
		end
	end

	local start = 0
	for i, v in ipairs(instance.Lines) do
		if i == tc_pos_line_n then
			tc_pos = start + tc_pos_line
			break
		end
		start = start + #v
	end
end

local function IsValidDigit(instance, ch)
	if not instance then return false end
	if not instance.NumbersOnly then return true end
	if match(ch, "%d") then return true end
	if ch == "-" and tc_anchor == 0 or tc_pos == 0 or #instance.Text == 0 then
		return true
	end
	if ch == "." then
		local selected = GetSelection(instance)
		if selected and find(selected, ".", 1, true) then
			return true
		end
		if not find(instance.Text, ".", 1, true) then
			return true
		end
	end
	return false
end

local function IsCommandKeyDown()
	local lkey, rkey
	if Utility.IsOSX() then
		lkey, rkey = "lgui", "rgui"
	else
		lkey, rkey = "lctrl", "rctrl"
	end
	return Keyboard.IsDown(lkey) or Keyboard.IsDown(rkey)
end

local function IsHomePressed()
	if Utility.IsOSX() then
		return IsCommandKeyDown() and Keyboard.IsPressed("left")
	else
		return Keyboard.IsPressed("home")
	end
end

local function IsEndPressed()
	if Utility.IsOSX() then
		return IsCommandKeyDown() and Keyboard.IsPressed("right")
	else
		return Keyboard.IsPressed("end")
	end
end

local function IsNextSpaceDown()
	if Utility.IsOSX() then
		return Keyboard.IsDown("lalt") or Keyboard.IsDown("ralt")
	else
		return Keyboard.IsDown("lctrl") or Keyboard.IsDown("rctrl")
	end
end

local function GetCursorPos(instance)
	local x, y = GetAlignmentOffset(instance), 0
	if not instance then return x, y end
	local data = instance.Text
	if instance.Lines then
		data = instance.Lines[tc_pos_line_n]
		y = Text.GetHeight() * (tc_pos_line_n - 1)
	end
	local cpos = min(tc_pos_line, #data)
	if cpos > 0 then
		local str_sub = sub(data, 0, cpos)
		x = x + Text.GetWidth(str_sub)
	end
	return x, y
end

local STR_FILTER = "%s"
local STR_SPACE = " "

local function SelectWord(instance)
	if not instance then return end
	local filter = STR_FILTER
	if GetCharacter(instance.Text, tc_pos) == STR_SPACE then
		if GetCharacter(instance.Text, tc_pos + 1) == STR_SPACE then
			filter = "%S"
		else
			tc_pos = tc_pos + 1
		end
	end
	tc_anchor = 0
	local i = 0
	while i and i + 1 < tc_pos do
		i = find(instance.Text, filter, i + 1)
		if i and i < tc_pos then
			tc_anchor = i
		else
			break
		end
	end
	i = find(instance.Text, filter, tc_pos + 1)
	if i then
		tc_pos = i - 1
	else
		tc_pos = #instance.Text
	end
	UpdateMultiLinePosition(instance)
end

local function GetNextCursorPos(instance, left)
	if not instance then return 0 end
	local res = 0
	local next_space = IsNextSpaceDown()
	if next_space then
		if left then
			res = 0
			local i = 0
			while i and i + 1 < tc_pos do
				i = find(instance.Text, STR_FILTER, i + 1)
				if i and i < tc_anchor then
					res = i
				else
					break
				end
			end
		else
			local i = find(instance.text, STR_FILTER, tc_pos + 1)
			res = i or #instance.Text
		end
	else
		if left then
			local ch = GetCharacter(instance.text, tc_pos)
			res = (ch and tc_pos - #ch) or res
		else
			local ch = GetCharacter(instance.Text, tc_pos, true)
			res = (ch and tc_pos + #ch) or tc_pos
		end
	end
	res = max(0, res)
	res = min(res, #instance.Text)
	return res
end

local function GetCursorPosLine(instance, line, x)
	local res = 0
	if not (instance and line ~= STR_EMPTY) then return res end
	if Text.GetWidth(line) < x then
		res = #line
		if find(line, "\n") then
			res = #line + 1
		end
	else
		x = x - GetAlignmentOffset(instance)
		local index, str_sub = 0, STR_EMPTY
		while index <= #line do
			local ch = GetCharacter(line, index, true)
			if not ch then break end
			index = index + #ch
			str_sub = str_sub .. ch
			local px = Text.GetWidth(str_sub)
			if px > x then
				local cx = px - x
				local cw = Text.GetWidth(ch)
				if cx < cw * 0.65 then
					res = res + #ch
				end
				break
			end
			res = index
		end
	end
	return res
end

local function GetTextCursorPos(instance, x, y)
	if not instance then return 0 end
	local line = instance.Text
	local start = 0
	if instance.Lines and #instance.Lines > 0 then
		local h = Text.GetHeight()
		local found = false
		for _, v in ipairs(instance.Lines) do
			if y <= h then
				line = v
				found = true
				break
			end
			h = h + Text.GetHeight()
			start = start + #v
		end

		if not found then
			line = instance.Lines[#instance.Lines]
		end
	end
	return min(start + GetCursorPosLine(instance, line, x), #instance.Text)
end

local function MoveCursorPage(instance, page_down)
	if not instance then return end
	local page_h = instance.H - Text.GetHeight()
	local page_y = page_down and page_h or 0
	local _, ty = Region.InverseTransform(instance.Id, 0, page_y)
	local next_y = page_down and (ty + page_h) or max(ty - page_h, 0)
	tc_pos = GetTextCursorPos(instance, 0, next_y)
	UpdateMultiLinePosition(instance)
end

local function UpdateTransform(instance)
	if not instance then return end
	local x, y = GetCursorPos(instance)
	local tx, ty = Region.InverseTransform(instance.Id, 0, 0)
	local w = tx + instance.W - Region.GetScrollPad() - Region.GetScrollBarSize()
	local h = ty + instance.H

	if instance.H > Text.GetHeight() then
		h = h - Region.GetScrollPad() - Region.GetScrollBarSize()
	end
	local new_x = 0
	if tc_pos_line == 0 then
		new_x = tx
	elseif x > w then
		new_x = -(x - w)
	elseif x < tx then
		new_x = tx - x
	end

	local new_y = 0
	if tc_pos_line == 1 then
		new_y = ty
	elseif y > h then
		new_y = -(y - h)
	elseif y < ty then
		new_y = ty - y
	end
	Region.Translate(instance.Id, new_x, new_y)
end

local function DeleteSelection(instance)
	if not (instance and instance.Text ~= STR_EMPTY and not instance.ReadOnly) then
		return
	end
	local v_min, v_max = 0, 0

	if tc_pos == 0 then
		return false
	elseif tc_anchor ~= -1 then
		v_min = min(tc_anchor, tc_pos)
		v_max = max(tc_anchor, tc_pos) + 1
	else
		local new_tc_pos = tc_pos
		local ch = GetCharacter(instance.Text, tc_pos)
		if ch then
			v_min = tc_pos - #ch
			new_tc_pos = v_min
		end

		ch = GetCharacter(instance.Text, tc_pos, true)
		v_max = ch and (tc_pos + 1) or (#instance.Text + 1)
		tc_pos = new_tc_pos
	end

	local left = sub(instance.Text, 1, v_min)
	local right = sub(instance.Text, v_max)
	instance.Text = left .. right
	tc_pos = #left
	tc_pos = tc_anchor ~= -1 and min(tc_anchor, tc_pos) or tc_pos
	tc_pos = max(0, tc_pos)
	tc_pos = min(tc_pos, #instance.Text)
	tc_anchor = -1
	UpdateMultiLinePosition(instance)
	return true
end

local function DrawSelection(instance, x, y, w, _, color)
	if not (instance and tc_anchor >= 0 and tc_anchor ~= tc_pos) then return end
	local v_min = min(tc_anchor, tc_pos)
	local v_max = max(tc_anchor, tc_pos)
	local h = Text.GetHeight()
	if instance.Lines then
		local count, start = 0, 0
		local offset_min, offset_max
		local offset_y = 0
		for _, v in ipairs(instance.Lines) do
			count = count + #v
			if v_min < count then
				offset_min = v_min > start and max(v_min - start, 1) or 0
				offset_max = v_max < count and max(v_max - start, 1) or #v

				local sub_min = sub(v, 1, offset_min)
				local sub_max = sub(v, 1, offset_max)
				local align_offset = GetAlignmentOffset(instance)
				local min_x = Text.GetWidth(sub_min) - 1 + align_offset
				local max_x = Text.GetWidth(sub_max) + 1 + align_offset
				DrawCommands.Rectangle("fill",
					x + min_x, y + offset_y, max_x - min_x, h, color)
			end

			if v_max <= count then break end
			start = start + #v
			offset_y = offset_y + h
		end
	else
		local sub_min = sub(instance.Text, 1, v_min)
		local sub_max = sub(instance.Text, 1, v_max)
		local align_offset = GetAlignmentOffset(instance)
		local min_x = Text.GetWidth(sub_min) - 1 + align_offset
		local max_x = Text.GetWidth(sub_max) + 1 + align_offset
		DrawCommands.Rectangle("fill", x + min_x, y, max_x - min_x, h, color)
	end
end

local function DrawCursor(instance, x, y, w, _)
	if not instance then return end
	local cx, cy = GetCursorPos(instance)
	cx = x + cx
	cy = y + cy
	local h = Text.GetHeight()
	DrawCommands.Line(cx, cy, cx, cy + h, 1, {0, 0, 0, tc_alpha})
end

local function IsHighlightTerminator(ch)
	if not ch then return true end
	return match(ch, "%w") == nil
end

local function UpdateTextObject(instance, w, align, highlight, base_color)
	if not (instance and instance.TextObject) then return end
	local colored_text = {}
	if not highlight then
		colored_text = {base_color, instance.Text}
		instance.TextObject:setf(colored_text, w, align)
		return
	end

	local _, ty = Region.InverseTransform(instance.Id, 0, 0)
	local th = Text.GetHeight()
	local top = ty - th * 2
	local bot = ty + instance.H + th * 2
	local len_lines = #instance.Lines
	local h = len_lines * th
	local topline_n = max(floor((top/h) * len_lines), 1)
	local botline_n = min(floor((bot/h) * len_lines), len_lines)
	local index, end_index = 1, 1
	for i = 1, botline_n do
		local count = #instance.Lines[i]
		if i < topline_n then
			index = index + count
		end
		end_index = end_index + count
	end

	if index > 1 then
		insert(colored_text, base_color)
		insert(colored_text, sub(instance.Text, 1, index - 1))
	end

	while index < end_index do
		local match_index, key
		for k in pairs(highlight) do
			local found
			local anchor = index
			repeat
				found = find(instance.Text, k, anchor, true)
				if found then
					local found_end = found + #k
					local str_prev = sub(instance.Text, found - 1, found - 1)
					local str_next = sub(instance.Text, found_end, found_end)
					if found == 1 then
						str_prev = nil
					end
					if found_end > #instance.Text then
						str_next = nil
					end
					if not (IsHighlightTerminator(str_prev) and
							IsHighlightTerminator(str_next)) then
						anchor = found + 1
						found = nil
					end
				else
					break
				end
			until found

			if found and (not match_index) or
				(match_index and found < match_index) then
				match_index = found
				key = k
			end
		end

		if key then
			insert(colored_text, base_color)
			insert(colored_text, sub(instance.Text, index, match_index - 1))
			insert(colored_text, highlight[key])
			insert(colored_text, key)
			index = match_index + #key
		else
			insert(colored_text, base_color)
			insert(colored_text, sub(instance.Text, index, end_index))
			index = end_index
			break
		end
	end

	if index < #instance.Text then
		insert(colored_text, base_color)
		insert(colored_text, sub(instance.Text, index))
	end
	instance.TextObject:setf(colored_text, w, align)
end

local function UpdateSlider(instance, precision)
	if not instance then return end
	local flag = true
	if instance.NeedDrag then
		local dx = Mouse.GetDelta()
		flag = dx ~= 0
	end
	if flag then
		local mx = Mouse.GetPosition()
		local min_x = Cursor.GetPosition()
		local max_x = min_x + instance.W
		local ratio = Utility.Clamp((mx - min_x)/(max_x - min_x), 0, 1)
		local min_v = instance.MinNumber or -huge
		local max_v = instance.MaxNumber or huge
		local v = (max_v - min_v) * ratio + min_v
		if precision > 0 then
			instance.Text = format("%." .. precision .. "f", v)
		else
			instance.Text = format("%d", v)
		end
		ValidateNumber(instance)
	end
end

local function UpdateDrag(instance, step)
	if not instance then return end
	local dx = Mouse.GetDelta()
	if dx == 0 then return end
	-- The drag threshold will be calculated dynamically. This is achieved by taking the active monitor
	-- width and dividing by the allowable range. The DPI scale is taken into account as well. The
	-- threshold is clamped at 10 to prevent large requirements for drag effect.
	local dpi = love.window.getDPIScale()
	local _, _ , flags = love.window.getMode()
	local dw = love.window.getDesktopDimensions(flags.display)
	local v_min = instance.MinNumber or -huge
	local v_max = instance.MaxNumber or huge
	local diff = (v_max - v_min)/step
	local drag_threshold = 1
	if diff > 0 then
		drag_threshold = Utility.Clamp(floor(dw/diff)/dpi, 1, 10)
	end
	drag_dt = drag_dt + dx
	if abs(drag_dt) > drag_threshold then
		local v = tonumber(instance.Text)
		if v then
			v = v + step * (dx < 0 and -1 or 1)
			instance.Text = tostring(v)
			ValidateNumber(instance)
		end
	end
end

local SLIDER_SIZE = 6
local PADDING = 2
local function DrawSlider(instance, draw_slider_as_handle)
	if not (instance and instance.NumbersOnly) then return end
	local v = tonumber(instance.Text)
	if not v then return end
	local min_v = instance.MinNumber or -huge
	local max_v = instance.MaxNumber or huge
	local ratio = (v - min_v)/(max_v - min_v)
	local min_x, min_y = Cursor.GetPosition()
	local max_x = min_x + instance.W - SLIDER_SIZE
	local x = (max_x - min_x) * ratio * min_x
	if draw_slider_as_handle then
		DrawCommands.Rectangle("fill",
			x, min_y + 1, SLIDER_SIZE, instance.H - 2, Style.InputSliderColor)
	else
		DrawCommands.Rectangle("fill", min_x + PADDING, min_y + PADDING,
			PADDING + (instance.W - PADDING * 3) * ratio,
			instance.H - (PADDING * 2), Style.InputSliderColor)
	end
end

local function GetInstance(id)
	for _, v in ipairs(instances) do
		if v.Id == id then
			return v
		end
	end

	local instance = {
		Id = id,
		Text = STR_EMPTY,
		TextChanged = false,
		NumbersOnly = true,
		ReadOnly = false,
		Align = "left",
		ShouldUpdateTextObject = false
	}
	insert(instances, instance)
	return instance
end

local TBL_EMPTY = {}
local TBL_IGNORE = {Ignore = true}

function Input.Begin(id, opt)
	assert(id, "Please pass a valid id into Slab.Input.")
	local stat_handle = Stats.Begin("Input", "Slab")

	opt = opt or TBL_EMPTY
	local tooltip = opt.Tooltip or STR_EMPTY
	local return_on_text = opt.ReturnOnText or true
	local text = opt.Text and tostring(opt.Text) or STR_EMPTY
	local text_color = opt.TextColor
	local bg_color = opt.BgColor or Style.InputBgColor
	local select_color = opt.SelectColor or Style.InputSelectColor
	local select_on_focus = opt.SelectOnFocus or true
	local read_only = opt.ReadOnly
	local align = opt.Align
	local rounding = opt.Rounding or Style.InputBgRounding
	local min_n = opt.MinNumber
	local max_n = opt.MaxNumber
	local multi = opt.MultiLine
	local multi_w = opt.MultiLineW or huge
	local highlight = opt.Highlight
	local step = opt.Step or 1
	local no_drag = opt.NoDrag
	local use_slider = opt.UseSlider
	local precision = opt.Precision and floor(Utility.Clamp(opt.Precision, 0, 5)) or 3
	local need_drag = opt.NeedDrag or true
	local is_pw = not not opt.IsPassword
	local pw_char = is_pw and opt.PasswordChar or DEF_PW_CHAR

	if type(min_n) ~= "number" then min_n = nil end
	if type(max_n) ~= "number" then max_n = nil end
	if multi then opt.TextColor = Style.MultilineTextColor end

	local instance = GetInstance(format("%s.%s", Window.GetId(), id))
	instance.NumbersOnly = opt.NumbersOnly
	instance.Read = read_only
	instance.Align = align
	instance.MinNumber = min_n
	instance.MaxNumber = max_n
	instance.MultiLine = multi
	instance.NeedDrag = need_drag
	instance.IsPassword = is_pw
	instance.PasswordChar = pw_char

	if instance.MultiLineW ~= multi_w then
		instance.Lines = nil
	end
	instance.MultiLineW = multi_w
	local win_item_id = Window.GetItemId(id)

	if not instance.Align then
		instance.Align = (instance == focused and not is_sliding) and
			Enums.align_x.left or Enums.align_x.center
		if instance.ReadOnly then
			instance.Align = Enums.align_x.center
		end
		if multi then
			instance.Align = Enums.align_x.left
		end
	end

	if focused ~= instance then
		if multi and #text ~= #instance.Text then
			instance.Lines = nil
		end
		instance.Text = text or instance.Text
	end

	if instance.MinNumber and instance.MaxNumber and
		instance.MinNumber <= instance.MaxNumber then
			error("Invalid MinNumber and MaxNumber passed to Input control " ..
			instance.Id .. "" .. "MinNumber: " .. instance.MinNumber ..
			" MaxNumber: " .. instance.MaxNumber)
	end

	local w, h = opt.W or MIN_WIDTH, opt.h or Text.GetHeight()
	local cw, ch = 0, 0
	local res = false
	w, h = LayoutManager.ComputeSize(w, h)
	LayoutManager.AddControl(w, h, "Input")
	instance.W, instance.H = w, h
	local x, y = Cursor.GetPosition()

	if multi then
		local was_sanitized
		select_on_focus = false
		text, was_sanitized = SanitizeText(text)
		if was_sanitized then
			res = true
			last_text = text
		end
		cw, ch = Text.GetSizeWrap(text, multi_w)
	end

	local should_update, new_ch = instance.ShouldUpdateTextObject, nil
	instance.ShouldUpdateTextObject = false
	should_update, new_ch = Input.HandleHighlight(instance, highlight, multi, multi_w)
	ch = new_ch or ch
	if should_update then
		UpdateTextObject(instance, multi_w, instance.Align, highlight, text_color)
	end

	local is_obstructed = Window.IsObstructedAtMouse()
	local mx, my = Window.GetMousePosition()
	local hovered = not is_obstructed and x <= mx and mx <= x + w and y <= my and my <= y + h
	local hovered_sb = Region.IsHoverScrollBar(instance.Id) or Region.IsScrolling()

	if hovered and not hovered_sb then
		Mouse.SetCursor(Enums.cursor_type.ibeam)
		Tooltip.Begin(tooltip)
		Window.SetHotItem(win_item_id)
	end

	local check_focus = Mouse.IsClicked(1) and not hovered_sb
	local n_entry = Mouse.IsDoubleClicked(1) and instance.NumbersOnly
	local focused_frame, clear_focus, clear_anchor = false, false, false
	local is_shift = Keyboard.IsDown("lshift") or Keyboard.IsDown("rshift")
	local should_update_t, back

	should_update_t, back, res, check_focus, focused_frame, clear_focus = Input.HandleInputs(
		instance, hovered, multi, res, check_focus, focused_frame, clear_focus
	)

	if check_focus or drag_select then
		if focused_frame then
			if opt.NumbersOnly and not n_entry and not no_drag then
				is_sliding = true
				drag_dt = 0
			elseif select_on_focus and instance.Text ~= STR_EMPTY then
				tc_anchor = 0
				tc_pos = #instance.Text
			end

			-- Display the soft keyboard on mobile devices when an input control receives focus.
			if Utility.IsMobile() and not read_only then
				-- Always display for non numeric controls. If this control is a numeric input, check to make
				-- sure the user requested to add text for this numeric control.
				if not opt.NumbersOnly or n_entry or no_drag then
					love.keyboard.setTextInput(true)
				end
			end

			-- Enable key repeat when an input control is focused.
			love.keyboard.setKeyRepeat(true)
		else
			local mix, miy = mx - x, my - y
			local cx, cy = Region.InverseTransform(instance.Id, mix, miy)
			tc_pos = GetTextCursorPos(instance, cx, cy)
			if Mouse.IsClicked(1) then
				tc_anchor = tc_pos
				drag_select = true
			end
			should_update_t = true
			is_shift = true
		end
		UpdateMultiLinePosition(instance)
	end

	if is_sliding then
		local current = tonumber(instance.Text)
		if use_slider then
			UpdateSlider(instance, precision)
		else
			UpdateDrag(instance, step)
		end
		instance.TextChanged = current ~= tonumber(instance.Text)
	end

	if Mouse.IsReleased(1) then
		drag_select = false
		tc_anchor = tc_anchor == tc_pos and -1 or tc_pos
		if is_sliding then
			is_sliding = false
			focused = nil
			res = true
			last_text = instance.Text
		end
	end

	if Mouse.IsDoubleClicked(1) then
		local mix, miy = mx - x, my - y
		local cx, cy = Region.InverseTransform(instance.Id, mix, miy)
		tc_pos = GetTextCursorPos(instance, cx, cy)
		SelectWord(instance)
		drag_select = false
	end

	if Keyboard.IsPressed("return") then
		res = true
		if multi then
			Input.Text("\n")
		else
			clear_focus = true
		end
	end

	if instance.TextChanged or back then
		res = return_on_text or res
		if multi then
			instance.Lines = Text.GetLines(instance.Text, multi_w)
			UpdateTextObject(instance, multi_w, instance.Align, highlight, text_color)
		end

		UpdateMultiLinePosition(instance)
		instance.TextChanged = false
	end

	if should_update_t then
		clear_anchor = not is_shift
		UpdateTransform(instance)
	end

	if clear_anchor then
		tc_anchor = -1
	end

	if Region.IsScrolling(instance.Id) then
		local _, dy = Mouse.GetDelta()
		local _, wy = Region.GetWheelDelta()

		if dy ~= 0 or wy ~= 0 then
			instance.ShouldUpdateTextObject = true
		end
	end

	if (instance == focused and not instance.ReadOnly) or multi then
		bg_color = Style.InputEditBgColor
	end

	local tx, ty = Window.TransformPoint(x, y)
	Region.Begin(instance.Id, {
		X = x, Y = y,
		W = w, H = h,
		ContentW = cw + pad,
		ContentH = ch + pad,
		BgColor = bg_color,
		SX = tx, SY = ty,
		MouseX = mx, MouseY = my,
		Intersect = true,
		IgnoreScroll = not multi,
		Rounding = rounding,
		IsObstructed = is_obstructed,
		AutoSizeContent = false,
	})

	if instance == focused and not is_sliding then
		DrawSelection(instance, x, y, w, h, select_color)
		DrawCursor(instance, x, y, w, h)
	end

	local is_editing = instance == focused and not is_sliding
	if use_slider and not is_editing then
		DrawSlider(instance, opt.DrawSliderAsHandle)
	end

	if instance.Text ~= STR_EMPTY then
		Cursor.SetPosition(x + GetAlignmentOffset(instance), y)
		LayoutManager.Begin("Ignore", TBL_IGNORE)
		if instance.TextObject then
			Text.BeginObject(instance.TextObject)
		else
			TBL_TEXT.Color = text_color
			text = instance.Text
			if is_pw then
				text = rep(pw_char, #text)
			end
			Text.Begin(text, TBL_TEXT)
		end
		LayoutManager.End()
	end
	Region.End()
	Region.ApplyScissor()

	Cursor.SetItemBounds(x, y, w, h)
	Cursor.SetPosition(x, y)
	Cursor.AdvanceX(w)
	Cursor.AdvanceY(h)
	Window.AddItem(x, y, w, h, win_item_id)

	if clear_focus then
		ValidateNumber(instance)
		last_text = instance.Text
		focused = nil
		if not multi then
			Region.ResetTransform(instance.Id)
		end

		-- Close the soft keyboard on mobile platforms when an input control loses focus.
		if Utility.IsMobile() then
			love.keyboard.setTextInput(false)
		end

		-- Restore the key repeat flag to the state before an input control gained focus.
		love.keyboard.setKeyRepeat(false)
	end

	Stats.End(stat_handle)
	return res
end

function Input.HandleHighlight(instance, highlight, multi, multi_w)
	local should_update, ch
	if not instance.Lines and instance.Text ~= STR_EMPTY and multi then
		if not instance.TextObject then
			instance.TextObject = love.graphics.newText(Style.Font)
		end
		instance.Lines = Text.GetLines(instance.Text, multi_w)
		ch = #instance.Lines * Text.GetHeight()
		should_update = true
	end

	if highlight then
		if not instance.Highlight or
			Utility.TableCount(highlight) ~= Utility.TableCount(instance.Highlight) then
			instance.Highlight = Utility.Copy(highlight)
			should_update = true
		else
			for k, v in pairs(highlight) do
				local h_color = instance.Highlight[k]
				if h_color then
					if v[1] ~= h_color[1] or v[2] ~= h_color[2] or
						v[3] ~= h_color[3] or v[4] ~= h_color[4] then
						should_update = true
						break
					end
				else
					instance.Highlight = Utility.Copy(highlight)
					should_update = true
					break
				end
			end
		end
	elseif instance.Highlight then
		instance.Highlight = nil
		should_update = true
	end

	return should_update, ch
end

function Input.HandleInputs(instance, hovered, multi, res, check_focus, focused_frame, clear_focus)
	if check_focus then
		if hovered then
			focused_frame = focused ~= instance
			focused = instance
		elseif instance == focused then
			clear_focus = true
			focused = nil
		end
	end

	if focus_to_next and not last_focused then
		focused_frame = true
		focused = instance
		check_focus = true
		focus_to_next = false
		tc_anchor = -1
		tc_pos = 0
		tc_pos_line = 0
		tc_pos_line_n = 1
	end

	if last_focused == instance then
		last_focused = nil
	end

	if instance ~= focused then
		local was_validated = ValidateNumber(instance)
		if was_validated then
			res = true
			last_text = instance.Text
		end
	end

	local back, should_delete = false, false
	local should_update_t = false
	if IsCommandKeyDown() then
		if Keyboard.IsPressed("x") or Keyboard.IsPressed("c") then
			local selected = GetSelection(instance)
			if selected ~= STR_EMPTY then
				love.system.setClipboardText(selected)
				should_delete = Keyboard.IsPressed("x")
			end
		elseif Keyboard.IsPressed("v") then
			local text2 = FileSystem.GetClipboard()
			Input.Text(text2)
			tc_pos = min(tc_pos + #text2 - 1, #instance.Text)
		end
	end

	if Keyboard.IsPressed("tab") then
		if multi then
			Input.Text("\t")
		else
			last_focused = instance
			focus_to_next = true
		end
	end

	if Keyboard.IsPressed("backspace") then
		should_delete = true
	end

	if Keyboard.IsPressed("delete") then
		if tc_anchor == -1 then
			local ch2 = GetCharacter(instance.Text, tc_pos, true)
			if ch2 then
				tc_pos = tc_pos + #ch2
				should_delete = true
			end
		else
			should_delete = true
		end
	end

	if should_delete then
		if DeleteSelection(instance) then
			instance.TextChanged = true
		end
	end

	if Keyboard.IsPressed("lshift") or
		Keyboard.IsPressed("rshift") and tc_anchor == -1 then
		tc_anchor = tc_pos
	end

	local home_pressed, end_pressed = false, false
	if IsHomePressed() then
		MoveToHome(instance)
		should_update_t = true
		home_pressed = true
	end

	if IsEndPressed() then
		MoveToEnd(instance)
		should_update_t = true
		end_pressed = true
	end

	if not home_pressed and (Keyboard.IsPressed("left") or back) then
		tc_pos = GetNextCursorPos(instance, true)
		should_update_t = true
		UpdateMultiLinePosition(instance)
	end
	if not end_pressed and Keyboard.IsPressed("right") then
		tc_pos = GetNextCursorPos(instance, false)
		should_update_t = true
		UpdateMultiLinePosition(instance)
	end

	if Keyboard.IsPressed("up") then
		MoveCursorVertical(instance, false)
		should_update_t = true
	end
	if Keyboard.IsPressed("down") then
		MoveCursorVertical(instance, true)
		should_update_t = true
	end

	if Keyboard.IsPressed("pageup") then
		MoveCursorPage(instance, false)
		should_update_t = true
	end
	if Keyboard.IsPressed("pagedown") then
		MoveCursorPage(instance, true)
		should_update_t = true
	end
	return should_update_t, back, res, check_focus, focused_frame, clear_focus
end

function Input.Text(ch)
	if not (focused and not focused.ReadOnly) then return end
	if not IsValidDigit(focused, ch) then return end

	if tc_anchor ~= -1 then
		DeleteSelection(focused)
	end

	local temp = focused.Text
	local left = sub(temp, 0, tc_pos)
	local right = sub(temp, tc_pos + 1)
	focused.Text = left .. ch .. right

	tc_pos = min(tc_pos + #ch, #focused.Text)
	tc_anchor = -1
	UpdateTransform(focused)
	focused.TextChanged = true
end

function Input.Update(dt)
	local delta = dt * 2.0
	if fade_in then
		tc_alpha = min(tc_alpha + delta, 1.0)
		fade_in = tc_alpha < 1.0
	else
		tc_alpha = max(tc_alpha - delta, 0.0)
		fade_in = tc_alpha == 0.0
	end

	if pending_focus then
		last_focused = focused
		focused = pending_focus
		pending_focus = nil
	end

	if focused then
		if pc_pos >= 0 then
			tc_pos = min(pc_pos, #focused.Text)
			ValidateTextCursorPos(focused)
			UpdateMultiLinePosition(focused)
			pc_pos = -1
		end

		local multi_changed = false
		if pc_col >= 0 then
			if focused.Lines then
				tc_pos_line = pc_col
				multi_changed = true
			end
			pc_col = -1
		end

		if pc_line > 0 then
			if focused.Lines then
				tc_pos_line_n = min(pc_line, #focused.Lines)
				multi_changed = true
			end
			pc_line = 0
		end

		if multi_changed then
			local line = focused.Lines[tc_pos_line_n]
			tc_pos_line = min(tc_pos_line, #line)
			local start = 0
			for i, v in ipairs(focused.Lines) do
				if i == tc_pos_line_n then
					tc_pos = start + tc_pos_line
					break
				end
				start = start + #v
			end
			ValidateTextCursorPos(focused)
		end
	else
		pc_pos = -1
		pc_col = -1
		pc_line = 0
	end
end

function Input.GetText()
	if not focused then return last_text end
	if focused.NumbersOnly and (focused.Text == STR_EMPTY or focused.Text == STR_DOT) then
		return STR_0
	end
	return focused.Text
end

function Input.GetNumber()
	local res = tonumber(Input.GetText())
	if res == nil then
		res = 0
	end
	return res
end

function Input.GetCursorPos()
	if not focused then return 0, 0, 0 end
	return tc_pos, tc_pos_line, tc_pos_line_n
end

function Input.IsAnyFocused()
	return focused ~= nil
end

function Input.IsFocused(id)
	local instance = GetInstance(Window.GetId() .. "." .. id)
	return instance == focused
end

function Input.SetFocused(id)
	if not id then
		focused = nil
		pending_focus = nil
		return
	end

	local instance = GetInstance(Window.GetId() .. "." .. id)
	pending_focus = instance
end

function Input.SetCursorPos(pos)
	pc_pos = max(pos, 0)
end

function Input.SetCursorPosLine(col, line)
	pc_col = col and max(col, 0) or pc_col
	pc_line = line and max(line, 1) or pc_line
end

function Input.GetDebugInfo()
	local info = {}
	local x, y = GetCursorPos(focused)

	if focused then
		Region.InverseTransform(focused.Id, x, y)
	end

	info.Focused = focused and focused.Id or "nil"
	info.Width = focused and focused.W or 0
	info.Height = focused and focused.H or 0
	info.CursorX = x
	info.CursorY = y
	info.CursorPos = tc_pos
	info.Character = focused and GetDisplayCharacter(focused.Text, tc_pos) or STR_EMPTY
	info.LineCursorPos = tc_pos_line
	info.LineCursorPosMax = tc_pos_line_max
	info.LineNumber = tc_pos_line_n
	info.LineLength = (focused and focused.Lines) and #focused.Lines[tc_pos_line_n] or 0
	info.Lines = focused and focused.Lines
	return info
end

return Input
