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
local min = math.min
local max = math.max
local floor = math.floor
local huge = math.huge
local gsub = string.gsub
local sub = string.sub
local match = string.match
local len = string.len
local byte = string.byte
local find = string.find

local Cursor = require(SLAB_PATH .. '.Internal.Core.Cursor')
local DrawCommands = require(SLAB_PATH .. '.Internal.Core.DrawCommands')
local Keyboard = require(SLAB_PATH .. '.Internal.Input.Keyboard')
local LayoutManager = require(SLAB_PATH .. '.Internal.UI.LayoutManager')
local Mouse = require(SLAB_PATH .. '.Internal.Input.Mouse')
local Region = require(SLAB_PATH .. '.Internal.UI.Region')
local Stats = require(SLAB_PATH .. '.Internal.Core.Stats')
local Style = require(SLAB_PATH .. '.Style')
local Text = require(SLAB_PATH .. '.Internal.UI.Text')
local Tooltip = require(SLAB_PATH .. '.Internal.UI.Tooltip')
local UTF8 = require('utf8')
local Utility = require(SLAB_PATH .. '.Internal.Core.Utility')
local Window = require(SLAB_PATH .. '.Internal.UI.Window')

local Input = {}
local Instances = {}
local Focused = nil
local LastFocused = nil
local TextCursorPos = 0
local TextCursorPosLine = 0
local TextCursorPosLineMax = 0
local TextCursorPosLineNumber = 1
local TextCursorAnchor = -1
local TextCursorAlpha = 0.0
local FadeIn = true
local DragSelect = false
local FocusToNext = false
local LastText = ""
local Pad = Region.GetScrollPad() + Region.GetScrollBarSize()
local PendingFocus = nil
local PendingCursorPos = -1
local PendingCursorColumn = -1
local PendingCursorLine = -1
local IsSliding = false

local MIN_WIDTH = 150.0

local function SanitizeText(Data)
	local Result = false

	if Data ~= nil then
		local Count = 0
		Data, Count = gsub(Data, "\r", "")
		Result = Count > 0
	end

	return Data, Result
end

local function GetDisplayCharacter(Data, Pos)
	local Result = ''

	if Data ~= nil and Pos > 0 and Pos < len(Data) then
		local Offset = UTF8.offset(Data, -1, Pos + 1)
		Result = sub(Data, Offset, Pos)

		if Result == nil then
			Result = 'nil'
		end
	end

	if Result == '\n' then
		Result = "\\n"
	end

	return Result
end

local function GetCharacter(Data, Index, Forward)
	local Result = ""
	if Forward then
		local Sub = sub(Data, Index + 1)
		Result = match(Sub, "[%z\1-\127\194-\244%s\n][\128-\191]*")
	else
		local Sub = sub(Data, 1, Index)
		Result = match(Sub, "[%z\1-\127\194-\244%s\n][\128-\191]*$")
	end
	return Result
end

local function UpdateMultiLinePosition(Instance)
	if Instance ~= nil then
		if Instance.Lines ~= nil then
			local Count = 0
			local Start = 0
			local Found = false
			for I, V in ipairs(Instance.Lines) do
				local Length = len(V)
				Count = Count + Length
				if TextCursorPos < Count then
					TextCursorPosLine = TextCursorPos - Start
					TextCursorPosLineNumber = I
					Found = true
					break
				end
				Start = Start + Length
			end

			if not Found then
				TextCursorPosLine = len(Instance.Lines[#Instance.Lines])
				TextCursorPosLineNumber = #Instance.Lines
			end
		else
			TextCursorPosLine = TextCursorPos
			TextCursorPosLineNumber = 1
		end
		TextCursorPosLineMax = TextCursorPosLine
	end
end

local function ValidateTextCursorPos(Instance)
	if Instance ~= nil then
		local OldPos = TextCursorPos
		local Byte = byte(sub(Instance.Text, TextCursorPos, TextCursorPos))
		-- This is a continuation byte. Check next byte to see if it is an ASCII character or
		-- the beginning of a UTF8 character.
		if Byte ~= nil and Byte > 127 then
			local NextByte = byte(sub(Instance.Text, TextCursorPos + 1, TextCursorPos + 1))
			if NextByte ~= nil and NextByte > 127 and NextByte < 191 then
				while Byte > 127 and Byte < 191 do
					TextCursorPos = TextCursorPos - 1
					Byte = byte(sub(Instance.Text, TextCursorPos, TextCursorPos))
				end

				if TextCursorPos < OldPos or Byte >= 191 then
					TextCursorPos = TextCursorPos - 1
					UpdateMultiLinePosition(Instance)
				end
			end
		end
	end
end

local function MoveToHome(Instance)
	if Instance ~= nil then
		if Instance.Lines ~= nil and TextCursorPosLineNumber > 1 then
			TextCursorPosLine = 0
			local Count = 0
			local Start = 0
			for I, V in ipairs(Instance.Lines) do
				Count = Count + len(V)
				if I == TextCursorPosLineNumber then
					TextCursorPos = Start
					break
				end
				Start = Start + len(V)
			end
		else
			TextCursorPos = 0
		end
		UpdateMultiLinePosition(Instance)
	end
end

local function MoveToEnd(Instance)
	if Instance ~= nil then
		if Instance.Lines ~= nil then
			local Count = 0
			for I, V in ipairs(Instance.Lines) do
				Count = Count + len(V)
				if I == TextCursorPosLineNumber then
					TextCursorPos = Count - 1
					
					if I == #Instance.Lines then
						TextCursorPos = Count
					end
					break
				end
			end
		else
			TextCursorPos = #Instance.Text
		end
		UpdateMultiLinePosition(Instance)
	end
end

local function ValidateNumber(Instance)
	local Result = false

	if Instance ~= nil and Instance.NumbersOnly and Instance.Text ~= "" then
		if sub(Instance.Text, #Instance.Text, #Instance.Text) == "." then
			return
		end

		local Value = tonumber(Instance.Text)
		if Value == nil then
			Value = 0.0
		end

		local OldValue = Value

		if Instance.MinNumber ~= nil then
			Value = max(Value, Instance.MinNumber)
		end
		if Instance.MaxNumber ~= nil then
			Value = min(Value, Instance.MaxNumber)
		end

		Result = OldValue ~= Value

		Instance.Text = tostring(Value)
	end

	return Result
end

local function GetAlignmentOffset(Instance)
	local Offset = 6.0
	if Instance ~= nil then
		if Instance.Align == 'center' then
			local TextW = Text.GetWidth(Instance.Text)
			Offset = (Instance.W * 0.5) - (TextW * 0.5)
		end
	end
	return Offset
end

local function GetSelection(Instance)
	if Instance ~= nil and TextCursorAnchor >= 0 and TextCursorAnchor ~= TextCursorPos then
		local Min = min(TextCursorAnchor, TextCursorPos) + 1
		local Max = max(TextCursorAnchor, TextCursorPos)

		return sub(Instance.Text, Min, Max)
	end
	return ""
end

local function MoveCursorVertical(Instance, MoveDown)
	if Instance ~= nil and Instance.Lines ~= nil then
		local OldLineNumber = TextCursorPosLineNumber
		if MoveDown then
			TextCursorPosLineNumber = min(TextCursorPosLineNumber + 1, #Instance.Lines)
		else
			TextCursorPosLineNumber = max(1, TextCursorPosLineNumber - 1)
		end
		local Line = Instance.Lines[TextCursorPosLineNumber]
		if OldLineNumber == TextCursorPosLineNumber then
			TextCursorPosLine = MoveDown and len(Line) or 0
		else
			if TextCursorPosLineNumber == #Instance.Lines and TextCursorPosLine >= len(Line) then
				TextCursorPosLine = len(Line)
			else
				TextCursorPosLine = min(len(Line), TextCursorPosLineMax + 1)
				local Ch = GetCharacter(Line, TextCursorPosLine)
				if Ch ~= nil then
					TextCursorPosLine = TextCursorPosLine - len(Ch)
				end
			end
		end
		local Start = 0
		for I, V in ipairs(Instance.Lines) do
			if I == TextCursorPosLineNumber then
				TextCursorPos = Start + TextCursorPosLine
				break
			end
			Start = Start + len(V)
		end
	end
end

local function IsValidDigit(Instance, Ch)
	if Instance ~= nil then
		if Instance.NumbersOnly then
			if match(Ch, "%d") ~= nil then
				return true
			end

			if Ch == "-" then
				if TextCursorAnchor == 0 or TextCursorPos == 0 or #Instance.Text == 0 then
					return true
				end
			end

			if Ch == "." then
				local Selected = GetSelection(Instance)
				if Selected ~= nil and find(Selected, ".", 1, true) ~= nil then
					return true
				end

				if find(Instance.Text, ".", 1, true) == nil then
					return true
				end
			end
		else
			return true
		end
	end
	return false
end

local function IsCommandKeyDown()
	local LKey, RKey = 'lctrl', 'rctrl'
	if Utility.IsOSX() then
		LKey, RKey = 'lgui', 'rgui'
	end
	return Keyboard.IsDown(LKey) or Keyboard.IsDown(RKey)
end

local function IsHomePressed()
	local Result = false
	if Utility.IsOSX() then
		Result = IsCommandKeyDown() and Keyboard.IsPressed('left')
	else
		Result = Keyboard.IsPressed('home')
	end
	return Result
end

local function IsEndPressed()
	local Result = false
	if Utility.IsOSX() then
		Result = IsCommandKeyDown() and Keyboard.IsPressed('right')
	else
		Result = Keyboard.IsPressed('end')
	end
	return Result
end

local function IsNextSpaceDown()
	local Result = false
	if Utility.IsOSX() then
		Result = Keyboard.IsDown('lalt') or Keyboard.IsDown('ralt')
	else
		Result = Keyboard.IsDown('lctrl') or Keyboard.IsDown('rctrl')
	end
	return Result
end

local function GetCursorXOffset(Instance)
	local Result = GetAlignmentOffset(Instance)
	if Instance ~= nil then
		if TextCursorPos > 0 then
			local Sub = sub(Instance.Text, 1, TextCursorPos)
			Result = Text.GetWidth(Sub) + GetAlignmentOffset(Instance)
		end
	end
	return Result
end

local function GetCursorPos(Instance)
	local X, Y = GetAlignmentOffset(Instance), 0.0

	if Instance ~= nil then
		local Data = Instance.Text
		if Instance.Lines ~= nil then
			Data = Instance.Lines[TextCursorPosLineNumber]
			Y = Text.GetHeight() * (TextCursorPosLineNumber - 1)
		end
		local CursorPos = min(TextCursorPosLine, len(Data))
		if CursorPos > 0 then
			local Sub = sub(Data, 0, CursorPos)
			X = X + Text.GetWidth(Sub)
		end
	end

	return X, Y
end

local function SelectWord(Instance)
	if Instance ~= nil then
		local Filter = "%s"
		if GetCharacter(Instance.Text, TextCursorPos) == " " then
			if GetCharacter(Instance.Text, TextCursorPos + 1) == " " then
				Filter = "%S"
			else
				TextCursorPos = TextCursorPos + 1
			end
		end
		TextCursorAnchor = 0
		local I = 0
		while I ~= nil and I + 1 < TextCursorPos do
			I = find(Instance.Text, Filter, I + 1)
			if I ~= nil and I < TextCursorPos then
				TextCursorAnchor = I
			else
				break
			end
		end
		I = find(Instance.Text, Filter, TextCursorPos + 1)
		if I ~= nil then
			TextCursorPos = I - 1
		else
			TextCursorPos = #Instance.Text
		end
		UpdateMultiLinePosition(Instance)
	end
end

local function GetNextCursorPos(Instance, Left)
	local Result = 0
	if Instance ~= nil then
		local NextSpace = IsNextSpaceDown()

		if NextSpace then
			if Left then
				Result = 0
				local I = 0
				while I ~= nil and I + 1 < TextCursorPos do
					I = find(Instance.Text, "%s", I + 1)
					if I ~= nil and I < TextCursorPos then
						Result = I
					else
						break
					end
				end
			else
				local I = find(Instance.Text, "%s", TextCursorPos + 1)
				if I ~= nil then
					Result = I
				else
					Result = #Instance.Text
				end
			end
		else
			if Left then
				local Ch = GetCharacter(Instance.Text, TextCursorPos)
				if Ch ~= nil then
					Result = TextCursorPos - len(Ch)
				end
			else
				local Ch = GetCharacter(Instance.Text, TextCursorPos, true)
				if Ch ~= nil then
					Result = TextCursorPos + len(Ch)
				else
					Result = TextCursorPos
				end
			end
		end
		Result = max(0, Result)
		Result = min(Result, len(Instance.Text))
	end
	return Result
end

local function GetCursorPosLine(Instance, Line, X)
	local Result = 0
	if Instance ~= nil and Line ~= "" then
		if Text.GetWidth(Line) < X then
			Result = len(Line)
			if find(Line, "\n") ~= nil then
				Result = len(Line) - 1
			end
		else
			X = X - GetAlignmentOffset(Instance)
			local PosX = X
			local Index = 0
			local Sub = ""
			while Index <= len(Line) do
				local Ch = GetCharacter(Line, Index, true)
				if Ch == nil then
					break
				end
				Index = Index + len(Ch)
				Sub = Sub .. Ch
				local PosX = Text.GetWidth(Sub)
				if PosX > X then
					local CharX = PosX - X
					local CharW = Text.GetWidth(Ch)
					if CharX < CharW * 0.65 then
						Result = Result + len(Ch)
					end
					break
				end
				Result = Index
			end
		end
	end
	return Result
end

local function GetTextCursorPos(Instance, X, Y)
	local Result = 0
	if Instance ~= nil then
		local Line = Instance.Text
		local Start = 0

		if Instance.Lines ~= nil and #Instance.Lines > 0 then
			local H = Text.GetHeight()
			local LineNumber = 1
			local Found = false
			for I, V in ipairs(Instance.Lines) do
				if Y <= H then
					Line = V
					Found = true
					break
				end
				H = H + Text.GetHeight()
				Start = Start + #V
			end

			if not Found then
				Line = Instance.Lines[#Instance.Lines]
			end
		end

		Result = min(Start + GetCursorPosLine(Instance, Line, X), #Instance.Text)
	end
	return Result
end

local function MoveCursorPage(Instance, PageDown)
	if Instance ~= nil then
		local PageH = Instance.H - Text.GetHeight()
		local PageY = PageDown and PageH or 0.0
		local X, Y = GetCursorPos(Instance)
		local TX, TY = Region.InverseTransform(Instance.Id, 0.0, PageY)
		local NextY = 0.0
		if PageDown then
			NextY = TY + PageH
		else
			NextY = max(TY - PageH, 0.0)
		end

		TextCursorPos = GetTextCursorPos(Instance, 0.0, NextY)
		UpdateMultiLinePosition(Instance)
	end
end

local function UpdateTransform(Instance)
	if Instance ~= nil then
		local X, Y = GetCursorPos(Instance)

		local TX, TY = Region.InverseTransform(Instance.Id, 0.0, 0.0)
		local W = TX + Instance.W - Region.GetScrollPad() - Region.GetScrollBarSize()
		local H = TY + Instance.H

		if Instance.H > Text.GetHeight() then
			H = H - Region.GetScrollPad() - Region.GetScrollBarSize()
		end

		local NewX = 0.0
		if TextCursorPosLine == 0 then
			NewX = TX
		elseif X > W then
			NewX = -(X - W)
		elseif X < TX then
			NewX = TX - X
		end

		local NewY = 0.0
		if TextCursorPosLineNumber == 1 then
			NewY = TY
		elseif Y > H then
			NewY = -(Y - H)
		elseif Y < TY then
			NewY = TY - Y
		end

		Region.Translate(Instance.Id, NewX, NewY)
	end
end

local function DeleteSelection(Instance)
	if Instance ~= nil and Instance.Text ~= "" and not Instance.ReadOnly then
		local Start = 0
		local Min = 0
		local Max = 0

		if TextCursorAnchor ~= -1 then
			Min = min(TextCursorAnchor, TextCursorPos)
			Max = max(TextCursorAnchor, TextCursorPos) + 1
		else
			if TextCursorPos == 0 then
				return false
			end

			local NewTextCursorPos = TextCursorPos
			local Ch = GetCharacter(Instance.Text, TextCursorPos)
			if Ch ~= nil then
				Min = TextCursorPos - len(Ch)
				NewTextCursorPos = Min
			end

			Ch = GetCharacter(Instance.Text, TextCursorPos, true)
			if Ch ~= nil then
				Max = TextCursorPos + 1
			else
				Max = len(Instance.Text) + 1
			end

			TextCursorPos = NewTextCursorPos
		end

		local Left = sub(Instance.Text, 1, Min)
		local Right = sub(Instance.Text, Max)
		Instance.Text = Left .. Right

		TextCursorPos = len(Left)

		if TextCursorAnchor ~= -1 then
			TextCursorPos = min(TextCursorAnchor, TextCursorPos)
		end
		TextCursorPos = max(0, TextCursorPos)
		TextCursorPos = min(TextCursorPos, len(Instance.Text))

		TextCursorAnchor = -1
		UpdateMultiLinePosition(Instance)
	end
	return true
end

local function DrawSelection(Instance, X, Y, W, H, Color)
	if Instance ~= nil and TextCursorAnchor >= 0 and TextCursorAnchor ~= TextCursorPos then
		local Min = min(TextCursorAnchor, TextCursorPos)
		local Max = max(TextCursorAnchor, TextCursorPos)
		H = Text.GetHeight()

		if Instance.Lines ~= nil then
			local Count = 0
			local Start = 0
			local OffsetMin = 0
			local OffsetMax = 0
			local OffsetY = 0
			for I, V in ipairs(Instance.Lines) do
				Count = Count + len(V)
				if Min < Count then
					if Min > Start then
						OffsetMin = max(Min - Start, 1)
					else
						OffsetMin = 0
					end

					if Max < Count then
						OffsetMax = max(Max - Start, 1)
					else
						OffsetMax = len(V)
					end

					local SubMin = sub(V, 1, OffsetMin)
					local SubMax = sub(V, 1, OffsetMax)
					local MinX = Text.GetWidth(SubMin) - 1.0 + GetAlignmentOffset(Instance)
					local MaxX = Text.GetWidth(SubMax) + 1.0 + GetAlignmentOffset(Instance)

					DrawCommands.Rectangle('fill', X + MinX, Y + OffsetY, MaxX - MinX, H, Color)
				end

				if Max <= Count then
					break
				end
				Start = Start + len(V)
				OffsetY = OffsetY + H
			end
		else
			local SubMin = sub(Instance.Text, 1, Min)
			local SubMax = sub(Instance.Text, 1, Max)
			local MinX = Text.GetWidth(SubMin) - 1.0 + GetAlignmentOffset(Instance)
			local MaxX = Text.GetWidth(SubMax) + 1.0 + GetAlignmentOffset(Instance)

			DrawCommands.Rectangle('fill', X + MinX, Y, MaxX - MinX, H, Color)
		end
	end
end

local function DrawCursor(Instance, X, Y, W, H)
	if Instance ~= nil then
		local CX, CY = GetCursorPos(Instance)
		local CX = X + CX
		local CY = Y + CY
		H = Text.GetHeight()

		DrawCommands.Line(CX, CY, CX, CY + H, 1.0, {0.0, 0.0, 0.0, TextCursorAlpha})
	end
end

local function IsHighlightTerminator(Ch)
	if Ch ~= nil then
		return match(Ch, "%w") == nil
	end

	return true
end

local function UpdateTextObject(Instance, Width, Align, Highlight, BaseColor)
	if Instance ~= nil and Instance.TextObject ~= nil then
		local ColoredText = {}

		if Highlight == nil then
			ColoredText = {BaseColor, Instance.Text}
		else
			--local StartTime = love.timer.getTime()

			local TX, TY = Region.InverseTransform(Instance.Id, 0, 0)
			local TextH = Text.GetHeight()
			local Top = TY - TextH * 2
			local Bottom = TY + Instance.H + TextH * 2
			local H = #Instance.Lines * TextH
			local TopLineNo = max(floor((Top / H) * #Instance.Lines), 1)
			local BottomLineNo = min(floor((Bottom / H) * #Instance.Lines), #Instance.Lines)

			local Index = 1
			local EndIndex = 1
			for I = 1, BottomLineNo, 1 do
				local Count = len(Instance.Lines[I])
				if I < TopLineNo then
					Index = Index + Count
				end

				EndIndex = EndIndex + Count
			end

			if Index > 1 then
				insert(ColoredText, BaseColor)
				insert(ColoredText, sub(Instance.Text, 1, Index - 1))
			end

			while Index < EndIndex do
				local MatchIndex = nil
				local Key = nil
				for K, V in pairs(Highlight) do
					local Found = nil
					local Anchor = Index
					repeat
						Found = find(Instance.Text, K, Anchor, true)

						if Found ~= nil then
							local FoundEnd = Found + len(K)
							local Prev = sub(Instance.Text, Found - 1, Found - 1)
							local Next = sub(Instance.Text, FoundEnd, FoundEnd)
							
							if Found == 1 then
								Prev = nil
							end

							if FoundEnd > len(Instance.Text) then
								Next = nil
							end

							if not (IsHighlightTerminator(Prev) and IsHighlightTerminator(Next)) then
								Anchor = Found + 1
								Found = nil
							end
						else
							break
						end
					until Found ~= nil

					if Found ~= nil then
						if MatchIndex == nil then
							MatchIndex = Found
							Key = K
						elseif Found < MatchIndex then
							MatchIndex = Found
							Key = K
						end
					end
				end

				if Key ~= nil then
					insert(ColoredText, BaseColor)
					insert(ColoredText, sub(Instance.Text, Index, MatchIndex - 1))

					insert(ColoredText, Highlight[Key])
					insert(ColoredText, Key)

					Index = MatchIndex + len(Key)
				else
					insert(ColoredText, BaseColor)
					insert(ColoredText, sub(Instance.Text, Index, EndIndex))
					Index = EndIndex
					break
				end
			end

			if Index < len(Instance.Text) then
				insert(ColoredText, BaseColor)
				insert(ColoredText, sub(Instance.Text, Index))
			end

			--print(string.format("UpdateTextObject Time: %f", (love.timer.getTime() - StartTime)))
		end

		if #ColoredText == 0 then
			ColoredText = {BaseColor, Instance.Text}
		end

		Instance.TextObject:setf(ColoredText, Width, Align)
	end
end

local function UpdateSlider(Instance)
	if Instance ~= nil then
		local MouseX, MouseY = Mouse.Position()
		local MinX = Cursor.GetPosition()
		local MaxX = MinX + Instance.W
		local Ratio = Utility.Clamp((MouseX - MinX) / (MaxX - MinX), 0.0, 1.0)
		local Min = Instance.MinNumber == nil and -huge or Instance.MinNumber
		local Max = Instance.MaxNumber == nil and huge or Instance.MaxNumber
		local IsInteger = floor(Min) == Min and floor(Max) == Max
		local Value = (Max - Min) * Ratio + Min
		if IsInteger then
			Instance.Text = string.format("%d", Value)
		else
			Instance.Text = string.format("%.3f", Value)
		end
	end
end

local function UpdateDrag(Instance, Step)
	if Instance ~= nil then
		local DeltaX, DeltaY = Mouse.GetDelta()
		if DeltaX ~= 0.0 then
			local Value = tonumber(Instance.Text)
			if Value ~= nil then
				Value = Value + Step * DeltaX
				Instance.Text = tostring(Value)
				ValidateNumber(Instance)
			end
		end
	end
end

local function DrawSlider(Instance)
	if Instance ~= nil and Instance.NumbersOnly then
		local Value = tonumber(Instance.Text)
		if Value ~= nil then
			local Min = Instance.MinNumber == nil and -huge or Instance.MinNumber
			local Max = Instance.MaxNumber == nil and huge or Instance.MaxNumber
			local Ratio = (Value - Min) / (Max - Min)
			local SliderSize = 6.0
			local MinX, MinY = Cursor.GetPosition()
			local MaxX, MaxY = MinX + Instance.W - SliderSize, MinY + Instance.H
			local X = (MaxX - MinX) * Ratio + MinX
			DrawCommands.Rectangle('fill', X, MinY + 1.0, SliderSize, Instance.H - 2.0, Style.InputSliderColor)
		end
	end
end

local function GetInstance(Id)
	for I, V in ipairs(Instances) do
		if V.Id == Id then
			return V
		end
	end
	local Instance = {}
	Instance.Id = Id
	Instance.Text = ""
	Instance.TextChanged = false
	Instance.NumbersOnly = true
	Instance.ReadOnly = false
	Instance.Align = 'left'
	Instance.MinNumber = nil
	Instance.MaxNumber = nil
	Instance.Lines = nil
	Instance.TextObject = nil
	Instance.Highlight = nil
	Instance.ShouldUpdateTextObject = false
	insert(Instances, Instance)
	return Instance
end

function Input.Begin(Id, Options)
	assert(Id ~= nil, "Please pass a valid Id into Slab.Input.")

	local StatHandle = Stats.Begin('Input', 'Slab')

	Options = Options == nil and {} or Options
	Options.Tooltip = Options.Tooltip == nil and "" or Options.Tooltip
	Options.ReturnOnText = Options.ReturnOnText == nil and true or Options.ReturnOnText
	Options.Text = Options.Text == nil and nil or Options.Text
	Options.TextColor = Options.TextColor == nil and nil or Options.TextColor
	Options.BgColor = Options.BgColor == nil and Style.InputBgColor or Options.BgColor
	Options.SelectColor = Options.SelectColor == nil and Style.InputSelectColor or Options.SelectColor
	Options.SelectOnFocus = Options.SelectOnFocus == nil and true or Options.SelectOnFocus
	Options.W = Options.W == nil and nil or Options.W
	Options.H = Options.H == nil and nil or Options.H
	Options.ReadOnly = Options.ReadOnly == nil and false or Options.ReadOnly
	Options.Align = Options.Align == nil and nil or Options.Align
	Options.Rounding = Options.Rounding == nil and Style.InputBgRounding or Options.Rounding
	Options.MinNumber = Options.MinNumber == nil and nil or Options.MinNumber
	Options.MaxNumber = Options.MaxNumber == nil and nil or Options.MaxNumber
	Options.MultiLine = Options.MultiLine == nil and false or Options.MultiLine
	Options.MultiLineW = Options.MultiLineW == nil and huge or Options.MultiLineW
	Options.Highlight = Options.Highlight == nil and nil or Options.Highlight
	Options.Step = Options.Step == nil and 1.0 or Options.Step
	Options.NoDrag = Options.NoDrag == nil and false or Options.NoDrag
	Options.UseSlider = Options.UseSlider == nil and false or Options.UseSlider

	if type(Options.MinNumber) ~= "number" then
		Options.MinNumber = nil
	end

	if type(Options.MaxNumber) ~= "number" then
		Options.MaxNumber = nil
	end

	if Options.MultiLine then
		Options.TextColor = Style.MultilineTextColor
	end

	local Instance = GetInstance(Window.GetId() .. "." .. Id)
	Instance.NumbersOnly = Options.NumbersOnly
	Instance.ReadOnly = Options.ReadOnly
	Instance.Align = Options.Align
	Instance.MinNumber = Options.MinNumber
	Instance.MaxNumber = Options.MaxNumber
	Instance.MultiLine = Options.MultiLine

	if Instance.MultiLineW ~= Options.MultiLineW then
		Instance.Lines = nil
	end

	Instance.MultiLineW = Options.MultiLineW
	local WinItemId = Window.GetItemId(Id)

	if Instance.Align == nil then
		Instance.Align = (Instance == Focused and not IsSliding) and 'left' or 'center'

		if Instance.ReadOnly then
			Instance.Align = 'center'
		end

		if Options.MultiLine then
			Instance.Align = 'left'
		end
	end

	if Focused ~= Instance then
		if Options.MultiLine and #Options.Text ~= #Instance.Text then
			Instance.Lines = nil
		end

		Instance.Text = Options.Text == nil and Instance.Text or Options.Text
	end

	if Instance.MinNumber ~= nil and Instance.MaxNumber ~= nil then
		assert(Instance.MinNumber <= Instance.MaxNumber, 
			"Invalid MinNumber and MaxNumber passed to Input control '" .. Instance.Id .. "'. MinNumber: " .. Instance.MinNumber .. " MaxNumber: " .. Instance.MaxNumber)
	end

	local H = Options.H == nil and Text.GetHeight() or Options.H
	local W = Options.W == nil and MIN_WIDTH or Options.W
	local ContentW, ContentH = 0.0, 0.0
	local Result = false

	W, H = LayoutManager.ComputeSize(W, H)
	LayoutManager.AddControl(W, H)

	Instance.W = W
	Instance.H = H

	local X, Y = Cursor.GetPosition()

	if Options.MultiLine then
		Options.SelectOnFocus = false
		local WasSanitized = false
		Options.Text, WasSanitized = SanitizeText(Options.Text)
		if WasSanitized then
			Result = true
			LastText = Options.Text
		end

		ContentW, ContentH = Text.GetSizeWrap(Instance.Text, Options.MultiLineW)
	end

	local ShouldUpdateTextObject = Instance.ShouldUpdateTextObject
	Instance.ShouldUpdateTextObject = false

	if Instance.Lines == nil and Instance.Text ~= "" then
		if Options.MultiLine then
			if Instance.TextObject == nil then
				Instance.TextObject = love.graphics.newText(Style.Font)
			end
			Instance.Lines = Text.GetLines(Instance.Text, Options.MultiLineW)
			ContentH = #Instance.Lines * Text.GetHeight()
			ShouldUpdateTextObject = true
		end
	end

	if Options.Highlight ~= nil then
		if Instance.Highlight == nil or Utility.TableCount(Options.Highlight) ~= Utility.TableCount(Instance.Highlight) then
			Instance.Highlight = Utility.Copy(Options.Highlight)
			ShouldUpdateTextObject = true
		else
			for K, V in pairs(Options.Highlight) do
				local HighlightColor = Instance.Highlight[K]
				if HighlightColor ~= nil then
					if V[1] ~= HighlightColor[1] or V[2] ~= HighlightColor[2] or V[3] ~= HighlightColor[3] or V[4] ~= HighlightColor[4] then
						ShouldUpdateTextObject = true
						break
					end
				else
					Instance.Highlight = Utility.Copy(Options.Highlight)
					ShouldUpdateTextObject = true
					break
				end
			end
		end
	else
		if Instance.Highlight ~= nil then
			Instance.Highlight = nil
			ShouldUpdateTextObject = true
		end
	end

	if ShouldUpdateTextObject then
		UpdateTextObject(Instance, Options.MultiLineW, Instance.Align, Options.Highlight, Options.TextColor)
	end

	local IsObstructed = Window.IsObstructedAtMouse()
	local MouseX, MouseY = Window.GetMousePosition()
	local Hovered = not IsObstructed and X <= MouseX and MouseX <= X + W and Y <= MouseY and MouseY <= Y + H
	local HoveredScrollBar = Region.IsHoverScrollBar(Instance.Id) or Region.IsScrolling()

	if Hovered and not HoveredScrollBar then
		Mouse.SetCursor('ibeam')
		Tooltip.Begin(Options.Tooltip)
		Window.SetHotItem(WinItemId)
	end

	local CheckFocus = Mouse.IsClicked(1) and not HoveredScrollBar
	local NumbersOnlyEntry = Mouse.IsDoubleClicked(1) and Instance.NumbersOnly

	local FocusedThisFrame = false
	local ClearFocus = false
	if CheckFocus then
		if Hovered then
			FocusedThisFrame = Focused ~= Instance
			Focused = Instance
		elseif Instance == Focused then
			ClearFocus = true
			Focused = nil
		end
	end

	if FocusToNext and LastFocused == nil then
		FocusedThisFrame = true
		Focused = Instance
		CheckFocus = true
		FocusToNext = false
		TextCursorAnchor = -1
		TextCursorPos = 0
		TextCursorPosLine = 0
		TextCursorPosLineNumber = 1
	end

	if LastFocused == Instance then
		LastFocused = nil
	end

	local IsEditing = Instance == Focused and not IsSliding

	if Instance == Focused then
		local Back = false
		local IgnoreBack = false
		local ShouldDelete = false
		local ShouldUpdateTransform = false
		local PreviousTextCursorPos = TextCursorPos

		if IsCommandKeyDown() then
			if Keyboard.IsPressed('x') or Keyboard.IsPressed('c') then
				local Selected = GetSelection(Instance)
				if Selected ~= "" then
					love.system.setClipboardText(Selected)
					ShouldDelete = Keyboard.IsPressed('x')
				end
			end

			if Keyboard.IsPressed('v') then
				local Text = love.system.getClipboardText()
				Input.Text(Text)
				TextCursorPos = min(TextCursorPos + #Text - 1, #Instance.Text)
			end
		end

		if Keyboard.IsPressed('tab') then
			if Options.MultiLine then
				Input.Text('\t')
			else
				LastFocused = Instance
				FocusToNext = true
			end
		end

		if Keyboard.IsPressed('backspace') then
			ShouldDelete = true
			IgnoreBack = TextCursorAnchor ~= -1
		end

		if Keyboard.IsPressed('delete') then
			if TextCursorAnchor == -1 then
				local Ch = GetCharacter(Instance.Text, TextCursorPos, true)
				if Ch ~= nil then
					TextCursorPos = TextCursorPos + len(Ch)
					ShouldDelete = true
				end
			else
				IgnoreBack = true
				ShouldDelete = true
			end
		end

		if ShouldDelete then
			if DeleteSelection(Instance) then
				Instance.TextChanged = true
			end
		end

		local ClearAnchor = false
		local IsShiftDown = Keyboard.IsDown('lshift') or Keyboard.IsDown('rshift')

		if Keyboard.IsPressed('lshift') or Keyboard.IsPressed('rshift') then
			if TextCursorAnchor == -1 then
				TextCursorAnchor = TextCursorPos
			end
		end

		local HomePressed, EndPressed = false, false

		if IsHomePressed() then
			MoveToHome(Instance)
			ShouldUpdateTransform = true
			HomePressed = true
		end

		if IsEndPressed() then
			MoveToEnd(Instance)
			ShouldUpdateTransform = true
			EndPressed = true
		end

		if not HomePressed and (Keyboard.IsPressed('left') or Back) then
			TextCursorPos = GetNextCursorPos(Instance, true)
			ShouldUpdateTransform = true
			UpdateMultiLinePosition(Instance)
		end
		if not EndPressed and Keyboard.IsPressed('right') then
			TextCursorPos = GetNextCursorPos(Instance, false)
			ShouldUpdateTransform = true
			UpdateMultiLinePosition(Instance)
		end

		if Keyboard.IsPressed('up') then
			MoveCursorVertical(Instance, false)
			ShouldUpdateTransform = true
		end
		if Keyboard.IsPressed('down') then
			MoveCursorVertical(Instance, true)
			ShouldUpdateTransform = true
		end

		if Keyboard.IsPressed('pageup') then
			MoveCursorPage(Instance, false)
			ShouldUpdateTransform = true
		end
		if Keyboard.IsPressed('pagedown') then
			MoveCursorPage(Instance, true)
			ShouldUpdateTransform = true
		end

		if CheckFocus or DragSelect then
			if FocusedThisFrame then
				if Options.NumbersOnly and not NumbersOnlyEntry and not Options.NoDrag then
					IsSliding = true
				elseif Options.SelectOnFocus and Instance.Text ~= "" then
					TextCursorAnchor = 0
					TextCursorPos = #Instance.Text
				end
			else
				local MouseInputX, MouseInputY = MouseX - X, MouseY - Y
				local CX, CY = Region.InverseTransform(Instance.Id, MouseInputX, MouseInputY)
				TextCursorPos = GetTextCursorPos(Instance, CX, CY)
				if Mouse.IsClicked(1) then
					TextCursorAnchor = TextCursorPos
					DragSelect = true
				end
				ShouldUpdateTransform = true
				IsShiftDown = true
			end
			UpdateMultiLinePosition(Instance)
		end

		if IsSliding then
			if Options.UseSlider then
				UpdateSlider(Instance)
			else
				UpdateDrag(Instance, Options.Step)
			end
		end

		if Mouse.IsReleased(1) then
			DragSelect = false
			if TextCursorAnchor == TextCursorPos then
				TextCursorAnchor = -1
			end

			if IsSliding then
				IsSliding = false
				Focused = nil
				Result = true
				LastText = Instance.Text
			end
		end

		if Mouse.IsDoubleClicked(1) then
			local MouseInputX, MouseInputY = MouseX - X, MouseY - Y
			local CX, CY = Region.InverseTransform(Instance.Id, MouseInputX, MouseInputY)
			TextCursorPos = GetTextCursorPos(Instance, CX, CY)
			SelectWord(Instance)
			DragSelect = false
		end

		if Keyboard.IsPressed('return') then
			Result = true
			if Options.MultiLine then
				Input.Text('\n')
			else
				ClearFocus = true
			end
		end

		if Instance.TextChanged or Back then
			if Options.ReturnOnText then
				Result = true
			end

			if Options.MultiLine then
				Instance.Lines = Text.GetLines(Instance.Text, Options.MultiLineW)
				UpdateTextObject(Instance, Options.MultiLineW, Instance.Align, Options.Highlight, Options.TextColor)
			end

			UpdateMultiLinePosition(Instance)

			Instance.TextChanged = false
			PreviousTextCursorPos = -1
		end

		if ShouldUpdateTransform then
			ClearAnchor = not IsShiftDown
			UpdateTransform(Instance)
		end

		if ClearAnchor then
			TextCursorAnchor = -1
		end
	else
		local WasValidated = ValidateNumber(Instance)
		if WasValidated then
			Result = true
			LastText = Instance.Text
		end
	end

	if Region.IsScrolling(Instance.Id) then
		local DeltaX, DeltaY = Mouse.GetDelta()
		local WheelX, WheelY = Region.GetWheelDelta()

		if DeltaY ~= 0.0 or WheelY ~= 0.0 then
			Instance.ShouldUpdateTextObject = true
		end
	end

	if (Instance == Focused and not Instance.ReadOnly) or Options.MultiLine then
		Options.BgColor = Style.InputEditBgColor
	end

	local TX, TY = Window.TransformPoint(X, Y)
	Region.Begin(Instance.Id, {
		X = X,
		Y = Y,
		W = W,
		H = H,
		ContentW = ContentW + Pad,
		ContentH = ContentH + Pad,
		BgColor = Options.BgColor,
		SX = TX,
		SY = TY,
		MouseX = MouseX,
		MouseY = MouseY,
		Intersect = true,
		IgnoreScroll = not Options.MultiLine,
		Rounding = Options.Rounding,
		IsObstructed = IsObstructed,
		AutoSizeContent = false
	})
	if Instance == Focused then
		if not IsSliding then
			DrawSelection(Instance, X, Y, W, H, Options.SelectColor)
			DrawCursor(Instance, X, Y, W, H)
		end
	end

	if Options.UseSlider then
		if not IsEditing then
			DrawSlider(Instance)
		end
	end

	if Instance.Text ~= "" then
		Cursor.SetPosition(X + GetAlignmentOffset(Instance), Y)

		LayoutManager.Begin('Ignore', {Ignore = true})
		if Instance.TextObject ~= nil then
			Text.BeginObject(Instance.TextObject)
		else
			Text.Begin(Instance.Text, {AddItem = false, Color = Options.TextColor})
		end
		LayoutManager.End()
	end
	Region.End()
	Region.ApplyScissor()

	Cursor.SetItemBounds(X, Y, W, H)
	Cursor.SetPosition(X, Y)
	Cursor.AdvanceX(W)
	Cursor.AdvanceY(H)

	Window.AddItem(X, Y, W, H, WinItemId)

	if ClearFocus then
		ValidateNumber(Instance)
		LastText = Instance.Text
		Focused = nil

		if not Options.MultiLine then
			Region.ResetTransform(Instance.Id)
		end
	end

	Stats.End(StatHandle)

	return Result
end

function Input.Text(Ch)
	if Focused ~= nil and not Focused.ReadOnly then
		if not IsValidDigit(Focused, Ch) then
			return
		end

		if TextCursorAnchor ~= -1 then
			DeleteSelection(Focused)
		end

		if TextCursorPos == 0 then
			Focused.Text = Ch .. Focused.Text
		else
			local Temp = Focused.Text
			local Left = sub(Temp, 0, TextCursorPos)
			local Right = sub(Temp, TextCursorPos + 1)
			Focused.Text = Left .. Ch .. Right
		end

		TextCursorPos = min(TextCursorPos + len(Ch), len(Focused.Text))
		TextCursorAnchor = -1
		UpdateTransform(Focused)
		Focused.TextChanged = true
	end
end

function Input.Update(dt)
	local Delta = dt * 2.0
	if FadeIn then
		TextCursorAlpha = min(TextCursorAlpha + Delta, 1.0)
		FadeIn = TextCursorAlpha < 1.0
	else
		TextCursorAlpha = max(TextCursorAlpha - Delta, 0.0)
		FadeIn = TextCursorAlpha == 0.0
	end

	if PendingFocus ~= nil then
		LastFocused = Focused
		Focused = PendingFocus
		PendingFocus = nil
	end

	if Focused ~= nil then
		if PendingCursorPos >= 0 then
			TextCursorPos = min(PendingCursorPos, #Focused.Text)
			ValidateTextCursorPos(Focused)
			UpdateMultiLinePosition(Focused)
			PendingCursorPos = -1
		end

		local MultiLineChanged = false

		if PendingCursorColumn >= 0 then
			if Focused.Lines ~= nil then
				TextCursorPosLine = PendingCursorColumn
				MultiLineChanged = true
			end

			PendingCursorColumn = -1
		end

		if PendingCursorLine > 0 then
			if Focused.Lines ~= nil then
				TextCursorPosLineNumber = min(PendingCursorLine, #Focused.Lines)
				MultiLineChanged = true
			end

			PendingCursorLine = 0
		end

		if MultiLineChanged then
			local Line = Focused.Lines[TextCursorPosLineNumber]
			TextCursorPosLine = min(TextCursorPosLine, len(Line))
			local Start = 0
			for I, V in ipairs(Focused.Lines) do
				if I == TextCursorPosLineNumber then
					TextCursorPos = Start + TextCursorPosLine
					break
				end
				Start = Start + len(V)
			end
			ValidateTextCursorPos(Focused)
		end
	else
		PendingCursorPos = -1
		PendingCursorColumn = -1
		PendingCursorLine = 0
	end
end

function Input.GetText()
	if Focused ~= nil then
		if Focused.NumbersOnly and (Focused.Text == "" or Focused.Text == ".") then
			return "0"
		end
		return Focused.Text
	end
	return LastText
end

function Input.GetCursorPos()
	if Focused ~= nil then
		return TextCursorPos, TextCursorPosLine, TextCursorPosLineNumber
	end

	return 0, 0, 0
end

function Input.IsAnyFocused()
	return Focused ~= nil
end

function Input.IsFocused(Id)
	local Instance = GetInstance(Window.GetId() .. '.' .. Id)
	return Instance == Focused
end

function Input.SetFocused(Id)
	local Instance = GetInstance(Window.GetId() .. '.' .. Id)
	PendingFocus = Instance
end

function Input.SetCursorPos(Pos)
	PendingCursorPos = max(Pos, 0)
end

function Input.SetCursorPosLine(Column, Line)
	if Column ~= nil then
		PendingCursorColumn = max(Column, 0)
	end

	if Line ~= nil then
		PendingCursorLine = max(Line, 1)
	end
end

function Input.GetDebugInfo()
	local Info = {}
	local X, Y = GetCursorPos(Focused)

	if Focused ~= nil then
		Region.InverseTransform(Focused.Id, X, Y)
	end

	Info['Focused'] = Focused ~= nil and Focused.Id or 'nil'
	Info['Width'] = Focused ~= nil and Focused.W or 0
	Info['Height'] = Focused ~= nil and Focused.H or 0
	Info['CursorX'] = X
	Info['CursorY'] = Y
	Info['CursorPos'] = TextCursorPos
	Info['Character'] = Focused ~= nil and GetDisplayCharacter(Focused.Text, TextCursorPos) or ''
	Info['LineCursorPos'] = TextCursorPosLine
	Info['LineCursorPosMax'] = TextCursorPosLineMax
	Info['LineNumber'] = TextCursorPosLineNumber
	Info['LineLength'] = (Focused ~= nil and Focused.Lines ~= nil) and len(Focused.Lines[TextCursorPosLineNumber]) or 0
	Info['Lines'] = Focused ~= nil and Focused.Lines or nil

	return Info
end

return Input
