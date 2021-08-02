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

local Utility = require(SLAB_PATH .. '.Internal.Core.Utility')

local Cursor = {}

local min = math.min
local max = math.max

local State =
{
	X = 0.0,
	Y = 0.0,
	PrevX = 0.0,
	PrevY = 0.0,
	AnchorX = 0.0,
	AnchorY = 0.0,
	ItemX = 0.0,
	ItemY = 0.0,
	ItemW = 0.0,
	ItemH = 0.0,
	PadX = 4.0,
	PadY = 4.0,
	NewLineSize = 16.0,
	LineY = 0.0,
	LineH = 0.0,
	PrevLineY = 0.0,
	PrevLineH = 0.0
}

local Stack = {}

function Cursor.SetPosition(X, Y)
	State.PrevX = State.X
	State.PrevY = State.Y
	State.X = X
	State.Y = Y
end

function Cursor.SetX(X)
	State.PrevX = State.X
	State.X = X
end

function Cursor.SetY(Y)
	State.PrevY = State.Y
	State.Y = Y
end

function Cursor.SetRelativePosition(X, Y)
	State.PrevX = State.X
	State.PrevY = State.Y
	State.X = State.AnchorX + X
	State.Y = State.AnchorY + Y
end

function Cursor.SetRelativeX(X)
	State.PrevX = State.X
	State.X = State.AnchorX + X
end

function Cursor.SetRelativeY(Y)
	State.PrevY = State.Y
	State.Y = State.AnchorY + Y
end

function Cursor.AdvanceX(X)
	State.PrevX = State.X
	State.X = State.X + X + State.PadX
end

function Cursor.AdvanceY(Y)
	State.X = State.AnchorX
	State.PrevY = State.Y
	State.Y = State.Y + Y + State.PadY
	State.PrevLineY = State.LineY
	State.PrevLineH = State.LineH
	State.LineY = 0.0
	State.LineH = 0.0
end

function Cursor.SetAnchor(X, Y)
	State.AnchorX = X
	State.AnchorY = Y
end

function Cursor.SetAnchorX(X)
	State.AnchorX = X
end

function Cursor.SetAnchorY(Y)
	State.AnchorY = Y
end

function Cursor.GetAnchor()
	return State.AnchorX, State.AnchorY
end

function Cursor.GetAnchorX()
	return State.AnchorX
end

function Cursor.GetAnchorY()
	return State.AnchorY
end

function Cursor.GetPosition()
	return State.X, State.Y
end

function Cursor.GetX()
	return State.X
end

function Cursor.GetY()
	return State.Y
end

function Cursor.GetRelativePosition()
	return Cursor.GetRelativeX(), Cursor.GetRelativeY()
end

function Cursor.GetRelativeX()
	return State.X - State.AnchorX
end

function Cursor.GetRelativeY()
	return State.Y - State.AnchorY
end

function Cursor.SetItemBounds(X, Y, W, H)
	State.ItemX = X
	State.ItemY = Y
	State.ItemW = W
	State.ItemH = H
	if State.LineY == 0.0 then
		State.LineY = Y
	end
	State.LineY = min(State.LineY, Y)
	State.LineH = max(State.LineH, H)
end

function Cursor.GetItemBounds()
	return State.ItemX, State.ItemY, State.ItemW, State.ItemH
end

function Cursor.IsInItemBounds(X, Y)
	return State.ItemX <= X and X <= State.ItemX + State.ItemW and State.ItemY <= Y and Y <= State.ItemY + State.ItemH
end

function Cursor.SameLine(Options)
	Options = Options == nil and {} or Options
	Options.Pad = Options.Pad == nil and 0.0 or Options.Pad
	Options.CenterY = Options.CenterY == nil and false or Options.CenterY

	State.LineY = State.PrevLineY
	State.LineH = State.PrevLineH
	State.X = State.ItemX + State.ItemW + State.PadX + Options.Pad
	State.Y = State.PrevY

	if Options.CenterY then
		State.Y = State.Y + (State.LineH * 0.5) - (State.NewLineSize * 0.5)
	end
end

function Cursor.SetNewLineSize(NewLineSize)
	State.NewLineSize = NewLineSize
end

function Cursor.GetNewLineSize()
	return State.NewLineSize
end

function Cursor.NewLine()
	Cursor.AdvanceY(State.NewLineSize)
end

function Cursor.GetLineHeight()
	return State.PrevLineH
end

function Cursor.PadX()
	return State.PadX
end

function Cursor.PadY()
	return State.PadY
end

function Cursor.Indent(Width)
	State.AnchorX = State.AnchorX + Width
	State.X = State.AnchorX
end

function Cursor.Unindent(Width)
	Cursor.Indent(-Width)
end

function Cursor.PushContext()
	table.insert(Stack, 1, Utility.Copy(State))
end

function Cursor.PopContext()
	if #Stack == 0 then
		return
	end

	State = table.remove(Stack, 1)
end

return Cursor
