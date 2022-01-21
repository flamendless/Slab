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

local Slab = require(SLAB_PATH .. '.Slab')
local DrawCommands = require(SLAB_PATH .. '.Internal.Core.DrawCommands')
local Input = require(SLAB_PATH .. '.Internal.UI.Input')
local LayoutManager = require(SLAB_PATH .. '.Internal.UI.LayoutManager')
local Mouse = require(SLAB_PATH .. '.Internal.Input.Mouse')
local Region = require(SLAB_PATH .. '.Internal.UI.Region')
local Stats = require(SLAB_PATH .. '.Internal.Core.Stats')
local Style = require(SLAB_PATH .. '.Style')
local Tooltip = require(SLAB_PATH .. '.Internal.UI.Tooltip')
local Tree = require(SLAB_PATH .. '.Internal.UI.Tree')
local Window = require(SLAB_PATH .. '.Internal.UI.Window')

local SlabDebug = {}
local SlabDebug_About = 'SlabDebug_About'
local SlabDebug_Mouse = {Title = "Mouse", IsOpen = false}
local SlabDebug_Windows = {Title = "Windows", IsOpen = false}
local SlabDebug_Regions = {Title = "Regions", IsOpen = false}
local SlabDebug_Tooltip = {Title = "Tooltip", IsOpen = false}
local SlabDebug_DrawCommands = {Title = "DrawCommands", IsOpen = false}
local SlabDebug_Performance = {Title = "Performance", IsOpen = false}
local SlabDebug_StyleEditor = {Title = "Style Editor", IsOpen = false, AutoSizeWindow = false, AllowResize = true, W = 700.0, H = 500.0}
local SlabDebug_Input = {Title = "Input", IsOpen = false}
local SlabDebug_MultiLine = {Title = "Multi-Line Input", IsOpen = false}
local SlabDebug_MultiLine_FileDialog = false
local SlabDebug_MultiLine_FileName = ""
local SlabDebug_MultiLine_Contents = ""
local SlabDebug_Tree = {Title = "Tree", IsOpen = false, AutoSizeWindow = false, AllowResize = true}
local SlabDebug_LayoutManager = {Title = "Layout Manager", IsOpen = false, AutoSizeWindow = false, AllowResize = true}

local SlabDebug_Windows_Categories = {"Inspector", "Stack"}
local SlabDebug_Windows_Category = "Inspector"
local SlabDebug_Regions_Selected = ""

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

local DrawPerformance_Category = nil
local DrawPerformance_WinX = 50.0
local DrawPerformance_WinY = 50.0
local DrawPerformance_ResetPosition = false
local DrawPerformance_Init = false
local DrawPerformance_W = 200.0

local function DrawPerformance()
	if not DrawPerformance_Init then
		Slab.EnableStats(true)
		DrawPerformance_Init = true
	end

	SlabDebug_Performance.X = DrawPerformance_WinX
	SlabDebug_Performance.Y = DrawPerformance_WinY
	SlabDebug_Performance.ResetPosition = DrawPerformance_ResetPosition

	Slab.BeginWindow('SlabDebug_Performance', SlabDebug_Performance)
	DrawPerformance_ResetPosition = false

	local Categories = Stats.GetCategories()

	if DrawPerformance_Category == nil then
		DrawPerformance_Category = Categories[1]
	end

	if Slab.BeginComboBox('DrawPerformance_Categories', {Selected = DrawPerformance_Category, W = DrawPerformance_W}) then
		for I, V in ipairs(Categories) do
			if Slab.TextSelectable(V) then
				DrawPerformance_Category = V
			end
		end

		Slab.EndComboBox()
	end

	if Slab.CheckBox(Slab.IsStatsEnabled(), "Enabled") then
		Slab.EnableStats(not Slab.IsStatsEnabled())
	end

	Slab.SameLine()

	if Slab.Button("Flush") then
		Slab.FlushStats()
	end

	Slab.Separator()

	if DrawPerformance_Category ~= nil then
		local Items = Stats.GetItems(DrawPerformance_Category)

		local Pad = 50.0
		local MaxW = 0.0
		for I, V in ipairs(Items) do
			MaxW = math.max(MaxW, Slab.GetTextWidth(V))
		end

		local CursorX, CursorY = Slab.GetCursorPos()
		Slab.SetCursorPos(MaxW * 0.5 - Slab.GetTextWidth("Stat") * 0.5)
		Slab.Text("Stat")

		local TimeX = MaxW + Pad
		local TimeW = Slab.GetTextWidth("Time")
		local TimeItemW = Slab.GetTextWidth(string.format("%.4f", 0.0))
		Slab.SetCursorPos(TimeX, CursorY)
		Slab.Text("Time")

		local MaxTimeX = TimeX + TimeW + Pad
		local MaxTimeW = Slab.GetTextWidth("Max Time")
		Slab.SetCursorPos(MaxTimeX, CursorY)
		Slab.Text("Max Time")

		local CallCountX = MaxTimeX + MaxTimeW + Pad
		local CallCountW = Slab.GetTextWidth("Call Count")
		Slab.SetCursorPos(CallCountX, CursorY)
		Slab.Text("Call Count")

		DrawPerformance_W = CallCountX + CallCountW

		Slab.Separator()

		for I, V in ipairs(Items) do
			local Time = Stats.GetTime(V, DrawPerformance_Category)
			local MaxTime = Stats.GetMaxTime(V, DrawPerformance_Category)
			local CallCount = Stats.GetCallCount(V, DrawPerformance_Category)

			CursorX, CursorY = Slab.GetCursorPos()
			Slab.SetCursorPos(MaxW * 0.5 - Slab.GetTextWidth(V) * 0.5)
			Slab.Text(V)

			Slab.SetCursorPos(TimeX + TimeW * 0.5 - TimeItemW * 0.5, CursorY)
			Slab.Text(string.format("%.4f", Time))

			Slab.SetCursorPos(MaxTimeX + MaxTimeW * 0.5 - TimeItemW * 0.5, CursorY)
			Slab.Text(string.format("%.4f", MaxTime))

			Slab.SetCursorPos(CallCountX + CallCountW * 0.5 - Slab.GetTextWidth(CallCount) * 0.5, CursorY)
			Slab.Text(CallCount)
		end
	end

	Slab.EndWindow()
end

local function EditColor(Color)
	Style_EditingColor = Color
	Style_ColorStore = {Color[1], Color[2], Color[3], Color[4]}
end

local function RestoreEditColor()
	Style_EditingColor[1] = Style_ColorStore[1]
	Style_EditingColor[2] = Style_ColorStore[2]
	Style_EditingColor[3] = Style_ColorStore[3]
	Style_EditingColor[4] = Style_ColorStore[4]
end

local function DrawStyleEditor()
	Slab.BeginWindow('SlabDebug_StyleEditor', SlabDebug_StyleEditor)
	local X, Y = Slab.GetWindowPosition()
	local W, H = Slab.GetWindowSize()

	local Style = Slab.GetStyle()
	local Names = Style.API.GetStyleNames()
	local CurrentStyle = Style.API.GetCurrentStyleName()
	Slab.BeginLayout('SlabDebug_StyleEditor_Styles_Layout', {ExpandW = true})
	if Slab.BeginComboBox('SlabDebug_StyleEditor_Styles', {Selected = CurrentStyle}) then
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
	Slab.EndLayout()

	Slab.Separator()

	local Refresh = false
	Slab.BeginLayout('SlabDebug_StyleEditor_Content_Layout', {Columns = 2, ExpandW = true})
	for K, V in pairs(Style) do
		if type(V) == "table" and K ~= "Font" and K ~= "API" then
			Slab.SetLayoutColumn(1)
			Slab.Text(K)
			Slab.SetLayoutColumn(2)
			local W, H = Slab.GetLayoutSize()
			H = Slab.GetTextHeight()
			Slab.Rectangle({W = W, H = H, Color = V, Outline = true})
			if Slab.IsControlClicked() then
				if Style_EditingColor ~= nil then
					RestoreEditColor()
					Refresh = true
				end

				EditColor(V)
			end
		end
	end

	for K, V in pairs(Style) do
		if type(V) == "number" and K ~= "FontSize" then
			Slab.SetLayoutColumn(1)
			Slab.Text(K)
			Slab.SetLayoutColumn(2)
			if Slab.Input('SlabDebug_Style_' .. K, {Text = tostring(V), ReturnOnText = false, NumbersOnly = true}) then
				Style[K] = Slab.GetInputNumber()
			end
		end
	end
	Slab.EndLayout()
	Slab.EndWindow()

	if Style_EditingColor ~= nil then
		local Result = Slab.ColorPicker({Color = Style_ColorStore, X = X + W, Y = Y})
		Style_EditingColor[1] = Result.Color[1]
		Style_EditingColor[2] = Result.Color[2]
		Style_EditingColor[3] = Result.Color[3]
		Style_EditingColor[4] = Result.Color[4]

		if Result.Button ~= 0 then
			if Result.Button == 1 then
				Style.API.StoreCurrentStyle()
			end

			if Result.Button == -1 then
				RestoreEditColor()
			end

			Style_EditingColor = nil
		end
	end

	if Style_FileDialog ~= nil then
		local Type = Style_FileDialog == 'new' and 'savefile' or Style_FileDialog == 'load' and 'openfile' or nil

		if Type ~= nil then
			local Path = love.filesystem.getRealDirectory(SLAB_FILE_PATH) .. "/" .. SLAB_FILE_PATH .. "Internal/Resources/Styles"
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
		Slab.BeginLayout(SlabDebug_About .. '.Buttons_Layout', {AlignX = 'center'})
		if Slab.Button("OK") then
			Slab.CloseDialog()
		end
		Slab.EndLayout()
		Slab.EndDialog()
	end
end

function SlabDebug.OpenAbout()
	Slab.OpenDialog(SlabDebug_About)
end

function SlabDebug.Mouse()
	Slab.BeginWindow('SlabDebug_Mouse', SlabDebug_Mouse)
	local X, Y = Mouse.Position()
	Slab.Text("X: " .. X)
	Slab.Text("Y: " .. Y)

	local DeltaX, DeltaY = Mouse.GetDelta()
	Slab.Text("Delta X: " .. DeltaX)
	Slab.Text("Delta Y: " .. DeltaY)

	for I = 1, 3, 1 do
		Slab.Text("Button " .. I .. ": " .. (Mouse.IsDown(I) and "Pressed" or "Released"))
	end

	Slab.Text("Hot Region: " .. Region.GetHotInstanceId())
	Slab.EndWindow()
end

function SlabDebug.Windows()
	Slab.BeginWindow('SlabDebug_Windows', SlabDebug_Windows)

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

function SlabDebug.Regions()
	Slab.BeginWindow('SlabDebug_Regions', SlabDebug_Regions)

	local Ids = Region.GetInstanceIds()
	if Slab.BeginComboBox('SlabDebug_Regions_Ids', {Selected = SlabDebug_Regions_Selected}) then
		for I, V in ipairs(Ids) do
			if Slab.TextSelectable(V) then
				SlabDebug_Regions_Selected = V
			end
		end
		Slab.EndComboBox()
	end

	local Info = Region.GetDebugInfo(SlabDebug_Regions_Selected)
	for I, V in ipairs(Info) do
		Slab.Text(V)
	end

	Slab.EndWindow()
end

function SlabDebug.Tooltip()
	Slab.BeginWindow('SlabDebug_Tooltip', SlabDebug_Tooltip)

	local Info = Tooltip.GetDebugInfo()
	for I, V in ipairs(Info) do
		Slab.Text(V)
	end

	Slab.EndWindow()
end

function SlabDebug.DrawCommands()
	Slab.BeginWindow('SlabDebug_DrawCommands', SlabDebug_DrawCommands)

	local Info = DrawCommands.GetDebugInfo()
	for K, V in pairs(Info) do
		DrawCommands_Item(V, K)
	end

	Slab.EndWindow()
end

function SlabDebug.Performance()
	DrawPerformance()
end

function SlabDebug.Performance_SetPosition(X, Y)
	DrawPerformance_WinX = X ~= nil and X or 50.0
	DrawPerformance_WinY = Y ~= nil and Y or 50.0
	DrawPerformance_ResetPosition = true
end

function SlabDebug.StyleEditor()
	DrawStyleEditor()
end

function SlabDebug.Input()
	Slab.BeginWindow('SlabDebug_Input', SlabDebug_Input)

	local Info = Input.GetDebugInfo()
	Slab.Text("Focused: " .. Info['Focused'])
	Slab.Text("Width: " .. Info['Width'])
	Slab.Text("Height: " .. Info['Height'])
	Slab.Text("Cursor X: " .. Info['CursorX'])
	Slab.Text("Cursor Y: " .. Info['CursorY'])
	Slab.Text("Cursor Position: " .. Info['CursorPos'])
	Slab.Text("Character: " .. Info['Character'])
	Slab.Text("Line Position: " .. Info['LineCursorPos'])
	Slab.Text("Line Position Max: " .. Info['LineCursorPosMax'])
	Slab.Text("Line Number: " .. Info['LineNumber'])
	Slab.Text("Line Length: " .. Info['LineLength'])

	local Lines = Info['Lines']
	if Lines ~= nil then
		Slab.Text("Lines: " .. #Lines)
	end

	Slab.EndWindow()
end

local SlabDebug_MultiLine_Highlight = {
	['function'] = {1, 0, 0, 1},
	['end'] = {1, 0, 0, 1},
	['if'] = {1, 0, 0, 1},
	['then'] = {1, 0, 0, 1},
	['local'] = {1, 0, 0, 1},
	['for'] = {1, 0, 0, 1},
	['do'] = {1, 0, 0, 1},
	['not'] = {1, 0, 0, 1},
	['while'] = {1, 0, 0, 1},
	['repeat'] = {1, 0, 0, 1},
	['until'] = {1, 0, 0, 1},
	['break'] = {1, 0, 0, 1},
	['else'] = {1, 0, 0, 1},
	['elseif'] = {1, 0, 0, 1},
	['in'] = {1, 0, 0, 1},
	['and'] = {1, 0, 0, 1},
	['or'] = {1, 0, 0, 1},
	['true'] = {1, 0, 0, 1},
	['false'] = {1, 0, 0, 1},
	['nil'] = {1, 0, 0, 1},
	['return'] = {1, 0, 0, 1}
}

local SlabDebug_MultiLine_ShouldHighlight = true

function SlabDebug.MultiLine()
	Slab.BeginWindow('SlabDebug_MultiLine', SlabDebug_MultiLine)

	if Slab.Button("Load") then
		SlabDebug_MultiLine_FileDialog = true
	end

	Slab.SameLine()

	if Slab.Button("Save", {Disabled = SlabDebug_MultiLine_FileName == ""}) then
		local Handle, Error = io.open(SlabDebug_MultiLine_FileName, "w")

		if Handle ~= nil then
			Handle:write(SlabDebug_MultiLine_Contents)
			Handle:close()
		end
	end

	local ItemW, ItemH = Slab.GetControlSize()

	Slab.SameLine()
	if Slab.CheckBox(SlabDebug_MultiLine_ShouldHighlight, "Use Lua Highlight", {Size = ItemH}) then
		SlabDebug_MultiLine_ShouldHighlight = not SlabDebug_MultiLine_ShouldHighlight
	end

	Slab.Separator()

	Slab.Text("File: " .. SlabDebug_MultiLine_FileName)

	if Slab.Input('SlabDebug_MultiLine', {
		MultiLine = true,
		Text = SlabDebug_MultiLine_Contents,
		W = 500.0,
		H = 500.0,
		Highlight = SlabDebug_MultiLine_ShouldHighlight and SlabDebug_MultiLine_Highlight or nil
	}) then
		SlabDebug_MultiLine_Contents = Slab.GetInputText()
	end

	Slab.EndWindow()

	if SlabDebug_MultiLine_FileDialog then
		local Result = Slab.FileDialog({AllowMultiSelect = false, Type = 'openfile'})

		if Result.Button ~= "" then
			SlabDebug_MultiLine_FileDialog = false

			if Result.Button == "OK" then
				SlabDebug_MultiLine_FileName = Result.Files[1]
				local Handle, Error = io.open(SlabDebug_MultiLine_FileName, "r")

				if Handle ~= nil then
					SlabDebug_MultiLine_Contents = Handle:read("*a")
					Handle:close()
				end
			end
		end
	end
end

function SlabDebug.Tree()
	if not SlabDebug_Tree.IsOpen then
		return
	end

	local Info = Tree.GetDebugInfo()

	Slab.BeginWindow('Tree', SlabDebug_Tree)
	Slab.Text("Instances: " .. #Info)

	Slab.BeginLayout('Tree_List_Layout', {ExpandW = true, ExpandH = true})
	Slab.BeginListBox('Tree_List')
	for I, V in ipairs(Info) do
		Slab.BeginListBoxItem('Item_' .. I)
		Slab.Text(V)
		Slab.EndListBoxItem()
	end
	Slab.EndListBox()
	Slab.EndLayout()

	Slab.EndWindow()
end

local SlabDebug_LayoutManager_Selected = nil

function SlabDebug.LayoutManager()
	local Info = LayoutManager.GetDebugInfo()

	Slab.BeginWindow('LayoutManager', SlabDebug_LayoutManager)

	Slab.BeginLayout('LayoutManager_Layout', {ExpandW = true})
	if Slab.BeginComboBox('LayoutManager_ID', {Selected = SlabDebug_LayoutManager_Selected}) then
		for K, V in pairs(Info) do
			if SlabDebug_LayoutManager_Selected == nil then
				SlabDebug_LayoutManager_Selected = K
			end

			if Slab.TextSelectable(K) then
				SlabDebug_LayoutManager_Selected = K
			end
		end

		Slab.EndComboBox()
	end
	Slab.EndLayout()

	if SlabDebug_LayoutManager_Selected ~= nil then
		local Items = Info[SlabDebug_LayoutManager_Selected]

		for I, V in ipairs(Items) do
			Slab.Text(V)
		end
	end

	Slab.EndWindow()
end

local function MenuItemWindow(Options)
	if Slab.MenuItemChecked(Options.Title, Options.IsOpen) then
		Options.IsOpen = not Options.IsOpen
	end
end

function SlabDebug.Menu()
	if Slab.BeginMenu("Debug") then
		if Slab.MenuItem("About") then
			SlabDebug.OpenAbout()
		end

		MenuItemWindow(SlabDebug_Mouse)
		MenuItemWindow(SlabDebug_Windows)
		MenuItemWindow(SlabDebug_Regions)
		MenuItemWindow(SlabDebug_Tooltip)
		MenuItemWindow(SlabDebug_DrawCommands)
		MenuItemWindow(SlabDebug_Performance)
		MenuItemWindow(SlabDebug_StyleEditor)
		MenuItemWindow(SlabDebug_Input)
		MenuItemWindow(SlabDebug_MultiLine)
		MenuItemWindow(SlabDebug_Tree)
		MenuItemWindow(SlabDebug_LayoutManager)

		Stats.SetEnabled(SlabDebug_Performance.IsOpen)

		Slab.EndMenu()
	end
end

function SlabDebug.Begin()
	SlabDebug.About()
	SlabDebug.Mouse()
	SlabDebug.Windows()
	SlabDebug.Regions()
	SlabDebug.Tooltip()
	SlabDebug.DrawCommands()
	SlabDebug.Performance()
	SlabDebug.StyleEditor()
	SlabDebug.Input()
	SlabDebug.MultiLine()
	SlabDebug.Tree()
	SlabDebug.LayoutManager()
end

return SlabDebug
