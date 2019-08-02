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
	if Instance ~= nil and Instance.Rows ~= nil then
		local Row = Instance.Rows[Instance.RowNo]

		if Row ~= nil then
			return Row.W, Row.H
		end
	end

	return 0, 0
end

local function GetRowCursorPos(Instance)
	if Instance ~= nil and Instance.Rows ~= nil then
		local Row = Instance.Rows[Instance.RowNo]

		if Row ~= nil then
			return Row.CursorX, Row.CursorY
		end
	end

	return nil, nil
end

local function GetLayoutH(Instance, IncludePad)
	IncludePad = IncludePad == nil and true or IncludePad

	if Instance ~= nil and Instance.Rows ~= nil then
		local H = 0

		for I, V in ipairs(Instance.Rows) do
			H = H + V.H

			if IncludePad then
				H = H + Cursor.PadY()
			end
		end

		return H
	end

	return 0
end

local function GetPreviousRowBottom(Instance)
	if Instance ~= nil and Instance.Rows ~= nil then
		if Instance.RowNo > 1 then
			local Y = Instance.Rows[Instance.RowNo - 1].CursorY
			local H = Instance.Rows[Instance.RowNo - 1].H
			return Y + H
		end
	end

	return nil
end

local function AddControl(Instance, W, H, Type)
	if Instance ~= nil then
		local RowW, RowH = GetRowSize(Instance)
		local WinX, WinY, WinW, WinH = GetWindowBounds()
		local CursorX, CursorY = Cursor.GetPosition()
		local X, Y = GetRowCursorPos(Instance)
		local LayoutH = GetLayoutH(Instance)
		local PrevRowBottom = GetPreviousRowBottom(Instance)

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

		if Instance.Rows ~= nil then
			local Row = Instance.Rows[RowNo]

			if Row ~= nil then
				Row.CursorX = X + W + Cursor.PadX()
				Row.CursorY = Y
			end
		end

		if Instance.PendingRows[Instance.RowNo] == nil then
			Instance.PendingRows[Instance.RowNo] = {
				CursorX = nil,
				CursorY = nil,
				W = 0,
				H = 0,
				RequestH = 0,
				MaxH = 0,
				Controls = {}
			}
		end

		local Row = Instance.PendingRows[RowNo]

		table.insert(Row.Controls, {
			X = Cursor.GetX(),
			Y = Cursor.GetY(),
			W = W,
			H = H,
			AlteredSize = Instance.AlteredSize,
			Type = Type
		})
		Row.W = Row.W + W + Cursor.PadX()
		Row.H = math.max(Row.H, H)

		Instance.RowNo = RowNo + 1
		Instance.AlteredSize = false
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
		Instance.PendingRows = nil
		Instance.RowNo = 1
		Instance.Ignore = false
		Instance.ExpandW = false
		Instance.X = 0
		Instance.Y = 0
		Instance.AlteredSize = false
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
		local X, Y = Active.X, Active.Y
		local WinX, WinY, WinW, WinH = GetWindowBounds()
		local RealW = WinW - X
		local RealH = WinH - Y

		if Window.IsAutoSize() then
			local LayoutH = GetLayoutH(Active, false)

			if LayoutH > 0 then
				RealH = LayoutH
			end
		end

		if Active.ExpandW then
			if Active.Rows ~= nil then
				local Count = 0
				local ReduceW = 0
				local Pad = 0
				local Row = Active.Rows[Active.RowNo]
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

				Count = math.max(Count, 1)

				W = (RealW - ReduceW - Pad) / Count
			end
		end

		if Active.ExpandH then
			if Active.Rows ~= nil then
				local Count = 0
				local ReduceH = 0
				local Pad = 0
				local MaxRowH = 0
				for I, Row in ipairs(Active.Rows) do
					local IsSizeAltered = false

					if I == Active.RowNo then
						MaxRowH = Row.MaxH
						Row.RequestH = math.max(Row.RequestH, H)
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

				if #Active.Rows > 1 then
					Pad = Cursor.PadY() * (#Active.Rows - 1)
				end

				Count = math.max(Count, 1)

				RealH = math.max(RealH - ReduceH - Pad, 0)
				H = math.max(RealH / Count, H)
				H = math.max(H, MaxRowH)
			end
		end

		Active.AlteredSize = true
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

	local Instance = GetInstance(Id)
	Instance.AlignX = Options.AlignX
	Instance.AlignY = Options.AlignY
	Instance.AlignRowY = Options.AlignRowY
	Instance.Ignore = Options.Ignore
	Instance.ExpandW = Options.ExpandW
	Instance.ExpandH = Options.ExpandH
	Instance.PendingRows = {}
	Instance.RowNo = 1
	Instance.X, Instance.Y = Cursor.GetRelativePosition()

	table.insert(Stack, 1, Instance)
	Active = Instance
end

function LayoutManager.End()
	assert(Active ~= nil, "LayoutManager.End was called without a call to LayoutManager.Begin!")

	local Rows = Active.Rows
	Active.Rows = Active.PendingRows
	Active.PendingRows = nil

	if Rows ~= nil and Active.Rows ~= nil and #Rows == #Active.Rows then
		for I, V in ipairs(Rows) do
			Active.Rows[I].MaxH = Rows[I].RequestH
		end
	end

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
		AddControl(Active, 0, Cursor.GetNewLineSize(), 'NewLine')
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
