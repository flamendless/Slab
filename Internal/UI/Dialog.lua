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
local FileSystem = require(SLAB_PATH .. '.Internal.Core.FileSystem')
local Image = require(SLAB_PATH .. '.Internal.UI.Image')
local Input = require(SLAB_PATH .. '.Internal.UI.Input')
local Keyboard = require(SLAB_PATH .. '.Internal.Input.Keyboard')
local ListBox = require(SLAB_PATH .. '.Internal.UI.ListBox')
local Mouse = require(SLAB_PATH .. '.Internal.Input.Mouse')
local Text = require(SLAB_PATH .. '.Internal.UI.Text')
local Utility = require(SLAB_PATH .. '.Internal.Core.Utility')
local Window = require(SLAB_PATH .. '.Internal.UI.Window')

local Dialog = {}
local Instances = {}
local ActiveInstance = nil
local Stack = {}

local function PruneResults(Items, DirectoryOnly)
	local Result = {}

	for I, V in ipairs(Items) do
		if FileSystem.IsDirectory(V) then
			if DirectoryOnly then
				table.insert(Result, V)
			end
		else
			if not DirectoryOnly then
				table.insert(Result, V)
			end
		end
	end

	return Result
end

local function OpenDirectory(Dir)
	if ActiveInstance ~= nil and ActiveInstance.Directory ~= nil then
		ActiveInstance.Items = nil
		if Dir == ".." then
			ActiveInstance.Directory = FileSystem.Parent(ActiveInstance.Directory)
		else
			ActiveInstance.Directory = ActiveInstance.Directory .. "/" .. Dir
		end
	end
end

local function FileDialogItem(Id, Label, IsDirectory, Index)
	ListBox.BeginItem(Id, {Selected = Utility.HasValue(ActiveInstance.Selected, Index)})

	if IsDirectory then
		Image.Begin('FileDialog_Folder', {Path = SLAB_PATH .. "/Internal/Resources/Textures/Folder.png"})
		Cursor.SameLine({CenterY = true})
	end

	Text.Begin(Label)

	if ListBox.IsItemClicked(1) then
		if ActiveInstance.AllowMultiSelect and (Keyboard.IsDown('lctrl') or Keyboard.IsDown('rctrl')) then
			table.insert(ActiveInstance.Selected, Index)
			table.insert(ActiveInstance.Return, ActiveInstance.Directory .. "/" .. Label)
		else
			ActiveInstance.Selected = {Index}
			ActiveInstance.Return = {ActiveInstance.Directory .. "/" .. Label}
		end
	end

	if ListBox.IsItemClicked(1, true) and IsDirectory then
		OpenDirectory(Label)
	end

	ListBox.EndItem()
end

local function IsInstanceOpen(Id)
	local Instance = Instances[Id]
	if Instance ~= nil then
		return Instance.IsOpen
	end
	return false
end

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
	Options.AutoSizeWindow = Options.AutoSizeWindow == nil and true or Options.AutoSizeWindow
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
			local ButtonW, ButtonH = Button.GetSize(V)
			ButtonWidth = ButtonWidth + ButtonW + Cursor.PadX()
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

function Dialog.FileDialog(Options)
	Options = Options == nil and {} or Options
	Options.AllowMultiSelect = Options.AllowMultiSelect == nil and true or Options.AllowMultiSelect
	Options.Directory = Options.Directory == nil and nil or Options.Directory
	Options.Type = Options.Type == nil and 'openfile' or Options.Type

	local Result = {Button = "", Files = {}}
	local WasOpen = IsInstanceOpen('FileDialog')

	Dialog.Open("FileDialog")
	local W = love.graphics.getWidth() * 0.65
	local H = love.graphics.getHeight() * 0.65
	if Dialog.Begin('FileDialog', {
		Title = "Open File",
		AutoSizeWindow = false,
		W = W,
		H = H,
		AutoSizeContent = false,
		AllowResize = false
	}) then
		ActiveInstance.AllowMultiSelect = Options.AllowMultiSelect

		if not WasOpen then
			if ActiveInstance.Directory == nil then
				ActiveInstance.Directory = love.filesystem.getSourceBaseDirectory()
			end

			if Options.Directory ~= nil and FileSystem.IsDirectory(Options.Directory) then
				ActiveInstance.Directory = Options.Directory
			end
		end

		if ActiveInstance.Items == nil then
			ActiveInstance.Items = FileSystem.GetDirectoryItems(ActiveInstance.Directory)
			ActiveInstance.Selected = {}
			ActiveInstance.Directories = {}
			ActiveInstance.Files = {}
			ActiveInstance.Return = {}

			for I, V in ipairs(ActiveInstance.Items) do
				if V ~= "." then
					if FileSystem.IsDirectory(ActiveInstance.Directory .. "/" .. V) or V == ".." then
						table.insert(ActiveInstance.Directories, V)
					else
						if Options.Type ~= 'opendirectory' then
							table.insert(ActiveInstance.Files, V)
						end
					end
				end
			end

			if not Utility.HasValue(ActiveInstance.Directories, "..") then
				table.insert(ActiveInstance.Directories, 1, "..")
			end
		end

		local WinW, WinH = Window.GetSize()
		local ButtonW, ButtonH = Button.GetSize("OK")

		Text.Begin(ActiveInstance.Directory)

		ListBox.Begin('FileDialog_ListBox', {H = WinH - ButtonH * 3.0 - Cursor.PadY() * 2.0})
		local Index = 1
		for I, V in ipairs(ActiveInstance.Directories) do
			FileDialogItem('Item_' .. Index, V, true, Index)
			Index = Index + 1
		end
		for I, V in ipairs(ActiveInstance.Files) do
			FileDialogItem('Item_' .. Index, V, false, Index)
			Index = Index + 1
		end
		ListBox.End()

		Cursor.SetRelativeY(H - ButtonH - Cursor.PadY())
		if Button.Begin("Cancel", {AlignRight = true}) then
			Result.Button = "Cancel"
		end

		Cursor.SameLine()

		if Button.Begin("OK", {AlignRight = true}) then
			local OpeningDirectory = false
			if #ActiveInstance.Return == 1 and Options.Type ~= 'opendirectory' then
				local Path = ActiveInstance.Return[1]
				if FileSystem.IsDirectory(Path) then
					OpeningDirectory = true
					OpenDirectory(FileSystem.GetBaseName(Path))
				end
			end

			if not OpeningDirectory then
				Result.Button = "OK"
				Result.Files = PruneResults(ActiveInstance.Return, Options.Type == 'opendirectory')
			end
		end

		if Result.Button ~= "" then
			ActiveInstance.Items = nil
			Dialog.Close()
		end

		Dialog.End()
	end
	return Result
end

return Dialog
