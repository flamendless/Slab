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

local ceil = math.ceil
local max = math.max
local min = math.min
local insert = table.insert
local unpack = table.unpack

local Button = require(SLAB_PATH .. '.Internal.UI.Button')
local Cursor = require(SLAB_PATH .. '.Internal.Core.Cursor')
local DrawCommands = require(SLAB_PATH .. '.Internal.Core.DrawCommands')
local Image = require(SLAB_PATH .. '.Internal.UI.Image')
local Input = require(SLAB_PATH .. '.Internal.UI.Input')
local LayoutManager = require(SLAB_PATH .. '.Internal.UI.LayoutManager')
local Mouse = require(SLAB_PATH .. '.Internal.Input.Mouse')
local Style = require(SLAB_PATH .. '.Style')
local Text = require(SLAB_PATH .. '.Internal.UI.Text')
local Utility = require(SLAB_PATH .. '.Internal.Core.Utility')
local Window = require(SLAB_PATH .. '.Internal.UI.Window')

local ColorPicker = {}

local SaturationMeshes = nil
local SaturationSize = 200.0
local SaturationStep = 5
local SaturationFocused = false

local TintMeshes = nil
local TintW = 30.0
local TintH = SaturationSize
local TintFocused = false

local AlphaMesh = nil
local AlphaW = TintW
local AlphaH = TintH
local AlphaFocused = false

local CurrentColor = {1.0, 1.0, 1.0, 1.0}
local ColorH = 25.0

local function IsEqual(A, B)
	for I, V in ipairs(A) do
		if V ~= B[I] then
			return false
		end
	end

	return true
end

local function InputColor(Component, Value, OffsetX)
	local Changed = false
	Text.Begin(string.format("%s ", Component))
	Cursor.SameLine()
	Cursor.SetRelativeX(OffsetX)
	if Input.Begin('ColorPicker_' .. Component, {W = 40.0, NumbersOnly = true, Text = tostring(ceil(Value * 255)), ReturnOnText = false}) then
		local NewValue = tonumber(Input.GetText())
		if NewValue ~= nil then
			NewValue = max(NewValue, 0)
			NewValue = min(NewValue, 255)
			Value = NewValue / 255
			Changed = true
		end
	end
	return Value, Changed
end

local function UpdateSaturationColors()
	if SaturationMeshes ~= nil then
		local MeshIndex = 1
		local Step = SaturationStep
		local C00 = {1.0, 1.0, 1.0, 1.0}
		local C10 = {1.0, 1.0, 1.0, 1.0}
		local C01 = {1.0, 1.0, 1.0, 1.0}
		local C11 = {1.0, 1.0, 1.0, 1.0}
		local StepX, StepY = 0, 0
		local Hue, Sat, Val = Utility.RGBtoHSV(CurrentColor[1], CurrentColor[2], CurrentColor[3])

		for I = 1, Step, 1 do
			for J = 1, Step, 1 do
				local S0 = StepX / Step
				local S1 = (StepX + 1) / Step
				local V0 = 1.0 - (StepY / Step)
				local V1 = 1.0 - ((StepY + 1) / Step)

				C00[1], C00[2], C00[3] = Utility.HSVtoRGB(Hue, S0, V0)
				C10[1], C10[2], C10[3] = Utility.HSVtoRGB(Hue, S1, V0)
				C01[1], C01[2], C01[3] = Utility.HSVtoRGB(Hue, S0, V1)
				C11[1], C11[2], C11[3] = Utility.HSVtoRGB(Hue, S1, V1)

				local Mesh = SaturationMeshes[MeshIndex]
				MeshIndex = MeshIndex + 1

				Mesh:setVertexAttribute(1, 3, C00[1], C00[2], C00[3], C00[4])
				Mesh:setVertexAttribute(2, 3, C10[1], C10[2], C10[3], C10[4])
				Mesh:setVertexAttribute(3, 3, C11[1], C11[2], C11[3], C11[4])
				Mesh:setVertexAttribute(4, 3, C01[1], C01[2], C01[3], C01[4])

				StepX = StepX + 1
			end

			StepX = 0
			StepY = StepY + 1
		end
	end
end

local function InitializeSaturationMeshes()
	if SaturationMeshes == nil then
		SaturationMeshes = {}
		local Step = SaturationStep
		local X, Y = 0.0, 0.0
		local Size = SaturationSize / Step

		for I = 1, Step, 1 do
			for J = 1, Step, 1 do
				local Verts = {
					{
						X, Y,
						0.0, 0.0
					},
					{
						X + Size, Y,
						1.0, 0.0
					},
					{
						X + Size, Y + Size,
						1.0, 1.0
					},
					{
						X, Y + Size,
						0.0, 1.0
					}
				}

				local NewMesh = love.graphics.newMesh(Verts)
				insert(SaturationMeshes, NewMesh)

				X = X + Size
			end

			X = 0.0
			Y = Y + Size
		end
	end

	UpdateSaturationColors()
end

local function InitializeTintMeshes()
	if TintMeshes == nil then
		TintMeshes = {}
		local Step = 6
		local X, Y = 0.0, 0.0
		local C0 = {1.0, 1.0, 1.0, 1.0}
		local C1 = {1.0, 1.0, 1.0, 1.0}
		local I = 0
		local Colors = {
			{1.0, 0.0, 0.0, 1.0},
			{1.0, 1.0, 0.0, 1.0},
			{0.0, 1.0, 0.0, 1.0},
			{0.0, 1.0, 1.0, 1.0},
			{0.0, 0.0, 1.0, 1.0},
			{1.0, 0.0, 1.0, 1.0},
			{1.0, 0.0, 0.0, 1.0}
		}

		for Index = 1, Step, 1 do
			C0 = Colors[Index]
			C1 = Colors[Index + 1]
			local Verts = {
				{
					X, Y,
					0.0, 0.0,
					C0[1], C0[2], C0[3], C0[4]
				},
				{
					TintW, Y,
					1.0, 0.0,
					C0[1], C0[2], C0[3], C0[4]
				},
				{
					TintW, Y + TintH / Step,
					1.0, 1.0,
					C1[1], C1[2], C1[3], C1[4]
				},
				{
					X, Y + TintH / Step,
					0.0, 1.0,
					C1[1], C1[2], C1[3], C1[4]
				}
			}

			local NewMesh = love.graphics.newMesh(Verts)
			insert(TintMeshes, NewMesh)

			Y = Y + TintH / Step
		end
	end
end

local function InitializeAlphaMesh()
	if AlphaMesh == nil then
		local Verts = {
			{
				0.0, 0.0,
				0.0, 0.0,
				1.0, 1.0, 1.0, 1.0
			},
			{
				AlphaW, 0.0,
				1.0, 0.0,
				1.0, 1.0, 1.0, 1.0
			},
			{
				AlphaW, AlphaH,
				1.0, 1.0,
				0.0, 0.0, 0.0, 1.0
			},
			{
				0.0, AlphaH,
				0.0, 1.0,
				0.0, 0.0, 0.0, 1.0
			}
		}

		AlphaMesh = love.graphics.newMesh(Verts)
	end
end

function ColorPicker.Begin(Options)
	Options = Options == nil and {} or Options
	Options.Color = Options.Color == nil and {1.0, 1.0, 1.0, 1.0} or Options.Color
	Options.Refresh = Options.Refresh == nil and false or Options.Refresh
	Options.X = Options.X == nil and nil or Options.X
	Options.Y = Options.Y == nil and nil or Options.Y

	if SaturationMeshes == nil then
		InitializeSaturationMeshes()
	end

	if TintMeshes == nil then
		InitializeTintMeshes()
	end

	if AlphaMesh == nil then
		InitializeAlphaMesh()
	end

	Window.Begin('ColorPicker', {Title = "Color Picker", X = Options.X, Y = Options.Y})

	if Window.IsAppearing() or Options.Refresh then
		CurrentColor[1] = Options.Color[1] or 0.0
		CurrentColor[2] = Options.Color[2] or 0.0
		CurrentColor[3] = Options.Color[3] or 0.0
		CurrentColor[4] = Options.Color[4] or 1.0
		UpdateSaturationColors()
	end

	local X, Y = Cursor.GetPosition()
	local MouseX, MouseY = Window.GetMousePosition()
	local H, S, V = Utility.RGBtoHSV(CurrentColor[1], CurrentColor[2], CurrentColor[3])
	local UpdateColor = false
	local MouseClicked = Mouse.IsClicked(1) and not Window.IsObstructedAtMouse()

	if SaturationMeshes ~= nil then
		for I, V in ipairs(SaturationMeshes) do
			DrawCommands.Mesh(V, X, Y)
		end

		Window.AddItem(X, Y, SaturationSize, SaturationSize)

		local UpdateSaturation = false
		if X <= MouseX and MouseX < X + SaturationSize and Y <= MouseY and MouseY < Y + SaturationSize then
			if MouseClicked then
				SaturationFocused = true
				UpdateSaturation = true
			end
		end

		if SaturationFocused and Mouse.IsDragging(1) then
			UpdateSaturation = true
		end

		if UpdateSaturation then
			local CanvasX = max(MouseX - X, 0)
			CanvasX = min(CanvasX, SaturationSize)

			local CanvasY = max(MouseY - Y, 0)
			CanvasY = min(CanvasY, SaturationSize)

			S = CanvasX / SaturationSize
			V = 1 - (CanvasY / SaturationSize)

			UpdateColor = true
		end

		local SaturationX = S * SaturationSize
		local SaturationY = (1.0 - V) * SaturationSize
		DrawCommands.Circle('line', X + SaturationX, Y + SaturationY, 4.0, {1.0, 1.0, 1.0, 1.0})

		X = X + SaturationSize + Cursor.PadX()
	end

	if TintMeshes ~= nil then
		for I, V in ipairs(TintMeshes) do
			DrawCommands.Mesh(V, X, Y)
		end

		Window.AddItem(X, Y, TintW, TintH)

		local UpdateTint = false
		if X <= MouseX and MouseX < X + TintW and Y <= MouseY and MouseY < Y + TintH then
			if MouseClicked then
				TintFocused = true
				UpdateTint = true
			end
		end

		if TintFocused and Mouse.IsDragging(1) then
			UpdateTint = true
		end

		if UpdateTint then
			local CanvasY = max(MouseY - Y, 0)
			CanvasY = min(CanvasY, TintH)

			H = CanvasY / TintH

			UpdateColor = true
		end

		local TintY = H * TintH
		DrawCommands.Line(X, Y + TintY, X + TintW, Y + TintY, 2.0, {1.0, 1.0, 1.0, 1.0})

		X = X + TintW + Cursor.PadX()
		DrawCommands.Mesh(AlphaMesh, X, Y)
		Window.AddItem(X, Y, AlphaW, AlphaH)

		local UpdateAlpha = false
		if X <= MouseX and MouseX < X + AlphaW and Y <= MouseY and MouseY < Y + AlphaH then
			if MouseClicked then
				AlphaFocused = true
				UpdateAlpha = true
			end
		end

		if AlphaFocused and Mouse.IsDragging(1) then
			UpdateAlpha = true
		end

		if UpdateAlpha then
			local CanvasY = max(MouseY - Y, 0)
			CanvasY = min(CanvasY, AlphaH)

			CurrentColor[4] = 1.0 - CanvasY / AlphaH

			UpdateColor = true
		end

		local A = 1.0 - CurrentColor[4]
		local AlphaY = A * AlphaH
		DrawCommands.Line(X, Y + AlphaY, X + AlphaW, Y + AlphaY, 2.0, {A, A, A, 1.0})

		Y = Y + AlphaH + Cursor.PadY()
	end

	if UpdateColor then
		CurrentColor[1], CurrentColor[2], CurrentColor[3] = Utility.HSVtoRGB(H, S, V)
		UpdateSaturationColors()
	end

	local OffsetX = Text.GetWidth("##")
	Cursor.AdvanceY(SaturationSize)
	X, Y = Cursor.GetPosition()
	local R = CurrentColor[1]
	local G = CurrentColor[2]
	local B = CurrentColor[3]
	local A = CurrentColor[4]

	CurrentColor[1], R = InputColor("R", R, OffsetX)
	CurrentColor[2], G = InputColor("G", G, OffsetX)
	CurrentColor[3], B = InputColor("B", B, OffsetX)
	CurrentColor[4], A = InputColor("A", A, OffsetX)

	if R or G or B or A then
		UpdateSaturationColors()
	end

	local InputX, InputY = Cursor.GetPosition()
	Cursor.SameLine()
	X = Cursor.GetX()
	Cursor.SetY(Y)

	local WinX, WinY, WinW, WinH = Window.GetBounds()
	WinW, WinH = Window.GetBorderlessSize()

	OffsetX = Text.GetWidth("####")
	local ColorX = X + OffsetX

	local ColorW = (WinX + WinW) - ColorX
	Cursor.SetPosition(ColorX, Y)
	Image.Begin('ColorPicker_CurrentAlpha', {
		Path = SLAB_FILE_PATH .. "/Internal/Resources/Textures/Transparency.png",
		SubW = ColorW,
		SubH = ColorH,
		WrapH = "repeat",
		WrapV = "repeat"
	})
	DrawCommands.Rectangle('fill', ColorX, Y, ColorW, ColorH, CurrentColor, Style.ButtonRounding)

	local LabelW, LabelH = Text.GetSize("New")
	Cursor.SetPosition(ColorX - LabelW - Cursor.PadX(), Y + (ColorH * 0.5) - (LabelH * 0.5))
	Text.Begin("New")

	Y = Y + ColorH + Cursor.PadY()

	Cursor.SetPosition(ColorX, Y)
	Image.Begin('ColorPicker_CurrentAlpha', {
		Path = SLAB_FILE_PATH .. "/Internal/Resources/Textures/Transparency.png",
		SubW = ColorW,
		SubH = ColorH,
		WrapH = "repeat",
		WrapV = "repeat"
	})
	DrawCommands.Rectangle('fill', ColorX, Y, ColorW, ColorH, Options.Color, Style.ButtonRounding)

	local LabelW, LabelH = Text.GetSize("Old")
	Cursor.SetPosition(ColorX - LabelW - Cursor.PadX(), Y + (ColorH * 0.5) - (LabelH * 0.5))
	Text.Begin("Old")

	if Mouse.IsReleased(1) then
		SaturationFocused = false
		TintFocused = false
		AlphaFocused = false
	end

	Cursor.SetPosition(InputX, InputY)
	Cursor.NewLine()

	LayoutManager.Begin('ColorPicker_Buttons_Layout', {AlignX = 'right'})
	local Result = {Button = 0, Color = Utility.MakeColor(CurrentColor)}
	if Button.Begin("OK") then
		Result.Button = 1
	end

	LayoutManager.SameLine()

	if Button.Begin("Cancel") then
		Result.Button = -1
		Result.Color = Utility.MakeColor(Options.Color)
	end
	LayoutManager.End()

	Window.End()

	return Result
end

return ColorPicker
