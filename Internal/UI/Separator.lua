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

local max = math.max

local Cursor = require(SLAB_PATH .. '.Internal.Core.Cursor')
local DrawCommands = require(SLAB_PATH .. '.Internal.Core.DrawCommands')
local LayoutManager = require(SLAB_PATH .. '.Internal.UI.LayoutManager')
local Style = require(SLAB_PATH .. '.Style')
local Window = require(SLAB_PATH .. '.Internal.UI.Window')

local Separator = {}

function Separator.Begin(Options)
	Options = Options == nil and {} or Options
	Options.IncludeBorders = Options.IncludeBorders == nil and false or Options.IncludeBorders
	Options.H = Options.H == nil and 4.0 or Options.H
	Options.Thickness = Options.Thickness == nil and 1.0 or Options.Thickness

	local W, H = LayoutManager.GetActiveSize()
	W, H = LayoutManager.ComputeSize(W, max(Options.H, Options.Thickness))
	LayoutManager.AddControl(W, H, 'Separator')
	local X, Y = Cursor.GetPosition()

	if Options.IncludeBorders then
		W = W + Window.GetBorder() * 2
		X = X - Window.GetBorder()
	end

	DrawCommands.Line(X, Y + H * 0.5, X + W, Y + H * 0.5, Options.Thickness, Style.SeparatorColor)

	Cursor.SetItemBounds(X, Y, W, H)
	Cursor.AdvanceY(H)
end

return Separator
