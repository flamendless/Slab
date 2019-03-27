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

local Style = require(SLAB_PATH .. ".Style")

local DrawCommands = {}

local Batches = {}
local PendingBatches = {}
local ActiveBatch = nil

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
	SubImage = 14
}

local Layers =
{
	Normal = 1,
	Focused = 2,
	ContextMenu = 3,
	MainMenuBar = 4,
	Dialog = 5,
	Debug = 6
}

local ActiveLayer = Layers.Normal

local function GetLayerDebugInfo(Batch)
	local Result = {}

	Result['Channel Count'] = #Batch

	local Channels = {}
	for K, Channel in pairs(Batch) do
		local Collection = {}
		Collection['Batch Count'] = #Channel
		table.insert(Channels, Collection)
	end

	Result['Channels'] = Channels

	return Result
end

local function DrawRect(Rect)
	love.graphics.setColor(Rect.Color)
	love.graphics.rectangle(Rect.Mode, Rect.X, Rect.Y, Rect.Width, Rect.Height)
end

local function GetTriangleVertices(X, Y, Radius, Direction)
	local Result = {}

	if Direction == 'north' then
		Result = 
		{
			X, Y - Radius,
			X - Radius, Y + Radius,
			X + Radius, Y + Radius
		}
	elseif Direction == 'east' then
		Result = 
		{
			X + Radius, Y,
			X - Radius, Y - Radius,
			X - Radius, Y + Radius
		}
	elseif Direction == 'south' then
		Result = 
		{
			X, Y + Radius,
			X + Radius, Y - Radius,
			X - Radius, Y - Radius
		}
	elseif Direction == 'west' then
		Result = 
		{
			X - Radius, Y,
			X + Radius, Y + Radius,
			X + Radius, Y - Radius
		}
	else
		assert(false, "Invalid direction given: " .. Direction)
	end

	return Result
end

local function DrawTriangle(Triangle)
	love.graphics.setColor(Triangle.Color)
	local Vertices = GetTriangleVertices(Triangle.X, Triangle.Y, Triangle.Radius, Triangle.Direction)
	love.graphics.polygon(Triangle.Mode, Vertices)
end

local function DrawCheck(Check)
	love.graphics.setColor(Check.Color)
	local Vertices =
	{
		Check.X - Check.Radius * 0.5, Check.Y,
		Check.X, Check.Y + Check.Radius,
		Check.X + Check.Radius, Check.Y - Check.Radius
	}
	love.graphics.line(Vertices)
end

local function DrawText(Text)
	love.graphics.setFont(Style.Font)
	love.graphics.setColor(Text.Color)
	love.graphics.print(Text.Text, Text.X, Text.Y)
end

local function DrawTextFormatted(Text)
	love.graphics.setFont(Style.Font)
	love.graphics.setColor(Text.Color)
	love.graphics.printf(Text.Text, Text.X, Text.Y, Text.W, Text.Align)
end

local function DrawLine(Line)
	love.graphics.setColor(Line.Color)
	local LineW = love.graphics.getLineWidth()
	love.graphics.setLineWidth(Line.Width)
	love.graphics.line(Line.X1, Line.Y1, Line.X2, Line.Y2)
	love.graphics.setLineWidth(LineW)
end

local function DrawCross(Cross)
	local X, Y = Cross.X, Cross.Y
	local R = Cross.Radius
	love.graphics.setColor(Cross.Color)
	love.graphics.line(X - R, Y - R, X + R, Y + R)
	love.graphics.line(X - R, Y + R, X + R, Y - R)
end

local function DrawImage(Image)
	love.graphics.setColor(Image.Color)
	love.graphics.draw(Image.Image, Image.X, Image.Y, Image.Rotation, Image.ScaleX, Image.ScaleY)
end

local function DrawSubImage(Image)
	love.graphics.setColor(Image.Color)
	love.graphics.draw(Image.Image, Image.Quad, Image.Transform)
end

local function DrawElements(Elements)
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
		end
	end
end

local function AssertActiveBatch()
	assert(ActiveBatch ~= nil, "DrawCommands.Begin was not called before commands were issued!")
end

local function DrawBatch(Batch, Layer)
	if Batch.Channels == nil then
		return
	end

	local Keys = {}
	for K, Channel in pairs(Batch.Channels) do
		table.insert(Keys, K)
	end

	table.sort(Keys)

	for Index, C in ipairs(Keys) do
		local Channel = Batch.Channels[C]
		if Channel ~= nil then
			for I, V in ipairs(Channel) do
				DrawElements(V.Elements)
			end
		end
	end
end

function DrawCommands.Reset()
	Batches = {}
	Batches[Layers.Normal] = {}
	Batches[Layers.Focused] = {}
	Batches[Layers.ContextMenu] = {}
	Batches[Layers.MainMenuBar] = {}
	Batches[Layers.Dialog] = {}
	Batches[Layers.Debug] = {}
	ActiveLayer = Layers.Normal
	PendingBatches = {}
	ActiveBatch = nil
end

function DrawCommands.Begin(Options)
	Options = Options == nil and {} or Options
	Options.Channel = Options.Channel == nil and 1 or Options.Channel

	if Batches[ActiveLayer].Channels == nil then
		Batches[ActiveLayer].Channels = {}
	end

	if Batches[ActiveLayer].Channels[Options.Channel] == nil then
		Batches[ActiveLayer].Channels[Options.Channel] = {}
	end

	local Channel = Batches[ActiveLayer].Channels[Options.Channel]

	ActiveBatch = {}
	ActiveBatch.Elements = {}
	table.insert(Channel, ActiveBatch)
	table.insert(PendingBatches, 1, ActiveBatch)
end

function DrawCommands.End()
	if ActiveBatch ~= nil then
		love.graphics.setScissor()
		table.remove(PendingBatches, 1)

		ActiveBatch = nil
		if #PendingBatches > 0 then
			ActiveBatch = PendingBatches[1]
		end
	end
end

function DrawCommands.SetLayer(Layer)
	if Layer == 'Normal' then
		ActiveLayer = Layers.Normal
	elseif Layer == 'Focused' then
		ActiveLayer = Layers.Focused
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

function DrawCommands.Rectangle(Mode, X, Y, Width, Height, Color)
	AssertActiveBatch()
	local Item = {}
	Item.Type = Types.Rect
	Item.Mode = Mode
	Item.X = X
	Item.Y = Y
	Item.Width = Width
	Item.Height = Height
	Item.Color = Color and Color or {0.0, 0.0, 0.0, 1.0}
	table.insert(ActiveBatch.Elements, Item)
end

function DrawCommands.Triangle(Mode, X, Y, Radius, Direction, Color)
	AssertActiveBatch()
	local Item = {}
	Item.Type = Types.Triangle
	Item.Mode = Mode
	Item.X = X
	Item.Y = Y
	Item.Radius = Radius
	Item.Direction = Direction
	Item.Color = Color and Color or {0.0, 0.0, 0.0, 1.0}
	table.insert(ActiveBatch.Elements, Item)
end

function DrawCommands.Print(Text, X, Y, Color)
	AssertActiveBatch()
	local Item = {}
	Item.Type = Types.Text
	Item.Text = Text
	Item.X = X
	Item.Y = Y
	Item.Color = Color and Color or {1.0, 1.0, 1.0, 1.0}
	table.insert(ActiveBatch.Elements, Item)
end

function DrawCommands.Printf(Text, X, Y, W, Align, Color)
	AssertActiveBatch()
	local Item = {}
	Item.Type = Types.TextFormatted
	Item.Text = Text
	Item.X = X
	Item.Y = Y
	Item.W = W
	Item.Align = Align and Align or 'left'
	Item.Color = Color and Color or {1.0, 1.0, 1.0, 1.0}
	table.insert(ActiveBatch.Elements, Item)
end

function DrawCommands.Scissor(X, Y, W, H)
	AssertActiveBatch()
	local Item = {}
	Item.Type = Types.Scissor
	Item.X = X
	Item.Y = Y
	Item.W = W
	Item.H = H
	table.insert(ActiveBatch.Elements, Item)
end

function DrawCommands.IntersectScissor(X, Y, W, H)
	AssertActiveBatch()
	local Item = {}
	Item.Type = Types.IntersectScissor
	Item.X = X and X or 0.0
	Item.Y = Y and Y or 0.0
	Item.W = W and W or 0.0
	Item.H = H and H or 0.0
	table.insert(ActiveBatch.Elements, Item)
end

function DrawCommands.TransformPush()
	AssertActiveBatch()
	local Item = {}
	Item.Type = Types.TransformPush
	table.insert(ActiveBatch.Elements, Item)
end

function DrawCommands.TransformPop()
	AssertActiveBatch()
	local Item = {}
	Item.Type = Types.TransformPop
	table.insert(ActiveBatch.Elements, Item)
end

function DrawCommands.ApplyTransform(Transform)
	AssertActiveBatch()
	local Item = {}
	Item.Type = Types.ApplyTransform
	Item.Transform = Transform
	table.insert(ActiveBatch.Elements, Item)
end

function DrawCommands.Check(X, Y, Radius, Color)
	AssertActiveBatch()
	local Item = {}
	Item.Type = Types.Check
	Item.X = X
	Item.Y = Y
	Item.Radius = Radius
	Item.Color = Color and Color or {0.0, 0.0, 0.0, 1.0}
	table.insert(ActiveBatch.Elements, Item)
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
	table.insert(ActiveBatch.Elements, Item)
end

function DrawCommands.Cross(X, Y, Radius, Color)
	AssertActiveBatch()
	local Item = {}
	Item.Type = Types.Cross
	Item.X = X
	Item.Y = Y
	Item.Radius = Radius
	Item.Color = Color and Color or {0.0, 0.0, 0.0, 1.0}
	table.insert(ActiveBatch.Elements, Item)
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
	table.insert(ActiveBatch.Elements, Item)
end

function DrawCommands.SubImage(X, Y, Image, SX, SY, SW, SH, Rotation, ScaleX, ScaleY, Color)
	AssertActiveBatch()
	local Item = {}
	Item.Type = Types.SubImage
	Item.Transform = love.math.newTransform(X, Y, Rotation, ScaleX, ScaleY)
	Item.Image = Image
	Item.Quad = love.graphics.newQuad(SX, SY, SW, SH, Image:getWidth(), Image:getHeight())
	Item.Color = Color and Color or {1.0, 1.0, 1.0, 1.0}
	table.insert(ActiveBatch.Elements, Item)
end

function DrawCommands.Execute()
	DrawBatch(Batches[Layers.Normal], 'Normal')
	DrawBatch(Batches[Layers.Focused], 'Focused')
	DrawBatch(Batches[Layers.ContextMenu], 'ContextMenu')
	DrawBatch(Batches[Layers.MainMenuBar], 'MainMenuBar')
	DrawBatch(Batches[Layers.Dialog], 'Dialog')
	DrawBatch(Batches[Layers.Debug], 'Debug')
end

function DrawCommands.GetDebugInfo()
	local Result = {}

	Result['Normal'] = GetLayerDebugInfo(Batches[Layers.Normal])
	Result['Focused'] = GetLayerDebugInfo(Batches[Layers.Focused])
	Result['ContextMenu'] = GetLayerDebugInfo(Batches[Layers.ContextMenu])
	Result['MainMenuBar'] = GetLayerDebugInfo(Batches[Layers.MainMenuBar])
	Result['Dialog'] = GetLayerDebugInfo(Batches[Layers.Dialog])
	Result['Debug'] = GetLayerDebugInfo(Batches[Layers.Debug])

	return Result
end

return DrawCommands
