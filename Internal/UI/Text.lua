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
local Layout = require(SLAB_PATH .. '.Internal.UI.Layout')
local Mouse = require(SLAB_PATH .. '.Internal.Input.Mouse')
local Stats = require(SLAB_PATH .. '.Internal.Core.Stats')
local Style = require(SLAB_PATH .. '.Style')
local Window = require(SLAB_PATH .. '.Internal.UI.Window')

local Text = {}

function Text.Begin(Label, Options)
	Stats.Begin('Text')

	Options = Options == nil and {} or Options
	Options.Color = Options.Color == nil and Style.TextColor or Options.Color
	Options.Pad = Options.Pad == nil and 0.0 or Options.Pad
	Options.AddItem = Options.AddItem == nil and true or Options.AddItem
	Options.HoverColor = Options.HoverColor == nil and Style.TextHoverBgColor or Options.HoverColor
	Options.CenterX = Options.CenterX == nil and false or Options.CenterX

	local X, Y = Cursor.GetPosition()
	local W = Text.GetWidth(Label)
	local H = Style.Font:getHeight()
	local Color = Options.Color
	local Result = false
	local PadX = Options.Pad
	local WinId = Window.GetItemId(Label)
	local MouseX, MouseY = Window.GetMousePosition()

	if Options.CenterX then
		X = Layout.CenterX(W)
	end

	local IsObstructed = Window.IsObstructedAtMouse()

	if not IsObstructed and X <= MouseX and MouseX <= X + W and Y <= MouseY and MouseY <= Y + H then
		Window.SetHotItem(WinId)
	end

	if Options.IsSelectable or Options.IsSelected then
		local WinX, WinY, WinW, WinH = Window.GetBounds()
		
		local CheckX = Options.IsSelectableTextOnly and X or WinX
		local CheckW = Options.IsSelectableTextOnly and W or WinW

		local Hovered = not IsObstructed and CheckX <= MouseX and MouseX <= CheckX + CheckW + PadX and Y <= MouseY and MouseY <= Y + H

		if Hovered or Options.IsSelected then
			DrawCommands.Rectangle('fill', CheckX, Y, CheckW + PadX, H, Options.HoverColor)
		end

		if Hovered then
			if Options.SelectOnHover then
				Result = true
			else
				if Mouse.IsClicked(1) then
					Result = true
				end
			end
		end
	end

	DrawCommands.Print(Label, math.floor(X + PadX * 0.5), math.floor(Y), Color, Style.Font)

	Cursor.SetItemBounds(X, Y, W + PadX, H)
	Cursor.AdvanceY(H)

	if Options.AddItem then
		Window.AddItem(X, Y, W + PadX, H, WinId)
	end

	Stats.End('Text')

	return Result
end

function Text.BeginFormatted(Label, Options)
	Stats.Begin('Textf')

	local WinW, WinH = Window.GetBorderlessSize()

	Options = Options == nil and {} or Options
	Options.Color = Options.Color == nil and Style.TextColor or Options.Color
	Options.W = Options.W == nil and WinW or Options.W
	Options.Align = Options.Align == nil and 'left' or Options.Align

	local X, Y = Cursor.GetPosition()

	DrawCommands.Printf(Label, math.floor(X), math.floor(Y), Options.W, Options.Align, Options.Color, Style.Font)

	local Width, Wrapped = Style.Font:getWrap(Label, Options.W)
	local H = #Wrapped * Style.Font:getHeight()

	Cursor.SetItemBounds(math.floor(X), math.floor(Y), Width, H)
	Cursor.AdvanceY(H)

	Window.ResetContentSize()
	Window.AddItem(math.floor(X), math.floor(Y), Width, H)

	Stats.End('Textf')
end

function Text.BeginObject(Object, Options)
	local WinW, WinH = Window.GetBorderlessSize()

	Options = Options == nil and {} or Options
	Options.Color = Options.Color == nil and Style.TextColor or Options.Color

	local X, Y = Cursor.GetPosition()
	local W, H = Object:getDimensions()

	DrawCommands.Text(Object, math.floor(X), math.floor(Y), Options.Color)

	Cursor.SetItemBounds(math.floor(X), math.floor(Y), W, H)
	Cursor.AdvanceY(Y)

	Window.ResetContentSize()
	Window.AddItem(math.floor(X), math.floor(Y), W, H)
end

function Text.GetWidth(Label)
	return Style.Font:getWidth(Label)
end

function Text.GetHeight()
	return Style.Font:getHeight()
end

function Text.GetSize(Label)
	return Style.Font:getWidth(Label), Style.Font:getHeight()
end

function Text.GetSizeWrap(Label, Width)
	local W, Lines = Style.Font:getWrap(Label, Width)
	return W, #Lines * Text.GetHeight()
end

function Text.GetLines(Label, Width)
	local W, Lines = Style.Font:getWrap(Label, Width)

	local Start = 0
	for I, V in ipairs(Lines) do
		if #V == 0 then
			Lines[I] = "\n"
		else
			local Offset = Start + #V + 1
			local Ch = string.sub(Label, Offset, Offset)

			if Ch == '\n' then
				Lines[I] = Lines[I] .. "\n"
			end
		end

		Start = Start + #Lines[I]
	end

	if string.sub(Label, #Label, #Label) == '\n' then
		table.insert(Lines, "")
	end

	if #Lines == 0 then
		table.insert(Lines, "")
	end

	return Lines
end

function Text.CreateObject()
	return love.graphics.newText(Style.Font)
end

return Text
