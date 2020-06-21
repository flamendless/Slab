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

local floor = math.floor
local insert = table.insert

local Cursor = require(SLAB_PATH .. '.Internal.Core.Cursor')
local DrawCommands = require(SLAB_PATH .. '.Internal.Core.DrawCommands')
local LayoutManager = require(SLAB_PATH .. '.Internal.UI.LayoutManager')
local Mouse = require(SLAB_PATH .. '.Internal.Input.Mouse')
local Stats = require(SLAB_PATH .. '.Internal.Core.Stats')
local Style = require(SLAB_PATH .. '.Style')
local Window = require(SLAB_PATH .. '.Internal.UI.Window')

local Text = {}

function Text.Begin(Label, Options)
	local StatHandle = Stats.Begin('Text', 'Slab')

	Options = Options == nil and {} or Options
	Options.Color = Options.Color == nil and Style.TextColor or Options.Color
	Options.Pad = Options.Pad == nil and 0.0 or Options.Pad
	Options.IsSelectable = Options.IsSelectable == nil and false or Options.IsSelectable
	Options.IsSelectableTextOnly = Options.IsSelectableTextOnly == nil and false or Options.IsSelectableTextOnly
	Options.IsSelected = Options.IsSelected == nil and false or Options.IsSelected
	Options.AddItem = Options.AddItem == nil and true or Options.AddItem
	Options.HoverColor = Options.HoverColor == nil and Style.TextHoverBgColor or Options.HoverColor
	Options.URL = Options.URL == nil and nil or Options.URL

	if Options.URL ~= nil then
		Options.IsSelectableTextOnly = true
		Options.Color = Style.TextURLColor
	end

	local W = Text.GetWidth(Label)
	local H = Style.Font:getHeight()
	local PadX = Options.Pad

	LayoutManager.AddControl(W + PadX, H)

	local Color = Options.Color
	local Result = false
	local WinId = Window.GetItemId(Label)
	local X, Y = Cursor.GetPosition()
	local MouseX, MouseY = Window.GetMousePosition()

	local IsObstructed = Window.IsObstructedAtMouse()

	if not IsObstructed and X <= MouseX and MouseX <= X + W and Y <= MouseY and MouseY <= Y + H then
		Window.SetHotItem(WinId)
	end

	local WinX, WinY, WinW, WinH = Window.GetBounds()
	local CheckX = Options.IsSelectableTextOnly and X or WinX
	local CheckW = Options.IsSelectableTextOnly and W or WinW
	local Hovered = not IsObstructed and CheckX <= MouseX and MouseX <= CheckX + CheckW + PadX and Y <= MouseY and MouseY <= Y + H

	if Options.IsSelectable or Options.IsSelected then
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

	if Hovered and Options.URL ~= nil then
		Mouse.SetCursor('hand')

		if Mouse.IsClicked(1) then
			love.system.openURL(Options.URL)
		end
	end

	DrawCommands.Print(Label, floor(X + PadX * 0.5), floor(Y), Color, Style.Font)

	if Options.URL ~= nil then
		DrawCommands.Line(X + PadX, Y + H, X + W, Y + H, 1.0, Color)
	end

	Cursor.SetItemBounds(X, Y, W + PadX, H)
	Cursor.AdvanceY(H)

	if Options.AddItem then
		Window.AddItem(X, Y, W + PadX, H, WinId)
	end

	Stats.End(StatHandle)

	return Result
end

function Text.BeginFormatted(Label, Options)
	local StatHandle = Stats.Begin('Textf', 'Slab')

	local WinW, WinH = Window.GetBorderlessSize()

	Options = Options == nil and {} or Options
	Options.Color = Options.Color == nil and Style.TextColor or Options.Color
	Options.W = Options.W == nil and WinW or Options.W
	Options.Align = Options.Align == nil and 'left' or Options.Align

	if Window.IsAutoSize() then
		Options.W = love.graphics.getWidth()
	end

	local Width, Wrapped = Style.Font:getWrap(Label, Options.W)
	local H = #Wrapped * Style.Font:getHeight()

	LayoutManager.AddControl(Width, H)

	local X, Y = Cursor.GetPosition()

	DrawCommands.Printf(Label, floor(X), floor(Y), Width, Options.Align, Options.Color, Style.Font)

	Cursor.SetItemBounds(floor(X), floor(Y), Width, H)
	Cursor.AdvanceY(H)

	Window.ResetContentSize()
	Window.AddItem(floor(X), floor(Y), Width, H)

	Stats.End(StatHandle)
end

function Text.BeginObject(Object, Options)
	local StatHandle = Stats.Begin('TextObject', 'Slab')

	local WinW, WinH = Window.GetBorderlessSize()

	Options = Options == nil and {} or Options
	Options.Color = Options.Color == nil and Style.TextColor or Options.Color

	local W, H = Object:getDimensions()

	LayoutManager.AddControl(W, H)

	local X, Y = Cursor.GetPosition()

	DrawCommands.Text(Object, floor(X), floor(Y), Options.Color)

	Cursor.SetItemBounds(floor(X), floor(Y), W, H)
	Cursor.AdvanceY(Y)

	Window.ResetContentSize()
	Window.AddItem(floor(X), floor(Y), W, H)

	Stats.End(StatHandle)
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
		insert(Lines, "")
	end

	if #Lines == 0 then
		insert(Lines, "")
	end

	return Lines
end

function Text.CreateObject()
	return love.graphics.newText(Style.Font)
end

return Text
