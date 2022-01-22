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

local floor = math.floor
local insert = table.insert
local max = math.max
local sub = string.sub

local Cursor = require(SLAB_PATH .. ".Internal.Core.Cursor")
local DrawCommands = require(SLAB_PATH .. ".Internal.Core.DrawCommands")
local LayoutManager = require(SLAB_PATH .. ".Internal.UI.LayoutManager")
local Mouse = require(SLAB_PATH .. ".Internal.Input.Mouse")
local Region = require(SLAB_PATH .. ".Internal.UI.Region")
local Stats = require(SLAB_PATH .. ".Internal.Core.Stats")
local Style = require(SLAB_PATH .. ".Style")
local Window = require(SLAB_PATH .. ".Internal.UI.Window")

local Text = {}

local TBL_EMPTY = {}

function Text.Begin(label, opt)
	local stat_handle = Stats.Begin("Text", "Slab")

	opt = opt or TBL_EMPTY

	local color = opt.Color or Style.TextColor
	local pad = opt.Pad or 0
	local is_selectable_text_only = opt.IsSelectableTextOnly
	local is_selectable = opt.IsSelectable or opt.IsSelectableTextOnly
	local is_selected = opt.IsSelected
	local add_item = opt.AddItem ~= false
	local hover_color = opt.HoverColor or Style.TextHoverBgColor
	local url = opt.URL

	if url then
		is_selectable_text_only = true
		color = Style.TextURLColor
	end

	local w = Text.GetWidth(label)
	local h = Style.Font:getHeight()
	LayoutManager.AddControl(w + pad, h , "Text")
	local res = false
	local win_id = Window.GetItemId(label)
	local x, y = Cursor.GetPosition()
	local mx, my = Window.GetMousePosition()
	local is_obstructed = Window.IsObstructedAtMouse()

	if not is_obstructed and x <= mx and mx <= x + w and y <= my and my <= y + h then
		Window.SetHotItem(win_id)
	end

	local wx, wy, ww, wh = Region.GetContentBounds()
	local check_x = is_selectable_text_only and x or wx
	-- The region's width may have been reset prior to the first control being added. Account for this discrepency.
	local check_w = is_selectable_text_only and w or max(ww, w)
	local hovered = not is_obstructed and
		check_x <= mx and mx <= check_x + check_w + pad and
		y <= my and my <= y + h

	if is_selectable or is_selected then
		if hovered or is_selected then
			DrawCommands.Rectangle("fill", check_x, y, check_w + pad, h, hover_color)
		end
		res = hovered and (opt.SelectOnHover or Mouse.IsClicked(1))
	end

	if hovered and url then
		Mouse.SetCursor("hand")
		if Mouse.IsClicked(1) then
			love.system.openURL(url)
		end
	end

	DrawCommands.Print(label, floor(x + pad * 0.5), floor(y), color, Style.Font)

	if url then
		DrawCommands.Line(x + pad, y + h, x + w, y + h, 1, color)
	end

	Cursor.SetItemBounds(x, y, w + pad, h)
	Cursor.AdvanceY(h)
	if add_item then
		Window.AddItem(x, y, w + pad, h, win_id)
	end
	Stats.End(stat_handle)
	return res
end

function Text.BeginFormatted(label, opt)
	local stat_handle = Stats.Begin("Textf", "Slab")
	local ww, wh = Window.GetBorderlessSize()
	opt = opt or TBL_EMPTY
	local w = opt.W or ww
	if Window.IsAutoSize() then
		w = love.graphics.getWidth()
	end

	local width, wrapped = Style.Font:getWrap(label, w)
	local height = #wrapped * Style.Font:getHeight()
	LayoutManager.AddControl(width, height, "TextFormatted")
	local x, y = Cursor.GetPosition()
	local fx, fy = floor(x), floor(y)
	DrawCommands.Printf(label, x, y, width, opt.Align or "left",
		opt.Color or Style.TextColor, Style.Font)
	Cursor.SetItemBounds(x, y, width, height)
	Cursor.AdvanceY(height)
	Window.ResetContentSize()
	Window.AddItem(x, y, width, height)
	Stats.End(stat_handle)
end

function Text.BeginObject(object, opt)
	local stat_handle = Stats.Begin("TextObject", "Slab")
	local ww, wh = Window.GetBorderlessSize()
	opt = opt or TBL_EMPTY
	local color = opt.Color or Style.TextColor
	local w, h = object:getDimensions()
	LayoutManager.AddControl(w, h, "TextObject")
	local x, y = Cursor.GetPosition()
	local fx, fy = floor(x), floor(y)
	DrawCommands.Text(object, fx, fy, color)
	Cursor.SetItemBounds(fx, fy, w, h)
	Cursor.AdvanceY(y)
	Window.ResetContentSize()
	Window.AddItem(fx, fy, w, h)
	Stats.End(stat_handle)
end

function Text.GetWidth(label)
	return Style.Font:getWidth(label)
end

function Text.GetHeight()
	return Style.Font:getHeight()
end

function Text.GetSize(label)
	return Style.Font:getWidth(label), Style.Font:getHeight()
end

function Text.GetSizeWrap(label, width)
	local w, lines = Style.Font:getWrap(label, width)
	return w, #lines * Text.GetHeight()
end

local STR_NEWLINE = "\n"
local STR_EMPTY = ""
function Text.GetLines(label, width)
	local w, lines = Style.Font:getWrap(label, width)
	local start = 0
	for i, v in ipairs(lines) do
		local len_v = #v
		if len_v == 0 then
			lines[i] = "\n"
		else
			local offset = start + len_v + 1
			local ch = sub(label, offset, offset)
			if ch == STR_NEWLINE then
				lines[i] = lines[i] .. STR_NEWLINE
			end
		end
		start = start + #lines[i]
	end

	local len_label = #label
	if sub(label, len_label, len_label) == STR_NEWLINE then
		insert(lines, STR_EMPTY)
	end

	if #lines == 0 then
		insert(lines, STR_EMPTY)
	end

	return lines
end

function Text.CreateObject()
	return love.graphics.newText(Style.Font)
end

return Text
