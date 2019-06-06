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

if SLAB_PATH == nil then
	SLAB_PATH = (...):match("(.-)[^%.]+$") 
end

local Button = require(SLAB_PATH .. '.Internal.UI.Button')
local CheckBox = require(SLAB_PATH .. '.Internal.UI.CheckBox')
local ColorPicker = require(SLAB_PATH .. '.Internal.UI.ColorPicker')
local ComboBox = require(SLAB_PATH .. '.Internal.UI.ComboBox')
local Cursor = require(SLAB_PATH .. '.Internal.Core.Cursor')
local Dialog = require(SLAB_PATH .. '.Internal.UI.Dialog')
local DrawCommands = require(SLAB_PATH .. '.Internal.Core.DrawCommands')
local Image = require(SLAB_PATH .. '.Internal.UI.Image')
local Input = require(SLAB_PATH .. '.Internal.UI.Input')
local Keyboard = require(SLAB_PATH .. '.Internal.Input.Keyboard')
local ListBox = require(SLAB_PATH .. '.Internal.UI.ListBox')
local Mouse = require(SLAB_PATH .. '.Internal.Input.Mouse')
local Menu = require(SLAB_PATH .. '.Internal.UI.Menu')
local MenuState = require(SLAB_PATH .. '.Internal.UI.MenuState')
local MenuBar = require(SLAB_PATH .. '.Internal.UI.MenuBar')
local Region = require(SLAB_PATH .. '.Internal.UI.Region')
local Separator = require(SLAB_PATH .. '.Internal.UI.Separator')
local Shape = require(SLAB_PATH .. '.Internal.UI.Shape')
local Stats = require(SLAB_PATH .. '.Internal.Core.Stats')
local Style = require(SLAB_PATH .. '.Style')
local Text = require(SLAB_PATH .. '.Internal.UI.Text')
local Tree = require(SLAB_PATH .. '.Internal.UI.Tree')
local Window = require(SLAB_PATH .. '.Internal.UI.Window')

--[[
	Slab

	Slab is an immediate mode GUI toolkit for the Love 2D framework. This library is designed to
	allow users to easily add this library to their existing Love 2D projects and quickly create
	tools to enable them to iterate on their ideas quickly. The user should be able to utilize this
	library with minimal integration steps and is completely written in Lua and utilizes
	the Love 2D API. No compiled binaries are required and the user will have access to the source
	so that they may make adjustments that meet the needs of their own projects and tools. Refer
	to main.lua and SlabTest.lua for example usage of this library.

	Supported Version: 11.2.0

	API:
		Initialize
		GetVersion
		GetLoveVersion
		Update
		Draw
		GetStyle

		Window:
			BeginWindow
			EndWindow
			GetWindowPosition
			GetWindowSize
			GetWindowContentSize
			GetWindowActiveSize
			BeginColumn
			EndColumn

		Menu:
			BeginMainMenuBar
			EndMainMenuBar
			BeginMenuBar
			EndMenuBar
			BeginMenu
			EndMenu
			BeginContextMenuItem
			BeginContextMenuWindow
			EndContextMenu
			MenuItem
			MenuItemChecked

		Separator
		Button
		RadioButton
		Text
		TextSelectable
		Textf
		CheckBox
		Input
		GetInputText
		GetInputNumber
		BeginTree
		EndTree
		BeginComboBox
		EndComboBox
		Image

		Cursor:
			SameLine
			NewLine
			SetCursorPos
			GetCursorPos

		Properties

		ListBox:
			BeginListBox
			EndListBox
			BeginListBoxItem
			IsListBoxItemClicked
			EndListBoxItem

		Dialog:
			OpenDialog
			BeginDialog
			EndDialog
			CloseDialog
			MessageBox
			FileDialog

		Mouse:
			IsMouseDown
			IsMouseClicked
			IsMouseReleased
			IsMouseDoubleClicked
			IsMouseDragging
			GetMousePosition
			GetMouseDelta

		Control:
			IsControlHovered
			IsControlClicked
			IsVoidHovered
			IsVoidClicked

		Keyboard:
			IsKeyDown
			IsKeyPressed
			IsKeyReleased

		Shape:
			Rectangle
--]]
local Slab = {}

-- Slab version numbers.
local Version_Major = 0
local Version_Minor = 4
local Version_Revision = 0

local FrameNumber = 0

local function TextInput(Ch)
	Input.Text(Ch)

	if love.textinput ~= nil then
		love.textinput(Ch)
	end
end

local function WheelMoved(X, Y)
	Window.WheelMoved(X, Y)

	if love.wheelmoved ~= nil then
		love.wheelmoved(X, Y)
	end
end

--[[
	Initialize

	Initializes Slab and hooks into the required events. This function should be called in love.load.

	args: [Table] The list of parameters passed in by the user on the command-line. This should be passed in from
		love.load function.

	Return: None.
--]]
function Slab.Initialize(args)
	Style.API.Initialize()
	love.handlers['textinput'] = TextInput
	love.handlers['wheelmoved'] = WheelMoved
end

--[[
	GetVersion

	Retrieves the current version of Slab being used as a string.

	Return: [String] String of the current Slab version.
--]]
function Slab.GetVersion()
	return string.format("%d.%d.%d", Version_Major, Version_Minor, Version_Revision)
end

--[[
	GetLoveVersion

	Retrieves the current version of Love being used as a string.

	Return: [String] String of the current Love version.
--]]
function Slab.GetLoveVersion()
	local Major, Minor, Revision, Codename = love.getVersion()
	return string.format("%d.%d.%d - %s", Major, Minor, Revision, Codename)
end

--[[
	Update

	Updates the input state and states of various widgets. This function must be called every frame.
	This should be called before any Slab calls are made to ensure proper responses to Input are made.

	dt: [Number] The delta time for the frame. This should be passed in from love.update.

	Return: None.
--]]
function Slab.Update(dt)
	FrameNumber = FrameNumber + 1

	Stats.Reset()
	Stats.Begin('Frame')
	Stats.Begin('Update')

	Mouse.Update()
	Keyboard.Update()
	Input.Update(dt)
	DrawCommands.Reset()
	Window.Reset()
	Window.SetFrameNumber(FrameNumber)

	if MenuState.IsOpened then
		MenuState.WasOpened = MenuState.IsOpened
		if Mouse.IsClicked(1) then
			MenuState.RequestClose = true
		end
	end

	Stats.End('Update')
end

--[[
	Draw

	This function will execute all buffered draw calls from the various Slab calls made prior. This
	function should be called from love.draw and should be called at the very to ensure Slab is rendered
	above the user's workspace.

	Return: None.
--]]
function Slab.Draw()
	Stats.Begin('Draw')

	Window.Validate()

	if MenuState.RequestClose then
		Menu.Close()
		MenuBar.Clear()
	end

	Mouse.UpdateCursor()

	if Mouse.IsReleased(1) then
		Button.ClearClicked()
	end

	DrawCommands.Execute()

	Stats.End('Draw')
	Stats.End('Frame')
end

--[[
	GetStyle

	Retrieve the style table associated with the current instance of Slab. This will allow the user to add custom styling
	to their controls.

	Return: [Table] The style table.
--]]
function Slab.GetStyle()
	return Style
end

--[[
	BeginWindow

	This function begins the process of drawing widgets to a window. This function must be followed up with
	an EndWindow call to ensure proper behavior of drawing windows.

	Id: [String] A unique string identifying this window in the project.
	Options: [Table] List of options that control how this window will behave.
		X: [Number] The X position to start rendering the window at.
		Y: [Number] The Y position to start rendering the window at.
		W: [Number] The starting width of the window.
		H: [Number] The starting height of the window.
		ContentW: [Number] The starting width of the content contained within this window.
		ContentH: [Number] The starting height of the content contained within this window.
		BgColor: [Table] The background color value for this window. Will use the default style WindowBackgroundColor if this is empty.
		Title: [String] The title to display for this window. If emtpy, no title bar will be rendered and the window will not be movable.
		AllowMove: [Boolean] Controls whether the window is movable within the title bar area. The default value is true.
		AllowResize: [Boolean] Controls whether the window is resizable. The default value is true. AutoSizeWindow must be false for this to work.
		AllowFocus: [Boolean] Controls whether the window can be focused. The default value is true.
		Border: [Number] The value which controls how much empty space should be left between all sides of the window from the content.
			The default value is 4.0
		NoOutline: [Boolean] Controls whether an outline should not be rendered. The default value is false.
		IsMenuBar: [Boolean] Controls whether if this window is a menu bar or not. This flag should be ignored and is used by the menu bar
			system. The default value is false.
		AutoSizeWindow: [Boolean] Automatically updates the window size to match the content size. The default value is true.
		AutoSizeWindowW: [Boolean] Automatically update the window width to match the content size. This value is taken from AutoSizeWindow by default.
		AutoSizeWindowH: [Boolean] Automatically update the window height to match the content size. This value is taken from AutoSizeWindow by default.
		AutoSizeContent: [Boolean] The content size of the window is automatically updated with each new widget. The default value is true.
		Layer: [String] The layer to which to draw this window. This is used internally and should be ignored by the user.
		ResetPosition: [Boolean] Determines if the window should reset any delta changes to its position.
		ResetSize: [Boolean] Determines if the window should reset any delta changes to its size.
		ResetContent: [Boolean] Determines if the window should reset any delta changes to its content size.
		ResetLayout: [Boolean] Will reset the position, size, and content. Short hand for the above 3 flags.
		SizerFilter: [Table] Specifies what sizers are enabled for the window. If nothing is specified, all sizers are available. The values can
			be: NW, NE, SW, SE, N, S, E, W
		CanObstruct: [Boolean] Sets whether this window is considered for obstruction of other windows and their controls. The default value is true.
		Rounding: [Number] Amount of rounding to apply to the corners of the window.
		Columns: [Number] The number of columns for this window. Must be larger than 1 for columns to work properly.

	Return: None
--]]
function Slab.BeginWindow(Id, Options)
	Window.Begin(Id, Options)
end

--[[
	EndWindow

	This function must be called after a BeginWindow and associated widget calls. If the user fails to call this, an assertion will be thrown
	to alert the user.

	Return: None.
--]]
function Slab.EndWindow()
	Window.End()
end

--[[
	GetWindowPosition

	Retrieves the active window's position.

	Return: [Number], [Number] The X and Y position of the active window.
--]]
function Slab.GetWindowPosition()
	return Window.GetPosition()
end

--[[
	GetWindowSize

	Retrieves the active window's size.

	Return: [Number], [Number] The width and height of the active window.
--]]
function Slab.GetWindowSize()
	return Window.GetSize()
end

--[[
	GetWindowContentSize

	Retrieves the active window's content size.

	Return: [Number], [Number] The width and height of the active window content.
--]]
function Slab.GetWindowContentSize()
	return Window.GetContentSize()
end

--[[
	GetWindowActiveSize

	Retrieves the active window's active size minus the borders. This could be the size of the window or
	the size of the current column.

	Return: [Number], [Number] The width and height of the window's active bounds.
--]]
function Slab.GetWindowActiveSize()
	return Window.GetBorderlessSize()
end

--[[
	BeginColumn

	The start of a column. EndColumn must be called after a call to BeginColumn and all controls have been rendered.

	Index: [Number] The index to the column to add controls to. This must be a valid column between 1 and the max column index
		defined by the Columns option in BeginWindow.

	Return: None.
--]]
function Slab.BeginColumn(Index)
	Window.BeginColumn(Index)
end

--[[
	EndColumn

	The end of a column. Must be called after a BeginColumn call.

	Return: None.
--]]
function Slab.EndColumn()
	Window.EndColumn()
end

--[[
	BeginMainMenuBar

	This function begins the process for setting up the main menu bar. This should be called outside of any BeginWindow/EndWindow calls.
	The user should only call EndMainMenuBar if this function returns true. Use BeginMenu/EndMenu calls to add menu items on the main menu bar.

	Example:
		if Slab.BeginMainMenuBar() then
			if Slab.BeginMenu("File") then
				if Slab.MenuItem("Quit") then
					love.event.quit()
				end

				Slab.EndMenu()
			end

			Slab.EndMainMenuBar()
		end

	Return: [Boolean] Returns true if the main menu bar process has started.
--]]
function Slab.BeginMainMenuBar()
	Cursor.SetPosition(0.0, 0.0)
	return Slab.BeginMenuBar(true)
end

--[[
	EndMainMenuBar

	This function should be called if BeginMainMenuBar returns true.

	Return: None.
--]]
function Slab.EndMainMenuBar()
	Slab.EndMenuBar()
end

--[[
	BeginMenuBar

	This function begins the process of rendering a menu bar for a window. This should only be called within a BeginWindow/EndWindow context.

	IsMainMenuBar: [Boolean] Is this menu bar for the main viewport. Used internally. Should be ignored for all other calls.

	Return: [Boolean] Returns true if the menu bar process has started.
--]]
function Slab.BeginMenuBar(IsMainMenuBar)
	return MenuBar.Begin(IsMainMenuBar)
end

--[[
	EndMenuBar

	This function should be called if BeginMenuBar returns true.

	Return: None.
--]]
function Slab.EndMenuBar()
	MenuBar.End()
end

--[[
	BeginMenu

	Adds a menu item that when the user hovers over, opens up an additional context menu. When used within a menu bar, BeginMenu calls
	will be added to the bar. Within a context menu, the menu item will be added within the context menu with an additional arrow to notify
	the user more options are available. If this function returns true, the user must call EndMenu.

	Label: [String] The label to display for this menu.

	Return: [Boolean] Returns true if the menu item is being hovered.
--]]
function Slab.BeginMenu(Label)
	return Menu.BeginMenu(Label)
end

--[[
	EndMenu

	Finishes up a BeginMenu. This function must be called if BeginMenu returns true.

	Return: None.
--]]
function Slab.EndMenu()
	Menu.EndMenu()
end

--[[
	BeginContextMenuItem

	Opens up a context menu based on if the user right clicks on the last item. This function should be placed immediately after an item
	call to open up a context menu for that specific item. If this function returns true, EndContextMenu must be called.

	Example:
		if Slab.Button("Button!") then
			-- Perform logic here when button is clicked
		end

		-- This will only return true if the previous button is hot and the user right-clicks.
		if Slab.BeginContextMenuItem() then
			Slab.MenuItem("Button Item 1")
			Slab.MenuItem("Button Item 2")

			Slab.EndContextMenu()
		end

	Return: [Boolean] Returns true if the user right clicks on the previous item call. EndContextMenu must be called in order for
		this to function properly.
--]]
function Slab.BeginContextMenuItem()
	return Menu.BeginContextMenu({IsItem = true})
end

--[[
	BeginContextMenuWindow

	Opens up a context menu based on if the user right clicks anywhere within the window. It is recommended to place this function at the end
	of a window's widget calls so that Slab can catch any BeginContextMenuItem calls before this call. If this function returns true,
	EndContextMenu must be called.

	Return: [Boolean] Returns true if the user right clicks anywhere within the window. EndContextMenu must be called in order for this
		to function properly.
--]]
function Slab.BeginContextMenuWindow()
	return Menu.BeginContextMenu({IsWindow = true})
end

--[[
	EndContextMenu

	Finishes up any BeginContextMenuItem/BeginContextMenuWindow if they return true.

	Return: None.
--]]
function Slab.EndContextMenu()
	Menu.EndContextMenu()
end

--[[
	MenuItem

	Adds a menu item to a given context menu.

	Label: [String] The label to display to the user.

	Return: [Boolean] Returns true if the user clicks on this menu item.
--]]
function Slab.MenuItem(Label)
	return Menu.MenuItem(Label)
end

--[[
	MenuItemChecked

	Adds a menu item to a given context menu. If IsChecked is true, then a check mark will be rendered next to the
	label.

	Example:
		local Checked = false
		if Slab.MenuItemChecked("Menu Item", Checked)
			Checked = not Checked
		end

	Label: [String] The label to display to the user.
	IsChecked: [Boolean] Determines if a check mark should be rendered next to the label.

	Return: [Boolean] Returns true if the user clicks on this menu item.
--]]
function Slab.MenuItemChecked(Label, IsChecked)
	return Menu.MenuItemChecked(Label, IsChecked)
end

--[[
	Separator

	This functions renders a separator line in the window.

	Option: [Table] List of options for how this separator will be drawn.
		IncludeBorders: [Boolean] Whether to extend the separator to include the window borders. This is false by default.
		H: [Number] The height of the separator. This doesn't change the line thickness, rather, specifies the cursor advancement
			in the Y direction.

	Return: None.
--]]
function Slab.Separator(Options)
	Separator.Begin(Options)
end

--[[
	Button

	Adds a button to the active window.

	Label: [String] The label to display on the button.
	Options: [Table] List of options for how this button will behave.
		Tooltip: [String] The tooltip to display when the user hovers over this button.
		AlignRight: [Boolean] Flag to push this button to the right side of the window.
		ExpandW: [Boolean] Expands the button to fit the contents of the window.
		Rounding: [Number] Amount of rounding to apply to the corners of the button.
		Invisible: [Boolean] Don't render the button, but keep the behavior.
		W: [Number] Override the width of the button.
		H: [Number] Override the height of the button.
		Disabled: [Boolean] If true, the button is not interactable by the user.

	Return: [Boolean] Returns true if the user clicks on this button.
--]]
function Slab.Button(Label, Options)
	return Button.Begin(Label, Options)
end

--[[
	RadioButton

	Adds a radio button entry to the active window. The grouping of radio buttons is determined by the user. An Index can
	be applied to the given radio button and a SelectedIndex can be passed in to determine if this specific radio button
	is the selected one.

	Label: [String] The label to display next to the button.
	Options: [Table] List of options for how this radio button will behave.
		Index: [Number] The index of this radio button. Will be 0 by default and not selectable. Assign an index to group the button.
		SelectedIndex: [Number] The index of the radio button that is selected. If this equals the Index field, then this radio button
			will be rendered as selected.
		Tooltip: [String] The tooltip to display when the user hovers over the button or label.

	Return: [Boolean] Returns true if the user clicks on this button.
--]]
function Slab.RadioButton(Label, Options)
	return Button.BeginRadio(Label, Options)
end

--[[
	Text

	Adds text to the active window.

	Label: [String] The string to be displayed in the window.
	Options: [Table] List of options for how this text is displayed.
		Color: [Table] The color to render the text.
		Pad: [Number] How far to pad the text from the left side of the current cursor position.
		IsSelectable: [Boolean] Whether this text is selectable using the text's Y position and the window X and width as the
			hot zone.
		IsSelectableTextOnly: [Boolean] Only available if IsSelectable is true. Will use the text width instead of the
			window width to determine the hot zone.
		IsSelected: [Boolean] Forces the hover background to be rendered.
		SelectOnHover: [Boolean] Returns true if the user is hovering over the hot zone of this text.
		HoverColor: [Table] The color to render the background if the IsSelected option is true.
		CenterX: [Boolean] Should the text be centered relative to the current active bounds.

	Return: [Boolean] Returns true if SelectOnHover option is set to true. False otherwise.
--]]
function Slab.Text(Label, Options)
	return Text.Begin(Label, Options)
end

--[[
	TextSelectable

	This function is a shortcut for SlabText with the IsSelectable option set to true.

	Label: [String] The string to be displayed in the window.
	Options: [Table] List of options for how this text is displayed.
		See Slab.Text for all options.

	Return: [Boolean] Returns true if user clicks on this text. False otherwise.
--]]
function Slab.TextSelectable(Label, Options)
	Options = Options == nil and {} or Options
	Options.IsSelectable = true
	return Slab.Text(Label, Options)
end

--[[
	Textf

	Adds formatted text to the active window. This text will wrap to fit within the contents of
	either the window or a user specified width.

	Label: [String] The text to be rendered.
	Options: [Table] List of options for how this text is displayed.
		Color: [Table] The color to render the text.
		W: [Number] The width to restrict the text to. If this option is not specified, then the window
			width is used.
		Align: [String] The alignment to use for this text. For more information, refer to the love documentation
			at https://love2d.org/wiki/AlignMode. Below are the available options:
			center: Align text center.
			left: Align text left.
			right: Align text right.
			justify: Align text both left and right.

	Return: None.
--]]
function Slab.Textf(Label, Options)
	Text.BeginFormatted(Label, Options)
end

--[[
	CheckBox

	Renders a check box with a label. The check box when enabled will render an 'X'.

	Enabled: [Boolean] Will render an 'X' within the box if true. Will be an empty box otherwise.
	Label: [String] The label to display after the check box.
	Options: [Table] List of options for how this check box will behave.
		Tooltip: [String] Text to be displayed if the user hovers over the check box.
		Id: [String] An optional Id that can be supplied by the user. By default, the Id will be the label.
		Rounding: [Number] Amount of rounding to apply to the corners of the check box.

	Return: [Boolean] Returns true if the user clicks within the check box.
--]]
function Slab.CheckBox(Enabled, Label, Options)
	return CheckBox.Begin(Enabled, Label, Options)
end

--[[
	Input

	This function will render an input box for a user to input text in. This widget behaves like input boxes
	found in other applications. This function will only return true if it has focus and user has either input
	text or pressed the return key.

	Example:
		local Text = "Hello World"
		if Slab.Input('Example', {Text = Text}) then
			Text = Slab.GetInputText()
		end

	Id: [String] A string that uniquely identifies this Input within the context of the window.
	Options: [Table] List of options for how this Input will behave.
		Tooltip: [String] Text to be displayed if the user hovers over the Input box.
		ReturnOnText: [Boolean] Will cause this function to return true whenever the user has input
			a new character into the Input box. This is true by default.
		Text: [String] The text to be supplied to the input box. It is recommended to use this option
			when ReturnOnText is true.
		BgColor: [Table] The background color for the input box.
		SelectColor: [Table] The color used when the user is selecting text within the input box.
		SelectOnFocus: [Boolean] When this input box is focused by the user, the text contents within the input
			will be selected. This is true by default.
		NumbersOnly: [Boolean] When true, only numeric characters and the '.' character are allowed to be input into
			the input box. If no text is input, the input box will display '0'.
		W: [Number] The width of the input box. By default, will be 150.0
		H: [Number] The height of the input box. By default, will be the height of the current font.
		ReadOnly: [Boolean] Whether this input field can be editable or not.
		Align: [String] Aligns the text within the input box. Options are:
			left: Aligns the text to the left. This will be set when this Input is focused.
			center: Aligns the text in the center. This is the default for when the text is not focused.
		Rounding: [Number] Amount of rounding to apply to the corners of the input box.
		MinNumber: [Number] The minimum value that can be entered into this input box. Only valid when NumbersOnly is true.
		MaxNumber: [Number] The maximum value that can be entered into this input box. Only valid when NumbersOnly is true.
		MultiLine: [Boolean] Determines whether this input control should support multiple lines. If this is true, then the
			SelectOnFocus flag will be false. The given text will also be sanitized to remove controls characters such as
			'\r'. Also, the text will be left aligned.
		MultiLineW: [Number] The width for which the lines of text should be wrapped at.

	Return: [Boolean] Returns true if the user has pressed the return key while focused on this input box. If ReturnOnText
		is set to true, then this function will return true whenever the user has input any character into the input box.
--]]
function Slab.Input(Id, Options)
	return Input.Begin(Id, Options)
end

--[[
	GetInputText

	Retrieves the text entered into the focused input box. Refer to the documentation for Slab.Input for an example on how to
	use this function.

	Return: [String] Returns the text entered into the focused input box.
--]]
function Slab.GetInputText()
	return Input.GetText()
end

--[[
	GetInputNumber

	Retrieves the text entered into the focused input box and attempts to conver the text into a number. Will always return a valid
	number.

	Return: [Number] Returns the text entered into the focused input box as a number.
--]]
function Slab.GetInputNumber()
	local Result = tonumber(Input.GetText())
	if Result == nil then
		Result = 0
	end
	return Result
end

--[[
	BeginTree

	This function will render a tree item with an optional label. The tree can be expanded or collapsed based on whether
	the user clicked on the tree item. This function can also be nested to create a hierarchy of tree items. This function
	will return false when collapsed and true when expanded. If this function returns true, Slab.EndTree must be called in
	order for this tree item to behave properly. The hot zone of this tree item will be the height of the label and the width
	of the window by default.

	Id: [String] A string uniquely identifying this tree item within the context of the window.
	Options: [Table] List of options for how this tree item will behave.
		Label: [String] The text to be rendered for this tree item.
		Tooltip: [String] The text to be rendered when the user hovers over this tree item.
		IsLeaf: [Boolean] If this is true, this tree item will not be expandable/collapsable.
		OpenWithHighlight: [Boolean] If this is true, the tree will be expanded/collapsed when the user hovers over the hot
			zone of this tree item. If this is false, the user must click the expand/collapse icon to interact with this tree
			item.
		Icon: [Object] A user supplied image. This must be a valid Love image or the call will assert.
		IconPath: [String] If the Icon option is nil, then a path can be specified. Slab will load and
			manage the image resource.
		IsSelected: [Boolean] If true, will render a highlight rectangle around the tree item.
		IsOpen: [Boolean] Will force the tree item to be expanded.

	Return: [Boolean] Returns true if this tree item is expanded. Slab.EndTree must be called if this returns true.
--]]
function Slab.BeginTree(Id, Options)
	return Tree.Begin(Id, Options)
end

--[[
	EndTree

	Finishes up any BeginTree calls if those functions return true.

	Return: None.
--]]
function Slab.EndTree()
	Tree.End()
end

--[[
	BeginComboBox

	This function renders a non-editable input field with a drop down arrow. When the user clicks this option, a window is
	created and the user can supply their own Slab.TextSelectable calls to add possible items to select from. This function
	will return true if the combo box is opened. Slab.EndComboBox must be called if this function returns true.

	Example:
		local Options = {"Apple", "Banana", "Orange", "Pear", "Lemon"}
		local Options_Selected = ""
		if Slab.BeginComboBox('Fruits', {Selected = Options_Selected}) then
			for K, V in pairs(Options) do
				if Slab.TextSelectable(V) then
					Options_Selected = V
				end
			end

			Slab.EndComboBox()
		end

	Id: [String] A string that uniquely identifies this combo box within the context of the active window.
	Options: [Table] List of options that control how this combo box behaves.
		Tooltip: [String] Text that is rendered when the user hovers over this combo box.
		Selected: [String] Text that is displayed in the non-editable input box for this combo box.
		W: [Number] The width of the combo box. The default value is 150.0.
		Rounding: [Number] Amount of rounding to apply to the corners of the combo box.

	Return: [Boolean] This function will return true if the combo box is open.
--]]
function Slab.BeginComboBox(Id, Options)
	return ComboBox.Begin(Id, Options)
end

--[[
	EndComboBox

	Finishes up any BeginComboBox calls if those functions return true.

	Return: None.
--]]
function Slab.EndComboBox()
	ComboBox.End()
end

--[[
	Image

	Draws an image at the current cursor position. The Id uniquely identifies this
	image to manage behaviors with this image. An image can be supplied through the
	options or a path can be specified which Slab will manage the loading and storing of
	the image reference.

	Id: [String] A string uniquely identifying this image within the context of the current window.
	Options: [Table] List of options controlling how the image should be drawn.
		Image: [Object] A user supplied image. This must be a valid Love image or the call will assert.
		Path: [String] If the Image option is nil, then a path must be specified. Slab will load and
			manage the image resource.
		Rotation: [Number] The rotation value to apply when this image is drawn.
		Scale: [Number] The scale value to apply to both the X and Y axis.
		ScaleX: [Number] The scale value to apply to the X axis.
		ScaleY: [Number] The scale value to apply to the Y axis.
		Color: [Table] The color to use when rendering this image.
		ReturnOnHover: [Boolean] Returns true when the mouse is hovered over the image.
		ReturnOnClick: [Boolean] Returns true when the mouse is released over the image.
		SubX: [Number] The X-coordinate used inside the given image.
		SubY: [Number] The Y-coordinate used inside the given image.
		SubW: [Number] The width used inside the given image.
		SubH: [Number] The height used insided the given image.
		WrapX: [String] The horizontal wrapping mode for this image. The available options are 'clamp', 'repeat', 
			'mirroredrepeat', and 'clampzero'. For more information refer to the Love2D documentation on wrap modes at
			https://love2d.org/wiki/WrapMode.
		WrapY: [String] The vertical wrapping mode for this image. The available options are 'clamp', 'repeat', 
			'mirroredrepeat', and 'clampzero'. For more information refer to the Love2D documentation on wrap modes at
			https://love2d.org/wiki/WrapMode.

	Return: [Boolean] Returns true if the mouse is hovering over the image or clicking on the image based on
		ReturnOnHover or ReturnOnClick options.
--]]
function Slab.Image(Id, Options)
	return Image.Begin(Id, Options)
end

--[[
	SameLine

	This forces the cursor to move back up to the same line as the previous widget. By default, all Slab widgets will
	advance the cursor to the next line based on the height of the current line. By using this call with other widget
	calls, the user will be able to set up multiple widgets on the same line to control how a window may look.

	Options: [Table] List of options that controls how the cursor should handle the same line.
		Pad: [Number] Extra padding to apply in the X direction.
		CenterY: [Boolean] Controls whether the cursor should be centered in the Y direction on the line. By default
			the line will use the NewLineSize, which is the height of the current font to center the cursor.

	Return: None.
--]]
function Slab.SameLine(Options)
	Cursor.SameLine(Options)
end

--[[
	NewLine

	This forces the cursor to advance to the next line based on the height of the current font.

	Return: None.
--]]
function Slab.NewLine()
	Cursor.NewLine()
end

--[[
	SetCursorPos

	Sets the cursor position. The default behavior is to set the cursor position relative to
	the current window. The absolute position can be set if the 'Absolute' option is set.

	Controls will only be drawn within a window. If the cursor is set outside of the current
	window context, the control will not be displayed.

	X: [Number] The X coordinate to place the cursor. If nil, then the X coordinate is not modified.
	Y: [Number] The Y coordinate to place the cursor. If nil, then the Y coordinate is not modified.
	Options: [Table] List of options that control how the cursor position should be set.
		Absolute: [Boolean] If true, will place the cursor using absolute coordinates.

	Return: None.
--]]
function Slab.SetCursorPos(X, Y, Options)
	Options = Options == nil and {} or Options
	Options.Absolute = Options.Absolute == nil and false or Options.Absolute

	if Options.Absolute then
		X = X == nil and Cursor.GetX() or X
		Y = Y == nil and Cursor.GetY() or Y
		Cursor.SetPosition(X, Y)
	else
		X = X == nil and Cursor.GetX() - Cursor.GetAnchorX() or X
		Y = Y == nil and Cursor.GetY() - Cursor.GetAnchorY() or Y
		Cursor.SetRelativePosition(X, Y)
	end
end

--[[
	GetCursorPos

	Gets the cursor position. The default behavior is to get the cursor position relative to
	the current window. The absolute position can be retrieved if the 'Absolute' option is set.

	Options: [Table] List of options that control how the cursor position should be retrieved.
		Absolute: [Boolean] If true, will return the cursor position in absolute coordinates.

	Return: [Number], [Number] The X and Y coordinates of the cursor.
--]]
function Slab.GetCursorPos(Options)
	Options = Options == nil and {} or Options
	Options.Absolute = Options.Absolute == nil and false or Options.Absolute

	local X, Y = Cursor.GetPosition()

	if not Options.Absolute then
		X = X - Cursor.GetAnchorX()
		Y = Y - Cursor.GetAnchorY()
	end

	return X, Y
end

--[[
	Properties

	Iterates through the table's key-value pairs and adds them to the active window. This currently only does
	a shallow loop and will not iterate through nested tables.

	TODO: Iterate through nested tables.

	Table: [Table] The list of properties to build widgets for.

	Return: None.
--]]
function Slab.Properties(Table)
	if Table ~= nil then
		for K, V in pairs(Table) do
			local Type = type(V)
			if Type == "boolean" then
				if Slab.CheckBox(V, K) then
					Table[K] = not Table[K]
				end
			elseif Type == "number" then
				Slab.Text(K .. ": ")
				Slab.SameLine()
				if Slab.Input(K, {Text = tostring(V), NumbersOnly = true, ReturnOnText = false}) then
					Table[K] = Slab.GetInputNumber()
				end
			elseif Type == "string" then
				Slab.Text(K .. ": ")
				Slab.SameLine()
				if Slab.Input(K, {Text = V, ReturnOnText = false}) then
					Table[K] = Slab.GetInputText()
				end
			end
		end
	end
end

--[[
	BeginListBox

	Begins the process of creating a list box. If this function is called, EndListBox must be called after all
	items have been added.

	Id: [String] A string uniquely identifying this list box within the context of the current window.
	Options: [Table] List of options controlling the behavior of the list box.
		W: [Number] The width of the list box. If nil, then the width of the window is used.
		H: [Number] The height of the list box. If nil, a default value of 150 is used. If H is 0, then
			the list box will stretch to the height of the window.
		Clear: [Boolean] Clears out the items in the list. It is recommended to only call this if the list items
			has changed and should not be set to true on every frame.
		Rounding: [Number] Amount of rounding to apply to the corners of the list box.

	Return: None.
--]]
function Slab.BeginListBox(Id, Options)
	ListBox.Begin(Id, Options)
end

--[[
	EndListBox

	Ends the list box container. Will close off the region and properly adjust the cursor.

	Return: None.
--]]
function Slab.EndListBox()
	ListBox.End()
end

--[[
	BeginListBoxItem

	Adds an item to the current list box with the given Id. The user can then draw controls however they see
	fit to display a single item. This allows the user to draw list items such as a texture with a name or just
	a text to represent the item. If this is called, EndListBoxItem must be called to complete the item.

	Id: [String] A string uniquely identifying this item within the context of the current list box.
	Options: [Table] List of options that control the behavior of the active list item.
		Selected: [Boolean] If true, will draw the item with a selection background.

	Return: None.
--]]
function Slab.BeginListBoxItem(Id, Options)
	ListBox.BeginItem(Id, Options)
end

--[[
	IsListBoxItemClicked

	Checks to see if a hot list item is clicked. This should only be called within a BeginListBoxLitem/EndListBoxItem
	block.

	Button: [Number] The button to check for the click of the item.
	IsDoubleClick: [Boolean] Check for double-click instead of single click.

	Return: [Boolean] Returns true if the active item is hovered with mouse and the requested mouse button is clicked.
--]]
function Slab.IsListBoxItemClicked(Button, IsDoubleClick)
	return ListBox.IsItemClicked(Button, IsDoubleClick)
end

--[[
	EndListBoxItem

	Ends the current item and commits the bounds of the item to the list.

	Return: None.
--]]
function Slab.EndListBoxItem()
	ListBox.EndItem()
end

--[[
	OpenDialog

	Opens the dialog box with the given Id. If the dialog box was opened, then it is pushed onto the stack.
	Calls to the BeginDialog with this same Id will return true if opened.

	Id: [String] A string uniquely identifying this dialog box.

	Return: None.
--]]
function Slab.OpenDialog(Id)
	Dialog.Open(Id)
end

--[[
	BeginDialog

	Begins the dialog window with the given Id if it is open. If this function returns true, then EndDialog must be called.
	Dialog boxes are windows which are centered in the center of the viewport. The dialog box cannot be moved and will
	capture all input from all other windows.

	Id: [String] A string uniquely identifying this dialog box.
	Options: [Table] List of options that control how this dialog box behaves. These are the same parameters found
		for BeginWindow, with some caveats. Certain options are overridden by the Dialog system. They are:
			X, Y, Layer, AllowFocus, AllowMove, and AutoSizeWindow.

	Return: [Boolean] Returns true if the dialog with the given Id is open.
--]]
function Slab.BeginDialog(Id, Options)
	return Dialog.Begin(Id, Options)
end

--[[
	EndDialog

	Ends the dialog window if a call to BeginDialog returns true.

	Return: None.
--]]
function Slab.EndDialog()
	Dialog.End()
end

--[[
	CloseDialog

	Closes the currently active dialog box.

	Return: None.
--]]
function Slab.CloseDialog()
	Dialog.Close()
end

--[[
	MessageBox

	Opens a message box to be displayed to the user with a title and a message. Buttons can be specified through the options
	table which when clicked, the string of the button is returned. This function should be called every frame when a message
	box wants to be displayed.

	Title: [String] The title to display for the message box.
	Message: [String] The message to be displayed. The text is aligned in the center. Multi-line strings are supported.
	Options: [Table] List of options to control the behavior of the message box.
		Buttons: [Table] List of buttons to display with the message box. The order of the buttons are displayed from right to left.

	Return: [String] The name of the button that was clicked. If none was clicked, an emtpy string is returned.
--]]
function Slab.MessageBox(Title, Message, Options)
	return Dialog.MessageBox(Title, Message, Options)
end

--[[
	FileDialog

	Opens up a dialog box that displays a file explorer for opening or saving files or directories. This function does not create any file
	handles, it just returns the list of files selected by the user.

	Options: [Table] List of options that control the behavior of the file dialog.
		AllowMultiSelect: [Boolean] Allows the user to select multiple items in the file dialog.
		Directory: [String] The starting directory when the file dialog is open. If none is specified, the dialog
			will start at love.filesystem.getSourceBaseDirectory and the dialog will remember the last
			directory navigated to by the user between calls to this function.
		Type: [String] The type of file dialog to use. The options are:
			openfile: This is the default method. The user will have access to both directories and files. However,
				only file selections are returned.
			opendirectory: This type is used to filter the file dialog for directories only. No files will appear
				in the list.
			savefile: This type is used to select a name of a file to save. The user will be prompted if they wish to overwrite
				an existing file.
		Filters: [Table] A list of filters the user can select from when browsing files. The table can contain tables or strings.
			Table: If a table is used for a filter, it should contain two elements. The first element is the filter while the second
				element is the description of the filter e.g. {"*.lua", "Lua Files"}
			String: If a raw string is used, then it should just be the filter. It is recommended to use the table option since a
				description can be given for each filter.

	Return: [Table] Returns items for how the user interacted with this file dialog.
		Button: [String] The button the user clicked. Will either be OK or Cancel.
		Files: [Table] An array of selected file items the user selected when OK is pressed. Will be empty otherwise.
--]]
function Slab.FileDialog(Options)
	return Dialog.FileDialog(Options)
end

--[[
	ColorPicker

	Displays a window to allow the user to pick a hue and saturation value of a color. This should be called every frame and the result
	should be handled to stop displaying the color picker and store the resulting color.

	Options: [Table] List of options that control the behavior of the color picker.
		Color: [Table] The color to modify. This should be in the format of 0-1 for each color component (RGBA).

	Return: [Table] Returns the button and color the user has selected.
		Button: [String] The button the user clicked. Will either be OK or Cancel.
		Color: [Table] The new color the user has chosen. This will always be returned.
--]]
function Slab.ColorPicker(Options)
	return ColorPicker.Begin(Options)
end

--[[
	IsMouseDown

	Determines if a given mouse button is down.

	Button: [Number] The button to check for. The valid numbers are: 1 - Left, 2 - Right, 3 - Middle.

	Return: [Boolean] True if the given button is down. False otherwise.
--]]
function Slab.IsMouseDown(Button)
	return Mouse.IsPressed(Button and Button or 1)
end

--[[
	IsMouseClicked

	Determines if a given mouse button changes state from up to down this frame.

	Button: [Number] The button to check for. The valid numbers are: 1 - Left, 2 - Right, 3 - Middle.

	Return: [Boolean] True if the given button changes state from up to down. False otherwise.
--]]
function Slab.IsMouseClicked(Button)
	return Mouse.IsClicked(Button and Button or 1)
end

--[[
	IsMouseReleased

	Determines if a given mouse button changes state from down to up this frame.

	Button: [Number] The button to check for. The valid numbers are: 1 - Left, 2 - Right, 3 - Middle.

	Return: [Boolean] True if the given button changes state from down to up. False otherwise.
--]]
function Slab.IsMouseReleased(Button)
	return Mouse.IsReleased(Button and Button or 1)
end

--[[
	IsMouseDoubleClicked

	Determines if a given mouse button has been clicked twice within a given time frame.

	Button: [Number] The button to check for. The valid numbers are: 1 - Left, 2 - Right, 3 - Middle.

	Return: [Boolean] True if the given button was double clicked. False otherwise.
--]]
function Slab.IsMouseDoubleClicked(Button)
	return Mouse.IsDoubleClicked(Button and Button or 1)
end

--[[
	IsMouseDragging

	Determines if a given mouse button is down and there has been movement.

	Button: [Number] The button to check for. The valid numbers are: 1 - Left, 2 - Right, 3 - Middle.

	Return: [Boolean] True if the button is held down and is moving. False otherwise.
--]]
function Slab.IsMouseDragging(Button)
	return Mouse.IsDragging(Button and Button or 1)
end

--[[
	GetMousePosition

	Retrieves the current mouse position in the viewport.

	Return: [Number], [Number] The X and Y coordinates of the mouse position.
--]]
function Slab.GetMousePosition()
	return Mouse.Position()
end

--[[
	GetMouseDelta

	Retrieves the change in mouse coordinates from the last frame.

	Return: [Number], [Number] The X and Y coordinates of the delta from the last frame.
--]]
function Slab.GetMouseDelta()
	return Mouse.GetDelta()
end

--[[
	IsControlHovered

	Checks to see if the last control added to the window is hovered by the mouse.

	Return: [Boolean] True if the last control is hovered, false otherwise.
--]]
function Slab.IsControlHovered()
	return Window.IsItemHot()
end

--[[
	IsControlClicked

	Checks to see if the previous control is hovered and clicked.

	Button: [Number] The button to check for. The valid numbers are: 1 - Left, 2 - Right, 3 - Middle.

	Return: [Boolean] True if the previous control is hovered and clicked. False otherwise.
--]]
function Slab.IsControlClicked(Button)
	return Slab.IsControlHovered() and Slab.IsMouseClicked(Button)
end

--[[
	IsVoidHovered

	Checks to see if any non-Slab area of the viewport is hovered.

	Return: [Boolean] True if any non-Slab area of the viewport is hovered. False otherwise.
--]]
function Slab.IsVoidHovered()
	return Region.GetHotInstanceId() == '' and not Region.IsScrolling()
end

--[[
	IsVoidClicked

	Checks to see if any non-Slab area of the viewport is clicked.

	Button: [Number] The button to check for. The valid numbers are: 1 - Left, 2 - Right, 3 - Middle.

	Return: [Boolean] True if any non-Slab area of the viewport is clicked. False otherwise.
--]]
function Slab.IsVoidClicked(Button)
	return Slab.IsMouseClicked(Button) and Slab.IsVoidHovered()
end

--[[
	IsKeyDown

	Checks to see if a specific key is held down. The key should be one of the love defined KeyConstant which the list can
	be found at https://love2d.org/wiki/KeyConstant.

	Key: [String] A love defined key constant.

	Return: [Boolean] True if the key is held down. False otherwise.
--]]
function Slab.IsKeyDown(Key)
	return Keyboard.IsDown(Key)
end

--[[
	IsKeyPressed

	Checks to see if a specific key state went from up to down this frame. The key should be one of the love defined KeyConstant which the list can
	be found at https://love2d.org/wiki/KeyConstant.

	Key: [String] A love defined key constant.

	Return: [Boolean] True if the key state went from up to down this frame. False otherwise.
--]]
function Slab.IsKeyPressed(Key)
	return Keyboard.IsPressed(Key, true)
end

--[[
	IsKeyPressed

	Checks to see if a specific key state went from down to up this frame. The key should be one of the love defined KeyConstant which the list can
	be found at https://love2d.org/wiki/KeyConstant.

	Key: [String] A love defined key constant.

	Return: [Boolean] True if the key state went from down to up this frame. False otherwise.
--]]
function Slab.IsKeyReleased(Key)
	return Keyboard.IsReleased(Key)
end

--[[
	Rectangle

	Draws a rectangle at the current cursor position for the active window.

	Options: [Table] List of options that control how this rectangle is displayed.
		Mode: [String] Whether this rectangle should be filled or outlines. The default value is 'fill'.
		W: [Number] The width of the rectangle.
		H: [Number] The height of the rectangle.
		Color: [Table] The color to use for this rectangle.
		Rounding: [Number] Amount of rounding to apply to each corner.
		Outline: [Boolean] If the Mode option is 'fill', this option will allow an outline to be drawn.
		OutlineColor: [Table] The color to use for the outline if requested.

	Return: None.
--]]
function Slab.Rectangle(Options)
	Shape.Rectangle(Options)
end

return Slab
