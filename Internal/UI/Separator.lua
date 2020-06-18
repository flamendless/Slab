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

local Cursor = require(SLAB_PATH .. '.Internal.Core.Cursor')
local DrawCommands = require(SLAB_PATH .. '.Internal.Core.DrawCommands')
local Style = require(SLAB_PATH .. '.Style')
local Window = require(SLAB_PATH .. '.Internal.UI.Window')

local Separator = {}
local SIZE_Y = 4.0

function Separator.Begin(Options)
	Options = Options == nil and {} or Options
	Options.IncludeBorders = Options.IncludeBorders == nil and false or Options.IncludeBorders
	Options.H = Options.H == nil and SIZE_Y or Options.H
	Options.Thickness = Options.Thickness == nil and 1.0 or Options.Thickness

	local X, Y = Cursor.GetPosition()
	local W, H = 0.0, 0.0

	if Options.IncludeBorders then
		local WinX, WinY, WinW, WinH = Window.GetBounds()
		X = WinX
		W = WinW
	else
		W, H = Window.GetBorderlessSize()
	end

	H = math.max(Options.H, Options.Thickness)

	DrawCommands.Line(X, Y + H * 0.5, X + W, Y + H * 0.5, Options.Thickness, Style.SeparatorColor)

	Cursor.SetItemBounds(X, Y, W, H)
	Cursor.AdvanceY(H)
end

return Separator
