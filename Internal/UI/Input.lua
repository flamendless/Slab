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
local Keyboard = require(SLAB_PATH .. '.Internal.Input.Keyboard')
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
local TextCursorAnchor = -1
local TextCursorAlpha = 0.0
local FadeIn = true
local DragSelect = false
local FocusToNext = false
local LastText = ""

local MIN_WIDTH = 150.0

local function ValidateNumber(Instance)
	local Result = false

	if Instance ~= nil and Instance.NumbersOnly and Instance.Text ~= "" then
		if string.sub(Instance.Text, #Instance.Text, #Instance.Text) == "." then
			return
		end

		local Value = tonumber(Instance.Text)
		if Value == nil then
			Value = 0.0
		end

		local OldValue = Value

		if Instance.MinNumber ~= nil then
			Value = math.max(Value, Instance.MinNumber)
		end
		if Instance.MaxNumber ~= nil then
			Value = math.min(Value, Instance.MaxNumber)
		end

		Result = OldValue ~= Value

		Instance.Text = tostring(Value)
	end

	return Result
end

local function GetAlignmentOffset(Instance)
	local Offset = 2.0
	if Instance.Align == 'center' then
		local TextW = Style.Font:getWidth(Instance.Text)
		Offset = (Instance.W * 0.5) - (TextW * 0.5)
	end
	return Offset
end

local function GetSelection(Instance)
	if Instance ~= nil and TextCursorAnchor >= 0 and TextCursorAnchor ~= TextCursorPos then
		local Min = math.min(TextCursorAnchor, TextCursorPos) + 1
		local Max = math.max(TextCursorAnchor, TextCursorPos)

		return string.sub(Instance.Text, Min, Max)
	end
	return ""
end

local function GetCharacter(Instance, Index)
	local Result = ""
	if Instance ~= nil then
		local Offset = UTF8.offset(Instance.Text, 0, Index)
		if Offset ~= nil then
			Result = string.sub(Instance.Text, Offset, Offset)
		end
	end
	return Result
end

local function IsValidDigit(Instance, Ch)
	if Instance ~= nil then
		if Instance.NumbersOnly then
			if string.match(Ch, "%d") ~= nil then
				return true
			end

			if Ch == "-" then
				if TextCursorAnchor == 0 or TextCursorPos == 0 or #Instance.Text == 0 then
					return true
				end
			end

			if Ch == "." then
				local Selected = GetSelection(Instance)
				if Selected ~= nil and string.find(Selected, ".", 1, true) ~= nil then
					return true
				end

				if string.find(Instance.Text, ".", 1, true) == nil then
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
			local Offset = UTF8.offset(Instance.Text, 0, TextCursorPos)
			local Sub = string.sub(Instance.Text, 1, Offset)
			Result = Style.Font:getWidth(Sub) + GetAlignmentOffset(Instance)
		end
	end
	return Result
end

local function SelectWord(Instance)
	if Instance ~= nil then
		local Filter = " "
		local RawSearch = true
		if GetCharacter(Instance, TextCursorPos) == " " then
			if GetCharacter(Instance, TextCursorPos + 1) == " " then
				Filter = "%S"
				RawSearch = false
			else
				TextCursorPos = TextCursorPos + 1
			end
		end
		TextCursorAnchor = 0
		local I = 0
		while I ~= nil and I + 1 < TextCursorPos do
			I = string.find(Instance.Text, Filter, I + 1, RawSearch)
			if I ~= nil and I < TextCursorPos then
				TextCursorAnchor = I
			else
				break
			end
		end
		I = string.find(Instance.Text, Filter, TextCursorPos + 1, RawSearch)
		if I ~= nil then
			TextCursorPos = I - 1
		else
			TextCursorPos = #Instance.Text
		end
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
					I = string.find(Instance.Text, " ", I + 1, true)
					if I ~= nil and I < TextCursorPos then
						Result = I
					else
						break
					end
				end
			else
				local I = string.find(Instance.Text, " ", TextCursorPos + 1, true)
				if I ~= nil then
					Result = I
				else
					Result = #Instance.Text
				end
			end
		else
			if Left then
				Result = TextCursorPos - 1
			else
				Result = TextCursorPos + 1
			end
		end
		Result = math.max(0, Result)
		Result = math.min(Result, #Instance.Text)
	end
	return Result
end

local function GetTextCursorPos(Instance, X)
	local Result = 0
	if Instance ~= nil then
		X = X - GetAlignmentOffset(Instance)
		for I = 1, #Instance.Text, 1 do
			local Offset = UTF8.offset(Instance.Text, 0, I)
			local Sub = string.sub(Instance.Text, 1, Offset)
			local PosX = Style.Font:getWidth(Sub)
			if PosX > X then
				local Char = string.sub(Instance.Text, Offset, Offset)
				local CharX = PosX - X
				local CharW = Style.Font:getWidth(Char)
				if CharX < CharW * 0.65 then
					Result = Result + 1
				end
				break
			end
			Result = I
		end
	end
	return Result
end

local function UpdateTransform(Instance)
	if Instance ~= nil then
		local Offset = GetCursorXOffset(Instance)
		local TX, TY = Region.InverseTransform(Instance.Id, 0.0, 0.0)
		local W = TX + Instance.W

		if Offset > W then
			Region.Translate(Instance.Id, -(Offset - W), 0.0)
		elseif Offset < TX then
			Region.Translate(Instance.Id, TX - Offset, 0.0)
		end
	end
end

local function DeleteSelection(Instance)
	local Result = false
	if Instance ~= nil and Instance.Text ~= "" and not Instance.ReadOnly then
		local Start = 0
		local Min = 0
		local Max = 0

		if TextCursorAnchor ~= -1 then
			Min = math.min(TextCursorAnchor, TextCursorPos) + 1
			Max = math.max(TextCursorAnchor, TextCursorPos) + 1

			if Min == 1 then
				Start = #Instance.Text + 1
			end

			Result = true
		else
			if TextCursorPos == 0 then
				return Result
			end

			Min = TextCursorPos
			Max = TextCursorPos + 1

			if Min == 1 then
				Start = #Instance.Text + 1
				Max = Min + 1
			end

			Result = true
		end

		local OffsetMin = UTF8.offset(Instance.Text, -1, math.max(Min, 1))
		local OffsetMax = UTF8.offset(Instance.Text,  1, Max)

		Instance.Text = string.sub(Instance.Text, Start, OffsetMin) .. string.sub(Instance.Text, OffsetMax)

		if Result then
			if TextCursorAnchor ~= -1 then
				TextCursorPos = math.min(TextCursorAnchor, TextCursorPos)
			end
			TextCursorPos = math.max(0, TextCursorPos)
			TextCursorPos = math.min(TextCursorPos, #Instance.Text + 1)
		end

		TextCursorAnchor = -1
	end
	return Result
end

local function DrawSelection(Instance, X, Y, W, H, Color)
	if Instance ~= nil and TextCursorAnchor >= 0 and TextCursorAnchor ~= TextCursorPos then
		local Min = math.min(TextCursorAnchor, TextCursorPos)
		local Max = math.max(TextCursorAnchor, TextCursorPos)

		local OffsetMin = UTF8.offset(Instance.Text, 1, math.max(Min, 1))
		local OffsetMax = UTF8.offset(Instance.Text, 1, Max)
		if Min == 0 then
			OffsetMin = 0
		end

		local SubMin = string.sub(Instance.Text, 1, OffsetMin)
		local SubMax = string.sub(Instance.Text, 1, OffsetMax)
		local MinX = Style.Font:getWidth(SubMin) - 1.0 + GetAlignmentOffset(Instance)
		local MaxX = Style.Font:getWidth(SubMax) + 1.0 + GetAlignmentOffset(Instance)

		DrawCommands.Rectangle('fill', X + MinX, Y, MaxX - MinX, H, Color)
	end
end

local function DrawCursor(Instance, X, Y, W, H)
	if Instance ~= nil then
		local CX = X + GetCursorXOffset(Instance)
		local CY = Y

		DrawCommands.Line(CX, CY, CX, CY + H, 1.0, {0.0, 0.0, 0.0, TextCursorAlpha})
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
	table.insert(Instances, Instance)
	return Instance
end

function Input.Begin(Id, Options)
	assert(Id ~= nil, "Please pass a valid Id into Slab.Input.")

	Stats.Begin('Input')

	Options = Options == nil and {} or Options
	Options.Tooltip = Options.Tooltip == nil and "" or Options.Tooltip
	Options.ReturnOnText = Options.ReturnOnText == nil and true or Options.ReturnOnText
	Options.Text = Options.Text == nil and nil or Options.Text
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

	if type(Options.MinNumber) ~= "number" then
		Options.MinNumber = nil
	end

	if type(Options.MaxNumber) ~= "number" then
		Options.MaxNumber = nil
	end

	local Instance = GetInstance(Window.GetId() .. "." .. Id)
	Instance.NumbersOnly = Options.NumbersOnly
	Instance.ReadOnly = Options.ReadOnly
	Instance.Align = Options.Align
	Instance.MinNumber = Options.MinNumber
	Instance.MaxNumber = Options.MaxNumber
	local WinItemId = Window.GetItemId(Id)
	if Focused ~= Instance then
		Instance.Text = Options.Text == nil and Instance.Text or Options.Text
	end

	if Instance.MinNumber ~= nil and Instance.MaxNumber ~= nil then
		assert(Instance.MinNumber < Instance.MaxNumber, 
			"Invalid MinNumber and MaxNumber passed to Input control '" .. Instance.Id .. "'. MinNumber: " .. Instance.MinNumber .. " MaxNumber: " .. Instance.MaxNumber)
	end

	local X, Y = Cursor.GetPosition()
	local H = Options.H == nil and Input.GetHeight() or Options.H
	local W = Options.W == nil and MIN_WIDTH or Options.W
	local Result = false

	Instance.W = W

	local MouseX, MouseY = Window.GetMousePosition()
	local Hovered = not Window.IsObstructedAtMouse() and X <= MouseX and MouseX <= X + W and Y <= MouseY and MouseY <= Y + H

	if Hovered then
		Mouse.SetCursor('ibeam')
		Tooltip.Begin(Options.Tooltip)
		Window.SetHotItem(WinItemId)
	end

	local CheckFocus = Mouse.IsClicked(1)

	local FocusedThisFrame = false
	local ClearFocus = false
	if CheckFocus then
		if Hovered then
			FocusedThisFrame = Focused ~= Instance
			Focused = Instance
		elseif Instance == Focused then
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
	end

	if LastFocused == Instance then
		LastFocused = nil
	end

	if Instance.Align == nil then
		Instance.Align = Instance == Focused and 'left' or 'center'

		if Instance.ReadOnly then
			Instance.Align = 'center'
		end
	end

	if Instance == Focused then
		local Back = false
		local IgnoreBack = false
		local ShouldDelete = false
		local ShouldUpdateTransform = false

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
				TextCursorPos = math.min(TextCursorPos + #Text - 1, #Instance.Text)
			end
		end

		if Keyboard.IsPressed('tab') then
			LastFocused = Instance
			FocusToNext = true
		end

		if Keyboard.IsPressed('backspace') then
			ShouldDelete = true
			IgnoreBack = TextCursorAnchor ~= -1
		end

		if Keyboard.IsPressed('delete') then
			ShouldDelete = true
			if TextCursorAnchor == -1 then
				TextCursorPos = TextCursorPos + 1
			else
				IgnoreBack = true
			end
		end

		if ShouldDelete then
			if DeleteSelection(Instance) then
				Back = not IgnoreBack
			end
		end

		local ClearAnchor = false
		local IsShiftDown = Keyboard.IsDown('lshift') or Keyboard.IsDown('rshift')

		if Keyboard.IsPressed('lshift') or Keyboard.IsPressed('rshift') then
			if TextCursorAnchor == -1 then
				TextCursorAnchor = TextCursorPos
			end
		end

		if IsHomePressed() then
			TextCursorPos = 0
			ShouldUpdateTransform = true
		end

		if IsEndPressed() then
			TextCursorPos = #Instance.Text
			ShouldUpdateTransform = true
		end

		if Keyboard.IsPressed('left') or Back then
			TextCursorPos = GetNextCursorPos(Instance, true)
			ShouldUpdateTransform = true
		end
		if Keyboard.IsPressed('right') then
			TextCursorPos = GetNextCursorPos(Instance, false)
			ShouldUpdateTransform = true
		end

		if CheckFocus or DragSelect then
			if FocusedThisFrame and Options.SelectOnFocus and Instance.Text ~= "" then
				TextCursorAnchor = 0
				TextCursorPos = #Instance.Text
			else
				local MouseInputX, MouseInputY = MouseX - X, MouseY - Y
				local CX, CY = Region.InverseTransform(Instance.Id, MouseInputX, MouseInputY)
				TextCursorPos = GetTextCursorPos(Instance, CX)
				if Mouse.IsClicked(1) then
					TextCursorAnchor = TextCursorPos
					DragSelect = true
				end
				ShouldUpdateTransform = true
				IsShiftDown = true
			end
		end

		if Mouse.IsReleased(1) then
			DragSelect = false
			if TextCursorAnchor == TextCursorPos then
				TextCursorAnchor = -1
			end
		end

		if Mouse.IsDoubleClicked(1) then
			local MouseInputX, MouseInputY = MouseX - X, MouseY - Y
			local CX, CY = Region.InverseTransform(Instance.Id, MouseInputX, MouseInputY)
			TextCursorPos = GetTextCursorPos(Instance, CX)
			SelectWord(Instance)
			DragSelect = false
		end

		if ShouldUpdateTransform then
			ClearAnchor = not IsShiftDown
			UpdateTransform(Instance)
		end

		if Keyboard.IsPressed('return') then
			Result = true
			ClearFocus = true
		end

		if Instance.TextChanged or Back then
			if Options.ReturnOnText then
				Result = true
			end

			Instance.TextChanged = false
		end

		if ClearAnchor then
			TextCursorAnchor = -1
		end
	else
		Result = ValidateNumber(Instance)
		if Result then
			LastText = Instance.Text
		end
	end

	if Instance == Focused and not Instance.ReadOnly then
		Options.BgColor = Style.InputEditBgColor
	end

	local TX, TY = Window.TransformPoint(X, Y)
	Region.Begin(Instance.Id, {
		X = X,
		Y = Y,
		W = W,
		H = H,
		BgColor = Options.BgColor,
		SX = TX,
		SY = TY,
		Intersect = true,
		IgnoreScroll = true,
		Rounding = Options.Rounding
	})
	if Instance == Focused then
		DrawSelection(Instance, X, Y, W, H, Options.SelectColor)
		DrawCursor(Instance, X, Y, W, H)
	end
	if Instance.Text ~= "" then
		Cursor.SetPosition(X + GetAlignmentOffset(Instance), Y)
		Text.Begin(Instance.Text, {AddItem = false})
	end
	Region.End()
	Region.ApplyScissor()

	Cursor.SetItemBounds(X, Y, W, H)
	Cursor.SetPosition(X, Y)
	Cursor.AdvanceX(W)
	Cursor.AdvanceY(H)

	Window.AddItem(X, Y, W, H, WinItemId)

	if ClearFocus then
		if Instance.NumbersOnly then
			local Value = tonumber(Instance.Text)
			if Value ~= nil then
				Instance.Text = tostring(Value)
			end
		end

		LastText = Instance.Text
		Focused = nil
		Region.ResetTransform(Instance.Id)
	end

	Stats.End('Input')

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
			local LOffset = UTF8.offset(Temp, 1, TextCursorPos)
			local ROffset = UTF8.offset(Temp, 2, TextCursorPos)

			Focused.Text = string.sub(Temp, 1, LOffset)
			Focused.Text = Focused.Text .. Ch
			Focused.Text = Focused.Text .. string.sub(Temp, ROffset)
		end

		TextCursorPos = math.min(TextCursorPos + 1, #Focused.Text)
		TextCursorAnchor = -1
		UpdateTransform(Focused)
		Focused.TextChanged = true
	end
end

function Input.Update(dt)
	local Delta = dt * 2.0
	if FadeIn then
		TextCursorAlpha = math.min(TextCursorAlpha + Delta, 1.0)
		FadeIn = TextCursorAlpha < 1.0
	else
		TextCursorAlpha = math.max(TextCursorAlpha - Delta, 0.0)
		FadeIn = TextCursorAlpha == 0.0
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

function Input.GetHeight()
	return Style.Font:getHeight()
end

return Input
