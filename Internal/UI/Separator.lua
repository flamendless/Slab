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

local Cursor = require(SLAB_PATH .. ".Internal.Core.Cursor")
local DrawCommands = require(SLAB_PATH .. ".Internal.Core.DrawCommands")
local LayoutManager = require(SLAB_PATH .. ".Internal.UI.LayoutManager")
local Style = require(SLAB_PATH .. ".Style")
local Window = require(SLAB_PATH .. ".Internal.UI.Window")

local Separator = {}
local STR_TITLE = "Separator"

local TBL_DEF = {
	IncludeBorders = false,
	H = 4,
	Thickness = 1,
}

function Separator.Begin(opt)
	opt = opt or TBL_DEF
	opt.IncludeBorders = opt.IncludeBorders or TBL_DEF.IncludeBorders
	opt.H = opt.H or TBL_DEF.H
	opt.Thickness = opt.Thickness or TBL_DEF.Thickness
	local w, h = LayoutManager.GetActiveSize()
	w, h = LayoutManager.ComputeSize(w, max(opt.H, opt.Thickness))
	LayoutManager.AddControl(w, h, STR_TITLE)
	local x, y = Cursor.GetPosition()

	if opt.IncludeBorders then
		w = w + Window.GetBorder() * 2
		x = x - Window.GetBorder()
	end

	DrawCommands.Line(x, y + h * 0.5, x + w, y + h * 0.5, opt.Thickness, Style.SeparatorColor)
	Cursor.SetItemBounds(x, y, w, h)
	Cursor.AdvanceY(h)
end

return Separator
