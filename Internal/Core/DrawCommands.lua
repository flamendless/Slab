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

local Stats = require(SLAB_PATH .. ".Internal.Core.Stats")
local TablePool = require(SLAB_PATH .. ".Internal.Core.TablePool")
local Scale = require(SLAB_PATH .. ".Internal.Core.Scale")

local insert = table.insert
local remove = table.remove
local sin = math.sin
local cos = math.cos
local rad = math.rad
local max = math.max
local min = math.min
local graphics = love.graphics

local DrawCommands = {}

local PendingBatches = {}
local ActiveBatch = nil
local Shaders = {}

local EMPTY = {}
local BLACK = { 0, 0, 0, 1 }
local WHITE = { 1, 1, 1, 1 }

local TypeRect = 1
local TypeTriangle = 2
local TypeText = 3
local TypeScissor = 4
local TypeTransformPush = 5
local TypeTransformPop = 6
local TypeApplyTransform = 7
local TypeCheck = 8
local TypeLine = 9
local TypeTextFormatted = 10
local TypeIntersectScissor = 11
local TypeCross = 12
local TypeImage = 13
local TypeSubImage = 14
local TypeCircle = 15
local TypeDrawCanvas = 16
local TypeMesh = 17
local TypeTextObject = 18
local TypeCurve = 19
local TypePolygon = 20
local TypeShaderPush = 21
local TypeShaderPop = 22

local LayerNormal = 1
local LayerDock = 2
local LayerContextMenu = 3
local LayerMainMenuBar = 4
local LayerDialog = 5
local LayerDebug = 6
local LayerMouse = 7

local LayerNames = {
	Normal = LayerNormal,
	Dock = LayerDock,
	ContextMenu = LayerContextMenu,
	MainMenuBar = LayerMainMenuBar,
	Dialog = LayerDialog,
	Debug = LayerDebug,
	Mouse = LayerMouse,
}

local LayerTable = { {}, {}, {}, {}, {}, {}, {} }

local ActiveLayer = LayerNormal
local StatsCategory = 'Slab Draw'

local pool = {}
for i = TypeRect, TypeShaderPop do
	pool[i] = TablePool()
end

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

local function DrawRect(Rect)
	local StatHandle = Stats.Begin('DrawRect', StatsCategory)

	local LineW = graphics.getLineWidth()
	graphics.setLineWidth(Rect.LineW)
	graphics.setColor(Rect.Color)
	local pixelOffset = Rect.Mode == 'line' and .5 or 0
	graphics.rectangle(Rect.Mode, Rect.X + pixelOffset, Rect.Y + pixelOffset, Rect.Width, Rect.Height, Rect.Radius, Rect.Radius)
	graphics.setLineWidth(LineW)

	Stats.End(StatHandle)
end

local function GetTriangleVertices(X, Y, Radius, Rotation)
	local Radians = rad(Rotation)

	local cs, sn = cos(Radians), sin(Radians)

	local X1, Y1 = 0, -Radius
	local X2, Y2 = -Radius, Radius
	local X3, Y3 = Radius, Radius

	local PX1 = X1 * cs - Y1 * sn
	local PY1 = Y1 * cs + X1 * sn

	local PX2 = X2 * cs - Y2 * sn
	local PY2 = Y2 * cs + X2 * sn

	local PX3 = X3 * cs - Y3 * sn
	local PY3 = Y3 * cs + X3 * sn

	return X + PX1, Y + PY1, X + PX2, Y + PY2, X + PX3, Y + PY3
end

local function DrawTriangle(Triangle)
	local StatHandle = Stats.Begin('DrawTriangle', StatsCategory)

	graphics.setColor(Triangle.Color)
	graphics.polygon(Triangle.Mode, GetTriangleVertices(Triangle.X, Triangle.Y, Triangle.Radius, Triangle.Rotation))

	Stats.End(StatHandle)
end

local function DrawCheck(Check)
	local StatHandle = Stats.Begin('DrawCheck', StatsCategory)

	graphics.setColor(Check.Color)
	graphics.line(
		Check.X - Check.Radius * 0.5, Check.Y,
		Check.X, Check.Y + Check.Radius,
		Check.X + Check.Radius, Check.Y - Check.Radius
	)

	Stats.End(StatHandle)
end

local function DrawText(Text)
	local StatHandle = Stats.Begin('DrawText', StatsCategory)

	graphics.setFont(Text.Font)
	graphics.setColor(Text.Color)
	graphics.print(Text.Text, Text.X, Text.Y)

	Stats.End(StatHandle)
end

local function DrawTextFormatted(Text)
	local StatHandle = Stats.Begin('DrawTextFormatted', StatsCategory)

	graphics.setFont(Text.Font)
	graphics.setColor(Text.Color)
	graphics.printf(Text.Text, Text.X, Text.Y, Text.W, Text.Align)

	Stats.End(StatHandle)
end

local function DrawTextObject(Text)
	local StatHandle = Stats.Begin('DrawTextObject', StatsCategory)

	graphics.setColor(1, 1, 1, 1)
	graphics.draw(Text.Text, Text.X, Text.Y)

	Stats.End(StatHandle)
end

local function DrawLine(Line)
	local StatHandle = Stats.Begin('DrawLine', StatsCategory)

	graphics.setColor(Line.Color)
	local LineW = graphics.getLineWidth()
	graphics.setLineWidth(Line.Width)
	graphics.line(Line.X1, Line.Y1, Line.X2, Line.Y2)
	graphics.setLineWidth(LineW)

	Stats.End(StatHandle)
end

local function DrawCross(Cross)
	local StatHandle = Stats.Begin('DrawCross', StatsCategory)

	local X, Y = Cross.X, Cross.Y
	local R = Cross.Radius
	graphics.setColor(Cross.Color)
	graphics.line(X - R, Y - R, X + R, Y + R)
	graphics.line(X - R, Y + R, X + R, Y - R)

	Stats.End(StatHandle)
end

local function DrawImage(Image)
	local StatHandle = Stats.Begin('DrawImage', StatsCategory)

	graphics.setColor(Image.Color)
	graphics.draw(Image.Image, Image.X, Image.Y, Image.Rotation, Image.ScaleX, Image.ScaleY)

	Stats.End(StatHandle)
end

local function DrawSubImage(Image)
	local StatHandle = Stats.Begin('DrawSubImage', StatsCategory)

	graphics.setColor(Image.Color)
	graphics.draw(Image.Image, Image.Quad, Image.Transform)

	Stats.End(StatHandle)
end

local function DrawCircle(Circle)
	local StatHandle = Stats.Begin('DrawCircle', StatsCategory)

	graphics.setColor(Circle.Color)
	graphics.circle(Circle.Mode, Circle.X, Circle.Y, Circle.Radius, Circle.Segments)

	Stats.End(StatHandle)
end

local function DrawCurve(Curve)
	local StatHandle = Stats.Begin('DrawCurve', StatsCategory)

	graphics.setColor(Curve.Color)
	graphics.line(Curve.Points)

	Stats.End(StatHandle)
end

local function DrawPolygon(Polygon)
	local StatHandle = Stats.Begin('DrawPolygon', StatsCategory)

	graphics.setColor(Polygon.Color)
	graphics.polygon(Polygon.Mode, Polygon.Points)

	Stats.End(StatHandle)
end

local function DrawCanvas(Canvas)
	local StatHandle = Stats.Begin('DrawCanvas', StatsCategory)

	graphics.setBlendMode('alpha', 'premultiplied')
	graphics.setColor(1.0, 1.0, 1.0, 1.0)
	graphics.draw(Canvas.Canvas, Canvas.X, Canvas.Y)
	graphics.setBlendMode('alpha')

	Stats.End(StatHandle)
end

local function DrawMesh(Mesh)
	local StatHandle = Stats.Begin('DrawMesh', StatsCategory)

	graphics.setColor(1.0, 1.0, 1.0, 1.0)
	graphics.draw(Mesh.Mesh, Mesh.X, Mesh.Y)

	Stats.End(StatHandle)
end

local function ShaderPush(shader)
	insert(Shaders, 1, shader.Shader)
	graphics.setShader(shader.Shader)
end

local function ShaderPop()
	remove(Shaders, 1)
	graphics.setShader(Shaders[1])
end

local function SetScissor(rect)
	graphics.setScissor(rect.X, rect.Y, rect.W, rect.H)
end

local function TransformPush()
	graphics.push()
end

local function TransformPop()
	graphics.pop()
end

local function ApplyTransform(transform)
	graphics.applyTransform(transform.Transform)
end

local function IntersectScissor(rect)
	graphics.intersectScissor(rect.X, rect.Y, rect.W, rect.H)
end

local DRAWTYPES = {
	DrawRect,
	DrawTriangle,
	DrawText,
	SetScissor,
	TransformPush,
	TransformPop,
	ApplyTransform,
	DrawCheck,
	DrawLine,
	DrawTextFormatted,
	IntersectScissor,
	DrawCross,
	DrawImage,
	DrawSubImage,
	DrawCircle,
	DrawCanvas,
	DrawMesh,
	DrawTextObject,
	DrawCurve,
	DrawPolygon,
	ShaderPush,
	ShaderPop,
}

local function DrawElements(Elements)
	local StatHandle = Stats.Begin('Draw Elements', StatsCategory)

	for i = 1, #Elements do
		local element = Elements[i]
		DRAWTYPES[element.Type](element)
	end

	Stats.End(StatHandle)
end

local function DrawChannel(channel)
	for i = 1, #channel do
		DrawElements(channel[i])
	end
end

local function ClearBatch(batch)
	for i = 1, #batch do
		pool[batch[i].Type]:push(batch[i])
		batch[i] = nil
	end
end

local function AssertActiveBatch()
	assert(ActiveBatch ~= nil, "DrawCommands.Begin was not called before commands were issued!")
end

local function DrawLayer(Layer, Name)
	if Layer == nil then
		return
	end

	local StatHandle = Stats.Begin('Draw Layer ' .. Name, StatsCategory)

	local minChannel, maxChannel = 1e9, 0
	for i in pairs(Layer) do
		minChannel, maxChannel = min(minChannel, i), max(maxChannel, i)
	end

	for i = minChannel, maxChannel do
		if Layer[i] then
			DrawChannel(Layer[i])
		end
	end

	Stats.End(StatHandle)
end

function DrawCommands.Reset()
	for i = LayerNormal, LayerMouse do
		local layer = LayerTable[i]
		for j, channel in pairs(layer) do
			for i, batch in ipairs(channel) do
				ClearBatch(batch)
			end
			layer[j] = nil
		end
	end

	ActiveLayer = LayerNormal
	ActiveBatch = nil
	for i in ipairs(Shaders) do
		Shaders[i] = nil
	end
end

function DrawCommands.Begin(channel)
	local layer = LayerTable[ActiveLayer]
	channel = channel or 1

	if layer[channel] == nil then
		layer[channel] = {}
	end

	ActiveBatch = {}
	insert(layer[channel], ActiveBatch)
	insert(PendingBatches, ActiveBatch)
end

function DrawCommands.End(clearElements)
	if ActiveBatch == nil then return end

	if clearElements then
		ClearBatch(ActiveBatch)
	end

	graphics.setScissor()
	remove(PendingBatches)

	ActiveBatch = PendingBatches[#PendingBatches]
end

function DrawCommands.SetLayer(Layer)
	ActiveLayer = LayerNames[Layer]
end

function DrawCommands.Rectangle(Mode, X, Y, Width, Height, Color, Radius, Segments, LineW)
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
		local Item = pool[TypeRect]:pull()
		Item.Type = TypeRect
		Item.Mode = Mode
		Item.X = X
		Item.Y = Y
		Item.Width = Width
		Item.Height = Height
		Item.Color = Color or BLACK
		Item.Radius = Radius or 0
		Item.LineW = LineW or graphics.getLineWidth()
		insert(ActiveBatch, Item)
	end
end

function DrawCommands.Triangle(Mode, X, Y, Radius, Rotation, Color)
	AssertActiveBatch()
	local Item = pool[TypeTriangle]:pull()
	Item.Type = TypeTriangle
	Item.Mode = Mode
	Item.X = X
	Item.Y = Y
	Item.Radius = Radius
	Item.Rotation = Rotation
	Item.Color = Color or BLACK
	insert(ActiveBatch, Item)
end

function DrawCommands.Print(Text, X, Y, Color, Font)
	AssertActiveBatch()
	local Item = pool[TypeText]:pull()
	Item.Type = TypeText
	Item.Text = Text
	Item.X = X
	Item.Y = Y
	Item.Color = Color or WHITE
	Item.Font = Font
	insert(ActiveBatch, Item)
end

function DrawCommands.Printf(Text, X, Y, W, Align, Color, Font)
	AssertActiveBatch()
	local Item = pool[TypeTextFormatted]:pull()
	Item.Type = TypeTextFormatted
	Item.Text = Text
	Item.X = X
	Item.Y = Y
	Item.W = W
	Item.Align = Align or 'left'
	Item.Color = Color or WHITE
	Item.Font = Font
	insert(ActiveBatch, Item)
end

function DrawCommands.Scissor(X, Y, W, H)
	AssertActiveBatch()
	if W ~= nil then
		W = max(W, 0.0)
	end
	if H ~= nil then
		H = max(H, 0.0)
	end
	local SF = Scale.GetScale()
	local Item = pool[TypeScissor]:pull()
	Item.Type = TypeScissor
	if X then X = X * SF end
	if Y then Y = Y * SF end
	if W then W = W * SF end
	if H then H = H * SF end
	Item.X = X
	Item.Y = Y
	Item.W = W
	Item.H = H
	insert(ActiveBatch, Item)
end

function DrawCommands.IntersectScissor(X, Y, W, H)
	AssertActiveBatch()
	if W ~= nil then
		W = max(W, 0.0)
	end
	if H ~= nil then
		H = max(H, 0.0)
	end
	local SF = Scale.GetScale()
	local Item = pool[TypeIntersectScissor]:pull()
	Item.Type = TypeIntersectScissor
	Item.X = (X or 0.0) * SF
	Item.Y = (Y or 0.0) * SF
	Item.W = (W or 0.0) * SF
	Item.H = (H or 0.0) * SF
	insert(ActiveBatch, Item)
end

function DrawCommands.TransformPush()
	AssertActiveBatch()
	local Item = pool[TypeTransformPush]:pull()
	Item.Type = TypeTransformPush
	insert(ActiveBatch, Item)
end

function DrawCommands.TransformPop()
	AssertActiveBatch()
	local Item = pool[TypeTransformPop]:pull()
	Item.Type = TypeTransformPop
	insert(ActiveBatch, Item)
end

function DrawCommands.ApplyTransform(Transform)
	AssertActiveBatch()
	local Item = pool[TypeApplyTransform]:pull()
	Item.Type = TypeApplyTransform
	Item.Transform = Transform
	insert(ActiveBatch, Item)
end

function DrawCommands.Check(X, Y, Radius, Color)
	AssertActiveBatch()
	local Item = pool[TypeCheck]:pull()
	Item.Type = TypeCheck
	Item.X = X
	Item.Y = Y
	Item.Radius = Radius
	Item.Color = Color or BLACK
	insert(ActiveBatch, Item)
end

function DrawCommands.Line(X1, Y1, X2, Y2, Width, Color)
	AssertActiveBatch()
	local Item = pool[TypeLine]:pull()
	Item.Type = TypeLine
	Item.X1 = X1
	Item.Y1 = Y1
	Item.X2 = X2
	Item.Y2 = Y2
	Item.Width = Width
	Item.Color = Color or BLACK
	insert(ActiveBatch, Item)
end

function DrawCommands.Cross(X, Y, Radius, Color)
	AssertActiveBatch()
	local Item = pool[TypeCross]:pull()
	Item.Type = TypeCross
	Item.X = X
	Item.Y = Y
	Item.Radius = Radius
	Item.Color = Color or BLACK
	insert(ActiveBatch, Item)
end

function DrawCommands.Image(X, Y, Image, Rotation, ScaleX, ScaleY, Color)
	AssertActiveBatch()
	local Item = pool[TypeImage]:pull()
	Item.Type = TypeImage
	Item.X = X
	Item.Y = Y
	Item.Image = Image
	Item.Rotation = Rotation
	Item.ScaleX = ScaleX
	Item.ScaleY = ScaleY
	Item.Color = Color or WHITE
	insert(ActiveBatch, Item)
end

function DrawCommands.SubImage(X, Y, Image, SX, SY, SW, SH, Rotation, ScaleX, ScaleY, Color)
	AssertActiveBatch()
	local Item = pool[TypeSubImage]:pull()
	Item.Type = TypeSubImage
	Item.Transform = love.math.newTransform(X, Y, Rotation, ScaleX, ScaleY)
	Item.Image = Image
	Item.Quad = graphics.newQuad(SX, SY, SW, SH, Image:getWidth(), Image:getHeight())
	Item.Color = Color or WHITE
	insert(ActiveBatch, Item)
end

function DrawCommands.Circle(Mode, X, Y, Radius, Color, Segments)
	AssertActiveBatch()
	local Item = pool[TypeCircle]:pull()
	Item.Type = TypeCircle
	Item.Mode = Mode
	Item.X = X
	Item.Y = Y
	Item.Radius = Radius
	Item.Color = Color or BLACK
	Item.Segments = Segments and Segments or 24
	insert(ActiveBatch, Item)
end

function DrawCommands.DrawCanvas(Canvas, X, Y)
	AssertActiveBatch()
	local Item = pool[TypeDrawCanvas]:pull()
	Item.Type = TypeDrawCanvas
	Item.Canvas = Canvas
	Item.X = X
	Item.Y = Y
	insert(ActiveBatch, Item)
end

function DrawCommands.Mesh(Mesh, X, Y)
	AssertActiveBatch()
	local Item = pool[TypeMesh]:pull()
	Item.Type = TypeMesh
	Item.Mesh = Mesh
	Item.X = X
	Item.Y = Y
	insert(ActiveBatch, Item)
end

function DrawCommands.Text(Text, X, Y)
	AssertActiveBatch()
	local Item = pool[TypeTextObject]:pull()
	Item.Type = TypeTextObject
	Item.Text = Text
	Item.X = X
	Item.Y = Y
	Item.Color = BLACK
	insert(ActiveBatch, Item)
end

function DrawCommands.Curve(Points, Color)
	AssertActiveBatch()
	local Item = pool[TypeCurve]:pull()
	Item.Type = TypeCurve
	Item.Points = Points
	Item.Color = Color or BLACK
	insert(ActiveBatch, Item)
end

function DrawCommands.Polygon(Mode, Points, Color)
	AssertActiveBatch()
	local Item = pool[TypePolygon]:pull()
	Item.Type = TypePolygon
	Item.Mode = Mode
	Item.Points = Points
	Item.Color = Color or BLACK
	insert(ActiveBatch, Item)
end

function DrawCommands.PushShader(Shader)
	AssertActiveBatch()
	local Item = pool[TypeShaderPush]:pull()
	Item.Type = TypeShaderPush
	Item.Shader = Shader
	insert(ActiveBatch, Item)
end

function DrawCommands.PopShader()
	AssertActiveBatch()
	local Item = pool[TypeShaderPop]:pull()
	Item.Type = TypeShaderPop
	insert(ActiveBatch, Item)
end

function DrawCommands.Execute()
	local StatHandle = Stats.Begin('Execute', StatsCategory)

	graphics.scale(Scale.GetScale())

	DrawLayer(LayerTable[LayerNormal], 'Normal')
	DrawLayer(LayerTable[LayerDock], 'Dock')
	DrawLayer(LayerTable[LayerContextMenu], 'ContextMenu')
	DrawLayer(LayerTable[LayerMainMenuBar], 'MainMenuBar')
	DrawLayer(LayerTable[LayerDialog], 'Dialog')
	DrawLayer(LayerTable[LayerDebug], 'Debug')
	DrawLayer(LayerTable[LayerMouse], 'Mouse')

	graphics.setShader()

	Stats.End(StatHandle)
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

function DrawCommands.GetDebugInfo()
	local Result = {}

	Result['Normal'] = GetLayerDebugInfo(LayerTable[LayerNormal])
	Result['Dock'] = GetLayerDebugInfo(LayerTable[LayerDock])
	Result['ContextMenu'] = GetLayerDebugInfo(LayerTable[LayerContextMenu])
	Result['MainMenuBar'] = GetLayerDebugInfo(LayerTable[LayerMainMenuBar])
	Result['Dialog'] = GetLayerDebugInfo(LayerTable[LayerDialog])
	Result['Debug'] = GetLayerDebugInfo(LayerTable[LayerDebug])
	Result['Mouse'] = GetLayerDebugInfo(LayerTable[LayerMouse])

	return Result
end

return DrawCommands
