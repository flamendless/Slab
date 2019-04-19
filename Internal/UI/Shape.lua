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
local Window = require(SLAB_PATH .. '.Internal.UI.Window')

local Shape = {}

function Shape.Rectangle(Options)
	Options = Options == nil and {} or Options
	Options.Mode = Options.Mode == nil and 'fill' or Options.Mode
	Options.W = Options.W == nil and 32 or Options.W
	Options.H = Options.H == nil and 32 or Options.H
	Options.Color = Options.Color == nil and nil or Options.Color
	Options.Rounding = Options.Rounding == nil and 2.0 or Options.Rounding
	Options.Outline = Options.Outline == nil and false or Options.Outline
	Options.OutlineColor = Options.OutlineColor == nil and {0.0, 0.0, 0.0, 1.0} or Options.OutlineColor

	local X, Y = Cursor.GetPosition()

	if Options.Outline and Options.Mode == 'fill' then
		DrawCommands.Rectangle('line', X, Y, Options.W, Options.H, Options.OutlineColor, Options.Rounding)
	end

	DrawCommands.Rectangle(Options.Mode, X, Y, Options.W, Options.H, Options.Color, Options.Rounding)
	Window.AddItem(X, Y, Options.W, Options.H)
	Cursor.AdvanceY(Options.H)
end

return Shape
