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

local Slab = require('Slab')
local DrawCommands = require(SLAB_PATH .. '.Internal.Core.DrawCommands')
local Mouse = require(SLAB_PATH .. '.Internal.Input.Mouse')
local Region = require(SLAB_PATH .. '.Internal.UI.Region')
local Stats = require(SLAB_PATH .. '.Internal.Core.Stats')
local Style = require(SLAB_PATH .. '.Style')
local Tooltip = require(SLAB_PATH .. '.Internal.UI.Tooltip')
local Window = require(SLAB_PATH .. '.Internal.UI.Window')

local SlabDebug = {}
local SlabDebug_About = 'SlabDebug_About'
local SlabDebug_Mouse = false
local SlabDebug_Windows = false
local SlabDebug_Tooltip = false
local SlabDebug_DrawCommands = false
local SlabDebug_Performance = false
local SlabDebug_StyleEditor = false

local SlabDebug_Windows_Categories = {"Inspector", "Stack"}
local SlabDebug_Windows_Category = "Inspector"

local Selected_Window = ""

local Style_EditingColor = nil
local Style_ColorStore = nil
local Style_FileDialog = nil

local function Window_Inspector()
	local Ids = Window.GetInstanceIds()
	if Slab.BeginComboBox('SlabDebug_Windows_Inspector', {Selected = Selected_Window}) then
		for I, V in ipairs(Ids) do
			if Slab.TextSelectable(V) then
				Selected_Window = V
			end
		end

		Slab.EndComboBox()
	end

	local Info = Window.GetInstanceInfo(Selected_Window)
	for I, V in ipairs(Info) do
		Slab.Text(V)
	end
end

local function Window_Stack()
	local Stack = Window.GetStackDebug()
	Slab.Text("Stack: " .. #Stack)
	for I, V in ipairs(Stack) do
		Slab.Text(V)
	end
end

local function DrawCommands_Item(Root, Label)
	if type(Root) == "table" then
		if Slab.BeginTree(Label) then
			for K, V in pairs(Root) do
				DrawCommands_Item(V, K)
			end

			Slab.EndTree()
		end
	else
		Slab.BeginTree(Label .. " " .. tostring(Root), {IsLeaf = true})
	end
end

local function PrintStatsCategory(Label, Category, Last, AddSeparator)
	Slab.BeginColumn(1)
	Slab.Text(Label)
	if AddSeparator then
		Slab.Separator()
	end
	Slab.EndColumn()

	Slab.BeginColumn(2)
	Slab.Text(string.format("%.5f", Stats.GetTime(Category, Last)), {CenterX = true})
	if AddSeparator then
		Slab.Separator()
	end
	Slab.EndColumn()

	Slab.BeginColumn(3)
	Slab.Text(Stats.GetCallCount(Category, Last), {CenterX = true})
	if AddSeparator then
		Slab.Separator()
	end
	Slab.EndColumn()
end

local function DrawPerformance()
	Slab.BeginWindow('SlabDebug_Performance', {Title = "Performance", Columns = 3, AutoSizeWindow = false, W = 450.0, H = 350.0})
	Slab.BeginColumn(1)
	Slab.Text("Category", {CenterX = true})
	Slab.Separator()
	Slab.EndColumn()

	Slab.BeginColumn(2)
	Slab.Text("Time", {CenterX = true})
	Slab.Separator()
	Slab.EndColumn()

	Slab.BeginColumn(3)
	Slab.Text("Call Count", {CenterX = true})
	Slab.Separator()
	Slab.EndColumn()

	PrintStatsCategory("Frame Time", 'Frame', true)
	PrintStatsCategory("Update Time", 'Update')
	PrintStatsCategory("Draw Time", 'Draw', true, true)
	PrintStatsCategory("Button Time", 'Button')
	PrintStatsCategory("Radio Button Time", 'RadioButton')
	PrintStatsCategory("Check Box Time", 'CheckBox')
	PrintStatsCategory("Combo Box Time", 'ComboBox')
	PrintStatsCategory("Image Time", 'Image')
	PrintStatsCategory("Input Time", 'Input')
	PrintStatsCategory("List Box Time", 'ListBox')
	PrintStatsCategory("Text Time", 'Text')
	PrintStatsCategory("Text Formatted Time", 'Textf')
	PrintStatsCategory("Tree Time", 'Tree')
	PrintStatsCategory("Window Time", 'Window')
	Slab.EndWindow()
end

local function EditColor(Color)
	Style_EditingColor = Color
	Style_ColorStore = {Color[1], Color[2], Color[3], Color[4]}
end

local function DrawStyleColor(Label, Color)
	local Style = Slab.GetStyle()
	local H = Style.Font:getHeight()
	local TextColor = Style.TextColor

	if Style_EditingColor == Color then
		TextColor = {1.0, 1.0, 0.0, 1.0}
	end

	Slab.BeginColumn(1)
	Slab.Text(Label, {Color = TextColor})
	Slab.EndColumn()

	Slab.BeginColumn(2)
	local ColW, ColH = Slab.GetWindowActiveSize()
	local X, Y = Slab.GetCursorPos()
	Slab.Rectangle({W = ColW, H = H, Color = Color, Outline = true})
	Slab.SetCursorPos(X, Y)

	if Slab.Button("", {Invisible = true, W = ColW, H = H}) then
		EditColor(Color)
	end
	Slab.EndColumn()
end

local function DrawStyleValue(Label, Value)
	local Style = Slab.GetStyle()

	Slab.BeginColumn(1)
	Slab.Text(Label)
	Slab.EndColumn()

	Slab.BeginColumn(2)
	local W, H = Slab.GetWindowActiveSize()
	if Slab.Input('SlabDebug_Style_' .. Label, {Text = Value, ReturnOnText = false, NumbersOnly = true, W = W}) then
		Style[Label] = tonumber(Slab.GetInputText())
	end
	Slab.EndColumn()
end

local function DrawStyleEditor()
	Slab.BeginWindow('SlabDebug_StyleEditor', {Title = "Style Editor", Columns = 2, AutoSizeWindow = false, AllowResize = true, W = 500.0, H = 400.0})

	local Style = Slab.GetStyle()
	local Names = Style.API.GetStyleNames()
	local CurrentStyle = Style.API.GetCurrentStyleName()
	local W, H = Slab.GetWindowActiveSize()
	if Slab.BeginComboBox('SlabDebug_StyleEditor_Styles', {W = W, Selected = CurrentStyle}) then
		for I, V in ipairs(Names) do
			if Slab.TextSelectable(V) then
				Style.API.SetStyle(V)
			end
		end

		Slab.EndComboBox()
	end

	if Slab.Button("New") then
		Style_FileDialog = 'new'
	end

	Slab.SameLine()

	if Slab.Button("Load") then
		Style_FileDialog = 'load'
	end

	Slab.SameLine()

	local SaveDisabled = Style.API.IsDefaultStyle(CurrentStyle)
	if Slab.Button("Save", {Disabled = SaveDisabled}) then
		Style.API.SaveCurrentStyle()
	end

	Slab.Separator()

	for K, V in pairs(Style) do
		if type(V) == "table" and K ~= "Font" and K ~= "API" then
			DrawStyleColor(K, V)
		end
	end

	for K, V in pairs(Style) do
		if type(V) == "number" and K ~= "FontSize" then
			DrawStyleValue(K, V)
		end
	end

	Slab.EndWindow()

	if Style_EditingColor ~= nil then
		local Result = Slab.ColorPicker({Color = Style_ColorStore})
		Style_EditingColor[1] = Result.Color[1]
		Style_EditingColor[2] = Result.Color[2]
		Style_EditingColor[3] = Result.Color[3]
		Style_EditingColor[4] = Result.Color[4]

		if Result.Button ~= "" then
			if Result.Button == "OK" then
				Style.API.StoreCurrentStyle()
			end

			if Result.Button == "Cancel" then
				Style_EditingColor[1] = Style_ColorStore[1]
				Style_EditingColor[2] = Style_ColorStore[2]
				Style_EditingColor[3] = Style_ColorStore[3]
				Style_EditingColor[4] = Style_ColorStore[4]
			end

			Style_EditingColor = nil
		end
	end

	if Style_FileDialog ~= nil then
		local Type = Style_FileDialog == 'new' and 'savefile' or Style_FileDialog == 'load' and 'openfile' or nil

		if Type ~= nil then
			local Path = love.filesystem.getRealDirectory(SLAB_PATH) .. "/" .. SLAB_PATH .. "Internal/Resources/Styles"
			local Result = Slab.FileDialog({AllowMultiSelect = false, Directory = Path, Type = Type, Filters = {{"*.style", "Styles"}}})

			if Result.Button ~= "" then
				if Result.Button == "OK" then
					if Style_FileDialog == 'new' then
						Style.API.CopyCurrentStyle(Result.Files[1])
					else
						Style.API.LoadStyle(Result.Files[1], true)
					end
				end

				Style_FileDialog = nil
			end
		else
			Style_FileDialog = nil
		end
	end
end

function SlabDebug.About()
	if Slab.BeginDialog(SlabDebug_About, {Title = "About"}) then
		Slab.Text("Slab Version: " .. Slab.GetVersion())
		Slab.Text("Love Version: " .. Slab.GetLoveVersion())
		Slab.NewLine()
		if Slab.Button("OK", {AlignRight = true}) then
			Slab.CloseDialog()
		end
		Slab.EndDialog()
	end
end

function SlabDebug.OpenAbout()
	Slab.OpenDialog(SlabDebug_About)
end

function SlabDebug.Mouse()
	Slab.BeginWindow('SlabDebug_Mouse', {Title = "Mouse"})
	local X, Y = Mouse.Position()
	Slab.Text("X: " .. X)
	Slab.Text("Y: " .. Y)

	for I = 1, 3, 1 do
		Slab.Text("Button " .. I .. ": " .. (Mouse.IsPressed(I) and "Pressed" or "Released"))
	end

	Slab.Text("Hot Region: " .. Region.GetHotInstanceId())
	Slab.EndWindow()
end

function SlabDebug.Windows()
	Slab.BeginWindow('SlabDebug_Windows', {Title = "Windows"})

	if Slab.BeginComboBox('SlabDebug_Windows_Categories', {Selected = SlabDebug_Windows_Category}) then
		for I, V in ipairs(SlabDebug_Windows_Categories) do
			if Slab.TextSelectable(V) then
				SlabDebug_Windows_Category = V
			end
		end

		Slab.EndComboBox()
	end

	if SlabDebug_Windows_Category == "Inspector" then
		Window_Inspector()
	elseif SlabDebug_Windows_Category == "Stack" then
		Window_Stack()
	end

	Slab.EndWindow()
end

function SlabDebug.Tooltip()
	Slab.BeginWindow('SlabDebug_Tooltip', {Title = "Tooltip"})

	local Info = Tooltip.GetDebugInfo()
	for I, V in ipairs(Info) do
		Slab.Text(V)
	end

	Slab.EndWindow()
end

function SlabDebug.DrawCommands()
	Slab.BeginWindow('SlabDebug_DrawCommands', {Title = "Draw Commands"})
	
	local Info = DrawCommands.GetDebugInfo()
	for K, V in pairs(Info) do
		DrawCommands_Item(V, K)
	end

	Slab.EndWindow()
end

function SlabDebug.Performance()
	Stats.SetEnabled(true)
	DrawPerformance()
end

function SlabDebug.StyleEditor()
	DrawStyleEditor()
end

function SlabDebug.Menu()
	if Slab.BeginMenu("Debug") then
		if Slab.MenuItem("About") then
			SlabDebug.OpenAbout()
		end

		if Slab.MenuItemChecked("Mouse", SlabDebug_Mouse) then
			SlabDebug_Mouse = not SlabDebug_Mouse
		end

		if Slab.MenuItemChecked("Windows", SlabDebug_Windows) then
			SlabDebug_Windows = not SlabDebug_Windows
		end

		if Slab.MenuItemChecked("Tooltip", SlabDebug_Tooltip) then
			SlabDebug_Tooltip = not SlabDebug_Tooltip
		end

		if Slab.MenuItemChecked("Draw Commands", SlabDebug_DrawCommands) then
			SlabDebug_DrawCommands = not SlabDebug_DrawCommands
		end

		if Slab.MenuItemChecked("Performance", SlabDebug_Performance) then
			SlabDebug_Performance = not SlabDebug_Performance
			Stats.SetEnabled(SlabDebug_Performance)
		end

		if Slab.MenuItemChecked("Style Editor", SlabDebug_StyleEditor) then
			SlabDebug_StyleEditor = not SlabDebug_StyleEditor
		end

		Slab.EndMenu()
	end
end

function SlabDebug.Begin()
	SlabDebug.About()

	if SlabDebug_Mouse then
		SlabDebug.Mouse()
	end

	if SlabDebug_Windows then
		SlabDebug.Windows()
	end

	if SlabDebug_Tooltip then
		SlabDebug.Tooltip()
	end

	if SlabDebug_DrawCommands then
		SlabDebug.DrawCommands()
	end

	if SlabDebug_Performance then
		SlabDebug.Performance()
	end

	if SlabDebug_StyleEditor then
		SlabDebug.StyleEditor()
	end
end

return SlabDebug
