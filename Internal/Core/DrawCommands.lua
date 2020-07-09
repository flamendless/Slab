--[[

MIT License

Copyright (c) 2019-2020 Mitchell Davis <coding.jackalope@gmail.com>

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

local Stats = require(SLAB_PATH .. ".Internal.Core.Stats")

local insert = table.insert
local remove = table.remove
local sin = math.sin
local cos = math.cos
local rad = math.rad

local DrawCommands = {}

local LayerTable = {}
local PendingBatches = {}
local ActiveBatch = nil
local Shaders = nil

local Types =
{
	Rect = 1,
	Triangle = 2,
	Text = 3,
	Scissor = 4,
	TransformPush = 5,
	TransformPop = 6,
	ApplyTransform = 7,
	Check = 8,
	Line = 9,
	TextFormatted = 10,
	IntersectScissor = 11,
	Cross = 12,
	Image = 13,
	SubImage = 14,
	Circle = 15,
	DrawCanvas = 16,
	Mesh = 17,
	TextObject = 18,
	Curve = 19,
	Polygon = 20,
	ShaderPush = 21,
	ShaderPop = 22
}

local Layers =
{
	Normal = 1,
	Dock = 2,
	ContextMenu = 3,
	MainMenuBar = 4,
	Dialog = 5,
	Debug = 6
}

local ActiveLayer = Layers.Normal
local StatsCategory = 'Slab Draw'

local function AddArc(Verts, CenterX, CenterY, Radius, Angle1, Angle2, Segments, X, Y)
	if Radius == 0 then
		insert(Verts, CenterX + X)
		insert(Verts, CenterY + Y)
		return
	end

	local Step = (Angle2 - Angle1) / Segments

	for Theta = Angle1, Angle2, Step do
		local Radians = rad(Theta)
		insert(Verts, sin(Radians) * Radius + CenterX + X)
		insert(Verts, cos(Radians) * Radius + CenterY + Y)
	end
end

local function GetLayerDebugInfo(Layer)
	local Result = {}

	Result['Channel Count'] = #Layer

	local Channels = {}
	for K, Channel in pairs(Layer) do
		local Collection = {}
		Collection['Batch Count'] = #Channel
		insert(Channels, Collection)
	end

	Result['Channels'] = Channels

	return Result
end

local function DrawRect(Rect)
	local StatHandle = Stats.Begin('DrawRect', StatsCategory)

	love.graphics.setColor(Rect.Color)
	love.graphics.rectangle(Rect.Mode, Rect.X, Rect.Y, Rect.Width, Rect.Height, Rect.Radius, Rect.Radius)

	Stats.End(StatHandle)
end

local function GetTriangleVertices(X, Y, Radius, Rotation)
	local Result = {}

	local Radians = rad(Rotation)

	local X1, Y1 = 0, -Radius
	local X2, Y2 = -Radius, Radius
	local X3, Y3 = Radius, Radius

	local PX1 = X1 * cos(Radians) - Y1 * sin(Radians)
	local PY1 = Y1 * cos(Radians) + X1 * sin(Radians)

	local PX2 = X2 * cos(Radians) - Y2 * sin(Radians)
	local PY2 = Y2 * cos(Radians) + X2 * sin(Radians)

	local PX3 = X3 * cos(Radians) - Y3 * sin(Radians)
	local PY3 = Y3 * cos(Radians) + X3 * sin(Radians)

	Result =
	{
		X + PX1, Y + PY1,
		X + PX2, Y + PY2,
		X + PX3, Y + PY3
	}
	
	return Result
end

local function DrawTriangle(Triangle)
	local StatHandle = Stats.Begin('DrawTriangle', StatsCategory)

	love.graphics.setColor(Triangle.Color)
	local Vertices = GetTriangleVertices(Triangle.X, Triangle.Y, Triangle.Radius, Triangle.Rotation)
	love.graphics.polygon(Triangle.Mode, Vertices)

	Stats.End(StatHandle)
end

local function DrawCheck(Check)
	local StatHandle = Stats.Begin('DrawCheck', StatsCategory)

	love.graphics.setColor(Check.Color)
	local Vertices =
	{
		Check.X - Check.Radius * 0.5, Check.Y,
		Check.X, Check.Y + Check.Radius,
		Check.X + Check.Radius, Check.Y - Check.Radius
	}
	love.graphics.line(Vertices)

	Stats.End(StatHandle)
end

local function DrawText(Text)
	local StatHandle = Stats.Begin('DrawText', StatsCategory)

	love.graphics.setFont(Text.Font)
	love.graphics.setColor(Text.Color)
	love.graphics.print(Text.Text, Text.X, Text.Y)

	Stats.End(StatHandle)
end

local function DrawTextFormatted(Text)
	local StatHandle = Stats.Begin('DrawTextFormatted', StatsCategory)

	love.graphics.setFont(Text.Font)
	love.graphics.setColor(Text.Color)
	love.graphics.printf(Text.Text, Text.X, Text.Y, Text.W, Text.Align)

	Stats.End(StatHandle)
end

local function DrawTextObject(Text)
	local StatHandle = Stats.Begin('DrawTextObject', StatsCategory)

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(Text.Text, Text.X, Text.Y)

	Stats.End(StatHandle)
end

local function DrawLine(Line)
	local StatHandle = Stats.Begin('DrawLine', StatsCategory)

	love.graphics.setColor(Line.Color)
	local LineW = love.graphics.getLineWidth()
	love.graphics.setLineWidth(Line.Width)
	love.graphics.line(Line.X1, Line.Y1, Line.X2, Line.Y2)
	love.graphics.setLineWidth(LineW)

	Stats.End(StatHandle)
end

local function DrawCross(Cross)
	local StatHandle = Stats.Begin('DrawCross', StatsCategory)

	local X, Y = Cross.X, Cross.Y
	local R = Cross.Radius
	love.graphics.setColor(Cross.Color)
	love.graphics.line(X - R, Y - R, X + R, Y + R)
	love.graphics.line(X - R, Y + R, X + R, Y - R)

	Stats.End(StatHandle)
end

local function DrawImage(Image)
	local StatHandle = Stats.Begin('DrawImage', StatsCategory)

	love.graphics.setColor(Image.Color)
	love.graphics.draw(Image.Image, Image.X, Image.Y, Image.Rotation, Image.ScaleX, Image.ScaleY)

	Stats.End(StatHandle)
end

local function DrawSubImage(Image)
	local StatHandle = Stats.Begin('DrawSubImage', StatsCategory)

	love.graphics.setColor(Image.Color)
	love.graphics.draw(Image.Image, Image.Quad, Image.Transform)

	Stats.End(StatHandle)
end

local function DrawCircle(Circle)
	local StatHandle = Stats.Begin('DrawCircle', StatsCategory)

	love.graphics.setColor(Circle.Color)
	love.graphics.circle(Circle.Mode, Circle.X, Circle.Y, Circle.Radius, Circle.Segments)

	Stats.End(StatHandle)
end

local function DrawCurve(Curve)
	local StatHandle = Stats.Begin('DrawCurve', StatsCategory)

	love.graphics.setColor(Curve.Color)
	love.graphics.line(Curve.Points)

	Stats.End(StatHandle)
end

local function DrawPolygon(Polygon)
	local StatHandle = Stats.Begin('DrawPolygon', StatsCategory)

	love.graphics.setColor(Polygon.Color)
	love.graphics.polygon(Polygon.Mode, Polygon.Points)

	Stats.End(StatHandle)
end

local function DrawCanvas(Canvas)
	local StatHandle = Stats.Begin('DrawCanvas', StatsCategory)

	love.graphics.setBlendMode('alpha', 'premultiplied')
	love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
	love.graphics.draw(Canvas.Canvas, Canvas.X, Canvas.Y)
	love.graphics.setBlendMode('alpha')

	Stats.End(StatHandle)
end

local function DrawMesh(Mesh)
	local StatHandle = Stats.Begin('DrawMesh', StatsCategory)

	love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
	love.graphics.draw(Mesh.Mesh, Mesh.X, Mesh.Y)

	Stats.End(StatHandle)
end

local function DrawElements(Elements)
	local StatHandle = Stats.Begin('Draw Elements', StatsCategory)

	for K, V in pairs(Elements) do
		if V.Type == Types.Rect then
			DrawRect(V)
		elseif V.Type == Types.Triangle then
			DrawTriangle(V)
		elseif V.Type == Types.Text then
			DrawText(V)
		elseif V.Type == Types.Scissor then
			love.graphics.setScissor(V.X, V.Y, V.W, V.H)
		elseif V.Type == Types.TransformPush then
			love.graphics.push()
		elseif V.Type == Types.TransformPop then
			love.graphics.pop()
		elseif V.Type == Types.ApplyTransform then
			love.graphics.applyTransform(V.Transform)
		elseif V.Type == Types.Check then
			DrawCheck(V)
		elseif V.Type == Types.Line then
			DrawLine(V)
		elseif V.Type == Types.TextFormatted then
			DrawTextFormatted(V)
		elseif V.Type == Types.IntersectScissor then
			love.graphics.intersectScissor(V.X, V.Y, V.W, V.H)
		elseif V.Type == Types.Cross then
			DrawCross(V)
		elseif V.Type == Types.Image then
			DrawImage(V)
		elseif V.Type == Types.SubImage then
			DrawSubImage(V)
		elseif V.Type == Types.Circle then
			DrawCircle(V)
		elseif V.Type == Types.DrawCanvas then
			DrawCanvas(V)
		elseif V.Type == Types.Mesh then
			DrawMesh(V)
		elseif V.Type == Types.TextObject then
			DrawTextObject(V)
		elseif V.Type == Types.Curve then
			DrawCurve(V)
		elseif V.Type == Types.Polygon then
			DrawPolygon(V)
		elseif V.Type == Types.ShaderPush then
			insert(Shaders, 1, V.Shader)
			love.graphics.setShader(V.Shader)
		elseif V.Type == Types.ShaderPop then
			remove(Shaders, 1)
			love.graphics.setShader(Shaders[1])
		end
	end

	Stats.End(StatHandle)
end

local function AssertActiveBatch()
	assert(ActiveBatch ~= nil, "DrawCommands.Begin was not called before commands were issued!")
end

local function DrawLayer(Layer, Name)
	if Layer.Channels == nil then
		return
	end

	local StatHandle = Stats.Begin('Draw Layer ' .. Name, StatsCategory)

	local Keys = {}
	for K, Channel in pairs(Layer.Channels) do
		insert(Keys, K)
	end

	table.sort(Keys)

	for Index, C in ipairs(Keys) do
		local Channel = Layer.Channels[C]
		if Channel ~= nil then
			for I, V in ipairs(Channel) do
				DrawElements(V.Elements)
			end
		end
	end

	Stats.End(StatHandle)
end

function DrawCommands.Reset()
	LayerTable = {}
	LayerTable[Layers.Normal] = {}
	LayerTable[Layers.Dock] = {}
	LayerTable[Layers.ContextMenu] = {}
	LayerTable[Layers.MainMenuBar] = {}
	LayerTable[Layers.Dialog] = {}
	LayerTable[Layers.Debug] = {}
	ActiveLayer = Layers.Normal
	PendingBatches = {}
	ActiveBatch = nil
	Shaders = {}
end

function DrawCommands.Begin(Options)
	Options = Options == nil and {} or Options
	Options.Channel = Options.Channel == nil and 1 or Options.Channel

	if LayerTable[ActiveLayer].Channels == nil then
		LayerTable[ActiveLayer].Channels = {}
	end

	if LayerTable[ActiveLayer].Channels[Options.Channel] == nil then
		LayerTable[ActiveLayer].Channels[Options.Channel] = {}
	end

	local Channel = LayerTable[ActiveLayer].Channels[Options.Channel]

	ActiveBatch = {}
	ActiveBatch.Elements = {}
	insert(Channel, ActiveBatch)
	insert(PendingBatches, 1, ActiveBatch)
end

function DrawCommands.End(ClearElements)
	ClearElements = ClearElements == nil and false or ClearElements

	if ActiveBatch ~= nil then
		if ClearElements then
			ActiveBatch.Elements = {}
		end

		love.graphics.setScissor()
		remove(PendingBatches, 1)

		ActiveBatch = nil
		if #PendingBatches > 0 then
			ActiveBatch = PendingBatches[1]
		end
	end
end

function DrawCommands.SetLayer(Layer)
	if Layer == 'Normal' then
		ActiveLayer = Layers.Normal
	elseif Layer == 'Dock' then
		ActiveLayer = Layers.Dock
	elseif Layer == 'ContextMenu' then
		ActiveLayer = Layers.ContextMenu
	elseif Layer == 'MainMenuBar' then
		ActiveLayer = Layers.MainMenuBar
	elseif Layer == 'Dialog' then
		ActiveLayer = Layers.Dialog
	elseif Layer == 'Debug' then
		ActiveLayer = Layers.Debug
	end
end

function DrawCommands.Rectangle(Mode, X, Y, Width, Height, Color, Radius, Segments)
	AssertActiveBatch()
	if type(Radius) == 'table' then
		Segments = Segments == nil and 10 or Segments

		local Verts = {}
		local TL = Radius[1]
		local TR = Radius[2]
		local BR = Radius[3]
		local BL = Radius[4]

		TL = TL == nil and 0 or TL
		TR = TR == nil and 0 or TR
		BR = BR == nil and 0 or BR
		BL = BL == nil and 0 or BL

		AddArc(Verts, Width - BR, Height - BR, BR, 0, 90, Segments, X, Y)
		AddArc(Verts, Width - TR, TR, TR, 90, 180, Segments, X, Y)
		AddArc(Verts, TL, TL, TL, 180, 270, Segments, X, Y)
		AddArc(Verts, BL, Height - BL, BL, 270, 360, Segments, X, Y)

		DrawCommands.Polygon(Mode, Verts, Color)
	else
		local Item = {}
		Item.Type = Types.Rect
		Item.Mode = Mode
		Item.X = X
		Item.Y = Y
		Item.Width = Width
		Item.Height = Height
		Item.Color = Color and Color or {0.0, 0.0, 0.0, 1.0}
		Item.Radius = Radius and Radius or 0.0
		insert(ActiveBatch.Elements, Item)
	end
end

function DrawCommands.Triangle(Mode, X, Y, Radius, Rotation, Color)
	AssertActiveBatch()
	local Item = {}
	Item.Type = Types.Triangle
	Item.Mode = Mode
	Item.X = X
	Item.Y = Y
	Item.Radius = Radius
	Item.Rotation = Rotation
	Item.Color = Color and Color or {0.0, 0.0, 0.0, 1.0}
	insert(ActiveBatch.Elements, Item)
end

function DrawCommands.Print(Text, X, Y, Color, Font)
	AssertActiveBatch()
	local Item = {}
	Item.Type = Types.Text
	Item.Text = Text
	Item.X = X
	Item.Y = Y
	Item.Color = Color and Color or {1.0, 1.0, 1.0, 1.0}
	Item.Font = Font
	insert(ActiveBatch.Elements, Item)
end

function DrawCommands.Printf(Text, X, Y, W, Align, Color, Font)
	AssertActiveBatch()
	local Item = {}
	Item.Type = Types.TextFormatted
	Item.Text = Text
	Item.X = X
	Item.Y = Y
	Item.W = W
	Item.Align = Align and Align or 'left'
	Item.Color = Color and Color or {1.0, 1.0, 1.0, 1.0}
	Item.Font = Font
	insert(ActiveBatch.Elements, Item)
end

function DrawCommands.Scissor(X, Y, W, H)
	AssertActiveBatch()
	if W ~= nil then
		assert(W >= 0.0, "Cannot set scissor with negative width.")
	end
	if H ~= nil then
		assert(H >= 0.0, "Cannot set scissor with negative height.")
	end
	local Item = {}
	Item.Type = Types.Scissor
	Item.X = X
	Item.Y = Y
	Item.W = W
	Item.H = H
	insert(ActiveBatch.Elements, Item)
end

function DrawCommands.IntersectScissor(X, Y, W, H)
	AssertActiveBatch()
	local Item = {}
	Item.Type = Types.IntersectScissor
	Item.X = X and X or 0.0
	Item.Y = Y and Y or 0.0
	Item.W = W and W or 0.0
	Item.H = H and H or 0.0
	insert(ActiveBatch.Elements, Item)
end

function DrawCommands.TransformPush()
	AssertActiveBatch()
	local Item = {}
	Item.Type = Types.TransformPush
	insert(ActiveBatch.Elements, Item)
end

function DrawCommands.TransformPop()
	AssertActiveBatch()
	local Item = {}
	Item.Type = Types.TransformPop
	insert(ActiveBatch.Elements, Item)
end

function DrawCommands.ApplyTransform(Transform)
	AssertActiveBatch()
	local Item = {}
	Item.Type = Types.ApplyTransform
	Item.Transform = Transform
	insert(ActiveBatch.Elements, Item)
end

function DrawCommands.Check(X, Y, Radius, Color)
	AssertActiveBatch()
	local Item = {}
	Item.Type = Types.Check
	Item.X = X
	Item.Y = Y
	Item.Radius = Radius
	Item.Color = Color and Color or {0.0, 0.0, 0.0, 1.0}
	insert(ActiveBatch.Elements, Item)
end

function DrawCommands.Line(X1, Y1, X2, Y2, Width, Color)
	AssertActiveBatch()
	local Item = {}
	Item.Type = Types.Line
	Item.X1 = X1
	Item.Y1 = Y1
	Item.X2 = X2
	Item.Y2 = Y2
	Item.Width = Width
	Item.Color = Color and Color or {0.0, 0.0, 0.0, 1.0}
	insert(ActiveBatch.Elements, Item)
end

function DrawCommands.Cross(X, Y, Radius, Color)
	AssertActiveBatch()
	local Item = {}
	Item.Type = Types.Cross
	Item.X = X
	Item.Y = Y
	Item.Radius = Radius
	Item.Color = Color and Color or {0.0, 0.0, 0.0, 1.0}
	insert(ActiveBatch.Elements, Item)
end

function DrawCommands.Image(X, Y, Image, Rotation, ScaleX, ScaleY, Color)
	AssertActiveBatch()
	local Item = {}
	Item.Type = Types.Image
	Item.X = X
	Item.Y = Y
	Item.Image = Image
	Item.Rotation = Rotation
	Item.ScaleX = ScaleX
	Item.ScaleY = ScaleY
	Item.Color = Color and Color or {1.0, 1.0, 1.0, 1.0}
	insert(ActiveBatch.Elements, Item)
end

function DrawCommands.SubImage(X, Y, Image, SX, SY, SW, SH, Rotation, ScaleX, ScaleY, Color)
	AssertActiveBatch()
	local Item = {}
	Item.Type = Types.SubImage
	Item.Transform = love.math.newTransform(X, Y, Rotation, ScaleX, ScaleY)
	Item.Image = Image
	Item.Quad = love.graphics.newQuad(SX, SY, SW, SH, Image:getWidth(), Image:getHeight())
	Item.Color = Color and Color or {1.0, 1.0, 1.0, 1.0}
	insert(ActiveBatch.Elements, Item)
end

function DrawCommands.Circle(Mode, X, Y, Radius, Color, Segments)
	AssertActiveBatch()
	local Item = {}
	Item.Type = Types.Circle
	Item.Mode = Mode
	Item.X = X
	Item.Y = Y
	Item.Radius = Radius
	Item.Color = Color and Color or {0.0, 0.0, 0.0, 1.0}
	Item.Segments = Segments and Segments or 24
	insert(ActiveBatch.Elements, Item)
end

function DrawCommands.DrawCanvas(Canvas, X, Y)
	AssertActiveBatch()
	local Item = {}
	Item.Type = Types.DrawCanvas
	Item.Canvas = Canvas
	Item.X = X
	Item.Y = Y
	insert(ActiveBatch.Elements, Item)
end

function DrawCommands.Mesh(Mesh, X, Y)
	AssertActiveBatch()
	local Item = {}
	Item.Type = Types.Mesh
	Item.Mesh = Mesh
	Item.X = X
	Item.Y = Y
	insert(ActiveBatch.Elements, Item)
end

function DrawCommands.Text(Text, X, Y)
	AssertActiveBatch()
	local Item = {}
	Item.Type = Types.TextObject
	Item.Text = Text
	Item.X = X
	Item.Y = Y
	Item.Color = {0, 0, 0, 1}
	insert(ActiveBatch.Elements, Item)
end

function DrawCommands.Curve(Points, Color)
	AssertActiveBatch()
	local Item = {}
	Item.Type = Types.Curve
	Item.Points = Points
	Item.Color = Color ~= nil and Color or {0, 0, 0, 1}
	insert(ActiveBatch.Elements, Item)
end

function DrawCommands.Polygon(Mode, Points, Color)
	AssertActiveBatch()
	local Item = {}
	Item.Type = Types.Polygon
	Item.Mode = Mode
	Item.Points = Points
	Item.Color = Color ~= nil and Color or {0, 0, 0, 1}
	insert(ActiveBatch.Elements, Item)
end

function DrawCommands.PushShader(Shader)
	AssertActiveBatch()
	local Item =
	{
		Type = Types.ShaderPush,
		Shader = Shader
	}
	insert(ActiveBatch.Elements, Item)
end

function DrawCommands.PopShader()
	AssertActiveBatch()
	local Item =
	{
		Type = Types.ShaderPop
	}
	insert(ActiveBatch.Elements, Item)
end

function DrawCommands.Execute()
	local StatHandle = Stats.Begin('Execute', StatsCategory)

	DrawLayer(LayerTable[Layers.Normal], 'Normal')
	DrawLayer(LayerTable[Layers.Dock], 'Dock')
	DrawLayer(LayerTable[Layers.ContextMenu], 'ContextMenu')
	DrawLayer(LayerTable[Layers.MainMenuBar], 'MainMenuBar')
	DrawLayer(LayerTable[Layers.Dialog], 'Dialog')
	DrawLayer(LayerTable[Layers.Debug], 'Debug')

	love.graphics.setShader()

	Stats.End(StatHandle)
end

function DrawCommands.GetDebugInfo()
	local Result = {}

	Result['Normal'] = GetLayerDebugInfo(LayerTable[Layers.Normal])
	Result['Dock'] = GetLayerDebugInfo(LayerTable[Layers.Dock])
	Result['ContextMenu'] = GetLayerDebugInfo(LayerTable[Layers.ContextMenu])
	Result['MainMenuBar'] = GetLayerDebugInfo(LayerTable[Layers.MainMenuBar])
	Result['Dialog'] = GetLayerDebugInfo(LayerTable[Layers.Dialog])
	Result['Debug'] = GetLayerDebugInfo(LayerTable[Layers.Debug])

	return Result
end

return DrawCommands
