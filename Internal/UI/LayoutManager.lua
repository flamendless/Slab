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

local insert = table.insert
local remove = table.remove
local max = math.max
local min = math.min

local Cursor = require(SLAB_PATH .. '.Internal.Core.Cursor')
local Window = require(SLAB_PATH .. '.Internal.UI.Window')

local LayoutManager = {}

local Instances = {}
local Stack = {}
local Active = nil

local function GetWindowBounds()
	local WinX, WinY, WinW, WinH = Window.GetBounds(true)
	local Border = Window.GetBorder()

	WinX = WinX + Border
	WinY = WinY + Border
	WinW = WinW - Border * 2
	WinH = WinH - Border * 2

	return WinX, WinY, WinW, WinH
end

local function GetRowSize(Instance)
	if Instance ~= nil then
		local Column = Instance.Columns[Instance.ColumnNo]

		if Column.Rows ~= nil then
			local Row = Column.Rows[Column.RowNo]

			if Row ~= nil then
				return Row.W, Row.H
			end
		end
	end

	return 0, 0
end

local function GetRowCursorPos(Instance)
	if Instance ~= nil then
		local Column = Instance.Columns[Instance.ColumnNo]

		if Column.Rows ~= nil then
			local Row = Column.Rows[Column.RowNo]

			if Row ~= nil then
				return Row.CursorX, Row.CursorY
			end
		end
	end

	return nil, nil
end

local function GetLayoutH(Instance, IncludePad)
	IncludePad = IncludePad == nil and true or IncludePad

	if Instance ~= nil then
		local Column = Instance.Columns[Instance.ColumnNo]

		if Column.Rows ~= nil then
			local H = 0

			for I, V in ipairs(Column.Rows) do
				H = H + V.H

				if IncludePad then
					H = H + Cursor.PadY()
				end
			end

			return H
		end
	end

	return 0
end

local function GetPreviousRowBottom(Instance)
	if Instance ~= nil then
		local Column = Instance.Columns[Instance.ColumnNo]

		if Column.Rows ~= nil and Column.RowNo > 1 and Column.RowNo <= #Column.Rows then
			local Y = Column.Rows[Column.RowNo - 1].CursorY
			local H = Column.Rows[Column.RowNo - 1].H
			return Y + H
		end
	end

	return nil
end

local function GetColumnPosition(Instance)
	if Instance ~= nil then
		local WinX, WinY, WinW, WinH = GetWindowBounds()
		local WinL, WinT = Window.GetPosition()
		local Count = #Instance.Columns
		local ColumnW = WinW / Count
		local TotalW = 0

		for I = 1, Instance.ColumnNo - 1, 1 do
			local Column = Instance.Columns[I]
			TotalW = TotalW + Column.W
		end

		local AnchorX, AnchorY = Instance.X, Instance.Y

		if not Instance.AnchorX then
			AnchorX = WinX - WinL - Window.GetBorder()
		end

		if not Instance.AnchorY then
			AnchorY = WinY - WinT - Window.GetBorder()
		end

		return AnchorX + TotalW, AnchorY
	end

	return 0, 0
end

local function GetColumnSize(Instance)
	if Instance ~= nil then
		local Column = Instance.Columns[Instance.ColumnNo]
		local WinX, WinY, WinW, WinH = GetWindowBounds()
		local Count = #Instance.Columns
		local ColumnW = WinW / Count
		local W, H = 0, GetLayoutH(Instance)

		if not Window.IsAutoSize() then
			W = ColumnW
			H = WinH
			Column.W = W
		else
			W = max(Column.W, ColumnW)
		end

		return W, H
	end

	return 0, 0
end

local function AddControl(Instance, W, H, Type)
	if Instance ~= nil then
		local RowW, RowH = GetRowSize(Instance)
		local WinX, WinY, WinW, WinH = GetWindowBounds()
		local CursorX, CursorY = Cursor.GetPosition()
		local X, Y = GetRowCursorPos(Instance)
		local LayoutH = GetLayoutH(Instance)
		local PrevRowBottom = GetPreviousRowBottom(Instance)
		local AnchorX, AnchorY = GetColumnPosition(Instance)
		WinW, WinH = GetColumnSize(Instance)
		local Column = Instance.Columns[Instance.ColumnNo]

		if RowW == 0 then
			RowW = W
		end

		if RowH == 0 then
			RowH = H
		end

		if X == nil then
			if Instance.AlignX == 'center' then
				X = max(WinW * 0.5 - RowW * 0.5 + AnchorX, AnchorX)
			elseif Instance.AlignX == 'right' then
				local Right = WinW - RowW
				if not Window.IsAutoSize() then
					Right = Right + Window.GetBorder()
				end

				X = max(Right, AnchorX)
			else
				X = AnchorX
			end
		end

		if Y == nil then
			if PrevRowBottom ~= nil then
				Y = PrevRowBottom + Cursor.PadY()
			else
				local RegionH = WinY + WinH - CursorY
				if Instance.AlignY == 'center' then
					Y = max(RegionH * 0.5 - LayoutH * 0.5 + AnchorY, AnchorY)
				elseif Instance.AlignY == 'bottom' then
					Y = max(WinH - LayoutH, AnchorY)
				else
					Y = AnchorY
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

		local RowNo = Column.RowNo

		if Column.Rows ~= nil then
			local Row = Column.Rows[RowNo]

			if Row ~= nil then
				Row.CursorX = X + W + Cursor.PadX()
				Row.CursorY = Y
			end
		end

		if Column.PendingRows[RowNo] == nil then
			local Row = {
				CursorX = nil,
				CursorY = nil,
				W = 0,
				H = 0,
				RequestH = 0,
				MaxH = 0,
				Controls = {}
			}
			insert(Column.PendingRows, Row)
		end

		local Row = Column.PendingRows[RowNo]

		insert(Row.Controls, {
			X = Cursor.GetX(),
			Y = Cursor.GetY(),
			W = W,
			H = H,
			AlteredSize = Column.AlteredSize,
			Type = Type
		})
		Row.W = Row.W + W + Cursor.PadX()
		Row.H = max(Row.H, H)

		Column.RowNo = RowNo + 1
		Column.AlteredSize = false
		Column.W = max(Row.W, Column.W)
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
		Instance.Ignore = false
		Instance.ExpandW = false
		Instance.X = 0
		Instance.Y = 0
		Instance.Columns = {}
		Instance.ColumnNo = 1
		Instances[Key] = Instance
	end

	return Instances[Key]
end

function LayoutManager.AddControl(W, H, Type)
	if Active ~= nil and not Active.Ignore then
		AddControl(Active, W, H)
	end
end

function LayoutManager.ComputeSize(W, H)
	if Active ~= nil then
		local X, Y = GetColumnPosition(Active)
		local WinW, WinH = GetColumnSize(Active)
		local RealW = WinW - X
		local RealH = WinH - Y
		local Column = Active.Columns[Active.ColumnNo]

		if not Active.AnchorX then
			RealW = WinW
		end

		if not Active.AnchorY then
			RealH = WinH
		end

		if Window.IsAutoSize() then
			local LayoutH = GetLayoutH(Active, false)

			if LayoutH > 0 then
				RealH = LayoutH
			end
		end

		if Active.ExpandW then
			if Column.Rows ~= nil then
				local Count = 0
				local ReduceW = 0
				local Pad = 0
				local Row = Column.Rows[Column.RowNo]
				if Row ~= nil then
					for I, V in ipairs(Row.Controls) do
						if V.AlteredSize then
							Count = Count + 1
						else
							ReduceW = ReduceW + V.W
						end
					end

					if #Row.Controls > 1 then
						Pad = Cursor.PadX() * (#Row.Controls - 1)
					end
				end

				Count = max(Count, 1)

				W = (RealW - ReduceW - Pad) / Count
			end
		end

		if Active.ExpandH then
			if Column.Rows ~= nil then
				local Count = 0
				local ReduceH = 0
				local Pad = 0
				local MaxRowH = 0
				for I, Row in ipairs(Column.Rows) do
					local IsSizeAltered = false

					if I == Column.RowNo then
						MaxRowH = Row.MaxH
						Row.RequestH = max(Row.RequestH, H)
					end

					for J, Control in ipairs(Row.Controls) do
						if Control.AlteredSize then
							if not IsSizeAltered then
								Count = Count + 1
								IsSizeAltered = true
							end
						end
					end

					if not IsSizeAltered then
						ReduceH = ReduceH + Row.H
					end
				end

				if #Column.Rows > 1 then
					Pad = Cursor.PadY() * (#Column.Rows - 1)
				end

				Count = max(Count, 1)

				RealH = max(RealH - ReduceH - Pad, 0)
				H = max(RealH / Count, H)
				H = max(H, MaxRowH)
			end
		end

		Column.AlteredSize = Active.ExpandW or Active.ExpandH
	end

	return W, H
end

function LayoutManager.Begin(Id, Options)
	assert(Id ~= nil or type(Id) ~= string, "A valid string Id must be given to BeginLayout!")

	Options = Options == nil and {} or Options
	Options.AlignX = Options.AlignX == nil and 'left' or Options.AlignX
	Options.AlignY = Options.AlignY == nil and 'top' or Options.AlignY
	Options.AlignRowY = Options.AlignRowY == nil and 'top' or Options.AlignRowY
	Options.Ignore = Options.Ignore == nil and false or Options.Ignore
	Options.ExpandW = Options.ExpandW == nil and false or Options.ExpandW
	Options.ExpandH = Options.ExpandH == nil and false or Options.ExpandH
	Options.AnchorX = Options.AnchorX == nil and false or Options.AnchorX
	Options.AnchorY = Options.AnchorY == nil and true or Options.AnchorY
	Options.Columns = Options.Columns == nil and 1 or Options.Columns

	Options.Columns = max(Options.Columns, 1)

	local Instance = GetInstance(Id)
	Instance.AlignX = Options.AlignX
	Instance.AlignY = Options.AlignY
	Instance.AlignRowY = Options.AlignRowY
	Instance.Ignore = Options.Ignore
	Instance.ExpandW = Options.ExpandW
	Instance.ExpandH = Options.ExpandH
	Instance.X, Instance.Y = Cursor.GetRelativePosition()
	Instance.AnchorX = Options.AnchorX
	Instance.AnchorY = Options.AnchorY

	if Options.Columns ~= #Instance.Columns then
		Instance.Columns = {}
		for I = 1, Options.Columns, 1 do
			local Column = {
				Rows = nil,
				PendingRows = {},
				RowNo = 1,
				W = 0
			}

			insert(Instance.Columns, Column)
		end
	end

	for I, Column in ipairs(Instance.Columns) do
		Column.PendingRows = {}
		Column.RowNo = 1
	end

	insert(Stack, 1, Instance)
	Active = Instance
end

function LayoutManager.End()
	assert(Active ~= nil, "LayoutManager.End was called without a call to LayoutManager.Begin!")

	for I, Column in ipairs(Active.Columns) do
		local Rows = Column.Rows
		Column.Rows = Column.PendingRows
		Column.PendingRows = nil

		if Rows ~= nil and Column.Rows ~= nil and #Rows == #Column.Rows then
			for I, V in ipairs(Rows) do
				Column.Rows[I].MaxH = Rows[I].RequestH
			end
		end
	end

	remove(Stack, 1)
	Active = nil

	if #Stack > 0 then
		Active = Stack[1]
	end
end

function LayoutManager.SameLine(CursorOptions)
	Cursor.SameLine(CursorOptions)
	if Active ~= nil then
		local Column = Active.Columns[Active.ColumnNo]
		Column.RowNo = max(Column.RowNo - 1, 1)
	end
end

function LayoutManager.NewLine()
	if Active ~= nil then
		AddControl(Active, 0, Cursor.GetNewLineSize(), 'NewLine')
	end
	Cursor.NewLine()
end

function LayoutManager.SetColumn(Index)
	if Active ~= nil then
		Index = max(Index, 1)
		Index = min(Index, #Active.Columns)
		Active.ColumnNo = Index
	end
end

function LayoutManager.GetActiveSize()
	if Active ~= nil then
		return GetColumnSize(Active)
	end

	return 0, 0
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
