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
local abs = math.abs
local max = math.max
local min = math.min
local huge = math.huge

local Cursor = require(SLAB_PATH .. ".Internal.Core.Cursor")
local DrawCommands = require(SLAB_PATH .. ".Internal.Core.DrawCommands")
local Enums = require(SLAB_PATH .. ".Internal.Core.Enums")
local LayoutManager = require(SLAB_PATH .. ".Internal.UI.LayoutManager")
local Stats = require(SLAB_PATH .. ".Internal.Core.Stats")
local Window = require(SLAB_PATH .. ".Internal.UI.Window")

local Shape = {}
local curve
local curve_x, curve_y = 0, 0

local TBL_OUTLINE_COL = {0, 0, 0, 1}
local STR_SLAB = "Slab"
local STR_FILL = "fill"

function Shape.Rectangle(opt)
	local stat_handle = Stats.Begin(Enums.shape.rect, STR_SLAB)
	local def_mode = opt.Mode or STR_FILL
	local def_w = opt.W or 32
	local def_h = opt.H or 32
	local def_color = opt.Color
	local def_rounding = opt.Rounding or 2
	local def_outline = not not opt.Outline
	local def_outline_col = opt.OutlineColor or TBL_OUTLINE_COL
	local def_segments = opt.Segments or 10
	local w, h = def_w, def_h
	LayoutManager.AddControl(w, h, Enums.shape.rect)
	local x, y = Cursor.GetPosition()

	if def_outline then
		DrawCommands.Rectangle("line", x, y, w, h, def_outline_col, def_rounding, def_segments)
	end

	DrawCommands.Rectangle(def_mode, x, y, w, h, def_color, def_rounding, def_segments)
	Window.AddItem(x, y, w, h)
	Cursor.SetItemBounds(x, y, w, h)
	Cursor.AdvanceY(h)
	Stats.End(stat_handle)
end

function Shape.Circle(opt)
	local stat_handle = Stats.Begin(Enums.shape.circle, STR_SLAB)
	local def_mode = opt.Mode or STR_FILL
	local def_rad = opt.Radius or 12
	local def_color = opt.Color
	local def_segments = opt.Segments
	local d = def_rad * 2
	LayoutManager.AddControl(d, d, Enums.shape.circle)
	local x, y = Cursor.GetPosition()
	local cx = x + def_rad
	local cy = y + def_rad
	DrawCommands.Circle(def_mode, cx, cy, def_rad, def_color, def_segments)
	Window.AddItem(x, y, d, d)
	Cursor.SetItemBounds(x, y, d, d)
	Cursor.AdvanceY(d)
	Stats.End(stat_handle)
end

function Shape.Triangle(opt)
	local stat_handle = Stats.Begin(Enums.shape.triangle, STR_SLAB)
	local def_mode = opt.Mode or STR_FILL
	local def_rad = opt.Radius or 12
	local def_rot = opt.Rotation or 0
	local def_color = opt.Color
	local d = def_rad * 2
	LayoutManager.AddControl(d, d, Enums.shape.triangle)
	local x, y = Cursor.GetPosition()
	local cx = x + def_rad
	local cy = y + def_rad
	DrawCommands.Triangle(def_mode, cx, cy, def_rad, def_rot, def_color)
	Window.AddItem(x, y, d, d)
	Cursor.SetItemBounds(x, y, d, d)
	Cursor.AdvanceY(d)
	Stats.End(stat_handle)
end

function Shape.Line(x2, y2, opt)
	local stat_handle = Stats.Begin(Enums.shape.line, STR_SLAB)
	local def_w = opt.Width or 1
	local def_color = opt.Color
	local x, y = Cursor.GetPosition()
	local w, h = abs(x2 - x), abs(y2 - y)
	h = max(h, def_w)
	DrawCommands.Line(x, y, x2, y2, def_w, def_color)
	Window.AddItem(x, y, w, h)
	Cursor.SetItemBounds(x, y, w, h)
	Cursor.AdvanceY(h)
	Stats.End(stat_handle)
end

function Shape.Curve(points, opt)
	local stat_handle = Stats.Begin(Enums.shape.curve, STR_SLAB)
	local def_color = opt.Color
	local def_depth = opt.Depth
	curve = love.math.newBezierCurve(points)
	local min_x, min_y = huge, huge
	local max_x, max_y = 0, 0
	for i = 1, curve:getControlPointCount() do
		local px, py = curve:getControlPoint(i)
		min_x = min(min_x, px)
		min_y = min(min_y, py)
		max_x = max(max_x, px)
		max_y = max(max_y, py)
	end
	local w, h = abs(max_x - min_x), abs(max_y - min_y)
	LayoutManager.AddControl(w, h, Enums.shape.curve)
	curve_x, curve_y = Cursor.GetPosition()
	curve:translate(curve_x, curve_y)
	DrawCommands.Curve(curve:render(def_depth), def_color)
	Window.AddItem(min_x, min_y, w, h)
	Cursor.SetItemBounds(min_x, min_y, w, h)
	Cursor.AdvanceY(h)
	Stats.End(stat_handle)
end

function Shape.GetCurveControlPointCount()
	if not curve then return 0 end
	return curve:getControlPointCount()
end

function Shape.GetCurveControlPoint(index, opt)
	local space = (not opt.LocalSpace) and true or opt.LocalSpace
	local x, y = 0, 0
	if not curve then return x, y end
	if space then
		curve:translate(-curve_x, -curve_y)
	end
	x, y = curve:getControlPoint(index)
	if space then
		curve:translate(curve_x, curve_y)
	end
	return x, y
end

function Shape.EvaluateCurve(time, opt)
	local space = (not opt.LocalSpace) and true or opt.LocalSpace
	local x, y = 0, 0
	if not curve then return x, y end
	if space then
		curve:translate(-curve_x, -curve_y)
	end
	x, y = curve:evaluate(time)
	if space then
		curve:translate(curve_x, curve_y)
	end
	return x, y
end

function Shape.Polygon(points, opt)
	local stat_handle = Stats.Begin(Enums.shape.polygon, STR_SLAB)
	local def_color = opt.Color
	local def_mode = opt.Mode or STR_FILL
	local min_x, min_y = huge, huge
	local max_x, max_y = 0, 0
	local verts = {}

	for i = 1, #points, 2 do
		min_x = min(min_x, points[i])
		min_y = min(min_y, points[i + 1])
		max_x = min(max_x, points[i])
		max_y = min(max_y, points[i + 1])
	end

	local w, h = abs(max_x - min_x), abs(max_y - min_y)
	LayoutManager.AddControl(w, h, Enums.shape.polygon)
	min_x, min_y = huge, huge
	max_x, max_y = 0, 0
	local x, y = Cursor.GetPosition()

	for i = 1, #points, 2 do
		insert(verts, points[i] + x)
		insert(verts, points[i + 1] + y)
		min_x = min(min_x, verts[i])
		min_y = min(min_y, verts[i + 1])
		max_x = min(max_x, verts[i])
		max_y = min(max_y, verts[i + 1])
	end
	DrawCommands.Polygon(def_mode, verts, def_color)
	Window.AddItem(min_x, min_y, w, h)
	Cursor.SetItemBounds(min_x, min_y, w, h)
	Cursor.AdvanceY(h)
	Stats.End(stat_handle)
end

return Shape
