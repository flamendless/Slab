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

local LayoutManager = {}

local Instances = {}
local Stack = {}
local Active = nil

local function GetRowSize(Instance)
	if Instance ~= nil and Instance.Controls ~= nil then
		local Row = Instance.Controls.Rows[Instance.RowNo]

		if Row ~= nil then
			return Row.W, Row.H
		end
	end

	return 0, 0
end

local function GetRowCursorPos(Instance)
	if Instance ~= nil and Instance.Controls ~= nil then
		local Row = Instance.Controls.Rows[Instance.RowNo]

		if Row ~= nil then
			return Row.CursorX, Row.CursorY
		end
	end

	return nil, nil
end

local function GetLayoutH(Instance)
	if Instance ~= nil and Instance.Controls ~= nil then
		local H = 0

		for I, V in ipairs(Instance.Controls.Rows) do
			H = H + V.H + Cursor.PadY()
		end

		return H
	end

	return 0
end

local function GetPreviousRowBottom(Instance)
	if Instance ~= nil and Instance.Controls ~= nil then
		if Instance.RowNo > 1 then
			local Y = Instance.Controls.Rows[Instance.RowNo - 1].CursorY
			local H = Instance.Controls.Rows[Instance.RowNo - 1].H
			return Y + H
		end
	end

	return nil
end

local function AddControl(Instance, W, H)
	if Instance ~= nil then
		local RowW, RowH = GetRowSize(Instance)
		local WinX, WinY, WinW, WinH = Window.GetBounds(true)
		local CursorX, CursorY = Cursor.GetPosition()
		local X, Y = GetRowCursorPos(Instance)
		local LayoutH = GetLayoutH(Instance)
		local PrevRowBottom = GetPreviousRowBottom(Instance)

		WinX = WinX + Window.GetBorder()
		WinY = WinY + Window.GetBorder()
		WinW = WinW - Window.GetBorder() * 2
		WinH = WinH - Window.GetBorder() * 2

		if RowW == 0 then
			RowW = WinW
		end

		if RowH == 0 then
			RowH = H
		end

		if X == nil then
			if Instance.AlignX == 'center' then
				X = math.max(WinW * 0.5 - RowW * 0.5, Cursor.GetRelativeX())
			elseif Instance.AlignX == 'right' then
				X = math.max(WinW - RowW + Window.GetBorder(), Cursor.GetRelativeX())
			else
				X = Cursor.GetRelativeX()
			end
		end

		if Y == nil then
			if PrevRowBottom ~= nil then
				Y = PrevRowBottom + Cursor.PadY()
			else
				local RegionH = WinY + WinH - CursorY
				if Instance.AlignY == 'center' then
					Y = math.max(RegionH * 0.5 - LayoutH * 0.5 + Cursor.GetRelativeY(), Cursor.GetRelativeY())
				elseif Instance.AlignY == 'bottom' then
					Y = math.max(WinH - LayoutH, Cursor.GetRelativeY())
				else
					Y = Cursor.GetRelativeY()
				end
			end
		end

		Cursor.SetX(WinX + X)
		Cursor.SetY(WinY + Y)

		if H < RowH then
			if Instance.AlignRowY == 'center' then
				Cursor.SetY(WinY + Y + RowH * 0.5 - H * 0.5)
			elseif Instance.AlignRowY == 'bottom' then
				Cursor.SetY(WinY + Y + RowH - H)
			end
		end

		local RowNo = Instance.RowNo

		if Instance.Controls ~= nil then
			local Row = Instance.Controls.Rows[RowNo]

			if Row ~= nil then
				Row.CursorX = X + W + Cursor.PadX()
				Row.CursorY = Y
			end
		end

		if Instance.PendingControls.Rows[Instance.RowNo] == nil then
			Instance.PendingControls.Rows[Instance.RowNo] = {
				CursorX = nil,
				CursorY = nil,
				W = 0.0,
				H = 0.0
			}
		end

		local Row = Instance.PendingControls.Rows[RowNo]

		Row.W = Row.W + W + Cursor.PadX()
		Row.H = math.max(Row.H, H)

		Instance.RowNo = RowNo + 1
	end
end

local function GetInstance(Id)
	local Key = Window.GetId() .. '.' .. Id

	if Instances[Key] == nil then
		local Instance = {}
		Instance.Id = Id
		Instance.WindowId = Window.GetId()
		Instance.AlignX = 'left'
		Instance.AlignY = 'top'
		Instance.AlignRowY = 'top'
		Instance.Controls = nil
		Instance.PendingControls = nil
		Instance.RowNo = 1
		Instance.Ignore = false
		Instances[Key] = Instance
	end

	return Instances[Key]
end

function LayoutManager.AddControl(W, H)
	if Active ~= nil and not Active.Ignore then
		AddControl(Active, W, H)
	end
end

function LayoutManager.Begin(Id, Options)
	assert(Id ~= nil or type(Id) ~= string, "A valid string Id must be given to BeginLayout!")

	Options = Options == nil and {} or Options
	Options.AlignX = Options.AlignX == nil and 'left' or Options.AlignX
	Options.AlignY = Options.AlignY == nil and 'top' or Options.AlignY
	Options.AlignRowY = Options.AlignRowY == nil and 'top' or Options.AlignRowY
	Options.Ignore = Options.Ignore == nil and false or Options.Ignore

	local Instance = GetInstance(Id)
	Instance.AlignX = Options.AlignX
	Instance.AlignY = Options.AlignY
	Instance.AlignRowY = Options.AlignRowY
	Instance.Ignore = Options.Ignore
	Instance.PendingControls = {Rows = {}}
	Instance.RowNo = 1

	table.insert(Stack, 1, Instance)
	Active = Instance
end

function LayoutManager.End()
	assert(Active ~= nil, "LayoutManager.End was called without a call to LayoutManager.Begin!")

	Active.Controls = Active.PendingControls
	Active.PendingControls = nil

	table.remove(Stack, 1)
	Active = nil

	if #Stack > 0 then
		Active = Stack[1]
	end
end

function LayoutManager.SameLine()
	if Active ~= nil then
		Active.RowNo = math.max(Active.RowNo - 1, 1)
	end
end

function LayoutManager.NewLine()
	if Active ~= nil then
		AddControl(Active, 0, Cursor.GetNewLineSize())
	end
end

function LayoutManager.Validate()
	local Message = nil

	for I, V in ipairs(Stack) do
		if Message == nil then
			Message = "The following layouts have not had EndLayout called:\n"
		end

		Message = Message .. "'" .. V.Id .. "' in window '" .. V.WindowId .. "'\n"
	end

	assert(Message == nil, Message)
end

return LayoutManager
