--[[

MIT License

Copyright (c) 2019 Mitchell Davis <coding.jackalope@gmail.com>

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
local Stats = require(SLAB_PATH .. '.Internal.Core.Stats')
local Window = require(SLAB_PATH .. '.Internal.UI.Window')

local Shape = {}
local Curve = nil
local CurveX, CurveY = 0, 0

function Shape.Rectangle(Options)
	local StatHandle = Stats.Begin('Rectangle', 'Slab')

	Options = Options == nil and {} or Options
	Options.Mode = Options.Mode == nil and 'fill' or Options.Mode
	Options.W = Options.W == nil and 32 or Options.W
	Options.H = Options.H == nil and 32 or Options.H
	Options.Color = Options.Color == nil and nil or Options.Color
	Options.Rounding = Options.Rounding == nil and 2.0 or Options.Rounding
	Options.Outline = Options.Outline == nil and false or Options.Outline
	Options.OutlineColor = Options.OutlineColor == nil and {0.0, 0.0, 0.0, 1.0} or Options.OutlineColor
	Options.Segments = Options.Segments == nil and 10 or Options.Segments

	local W = Options.W
	local H = Options.H
	LayoutManager.AddControl(W, H)

	local X, Y = Cursor.GetPosition()

	if Options.Outline then
		DrawCommands.Rectangle('line', X, Y, W, H, Options.OutlineColor, Options.Rounding, Options.Segments)
	end

	DrawCommands.Rectangle(Options.Mode, X, Y, W, H, Options.Color, Options.Rounding, Options.Segments)

	Window.AddItem(X, Y, W, H)
	Cursor.SetItemBounds(X, Y, W, H)
	Cursor.AdvanceY(H)

	Stats.End(StatHandle)
end

function Shape.Circle(Options)
	local StatHandle = Stats.Begin('Circle', 'Slab')

	Options = Options == nil and {} or Options
	Options.Mode = Options.Mode == nil and 'fill' or Options.Mode
	Options.Radius = Options.Radius == nil and 12.0 or Options.Radius
	Options.Color = Options.Color == nil and nil or Options.Color
	Options.Segments = Options.Segments == nil and nil or Options.Segments

	local Diameter = Options.Radius * 2.0

	LayoutManager.AddControl(Diameter, Diameter)

	local X, Y = Cursor.GetPosition()
	local CenterX = X + Options.Radius
	local CenterY = Y + Options.Radius

	DrawCommands.Circle(Options.Mode, CenterX, CenterY, Options.Radius, Options.Color, Options.Segments)
	Window.AddItem(X, Y, Diameter, Diameter)
	Cursor.SetItemBounds(X, Y, Diameter, Diameter)
	Cursor.AdvanceY(Diameter)

	Stats.End(StatHandle)
end

function Shape.Triangle(Options)
	local StatHandle = Stats.Begin('Triangle', 'Slab')

	Options = Options == nil and {} or Options
	Options.Mode = Options.Mode == nil and 'fill' or Options.Mode
	Options.Radius = Options.Radius == nil and 12 or Options.Radius
	Options.Rotation = Options.Rotation == nil and 0 or Options.Rotation
	Options.Color = Options.Color == nil and nil or Options.Color

	local Diameter = Options.Radius * 2.0

	LayoutManager.AddControl(Diameter, Diameter)

	local X, Y = Cursor.GetPosition()
	local CenterX = X + Options.Radius
	local CenterY = Y + Options.Radius

	DrawCommands.Triangle(Options.Mode, CenterX, CenterY, Options.Radius, Options.Rotation, Options.Color)
	Window.AddItem(X, Y, Diameter, Diameter)
	Cursor.SetItemBounds(X, Y, Diameter, Diameter)
	Cursor.AdvanceY(Diameter)

	Stats.End(StatHandle)
end

function Shape.Line(X2, Y2, Options)
	local StatHandle = Stats.Begin('Line', 'Slab')

	Options = Options == nil and {} or Options
	Options.Width = Options.Width == nil and 1.0 or Options.Width
	Options.Color = Options.Color == nil and nil or Options.Color

	local X, Y = Cursor.GetPosition()
	local W, H = math.abs(X2 - X), math.abs(Y2 - Y)
	H = math.max(H, Options.Width)

	DrawCommands.Line(X, Y, X2, Y2, Options.Width, Options.Color)
	Window.AddItem(X, Y, W, H)
	Cursor.SetItemBounds(X, Y, W, H)
	Cursor.AdvanceY(H)

	Stats.End(StatHandle)
end

function Shape.Curve(Points, Options)
	local StatHandle = Stats.Begin('Curve', 'Slab')

	Options = Options == nil and {} or Options
	Options.Color = Options.Color == nil and nil or Options.Color
	Options.Depth = Options.Depth == nil and nil or Options.Depth

	Curve = love.math.newBezierCurve(Points)

	local MinX, MinY = math.huge, math.huge
	local MaxX, MaxY = 0, 0
	for I = 1, Curve:getControlPointCount(), 1 do
		local PX, PY = Curve:getControlPoint(I)
		MinX = math.min(MinX, PX)
		MinY = math.min(MinY, PY)

		MaxX = math.max(MaxX, PX)
		MaxY = math.max(MaxY, PY)
	end

	local W = math.abs(MaxX - MinX)
	local H = math.abs(MaxY - MinY)

	LayoutManager.AddControl(W, H)

	CurveX, CurveY = Cursor.GetPosition()
	Curve:translate(CurveX, CurveY)

	DrawCommands.Curve(Curve:render(Options.Depth), Options.Color)
	Window.AddItem(MinX, MinY, W, H)
	Cursor.SetItemBounds(MinX, MinY, W, H)
	Cursor.AdvanceY(H)

	Stats.End(StatHandle)
end

function Shape.GetCurveControlPointCount()
	if Curve ~= nil then
		return Curve:getControlPointCount()
	end

	return 0
end

function Shape.GetCurveControlPoint(Index, Options)
	Options = Options == nil and {} or Options
	Options.LocalSpace = Options.LocalSpace == nil and true or Options.LocalSpace

	local X, Y = 0, 0
	if Curve ~= nil then
		if Options.LocalSpace then
			Curve:translate(-CurveX, -CurveY)
		end

		X, Y = Curve:getControlPoint(Index)

		if Options.LocalSpace then
			Curve:translate(CurveX, CurveY)
		end
	end

	return X, Y
end

function Shape.EvaluateCurve(Time, Options)
	Options = Options == nil and {} or Options
	Options.LocalSpace = Options.LocalSpace == nil and true or Options.LocalSpace

	local X, Y = 0, 0
	if Curve ~= nil then
		if Options.LocalSpace then
			Curve:translate(-CurveX, -CurveY)
		end

		X, Y = Curve:evaluate(Time)

		if Options.LocalSpace then
			Curve:translate(CurveX, CurveY)
		end
	end

	return X, Y
end

function Shape.Polygon(Points, Options)
	local StatHandle = Stats.Begin('Polygon', 'Slab')

	Options = Options == nil and {} or Options
	Options.Color = Options.Color == nil and nil or Options.Color
	Options.Mode = Options.Mode == nil and 'fill' or Options.Mode

	local MinX, MinY = math.huge, math.huge
	local MaxX, MaxY = 0, 0
	local Verts = {}

	for I = 1, #Points, 2 do
		MinX = math.min(MinX, Points[I])
		MinY = math.min(MinY, Points[I+1])

		MaxX = math.max(MaxX, Points[I])
		MaxY = math.max(MaxY, Points[I+1])
	end

	local W = math.abs(MaxX - MinX)
	local H = math.abs(MaxY - MinY)

	LayoutManager.AddControl(W, H)

	MinX, MinY = math.huge, math.huge
	MaxX, MaxY = 0, 0
	local X, Y = Cursor.GetPosition()
	for I = 1, #Points, 2 do
		table.insert(Verts, Points[I] + X)
		table.insert(Verts, Points[I+1] + Y)

		MinX = math.min(MinX, Verts[I])
		MinY = math.min(MinY, Verts[I+1])

		MaxX = math.max(MaxX, Verts[I])
		MaxY = math.max(MaxY, Verts[I+1])
	end

	DrawCommands.Polygon(Options.Mode, Verts, Options.Color)
	Window.AddItem(MinX, MinY, W, H)
	Cursor.SetItemBounds(MinX, MinY, W, H)
	Cursor.AdvanceY(H)

	Stats.End(StatHandle)
end

return Shape
