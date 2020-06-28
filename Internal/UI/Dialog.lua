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
local min = math.min
local max = math.max
local floor = math.floor

local Button = require(SLAB_PATH .. '.Internal.UI.Button')
local ComboBox = require(SLAB_PATH .. '.Internal.UI.ComboBox')
local Cursor = require(SLAB_PATH .. '.Internal.Core.Cursor')
local FileSystem = require(SLAB_PATH .. '.Internal.Core.FileSystem')
local Image = require(SLAB_PATH .. '.Internal.UI.Image')
local Input = require(SLAB_PATH .. '.Internal.UI.Input')
local Keyboard = require(SLAB_PATH .. '.Internal.Input.Keyboard')
local LayoutManager = require(SLAB_PATH .. '.Internal.UI.LayoutManager')
local ListBox = require(SLAB_PATH .. '.Internal.UI.ListBox')
local Mouse = require(SLAB_PATH .. '.Internal.Input.Mouse')
local Region = require(SLAB_PATH .. '.Internal.UI.Region')
local Style = require(SLAB_PATH .. '.Style')
local Text = require(SLAB_PATH .. '.Internal.UI.Text')
local Tree = require(SLAB_PATH .. '.Internal.UI.Tree')
local Utility = require(SLAB_PATH .. '.Internal.Core.Utility')
local Window = require(SLAB_PATH .. '.Internal.UI.Window')

local Dialog = {}
local Instances = {}
local ActiveInstance = nil
local Stack = {}
local InstanceStack = {}
local FileDialog_AskOverwrite = false
local FilterW = 0.0

local function ValidateSaveFile(Files, Extension)
	if Extension == nil or Extension == "" then
		return
	end

	if Files ~= nil and #Files == 1 then
		local Index = string.find(Files[1], ".", 1, true)

		if Index ~= nil then
			Files[1] = string.sub(Files[1], 1, Index - 1)
		end

		Files[1] = Files[1] .. Extension
	end
end

local function UpdateInputText(Instance)
	if Instance ~= nil then
		if #Instance.Return > 0 then
			Instance.Text = #Instance.Return > 1 and "<Multiple>" or Instance.Return[1]
		else
			Instance.Text = ""
		end
	end
end

local function PruneResults(Items, DirectoryOnly)
	local Result = {}

	for I, V in ipairs(Items) do
		if FileSystem.IsDirectory(V) then
			if DirectoryOnly then
				insert(Result, V)
			end
		else
			if not DirectoryOnly then
				insert(Result, V)
			end
		end
	end

	return Result
end

local function OpenDirectory(Dir)
	if ActiveInstance ~= nil and ActiveInstance.Directory ~= nil then
		ActiveInstance.Parsed = false
		if Dir == ".." then
			ActiveInstance.Directory = FileSystem.Parent(ActiveInstance.Directory)
		else
			if string.sub(Dir, #Dir, #Dir) == FileSystem.Separator() then
				Dir = string.sub(Dir, 1, #Dir - 1)
			end
			ActiveInstance.Directory = Dir
		end
	end
end

local function FileDialogItem(Id, Label, IsDirectory, Index)
	ListBox.BeginItem(Id, {Selected = Utility.HasValue(ActiveInstance.Selected, Index)})

	if IsDirectory then
		Image.Begin('FileDialog_Folder', {Path = SLAB_FILE_PATH .. "/Internal/Resources/Textures/Folder.png"})
		Cursor.SameLine({CenterY = true})
	end

	Text.Begin(Label)

	if ListBox.IsItemClicked(1) then
		local Set = true
		if ActiveInstance.AllowMultiSelect then
			if Keyboard.IsDown('lctrl') or Keyboard.IsDown('rctrl') then
				Set = false
				if Utility.HasValue(ActiveInstance.Selected, Index) then
					Utility.Remove(ActiveInstance.Selected, Index)
					Utility.Remove(ActiveInstance.Return, ActiveInstance.Directory .. "/" .. Label)
				else
					insert(ActiveInstance.Selected, Index)
					insert(ActiveInstance.Return, ActiveInstance.Directory .. "/" .. Label)
				end
			elseif Keyboard.IsDown('lshift') or Keyboard.IsDown('rshift') then
				if #ActiveInstance.Selected > 0 then
					Set = false
					local Anchor = ActiveInstance.Selected[#ActiveInstance.Selected]
					local Min = min(Anchor, Index)
					local Max = max(Anchor, Index)

					ActiveInstance.Selected = {}
					ActiveInstance.Return = {}
					for I = Min, Max, 1 do
						insert(ActiveInstance.Selected, I)
						if I > #ActiveInstance.Directories then
							I = I - #ActiveInstance.Directories
							insert(ActiveInstance.Return, ActiveInstance.Directory .. "/" .. ActiveInstance.Files[I])
						else
							insert(ActiveInstance.Return, ActiveInstance.Directory .. "/" .. ActiveInstance.Directories[I])
						end
					end
				end
			end
		end

		if Set then
			ActiveInstance.Selected = {Index}
			ActiveInstance.Return = {ActiveInstance.Directory .. "/" .. Label}
		end

		UpdateInputText(ActiveInstance)
	end

	local Result = false

	if ListBox.IsItemClicked(1, true) then
		if IsDirectory then
			OpenDirectory(ActiveInstance.Directory .. "/" .. Label)
		else
			Result = true
		end
	end

	ListBox.EndItem()

	return Result
end

local function AddDirectoryItem(Path)
	local Separator = FileSystem.Separator()
	local Item = {}
	Item.Path = Path
	Item.Name = FileSystem.GetBaseName(Path)
	Item.Name = Item.Name == "" and Separator or Item.Name
	-- Remove the starting slash for Unix style directories.
	if string.sub(Item.Name, 1, 1) == Separator and Item.Name ~= Separator then
		Item.Name = string.sub(Item.Name, 2)
	end
	Item.Children = nil
	return Item
end

local function FileDialogExplorer(Instance, Root)
	if Instance == nil then
		return
	end

	if Root ~= nil then
		local ShouldOpen = Window.IsAppearing() and string.find(Instance.Directory, Root.Path, 1, true) ~= nil

		local Options = {
			Label = Root.Name,
			OpenWithHighlight = false,
			IsSelected = ActiveInstance.Directory == Root.Path,
			IsOpen = ShouldOpen
		}
		local IsOpen = Tree.Begin(Root.Path, Options)

		if Mouse.IsClicked(1) and Window.IsItemHot() then
			OpenDirectory(Root.Path)
		end

		if IsOpen then
			if Root.Children == nil then
				Root.Children = {}

				local Separator = FileSystem.Separator()
				local Directories = FileSystem.GetDirectoryItems(Root.Path .. Separator, {Files = false})
				for I, V in ipairs(Directories) do
					local Path = Root.Path
					if string.sub(Path, #Path) ~= Separator and Path ~= Separator then
						Path = Path .. Separator
					end
					if string.sub(V, 1, 1) == Separator then
						V = string.sub(V, 2)
					end
					local Item = AddDirectoryItem(Path .. FileSystem.GetBaseName(V))
					insert(Root.Children, Item)
				end
			end

			for I, V in ipairs(Root.Children) do
				FileDialogExplorer(Instance, V)
			end

			Tree.End()
		end
	end
end

local function GetFilter(Instance, Index)
	local Filter = "*.*"
	local Desc = "All Files"
	if Instance ~= nil and #Instance.Filters > 0 then
		if Index == nil then
			Index = Instance.SelectedFilter
		end

		local Item = Instance.Filters[Index]
		if Item ~= nil then
			if type(Item) == "table" then
				if #Item == 1 then
					Filter = Item[1]
					Desc = ""
				elseif #Item == 2 then
					Filter = Item[1]
					Desc = Item[2]
				end
			else
				Filter = tostring(Item)
				Desc = ""
			end
		end
	end

	return Filter, Desc
end

local function GetExtension(Instance)
	local Filter, Desc = GetFilter(Instance)
	local Result = ""

	if Filter ~= "*.*" then
		local Index = string.find(Filter, ".", 1, true)

		if Index ~= nil then
			Result = string.sub(Filter, Index)
		end
	end

	return Result
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
	Options.X = floor(love.graphics.getWidth() * 0.5 - Instance.W * 0.5)
	Options.Y = floor(love.graphics.getHeight() * 0.5 - Instance.H * 0.5)
	Options.Layer = 'Dialog'
	Options.AllowFocus = false
	Options.AllowMove = false
	Options.AutoSizeWindow = Options.AutoSizeWindow == nil and true or Options.AutoSizeWindow
	Options.NoSavedSettings = true

	Window.Begin(Instance.Id, Options)

	ActiveInstance = Instance
	insert(InstanceStack, 1, ActiveInstance)

	return true
end

function Dialog.End()
	ActiveInstance.W, ActiveInstance.H = Window.GetSize()
	Window.End()

	ActiveInstance = nil
	remove(InstanceStack, 1)

	if #InstanceStack > 0 then
		ActiveInstance = InstanceStack[1]
	end
end

function Dialog.Open(Id)
	local Instance = GetInstance(Id)
	if not Instance.IsOpen then
		Instance.IsOpen = true
		insert(Stack, 1, Instance)
		Window.SetStackLock(Instance.Id)
		Window.PushToTop(Instance.Id)
	end
end

function Dialog.Close()
	if ActiveInstance ~= nil and ActiveInstance.IsOpen then
		ActiveInstance.IsOpen = false
		remove(Stack, 1)
		Window.SetStackLock(nil)

		if #Stack > 0 then
			Instance = Stack[1]
			Window.SetStackLock(Instance.Id)
			Window.PushToTop(Instance.Id)
		end
	end
end

function Dialog.IsOpen()
	return #Stack > 0
end

function Dialog.MessageBox(Title, Message, Options)
    local Result = ""
    Dialog.Open('MessageBox')
    if Dialog.Begin('MessageBox', {Title = Title, Border = 12}) then
        Options = Options == nil and {} or Options
        Options.Buttons = Options.Buttons == nil and {"OK"} or Options.Buttons

        LayoutManager.Begin('MessageBox_Message_Layout', {AlignX = 'center', AlignY = 'center'})
        LayoutManager.NewLine()
        local TextW = min(Text.GetWidth(Message), love.graphics.getWidth() * 0.80)
        Text.BeginFormatted(Message, {Align = 'center', W = TextW})
        LayoutManager.End()

        Cursor.NewLine()
        Cursor.NewLine()

        LayoutManager.Begin('MessageBox_Buttons_Layout', {AlignX = 'right', AlignY = 'bottom'})
        for I, V in ipairs(Options.Buttons) do
            if Button.Begin(V) then
                Result = V
            end
            Cursor.SameLine()
            LayoutManager.SameLine()
        end
        LayoutManager.End()

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
	Options.Filters = Options.Filters == nil and {{"*.*", "All Files"}} or Options.Filters

	local Title = "Open File"
	if Options.Type == 'savefile' then
		Options.AllowMultiSelect = false
		Title = "Save File"
	elseif Options.Type == 'opendirectory' then
		Title = "Open Directory"
	end

	local Result = {Button = "", Files = {}}
	local WasOpen = IsInstanceOpen('FileDialog')

	Dialog.Open("FileDialog")
	local W = love.graphics.getWidth() * 0.65
	local H = love.graphics.getHeight() * 0.65
	if Dialog.Begin('FileDialog', {
		Title = Title,
		AutoSizeWindow = false,
		W = W,
		H = H,
		AutoSizeContent = false,
		AllowResize = false
	}) then
		ActiveInstance.AllowMultiSelect = Options.AllowMultiSelect

		if not WasOpen then
			ActiveInstance.Text = ""
			if ActiveInstance.Directory == nil then
				ActiveInstance.Directory = love.filesystem.getSourceBaseDirectory()
			end

			if Options.Directory ~= nil and FileSystem.IsDirectory(Options.Directory) then
				ActiveInstance.Directory = Options.Directory
			end

			ActiveInstance.Filters = Options.Filters
			ActiveInstance.SelectedFilter = 1
		end

		local Clear = false
		if not ActiveInstance.Parsed then
			local Filter = GetFilter(ActiveInstance)
			ActiveInstance.Root = AddDirectoryItem(FileSystem.GetRootDirectory(ActiveInstance.Directory))
			ActiveInstance.Selected = {}
			ActiveInstance.Directories = FileSystem.GetDirectoryItems(ActiveInstance.Directory .. "/", {Files = false})
			ActiveInstance.Files = FileSystem.GetDirectoryItems(ActiveInstance.Directory .. "/", {Directories = false, Filter = Filter})
			ActiveInstance.Return = {ActiveInstance.Directory .. "/"}
			ActiveInstance.Text = ""
			ActiveInstance.Parsed = true

			UpdateInputText(ActiveInstance)

			for I, V in ipairs(ActiveInstance.Directories) do
				ActiveInstance.Directories[I] = FileSystem.GetBaseName(V)
			end

			for I, V in ipairs(ActiveInstance.Files) do
				ActiveInstance.Files[I] = FileSystem.GetBaseName(V)
			end

			Clear = true
		end

		local WinW, WinH = Window.GetSize()
		local ButtonW, ButtonH = Button.GetSize("OK")
		local ExplorerW = 150.0
		local ListH = WinH - Text.GetHeight() - ButtonH * 3.0 - Cursor.PadY() * 2.0
		local PrevAnchorX = Cursor.GetAnchorX()

		Text.Begin(ActiveInstance.Directory)

		local CursorX, CursorY = Cursor.GetPosition()
		local MouseX, MouseY = Window.GetMousePosition()
		Region.Begin('FileDialog_DirectoryExplorer', {
			X = CursorX,
			Y = CursorY,
			W = ExplorerW,
			H = ListH,
			AutoSizeContent = true,
			NoBackground = true,
			Intersect = true,
			MouseX = MouseX,
			MouseY = MouseY,
			IsObstructed = Window.IsObstructedAtMouse(),
			Rounding = Style.WindowRounding
		})

		Cursor.AdvanceX(0.0)
		Cursor.SetAnchorX(Cursor.GetX())

		FileDialogExplorer(ActiveInstance, ActiveInstance.Root)

		Region.End()
		Region.ApplyScissor()
		Cursor.AdvanceX(ExplorerW + 4.0)
		Cursor.SetY(CursorY)

		LayoutManager.Begin('FileDialog_ListBox_Expand', {AnchorX = true, ExpandW = true})
		ListBox.Begin('FileDialog_ListBox', {H = ListH, Clear = Clear})
		local Index = 1
		local ItemSelected = false
		for I, V in ipairs(ActiveInstance.Directories) do
			FileDialogItem('Item_' .. Index, V, true, Index)
			Index = Index + 1
		end
		if Options.Type ~= 'opendirectory' then
			for I, V in ipairs(ActiveInstance.Files) do
				if FileDialogItem('Item_' .. Index, V, false, Index) then
					ItemSelected = true
				end
				Index = Index + 1
			end
		end
		ListBox.End()
		LayoutManager.End()

		local ListBoxX, ListBoxY, ListBoxW, ListBoxH = Cursor.GetItemBounds()
		local InputW = ListBoxX + ListBoxW - PrevAnchorX - FilterW - Cursor.PadX()

		Cursor.SetAnchorX(PrevAnchorX)
		Cursor.SetX(PrevAnchorX)

		local ReadOnly = Options.Type ~= 'savefile'
		if Input.Begin('FileDialog_Input', {W = InputW, ReadOnly = ReadOnly, Text = ActiveInstance.Text, Align = 'left'}) then
			ActiveInstance.Text = Input.GetText()
			ActiveInstance.Return[1] = ActiveInstance.Text
		end

		Cursor.SameLine()

		local Filter, Desc = GetFilter(ActiveInstance)
		if ComboBox.Begin('FileDialog_Filter', {Selected = Filter .. " " .. Desc}) then
			for I, V in ipairs(ActiveInstance.Filters) do
				Filter, Desc = GetFilter(ActiveInstance, I)
				if Text.Begin(Filter .. " " .. Desc, {IsSelectable = true}) then
					ActiveInstance.SelectedFilter = I
					ActiveInstance.Parsed = false
				end
			end

			ComboBox.End()
		end

		local FilterCBX, FilterCBY, FilterCBW, FilterCBH = Cursor.GetItemBounds()
		FilterW = FilterCBW

		LayoutManager.Begin('FileDialog_Buttons_Layout', {AlignX = 'right', AlignY = 'bottom'})
		if Button.Begin("OK") or ItemSelected then
			local OpeningDirectory = false
			if #ActiveInstance.Return == 1 and Options.Type ~= 'opendirectory' then
				local Path = ActiveInstance.Return[1]
				if FileSystem.IsDirectory(Path) then
					OpeningDirectory = true
					OpenDirectory(Path)
				elseif Options.Type == 'savefile' then
					if FileSystem.Exists(Path) then
						FileDialog_AskOverwrite = true
						OpeningDirectory = true
					end
				end
			end

			if not OpeningDirectory then
				Result.Button = "OK"
				Result.Files = PruneResults(ActiveInstance.Return, Options.Type == 'opendirectory')

				if Options.Type == 'savefile' then
					ValidateSaveFile(Result.Files, GetExtension(ActiveInstance))
				end
			end
		end

		Cursor.SameLine()
		LayoutManager.SameLine()

		if Button.Begin("Cancel") then
			Result.Button = "Cancel"
		end
		LayoutManager.End()

		if FileDialog_AskOverwrite then
			local FileName = #ActiveInstance.Return > 0 and ActiveInstance.Return[1] or ""
			local AskOverwrite = Dialog.MessageBox("Overwriting", "Are you sure you would like to overwrite file " .. FileName, {Buttons = {"Cancel", "No", "Yes"}})

			if AskOverwrite ~= "" then
				if AskOverwrite == "No" then
					Result.Button = "Cancel"
					Result.Files = {}
				elseif AskOverwrite == "Yes" then
					Result.Button = "OK"
					Result.Files = PruneResults(ActiveInstance.Return, Options.Type == 'opendirectory')
				end

				FileDialog_AskOverwrite = false
			end
		end

		if Result.Button ~= "" then
			ActiveInstance.Parsed = false
			Dialog.Close()
		end

		Dialog.End()
	end
	return Result
end

return Dialog
