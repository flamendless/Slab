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
local Window = require(SLAB_PATH .. '.Internal.UI.Window')

local Layout = {}

function Layout.AlignRight(W)
	local X, Y = Cursor.GetPosition()
	local WinX, WinY, WinW, WinH = Window.GetBounds()
	local ContentW, ContentH = Window.GetBorderlessSize()

	local Offset = WinX + ContentW
	local RightPad = 0.0

	if ContentW > WinW then
		Offset = WinX + ContentW
	end

	local ItemX, ItemY, ItemW, ItemH = Cursor.GetItemBounds()
	if ItemY == Y then
		Offset = ItemX
		RightPad = Cursor.PadX()
	end

	return Offset - W - RightPad
end

function Layout.CenterX(W)
	local X, Y = Cursor.GetPosition()
	local WinW, WinH = Window.GetBorderlessSize()

	return X + (WinW * 0.5) - (W * 0.5)
end

return Layout
