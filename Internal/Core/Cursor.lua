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
local min = math.min
local max = math.max

local Utility = require(SLAB_PATH .. ".Internal.Core.Utility")

local Cursor = {}

local state = {
	x = 0, y = 0,
	prev_x = 0, prev_y = 0,
	anchor_x = 0, anchor_y = 0,
	item_x = 0, item_y = 0,
	item_w = 0, item_h = 0,
	pad_x = 0, pad_y = 0,
	newline_size = 16,
	line_y = 0, line_h = 0,
	prev_line_y = 0, prev_line_h = 0
}

local stack = {}

function Cursor.SetPosition(x, y)
	Cursor.SetX(x)
	Cursor.SetY(y)
end

function Cursor.SetX(x)
	state.prev_x = state.x
	state.x = x
end

function Cursor.SetY(y)
	state.prev_y = state.y
	state.y = y
end

function Cursor.SetRelativePosition(x, y)
	Cursor.SetPosition(state.anchor_x + x, state.anchor_y + y)
end

function Cursor.SetRelativeX(x)
	Cursor.SetX(state.anchor_x + x)
end

function Cursor.SetRelativeY(y)
	Cursor.SetX(state.anchor_y + y)
end

function Cursor.AdvanceX(x)
	Cursor.SetX(state.x + x + state.pad_x)
end

function Cursor.AdvanceY(y)
	state.x = state.anchor_x
	state.prev_y = state.y
	state.y = state.y + y + state.pad_y
	state.prev_line_y = state.line_y
	state.prev_line_h = state.line_h
	state.line_y = 0
	state.line_h = 0
end

function Cursor.SetAnchor(x, y)
	state.anchor_x = x
	state.anchor_y = y
end

function Cursor.SetAnchorX(x)
	state.anchor_x = x
end

function Cursor.SetAnchorY(y)
	state.anchor_y = y
end

function Cursor.GetAnchor()
	return state.anchor_x, state.anchor_y
end

function Cursor.GetAnchorX()
	return state.anchor_x
end

function Cursor.GetAnchorY()
	return state.anchor_y
end

function Cursor.GetPosition()
	return state.x, state.y
end

function Cursor.GetX()
	return state.x
end

function Cursor.GetY()
	return state.y
end

function Cursor.GetRelativePosition()
	return Cursor.GetRelativeX(), Cursor.GetRelativeY()
end

function Cursor.GetRelativeX()
	return state.x - state.anchor_x
end

function Cursor.GetRelativeY()
	return state.y - state.anchor_y
end

function Cursor.SetItemBounds(x, y, w, h)
	state.item_x, state.item_y = x, y
	state.item_w, state.item_h = w, h
	state.line_y = state.line_y == 0 and y or state.line_y
	state.line_y = min(state.line_y, y)
	state.line_h = max(state.line_h, h)
end

function Cursor.GetItemBounds()
	return state.item_x, state.item_y, state.item_w, state.item_h
end

function Cursor.IsInItemBounds(x, y)
	return state.item_x <= x and x <= state.item_x + state.item_w and
		state.item_y <= y and y <= state.item_y + state.item_h
end

local TBL_EMPTY = {}
function Cursor.SameLine(opt)
	opt = opt or TBL_EMPTY
	local indent = opt.Indent or 0
	local center_y = opt.CenterY

	state.line_y = state.prev_line_y
	state.line_h = state.prev_line_h
	state.x = state.item_x + state.item_w + state.pad_x + indent
	state.y = state.prev_y

	if center_y then
		state.y = state.y + (state.line_h * 0.5) - (state.newline_size * 0.5)
	end
end

function Cursor.SetNewLineSize(newline_size)
	state.newline_size = newline_size
end

function Cursor.GetNewLineSize()
	return state.newline_size
end

function Cursor.NewLine(n)
	Cursor.AdvanceY(state.newline_size * (n or 1))
end

function Cursor.GetLineHeight()
	return state.prev_line_h
end

function Cursor.PadX()
	return state.pad_x
end

function Cursor.PadY()
	return state.pad_y
end

function Cursor.Indent(width)
	state.anchor_x = state.anchor_x + width
	state.x = state.anchor_x
end

function Cursor.Unindent(width)
	Cursor.Indent(-width)
end

function Cursor.PushContext()
	table.insert(stack, 1, Utility.Copy(state))
end

function Cursor.PopContext()
	if #stack == 0 then return end
	state = table.remove(stack, 1)
end

return Cursor
