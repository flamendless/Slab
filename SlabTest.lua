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
local SlabDebug = require(SLAB_PATH .. '.SlabDebug')

local SlabTest = {}

local function DrawOverview()
	Slab.Textf(
		"Slab is an immediate mode GUI toolkit for the Love 2D framework. This library " ..
		"is designed to allow users to easily add this library to their existing Love 2D projects and " ..
		"quickly create tools to enable them to iterate on their ideas quickly. The user should be able " ..
		"to utilize this library with minimal integration steps and is completely written in Lua and utilizes " ..
		"the Love 2D API. No compiled binaries are required and the user will have access to the source so " ..
		"that they may make adjustments that meet the needs of their own projects and tools. Refer to main.lua " ..
		"and SlabTest.lua for example usage of this library.\n\n" ..
		"This window will demonstrate the usage of the Slab library and give an overview of all the supported controls " ..
		"and features.")

	Slab.NewLine()

	Slab.Text("The current version of Slab is: ")
	Slab.SameLine()
	Slab.Text(Slab.GetVersion(), {Color = {0, 1, 0, 1}})

	Slab.Text("The current version of LÖVE is: ")
	Slab.SameLine()
	Slab.Text(Slab.GetLoveVersion(), {Color = {0, 1, 0, 1}})
end

local DrawButtons_NumClicked = 0
local DrawButtons_NumClicked_Invisible = 0
local DrawButtons_Enabled = false
local DrawButtons_Hovered = false

local function DrawButtons()
	Slab.Textf("Buttons are simple controls which respond to a user's left mouse click. Buttons will simply return true when they are clicked.")

	Slab.NewLine()

	if Slab.Button("Button") then
		DrawButtons_NumClicked = DrawButtons_NumClicked + 1
	end

	Slab.SameLine()
	Slab.Text("You have clicked this button " .. DrawButtons_NumClicked .. " time(s).")

	Slab.NewLine()
	Slab.Separator()

	Slab.Textf("Buttons can be tested for mouse hover with the call to Slab.IsControlHovered right after declaring the button.")
	Slab.Button(DrawButtons_Hovered and "Hovered" or "Not Hovered", {W = 100})
	DrawButtons_Hovered = Slab.IsControlHovered()

	Slab.NewLine()
	Slab.Separator()

	Slab.Textf(
		"Buttons can be aligned to fit on the right side of the of window. When multiple buttons are declared with this " ..
		"option set along with Slab.SameLine call, each button will be moved over to make room for the new aligned button.")

	Slab.Button("Cancel", {AlignRight = true})
	Slab.SameLine()
	Slab.Button("OK", {AlignRight = true})

	Slab.NewLine()
	Slab.Separator()

	Slab.Textf("Buttons can be set to expand to the size of the window.")
	Slab.Button("Expanded Button", {ExpandW = true})

	Slab.NewLine()
	Slab.Separator()

	Slab.Textf("Buttons can have a custom width and height.")
	Slab.Button("Square", {W = 75, H = 75})

	Slab.NewLine()
	Slab.Separator()

	Slab.Textf(
		"Buttons can also be invisible. Below is a rectangle with an invisible button so that the designer can " ..
		"implement a custom button but still rely on the button behavior. Below is a custom rectangle drawn with an " ..
		"invisible button drawn at the same location.")
	local X, Y = Slab.GetCursorPos()
	Slab.Rectangle({Mode = 'line', W = 50.0, H = 50.0, Color = {1, 1, 1, 1}})
	Slab.SetCursorPos(X, Y)

	if Slab.Button("", {Invisible = true, W = 50.0, H = 50.0}) then
		DrawButtons_NumClicked_Invisible = DrawButtons_NumClicked_Invisible + 1
	end

	Slab.SameLine({CenterY = true})
	Slab.Text("Invisible button has been clicked " .. DrawButtons_NumClicked_Invisible .. " time(s).")

	Slab.NewLine()
	Slab.Separator()

	Slab.Textf("Buttons can also be disabled. Click the button below to toggle the status of the neighboring button.")

	if Slab.Button("Toggle") then
		DrawButtons_Enabled = not DrawButtons_Enabled
	end

	Slab.SameLine()
	Slab.Button(DrawButtons_Enabled and "Enabled" or "Disabled", {Disabled = not DrawButtons_Enabled})
end

local DrawText_Width = 450.0
local DrawText_Alignment = {'left', 'center', 'right', 'justify'}
local DrawText_Alignment_Selected = 'left'
local DrawText_NumClicked = 0
local DrawText_NumClicked_TextOnly = 0

local function DrawText()
	Slab.Textf("Text controls displays text on the current window. Slab currently offers three ways to control the text.")

	Slab.NewLine()
	Slab.Separator()

	Slab.Text("The most basic text control is Slab.Text.")
	Slab.Text("The color of the text can be controlled with the 'Color' option.", {Color = {0, 1, 0, 1}})

	Slab.NewLine()
	Slab.Separator()

	Slab.Textf(
		"Text can be formatted using the Slab.Textf API. Formatted text will wrap the text based on the 'W' option. " ..
		"If the 'W' option is not specified, the window's width will be used as the width. Formatted text also has an " ..
		"alignment option.")

	Slab.NewLine()
	Slab.Text("Width")
	Slab.SameLine()
	if Slab.Input('DrawText_Width', {Text = tostring(DrawText_Width), NumbersOnly = true, ReturnOnText = false}) then
		DrawText_Width = Slab.GetInputNumber()
	end

	Slab.SameLine()
	Slab.Text("Alignment")
	Slab.SameLine()
	if Slab.BeginComboBox('DrawText_Alignment', {Selected = DrawText_Alignment_Selected}) then
		for I, V in ipairs(DrawText_Alignment) do
			if Slab.TextSelectable(V) then
				DrawText_Alignment_Selected = V
			end
		end

		Slab.EndComboBox()
	end

	Slab.Textf(
		"Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore " ..
		"et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut " ..
		"aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum " ..
		"dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui " ..
		"officia deserunt mollit anim id est laborum.", {W = DrawText_Width, Align = DrawText_Alignment_Selected})

	Slab.NewLine()
	Slab.Separator()

	Slab.Textf(
		"Text can also be interacted with using the Slab.TextSelectable function. A background will be " ..
		"rendered when the mouse is hovered over the text and the function will return true when clicked on. " ..
		"The selectable area expands to the width of the window by default. This can be changed to just the text " ..
		"with the 'IsSelectableTextOnly' option.")

	Slab.NewLine()
	if Slab.TextSelectable("This text has been clicked " .. DrawText_NumClicked .. " time(s).") then
		DrawText_NumClicked = DrawText_NumClicked + 1
	end

	Slab.NewLine()
	if Slab.TextSelectable("This text has been clicked " .. DrawText_NumClicked_TextOnly .. " time(s).", {IsSelectableTextOnly = true}) then
		DrawText_NumClicked_TextOnly = DrawText_NumClicked_TextOnly + 1
	end

	Slab.NewLine()
	Slab.Separator()

	Slab.Textf("Text can also be centered horizontally within the bounds of the window.")

	Slab.NewLine()
	Slab.Text("Centered Text", {CenterX = true})
end

local DrawCheckBox_Checked = false
local DrawCheckBox_Checked_NoLabel = false

local function DrawCheckBox()
	Slab.Textf(
		"Check boxes are controls that will display an empty box with an optional label. The function will " ..
		"return true if the user has clicked on the box. The code is then responsible for updating the checked " ..
		"flag to be passed back into the function.")

	Slab.NewLine()
	if Slab.CheckBox(DrawCheckBox_Checked, "Check Box") then
		DrawCheckBox_Checked = not DrawCheckBox_Checked
	end

	Slab.NewLine()
	Slab.Text("A check box with no label.")
	if Slab.CheckBox(DrawCheckBox_Checked_NoLabel) then
		DrawCheckBox_Checked_NoLabel = not DrawCheckBox_Checked_NoLabel
	end
end

local DrawRadioButton_Selected = 1

local function DrawRadioButton()
	Slab.Textf("Radio buttons offer the user to select one option from a list of options.")

	Slab.NewLine()
	for I = 1, 5, 1 do
		if Slab.RadioButton("Option " .. I, {Index = I, SelectedIndex = DrawRadioButton_Selected}) then
			DrawRadioButton_Selected = I
		end
	end
end

local DrawMenus_Window_Selected = "Right click and select an option."
local DrawMenus_Control_Selected = "Right click and select an option from a control."
local DrawMenus_CheckBox = false
local DrawMenus_ComboBox = {"Apple", "Banana", "Pear", "Orange", "Lemon"}
local DrawMenus_ComboBox_Selected = "Apple"

local function DrawContextMenuItem(Label)
	if Slab.BeginContextMenuItem() then
		for I = 1, 5, 1 do
			local MenuLabel = Label .. " Option " .. I
			if Slab.MenuItem(MenuLabel) then
				DrawMenus_Control_Selected = MenuLabel
			end
		end

		Slab.EndContextMenu()
	end
end

local function DrawMenus()
	Slab.Textf(
		"Menus are windows that allow users to make a selection from a list of items. " ..
		"Below are descriptions of the various menus and how they can be utilized.")

	Slab.NewLine()
	Slab.Separator()

	Slab.Textf(
		"The main menu bar is rendered at the top of the window with menu items being added " ..
		"from left to right. When a menu item is clicked, a context menu is opened below the " ..
		"selected item. Creating the main menu bar can open anywhere in the code after the " ..
		"Slab.Update call. These functions should not be called within a BeginWindow/EndWindow " ..
		"call.")

	Slab.NewLine()
	Slab.Separator()

	Slab.Textf(
		"Context menus are menus which are rendered above all other controls to allow the user to make a selection " ..
		"out of a list of items. These can be opened up through the menu bar, or through a right-click " ..
		"action from the user on a given window or control. Menus and menu items make up the context menu " ..
		"and menus can be nested to allow a tree options to be displayed.")

	Slab.NewLine()

	Slab.Textf(
		"Controls can have their own context menus. Right-click on each control to open up the menu " ..
		"and select an option.")

	Slab.NewLine()
	Slab.Text(DrawMenus_Control_Selected)
	Slab.NewLine()

	Slab.Button("Button")
	DrawContextMenuItem("Button")

	Slab.Text("Text")
	DrawContextMenuItem("Text")

	if Slab.CheckBox(DrawMenus_CheckBox, "Check Box") then
		DrawMenus_CheckBox = not DrawMenus_CheckBox
	end
	DrawContextMenuItem("Check Box")

	Slab.Input('DrawMenus_Input')
	DrawContextMenuItem("Input")

	if Slab.BeginComboBox('DrawMenus_ComboBox', {Selected = DrawMenus_ComboBox_Selected}) then
		for I, V in ipairs(DrawMenus_ComboBox) do
			if Slab.TextSelectable(V) then
				DrawMenus_Window_Selected = V
			end
		end

		Slab.EndComboBox()
	end
	DrawContextMenuItem("Combo Box")

	Slab.NewLine()
	Slab.Separator()

	Slab.Textf(
		"Right-clicking anywhere within this window will open up a context menu. Note that BeginContextMenuWindow " ..
		"must come after all BeginContextMenuItem calls.")

	Slab.NewLine()

	Slab.Textf(DrawMenus_Window_Selected)

	if Slab.BeginContextMenuWindow() then
		if Slab.BeginMenu("Window Menu 1") then
			for I = 1, 5, 1 do
				if Slab.MenuItem("Sub Window Option " .. I) then
					DrawMenus_Window_Selected = "Sub Window Option " .. I .. " selected."
				end
			end

			Slab.EndMenu()
		end

		for I = 1, 5, 1 do
			if Slab.MenuItem("Window Option " .. I) then
				DrawMenus_Window_Selected = "Window Option " .. I .. " selected."
			end
		end

		Slab.EndContextMenu()
	end
end

local DrawComboBox_Options = {"England", "France", "Germany", "USA", "Canada", "Mexico", "Japan", "South Korea", "China", "Russia", "India"}
local DrawComboBox_Selected = "USA"
local DrawComboBox_Selected_Width = "USA"

local function DrawComboBox()
	Slab.Textf(
		"A combo box allows the user to select a single item from a list and display the selected item " ..
		"in the combo box. The list is only visible when the user is interacting with the control.")

	Slab.NewLine()

	if Slab.BeginComboBox('DrawComboBox_One', {Selected = DrawComboBox_Selected}) then
		for I, V in ipairs(DrawComboBox_Options) do
			if Slab.TextSelectable(V) then
				DrawComboBox_Selected = V
			end
		end

		Slab.EndComboBox()
	end

	Slab.NewLine()
	Slab.Separator()

	Slab.Textf("A combo box's width can be modified with the 'W' option.")

	Slab.NewLine()

	local W, H = Slab.GetWindowActiveSize()
	if Slab.BeginComboBox('DrawComboBox_Two', {Selected = DrawComboBox_Selected_Width, W = W}) then
		for I, V in ipairs(DrawComboBox_Options) do
			if Slab.TextSelectable(V) then
				DrawComboBox_Selected_Width = V
			end
		end

		Slab.EndComboBox()
	end
end

local DrawInput_Basic = "Hello World"
local DrawInput_Basic_Return = "Hello World"
local DrawInput_Basic_Numbers = 0
local DrawInput_Basic_Numbers_Clamped = 0.5
local DrawInput_MultiLine = 
[[
function Foo()
	print("Bar")
end

The quick brown fox jumped over the lazy dog.]]
local DrawInput_MultiLine_Width = math.huge

local function DrawInput()
	Slab.Textf(
		"The input control allows the user to enter in text into an input box. This control is similar " ..
		"to input boxes found in other applications.")

	Slab.NewLine()

	Slab.Textf(
		"The first example is very simple. An Input control is declared and the resulting text is captured if " ..
		"the function returns true. By default, the function will return true on any text that is entered.")

	if Slab.Input('DrawInput_Basic', {Text = DrawInput_Basic}) then
		DrawInput_Basic = Slab.GetInputText()
	end

	Slab.NewLine()

	Slab.Textf(
		"The return behavior can be modified so that the function will only return true if the Enter/Return " ..
		"key is pressed. If the control loses focus without the Enter/Return key pressed, then the text will " ..
		"revert back to what it was before.")

	if Slab.Input('DrawInput_Basic_Return', {Text = DrawInput_Basic_Return, ReturnOnText = false}) then
		DrawInput_Basic_Return = Slab.GetInputText()
	end

	Slab.NewLine()
	Slab.Separator()

	Slab.Textf("Input controls can be configured to only take numeric values.")

	if Slab.Input('DrawInput_Basic_Numbers', {Text = tostring(DrawInput_Basic_Numbers), NumbersOnly = true}) then
		DrawInput_Basic_Numbers = Slab.GetInputNumber()
	end

	Slab.NewLine()

	Slab.Textf(
		"These numeric controls can also have min and/or max values set. Below is an example where the " ..
		"numeric input control is clamped from 0.0 to 1.0.")

	if Slab.Input('DrawInput_Basic_Numbers_Clamped', {Text = tostring(DrawInput_Basic_Numbers_Clamped), NumbersOnly = true, MinNumber = 0.0, MaxNumber = 1.0}) then
		DrawInput_Basic_Numbers_Clamped = Slab.GetInputNumber()
	end

	Slab.NewLine()
	Slab.Separator()

	Slab.Textf(
		"Input controls also allow for multi-line editing using the MultiLine option. The default text wrapping " ..
		"option is set to math.huge, but this can be modified with the MultiLineW option. The example below demonstrates " ..
		"how to set up a multi-line input control and shows how the size of the control can be modified.")

	Slab.NewLine()
	Slab.Text("MultiLineW")
	Slab.SameLine()
	if Slab.Input('DrawInput_MultiLine_Width', {Text = tostring(DrawInput_MultiLine_Width), NumbersOnly = true, ReturnOnText = false}) then
		DrawInput_MultiLine_Width = Slab.GetInputNumber()
	end

	local W, H = Slab.GetWindowActiveSize()

	if Slab.Input('DrawInput_MultiLine', {Text = DrawInput_MultiLine, MultiLine = true, MultiLineW = DrawInput_MultiLine_Width, W = W, H = 150.0}) then
		DrawInput_MultiLine = Slab.GetInputText()
	end
end

local DrawImage_Path = SLAB_PATH .. "/Internal/Resources/Textures/power.png"
local DrawImage_Path_Icons = SLAB_PATH .. "/Internal/Resources/Textures/gameicons.png"
local DrawImage_Color = {1, 0, 0, 1}
local DrawImage_Color_Edit = false
local DrawImage_Scale = 1.0
local DrawImage_Scale_X = 1.0
local DrawImage_Scale_Y = 1.0
local DrawImage_Power = false
local DrawImage_Power_Hovered = false
local DrawImage_Power_On = {0, 1, 0, 1}
local DrawImage_Power_Off = {1, 0, 0, 1}
local DrawImage_Icon_X = 0
local DrawImage_Icon_Y = 0
local DrawImage_Icon_Move = false

local function DrawImage()
	Slab.Textf(
		"Images can be drawn within windows and react to user interaction. A path to an image can be specified through the options of " ..
		"the Image function. If this is done, Slab will manage the image resource and will use the path as a key to the resource.")

	Slab.Image('DrawImage_Basic', {Path = DrawImage_Path})

	Slab.NewLine()
	Slab.Separator()

	Slab.Textf(
		"An image's color can be modified with the 'Color' option.")

	if Slab.Button("Change Color") then
		DrawImage_Color_Edit = true
	end

	if DrawImage_Color_Edit then
		local Result = Slab.ColorPicker({Color = DrawImage_Color})

		if Result.Button ~= "" then
			DrawImage_Color_Edit = false

			if Result.Button == "OK" then
				DrawImage_Color = Result.Color
			end
		end
	end

	Slab.Image('DrawImage_Color', {Path = DrawImage_Path, Color = DrawImage_Color})

	Slab.NewLine()
	Slab.Separator()

	Slab.Textf(
		"There is an option to modify the scale of an image. The scale can both be affected " ..
		"on the X or Y axis.")

	Slab.Text("Scale")
	Slab.SameLine()
	if Slab.Input('DrawImage_Scale', {Text = tostring(DrawImage_Scale), NumbersOnly = true, ReturnOnText = false, W = 75}) then
		DrawImage_Scale = Slab.GetInputNumber()
		DrawImage_Scale_X = DrawImage_Scale
		DrawImage_Scale_Y = DrawImage_Scale
	end

	Slab.SameLine({Pad = 6.0})
	Slab.Text("Scale X")
	Slab.SameLine()
	if Slab.Input('DrawImage_Scale_X', {Text = tostring(DrawImage_Scale_X), NumbersOnly = true, ReturnOnText = false, W = 75}) then
		DrawImage_Scale_X = Slab.GetInputNumber()
	end

	Slab.SameLine({Pad = 6.0})
	Slab.Text("Scale Y")
	Slab.SameLine()
	if Slab.Input('DrawImage_Scale_Y', {Text = tostring(DrawImage_Scale_Y), NumbersOnly = true, ReturnOnText = false, W = 75}) then
		DrawImage_Scale_Y = Slab.GetInputNumber()
	end

	Slab.Image('DrawImage_Scale', {Path = DrawImage_Path, ScaleX = DrawImage_Scale_X, ScaleY = DrawImage_Scale_Y})

	Slab.NewLine()
	Slab.Separator()

	Slab.Textf(
		"Images can also have interactions through the control API. The left image will change when the mouse is hovered " ..
		"while the right image will change on click.")

	Slab.Image('DrawImage_Hover', {Path = DrawImage_Path, Color = DrawImage_Power_Hovered and DrawImage_Power_On or DrawImage_Power_Off})
	DrawImage_Power_Hovered = Slab.IsControlHovered()

	Slab.SameLine({Pad = 12.0})
	Slab.Image('DrawImage_Click', {Path = DrawImage_Path, Color = DrawImage_Power and DrawImage_Power_On or DrawImage_Power_Off})
	if Slab.IsControlClicked() then
		DrawImage_Power = not DrawImage_Power
	end

	Slab.NewLine()
	Slab.Separator()

	Slab.Textf(
		"A sub region can be defined to draw a section of an image.")

	local X, Y = Slab.GetCursorPos()
	local AbsX, AbsY = Slab.GetCursorPos({Absolute = true})
	Slab.Image('DrawImage_Icons', {Path = DrawImage_Path_Icons})
	if Slab.IsControlClicked() then
		local MouseX, MouseY = Slab.GetMousePositionWindow()
		local Left = AbsX + DrawImage_Icon_X
		local Right = Left + 50.0
		local Top = AbsY + DrawImage_Icon_Y
		local Bottom = Top + 50.0
		if Left <= MouseX and MouseX <= Right and
			Top <= MouseY and MouseY <= Bottom then
			DrawImage_Icon_Move = true
		end
	end

	if Slab.IsMouseReleased() then
		DrawImage_Icon_Move = false
	end

	local W, H = Slab.GetControlSize()

	if DrawImage_Icon_Move then
		local DeltaX, DeltaY = Slab.GetMouseDelta()
		DrawImage_Icon_X = math.max(DrawImage_Icon_X + DeltaX, 0.0)
		DrawImage_Icon_X = math.min(DrawImage_Icon_X, W - 50.0)

		DrawImage_Icon_Y = math.max(DrawImage_Icon_Y + DeltaY, 0.0)
		DrawImage_Icon_Y = math.min(DrawImage_Icon_Y, H - 50.0)
	end

	Slab.SetCursorPos(X + DrawImage_Icon_X, Y + DrawImage_Icon_Y)
	Slab.Rectangle({Mode = 'line', Color = {0, 0, 0, 1}, W = 50.0, H = 50.0})

	Slab.SetCursorPos(X + W + 12.0, Y)
	Slab.Image('DrawImage_Icons_Region', {
		Path = DrawImage_Path_Icons,
		SubX = DrawImage_Icon_X,
		SubY = DrawImage_Icon_Y,
		SubW = 50.0,
		SubH = 50.0
	})
end

function SlabTest.MainMenuBar()
	if Slab.BeginMainMenuBar() then
		if Slab.BeginMenu("File") then
			if Slab.MenuItem("Quit") then
				love.event.quit()
			end

			Slab.EndMenu()
		end

		SlabDebug.Menu()

		Slab.EndMainMenuBar()
	end
end

local Categories = {
	{"Overview", DrawOverview},
	{"Buttons", DrawButtons},
	{"Text", DrawText},
	{"Check Box", DrawCheckBox},
	{"Radio Button", DrawRadioButton},
	{"Menus", DrawMenus},
	{"Combo Box", DrawComboBox},
	{"Input", DrawInput},
	{"Image", DrawImage}
}

local Selected = nil

function SlabTest.Begin()
	SlabTest.MainMenuBar()

	if Selected == nil then
		Selected = Categories[1]
	end

	Slab.BeginWindow('Main', {Title = "Slab", AutoSizeWindow = false, W = 800.0, H = 600.0})

	local W, H = Slab.GetWindowActiveSize()

	if Slab.BeginComboBox('Categories', {Selected = Selected[1], W = W}) then
		for I, V in ipairs(Categories) do
			if Slab.TextSelectable(V[1]) then
				Selected = Categories[I]
			end
		end

		Slab.EndComboBox()
	end

	Slab.Separator()

	if Selected ~= nil and Selected[2] ~= nil then
		Selected[2]()
	end

	Slab.EndWindow()

	SlabDebug.Begin()
end

return SlabTest
