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

local Button = require(SLAB_PATH .. '.Internal.UI.Button')
local Cursor = require(SLAB_PATH .. '.Internal.Core.Cursor')
local Text = require(SLAB_PATH .. '.Internal.UI.Text')
local Window = require(SLAB_PATH .. '.Internal.UI.Window')

local Dialog = {}
local Instances = {}
local ActiveInstance = nil
local Stack = {}

local function GetInstance(Id)
	if Instances[Id] == nil then
		local Instance = {}
		Instance.Id = Id
		Instance.IsOpen = false
		Instance.W = 0.0
		Instance.H = 0.0
		Instances[Id] = Instance
	end
	return Instances[Id]
end

function Dialog.Begin(Id, Options)
	local Instance = GetInstance(Id)
	if not Instance.IsOpen then
		return false
	end

	Options = Options == nil and {} or Options
	Options.Border = Options.Border == nil and 12.0 or Options.Border
	Options.X = love.graphics.getWidth() * 0.5 - Instance.W * 0.5
	Options.Y = love.graphics.getHeight() * 0.5 - Instance.H * 0.5
	Options.Layer = 'Dialog'
	Options.AllowFocus = false
	Options.AllowMove = false
	Options.AutoSizeWindow = true
	if #Stack > 0 and Stack[1] == Instance then
		Options.SkipObstruct = true
	end

	Window.Begin(Instance.Id, Options)

	ActiveInstance = Instance

	return true
end

function Dialog.End()
	assert(ActiveInstance ~= nil, "EndDialog was called outside of BeginDialog.")
	ActiveInstance.W, ActiveInstance.H = Window.GetSize()
	Window.End()

	ActiveInstance = nil
end

function Dialog.Open(Id)
	local Instance = GetInstance(Id)
	if not Instance.IsOpen then
		Instance.IsOpen = true
		table.insert(Stack, 1, Instance)
	end
end

function Dialog.Close()
	if ActiveInstance ~= nil and ActiveInstance.IsOpen then
		ActiveInstance.IsOpen = false
		table.remove(Stack, 1)

		if #Stack > 0 then
			ActiveInstance = Stack[1]
		end
	end
end

function Dialog.IsOpen()
	return #Stack > 0
end

function Dialog.MessageBox(Title, Message, Options)
	local Result = ""
	Dialog.Open('MessageBox')
	if Dialog.Begin('MessageBox', {Title = Title}) then
		Options = Options == nil and {} or Options
		Options.Buttons = Options.Buttons == nil and {"OK"} or Options.Buttons

		Cursor.NewLine()

		local WinX, WinY, WinW, WinH = Window.GetBounds()
		local TextW = Text.GetWidth(Message)
		TextW = math.min(TextW, love.graphics.getWidth() * 0.65)
		Cursor.SetX(WinX + (WinW * 0.5) - (TextW * 0.5))
		Text.BeginFormatted(Message, {W = TextW, Align = 'center'})

		Cursor.NewLine()
		Cursor.NewLine()

		local ButtonWidth = 0.0
		local WinW, WinH = Window.GetSize()
		for I, V in ipairs(Options.Buttons) do
			ButtonWidth = ButtonWidth + Button.GetWidth(V) + Cursor.PadX()
		end

		for I, V in ipairs(Options.Buttons) do
			if Button.Begin(V, {AlignRight = WinW > ButtonWidth}) then
				Result = V
			end
			Cursor.SameLine()
		end

		if Result ~= "" then
			Dialog.Close()
		end

		Dialog.End()
	end

	return Result
end

return Dialog
