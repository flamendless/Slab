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

if SLAB_PATH == nil then
	SLAB_PATH = (...):match("(.-)[^%.]+$")
end

SLAB_FILE_PATH = debug.getinfo(1, 'S').source:match("^@(.+)/")
SLAB_FILE_PATH = SLAB_FILE_PATH == nil and "" or SLAB_FILE_PATH
local StatsData = {}
local PrevStatsData = {}

local Button = require(SLAB_PATH .. '.Internal.UI.Button')
local CheckBox = require(SLAB_PATH .. '.Internal.UI.CheckBox')
local ColorPicker = require(SLAB_PATH .. '.Internal.UI.ColorPicker')
local ComboBox = require(SLAB_PATH .. '.Internal.UI.ComboBox')
local Config = require(SLAB_PATH .. '.Internal.Core.Config')
local Cursor = require(SLAB_PATH .. '.Internal.Core.Cursor')
local Scale = require(SLAB_PATH .. ".Internal.Core.Scale")
local Dialog = require(SLAB_PATH .. '.Internal.UI.Dialog')
local Dock = require(SLAB_PATH .. '.Internal.UI.Dock')
local DrawCommands = require(SLAB_PATH .. '.Internal.Core.DrawCommands')
local FileSystem = require(SLAB_PATH .. '.Internal.Core.FileSystem')
local Image = require(SLAB_PATH .. '.Internal.UI.Image')
local Input = require(SLAB_PATH .. '.Internal.UI.Input')
local Keyboard = require(SLAB_PATH .. '.Internal.Input.Keyboard')
local LayoutManager = require(SLAB_PATH .. '.Internal.UI.LayoutManager')
local ListBox = require(SLAB_PATH .. '.Internal.UI.ListBox')
local Messages = require(SLAB_PATH .. '.Internal.Core.Messages')
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
local Utility = require(SLAB_PATH .. '.Internal.Core.Utility')
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

	Supported Version: 11.3.0

	API:
		Initialize
		GetVersion
		GetLoveVersion
		Update
		Draw
		SetINIStatePath
		GetINIStatePath
		SetVerbose
		GetMessages

		Style:
			GetStyle
			PushFont
			PopFont

		Window:
			BeginWindow
			EndWindow
			GetWindowPosition
			GetWindowSize
			GetWindowContentSize
			GetWindowActiveSize
			IsWindowAppearing
			PushID
			PopID

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
		GetTextSize
		GetTextWidth
		GetTextHeight
		CheckBox
		Input
		InputNumberDrag
		InputNumberSlider
		GetInputText
		GetInputNumber
		GetInputCursorPos
		IsInputFocused
		IsAnyInputFocused
		SetInputFocus
		SetInputCursorPos
		SetInputCursorPosLine
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
			Indent
			Unindent

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
			ColorPicker

		Mouse:
			IsMouseDown
			IsMouseClicked
			IsMouseReleased
			IsMouseDoubleClicked
			IsMouseDragging
			GetMousePosition
			GetMousePositionWindow
			GetMouseDelta
			SetCustomMouseCursor
			ClearCustomMouseCursor

		Control:
			IsControlHovered
			IsControlClicked
			GetControlSize
			IsVoidHovered
			IsVoidClicked

		Keyboard:
			IsKeyDown
			IsKeyPressed
			IsKeyReleased

		Shape:
			Rectangle
			Circle
			Triangle
			Line
			Curve
			GetCurveControlPointCount
			GetCurveControlPoint
			EvaluateCurve
			EvaluateCurveMouse
			Polygon

		Stats:
			BeginStat
			EndStat
			EnableStats
			IsStatsEnabled
			FlushStats

		Layout:
			BeginLayout
			EndLayout
			SetLayoutColumn
			GetLayoutSize

		Scroll:
			SetScrollSpeed
			GetScrollSpeed

		Shader:
			PushShader
			PopShader

		Dock:
			EnableDocks
			DisableDocks
			SetDockOptions
--]]
local Slab = {}

-- Slab version numbers.
local Version_Major = 0
local Version_Minor = 9
local Version_Revision = 0

local FrameStatHandle = nil

-- The path to save the UI state to a file. This will default to the save directory.
local INIStatePath = "Slab.ini"
local IsDefault = true
local QuitFn = nil
local Verbose = false
local Initialized = false
local DontInterceptEventHandlers = false


local ModifyCursor = true

local function LoadState()
	if INIStatePath == nil then return end

	local Result, Error = Config.LoadFile(INIStatePath, IsDefault)
	if Result ~= nil then
		Dock.Load(Result)
		Tree.Load(Result)
		Window.Load(Result)
	end

	if Verbose then
		print("Load INI file:", INIStatePath, "Error:", Error)
	end
end

local function SaveState()
	if INIStatePath == nil then return end

	local Table = {}
	Dock.Save(Table)
	Tree.Save(Table)
	Window.Save(Table)
	local Result, Error = Config.Save(INIStatePath, Table, IsDefault)

	if Verbose then
		print("Save INI file:", INIStatePath, "Error:", Error)
	end
end

local function TextInput(Ch)
	Input.Text(Ch)

	if (not DontInterceptEventHandlers) and love.textinput ~= nil then
		love.textinput(Ch)
	end
end

local function WheelMoved(X, Y)
	Window.WheelMoved(X, Y)

	if (not DontInterceptEventHandlers) and love.wheelmoved ~= nil then
		love.wheelmoved(X, Y)
	end
end

local function OnQuit()
	SaveState()

	if QuitFn ~= nil then
		QuitFn()
	end
end

--[[
	Event forwarding
--]]

Slab.OnTextInput = TextInput;
Slab.OnWheelMoved = WheelMoved;
Slab.OnQuit = OnQuit;
Slab.OnKeyPressed = Keyboard.OnKeyPressed;
Slab.OnKeyReleased = Keyboard.OnKeyReleased;
Slab.OnMouseMoved = Mouse.OnMouseMoved
Slab.OnMousePressed = Mouse.OnMousePressed;
Slab.OnMouseReleased = Mouse.OnMouseReleased;

--[[
	Initialize

	Initializes Slab and hooks into the required events. This function should be called in love.load.

	args: [Table] The list of parameters passed in by the user on the command-line. This should be passed in from
		love.load function. Below is a list of arguments available to modify Slab:
		NoMessages: [String] Disables the messaging system that warns developers of any changes in the API.
		NoDocks: [String] Disables all docks.
		NoCursor: [String] Disables modifying the cursor

	Return: None.
--]]
function Slab.Initialize(args, dontInterceptEventHandlers)
	if Initialized then
		return
	end

	DontInterceptEventHandlers = dontInterceptEventHandlers
	Style.API.Initialize()

	args = args or {}
	if type(args) == 'table' then
		for I, V in ipairs(args) do
			if string.lower(V) == 'nomessages' then
				Messages.SetEnabled(false)
			elseif string.lower(V) == 'nodocks' then
				Slab.DisableDocks({'Left', 'Right', 'Bottom'})
			elseif string.lower(V) == 'nocursor' then
				ModifyCursor = false
			end
		end
	end

	if not dontInterceptEventHandlers then
		love.handlers['textinput'] = TextInput
		love.handlers['wheelmoved'] = WheelMoved

		-- In Love 11.3, overriding love.handlers['quit'] doesn't seem to affect the callback during shutdown.
		-- Storing and overriding love.quit manually will properly call Slab's callback. This function will call
		-- the stored function once Slab is finished with its process.
		QuitFn = love.quit
		love.quit = OnQuit
	end

	Keyboard.Initialize(args, dontInterceptEventHandlers)
	Mouse.Initialize(args, dontInterceptEventHandlers)

	LoadState()

	Initialized = true
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
	Stats.Reset(false)
	FrameStatHandle = Stats.Begin('Frame', 'Slab')
	local StatHandle = Stats.Begin('Update', 'Slab')

	Mouse.Update()
	Keyboard.Update()
	Input.Update(dt)
	DrawCommands.Reset()
	Window.Reset()
	LayoutManager.Validate()

	if MenuState.IsOpened then
		MenuState.WasOpened = MenuState.IsOpened
		if Mouse.IsClicked(1) then
			MenuState.RequestClose = true
		end
	end

	Stats.End(StatHandle)
end

--[[
	Draw

	This function will execute all buffered draw calls from the various Slab calls made prior. This
	function should be called from love.draw and should be called at the very to ensure Slab is rendered
	above the user's workspace.

	Return: None.
--]]
function Slab.Draw()
	if Stats.IsEnabled() then
		PrevStatsData = love.graphics.getStats(PrevStatsData)
	end

	local StatHandle = Stats.Begin('Draw', 'Slab')

	Window.Validate()

	local MovingInstance = Window.GetMovingInstance()
	if MovingInstance ~= nil then
		Dock.DrawOverlay()
		Dock.SetPendingWindow(MovingInstance)
	else
		Dock.Commit()
	end

	if MenuState.RequestClose then
		Menu.Close()
		MenuBar.Clear()
	end

	if ModifyCursor then
		Mouse.Draw()
	end

	if Mouse.IsReleased(1) then
		Button.ClearClicked()
	end

	love.graphics.push()
	love.graphics.origin()
	DrawCommands.Execute()
	love.graphics.pop()

	Stats.End(StatHandle)

	-- Only call end if 'Update' was called and a valid handle was retrieved. This can happen for developers using a custom
	-- run function with a fixed update.
	if FrameStatHandle ~= nil then
		Stats.End(FrameStatHandle)
		FrameStatHandle = nil
	end

	if Stats.IsEnabled() then
		StatsData = love.graphics.getStats(StatsData)
		for k, v in pairs(StatsData) do
			StatsData[k] = v - PrevStatsData[k]
		end
	end
end

--[[
	SetINIStatePath

	Sets the INI path to save the UI state. If nil, Slab will not save the state to disk.

	Return: None.
--]]
function Slab.SetINIStatePath(Path)
	INIStatePath = Path
	IsDefault = false
end

--[[
	GetINIStatePath

	Gets the INI path to save the UI state. This value can be nil.

	Return: [String] The path on disk the UI state will be saved to.
--]]
function Slab.GetINIStatePath()
	return INIStatePath
end

--[[
	SetVerbose

	Enable/Disables internal Slab logging. Could be useful for diagnosing problems that occur inside of Slab.

	IsVerbose: [Boolean] Flag to enable/disable verbose logging.

	Return: None.
--]]
function Slab.SetVerbose(IsVerbose)
	Verbose = (IsVerbose == nil or type(IsVerbose) ~= 'boolean') and false or IsVerbose
end

--[[
	GetMessages

	Retrieves a list of existing messages that has been captured by Slab.

	Return: [Table] List of messages that have been broadcasted from Slab.
--]]
function Slab.GetMessages()
	return Messages.Get()
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
    SetScale

    Sets the rendering scale for the Slab context.

	scaleFactor: [number] The scale factor to use

	Return: None.
--]]
function Slab.SetScale(scaleFactor)
	Scale.SetScale(scaleFactor)
end


--[[
    GetScale

	Retrieve the scale of the current Slab context.

	Return: [number] The current scale.
--]]
function Slab.GetScale()
	return Scale.GetScale()
end


--[[
	PushFont

	Pushes a Love font object onto the font stack. All text rendering will use this font until PopFont is called.

	Font: [Object] The Love font object to use.

	Return: None.
--]]
function Slab.PushFont(Font)
	Style.API.PushFont(Font)
end

--[[
	PopFont

	Pops the last font from the stack.

	Return: None.
--]]
function Slab.PopFont()
	Style.API.PopFont()
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
		TitleH: [Number] The height of the title bar. By default, this will be the height of the current font set in the style. If no title is
			set, this is ignored.
		TitleAlignX: [String] Horizontal alignment of the title. The available options are 'left', 'center', and 'right'. The default is 'center'.
		TitleAlignY: [String] Vertical alignment of the title. The available options are 'top', 'center', and 'bottom'. The default is 'center'.
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
		IsOpen: [Boolean] Determines if the window is open. If this value exists within the options, a close button will appear in
			the corner of the window and is updated when this button is pressed to reflect the new open state of this window.
		NoSavedSettings: [Boolean] Flag to disable saving this window's settings to the state INI file.
		ConstrainPosition: [Boolean] Flag to constrain the position of the window to the bounds of the viewport.
		ShowMinimize: [Boolean] Flag to show a minimize button in the title bar of the window. Default is `true`.

	Return: [Boolean] The open state of this window. Useful for simplifying API calls by storing the result in a flag instead of a table.
		EndWindow must still be called regardless of the result for this value.
--]]
function Slab.BeginWindow(Id, Options)
	return Window.Begin(Id, Options)
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

	Retrieves the active window's active size minus the borders.

	Return: [Number], [Number] The width and height of the window's active bounds.
--]]
function Slab.GetWindowActiveSize()
	return Window.GetBorderlessSize()
end

--[[
	IsWindowAppearing

	Is the current window appearing this frame. This will return true if BeginWindow has
	not been called for a window over 2 or more frames.

	Return: [Boolean] True if the window is appearing this frame. False otherwise.
--]]
function Slab.IsWindowAppearing()
	return Window.IsAppearing()
end

--[[
	PushID

	Pushes a custom ID onto a stack. This allows developers to differentiate between similar controls such as
	text controls.

	ID: [String] The custom ID to add.

	Return: None.
--]]
function Slab.PushID(ID)
	assert(type(ID) == 'string', "'ID' parameter must be a string value.")

	Window.PushID(ID)
end

--[[
	PopID

	Pops the last custom ID from the stack.

	Return: None.
--]]
function Slab.PopID()
	Window.PopID()
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
	Options: [Table] List of options that control how this menu behaves.
		Enabled: [Boolean] Determines if this menu is enabled. This value is true by default. Disabled items are displayed but
			cannot be interacted with.

	Return: [Boolean] Returns true if the menu item is being hovered.
--]]
function Slab.BeginMenu(Label, Options)
	return Menu.BeginMenu(Label, Options)
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

	Button: [Number] The mouse button to use for opening up this context menu.

	Return: [Boolean] Returns true if the user right clicks on the previous item call. EndContextMenu must be called in order for
		this to function properly.
--]]
function Slab.BeginContextMenuItem(Button)
	return Menu.BeginContextMenu({IsItem = true, Button = Button})
end

--[[
	BeginContextMenuWindow

	Opens up a context menu based on if the user right clicks anywhere within the window. It is recommended to place this function at the end
	of a window's widget calls so that Slab can catch any BeginContextMenuItem calls before this call. If this function returns true,
	EndContextMenu must be called.

	Button: [Number] The mouse button to use for opening up this context menu.

	Return: [Boolean] Returns true if the user right clicks anywhere within the window. EndContextMenu must be called in order for this
		to function properly.
--]]
function Slab.BeginContextMenuWindow(Button)
	return Menu.BeginContextMenu({IsWindow = true, Button = Button})
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
	Options: [Table] List of options that control how this menu behaves.
		Enabled: [Boolean] Determines if this menu is enabled. This value is true by default. Disabled items are displayed but
			cannot be interacted with.
		Hint: [String] Show an input hint to the right of the menu item

	Return: [Boolean] Returns true if the user clicks on this menu item.
--]]
function Slab.MenuItem(Label, Options)
	return Menu.MenuItem(Label, Options)
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
	Options: [Table] List of options that control how this menu behaves.
		Enabled: [Boolean] Determines if this menu is enabled. This value is true by default. Disabled items are displayed but
			cannot be interacted with.

	Return: [Boolean] Returns true if the user clicks on this menu item.
--]]
function Slab.MenuItemChecked(Label, IsChecked, Options)
	return Menu.MenuItemChecked(Label, IsChecked, Options)
end

--[[
	Separator

	This functions renders a separator line in the window.

	Option: [Table] List of options for how this separator will be drawn.
		IncludeBorders: [Boolean] Whether to extend the separator to include the window borders. This is false by default.
		H: [Number] The height of the separator. This doesn't change the line thickness, rather, specifies the cursor advancement
			in the Y direction.
		Thickness: [Number] The thickness of the line rendered. The default value is 1.0.

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
		Rounding: [Number] Amount of rounding to apply to the corners of the button.
		Invisible: [Boolean] Don't render the button, but keep the behavior.
		W: [Number] Override the width of the button.
		H: [Number] Override the height of the button.
		Disabled: [Boolean] If true, the button is not interactable by the user.
		Image: [Table] A table of options used to draw an image instead of a text label. Refer to the 'Image' documentation for a list
			of available options.
		Color: [Table]: The background color of the button when idle. The default value is the ButtonColor property in the Style's table.
		HoverColor: [Table]: The background color of the button when a mouse is hovering the control. The default value is the ButtonHoveredColor property
			in the Style's table.
		PressColor: [Table]: The background color of the button when the button is pressed but not released. The default value is the ButtonPressedColor
			property in the Style's table.
		PadX: [Number] Amount of additional horizontal space the background will expand to from the center. The default value is 20.
		PadY: [Number] Amount of additional vertical space the background will expand to from the center. The default value is 5.
		VLines: [Number] Number of lines in a multiline button text. The default value is 1.

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
		PadH: [Number] How far to pad the text vertically, will render centered in this region
		IsSelectable: [Boolean] Whether this text is selectable using the text's Y position and the window X and width as the
			hot zone.
		IsSelectableTextOnly: [Boolean] Will use the text width instead of the window width to determine the hot zone. Will set IsSelectable
			to true if that option is missing.
		IsSelected: [Boolean] Forces the hover background to be rendered.
		SelectOnHover: [Boolean] Returns true if the user is hovering over the hot zone of this text.
		HoverColor: [Table] The color to render the background if the IsSelected option is true.
		URL: [String] A URL address to open when this text control is clicked.

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
	GetTextSize

	Retrieves the width and height of the given text. The result is based on the current font.

	Label: [String] The string to retrieve the size for.

	Return: [Number], [Number] The width and height of the given text.
--]]
function Slab.GetTextSize(Label)
	return Text.GetSize(Label)
end

--[[
	GetTextWidth

	Retrieves the width of the given text. The result is based on the current font.

	Label: [String] The string to retrieve the width for.

	Return: [Number] The width of the given text.
--]]
function Slab.GetTextWidth(Label)
	local W, H = Slab.GetTextSize(Label)
	return W
end

--[[
	GetTextHeight

	Retrieves the height of the current font.

	Return: [Number] The height of the current font.
--]]
function Slab.GetTextHeight()
	return Text.GetHeight()
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
		Size: [Number] The uniform size of the box. The default value is 16.
		Disabled: [Boolean] Dictates whether this check box is enabled for interaction.

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
		TextColor: [Table] The color to use for the text. The default color is the color used for text, but there is also
			a default multiline text color defined in the Style.
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
		Highlight: [Table] A list of key-values that define what words to highlight what color. Strings should be used for
			the word to highlight and the value should be a table defining the color.
		Step: [Number] The step amount for numeric controls when the user click and drags. The default value is 1.0.
		NoDrag: [Boolean] Determines whether this numberic control allows the user to click and drag to alter the value.
		UseSlider: [Boolean] If enabled, displays a slider inside the input control. This will only be drawn if the NumbersOnly
			option is set to true. The position of the slider inside the control determines the value based on the MinNumber
			and MaxNumber option.
		IsPassword: [Boolean] If enabled, mask the text with another character. Default is false.
		PasswordChar: [Char/String] Sets the character or string to use along with IsPassword flag. Default is "*"

	Return: [Boolean] Returns true if the user has pressed the return key while focused on this input box. If ReturnOnText
		is set to true, then this function will return true whenever the user has input any character into the input box.
--]]
function Slab.Input(Id, Options)
	return Input.Begin(Id, Options)
end

--[[
	InputNumberDrag

	This is a wrapper function for calling the Input function which sets the proper options to set up the input box for
	displaying and editing numbers. The user will be able to click and drag the control to alter the value. Double-clicking
	inside this control will allow for manually editing the value.

	Id: [String] A string that uniquely identifies this Input within the context of the window.
	Value: [Number] The value to display in the control.
	Min: [Number] The minimum value that can be set for this number control. If nil, then this value will be set to -math.huge.
	Max: [Number] The maximum value that can be set for this number control. If nil, then this value will be set to math.huge.
	Step: [Number] The amount to increase value when mouse delta reaches threshold.
	Options: [Table] List of options for how this input control is displayed. See Slab.Input for all options.

	Return: [Boolean] Returns true whenever this valued is modified.
--]]
function Slab.InputNumberDrag(Id, Value, Min, Max, Step, Options)
	Options = Options == nil and {} or Options
	Options.Text = tostring(Value)
	Options.MinNumber = Min
	Options.MaxNumber = Max
	Options.Step = Step
	Options.NumbersOnly = true
	Options.UseSlider = false
	Options.NoDrag = false
	return Slab.Input(Id, Options)
end

--[[
	InputNumberSlider

	This is a wrapper function for calling the Input function which sets the proper options to set up the input box for
	displaying and editing numbers. This will also force the control to display a slider, which determines what the value
	stored is based on the Min and Max options. Double-clicking inside this control will allow for manually editing
	the value.

	Id: [String] A string that uniquely identifies this Input within the context of the window.
	Value: [Number] The value to display in the control.
	Min: [Number] The minimum value that can be set for this number control. If nil, then this value will be set to -math.huge.
	Max: [Number] The maximum value that can be set for this number control. If nil, then this value will be set to math.huge.
	Options: [Table] List of options for how this input control is displayed. See Slab.Input for all options.
		Precision: [Number] An integer in the range [0..5]. This will set the size of the fractional component.
		NeedDrag: [Boolean] This will determine if slider needs to be dragged before changing value, otherwise just clicking in the slider will adjust the value into the clicked value. Default is true.

	Return: [Boolean] Returns true whenever this valued is modified.
--]]
function Slab.InputNumberSlider(Id, Value, Min, Max, Options)
	Options = Options == nil and {} or Options
	Options.Text = tostring(Value)
	Options.MinNumber = Min
	Options.MaxNumber = Max
	Options.NumbersOnly = true
	Options.UseSlider = true
	return Slab.Input(Id, Options)
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
	GetInputCursorPos

	Retrieves the position of the input cursor for the focused input control. There are three values that are returned. The first one
	is the absolute position of the cursor with regards to the text for the control. The second is the column position of the cursor
	on the current line. The final value is the line number. The column will match the absolute position if the input control is not
	multi line.

	Return: [Number], [Number], [Number] The absolute position of the cursor, the column position of the cursor on the current line,
		and the line number of the cursor. These values will all be zero if no input control is focused.
--]]
function Slab.GetInputCursorPos()
	return Input.GetCursorPos()
end

--[[
	IsInputFocused

	Returns whether the input control with the given Id is focused or not.

	Id: [String] The Id of the input control to check.

	Return: [Boolean] True if the input control with the given Id is focused. False otherwise.
--]]
function Slab.IsInputFocused(Id)
	return Input.IsFocused(Id)
end

--[[
	IsAnyInputFocused

	Returns whether any input control is focused or not.

	Return: [Boolean] True if there is an input control focused. False otherwise.
--]]
function Slab.IsAnyInputFocused()
	return Input.IsAnyFocused()
end

--[[
	SetInputFocus

	Sets the focus of the input control to the control with the given Id. The focus is set at the beginning
	of the next frame to avoid any input events from the current frame.

	Id: [String] The Id of the input control to focus.
--]]
function Slab.SetInputFocus(Id)
	Input.SetFocused(Id)
end

--[[
	SetInputCursorPos

	Sets the absolute text position in bytes of the focused input control. This value is applied on the next frame.
	This function can be combined with the SetInputFocus function to modify the cursor positioning of the desired
	input control. Note that the input control supports UTF8 characters so if the desired position is not a valid
	character, the position will be altered to find the next closest valid character.

	Pos: [Number] The absolute position in bytes of the text of the focused input control.
--]]
function Slab.SetInputCursorPos(Pos)
	Input.SetCursorPos(Pos)
end

--[[
	SetInputCursorPosLine

	Sets the column and line number of the focused input control. These values are applied on the next frame. This
	function behaves the same as SetInputCursorPos, but allows for setting the cursor by column and line.

	Column: [Number] The text position in bytes of the current line.
	Line: [Number] The line number to set.
--]]
function Slab.SetInputCursorPosLine(Column, Line)
	Input.SetCursorPosLine(Column, Line)
end

--[[
	BeginTree

	This function will render a tree item with an optional label. The tree can be expanded or collapsed based on whether
	the user clicked on the tree item. This function can also be nested to create a hierarchy of tree items. This function
	will return false when collapsed and true when expanded. If this function returns true, Slab.EndTree must be called in
	order for this tree item to behave properly. The hot zone of this tree item will be the height of the label and the width
	of the window by default.

	Id: [String/Table] A string or table uniquely identifying this tree item within the context of the window. If the given Id
		is a table, then the internal Tree entry for this table will be removed once the table has been garbage collected.
	Options: [Table] List of options for how this tree item will behave.
		Label: [String] The text to be rendered for this tree item.
		Tooltip: [String] The text to be rendered when the user hovers over this tree item.
		IsLeaf: [Boolean] If this is true, this tree item will not be expandable/collapsable.
		OpenWithHighlight: [Boolean] If this is true, the tree will be expanded/collapsed when the user hovers over the hot
			zone of this tree item. If this is false, the user must click the expand/collapse icon to interact with this tree
			item.
		Icon: [Table] List of options to use for drawing the icon. Refer to the 'Image' documentation for more information.
		IsSelected: [Boolean] If true, will render a highlight rectangle around the tree item.
		IsOpen: [Boolean] Will force the tree item to be expanded.
		NoSavedSettings: [Boolean] Flag to disable saving this tree's settings to the state INI file.

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
		UseOutline: [Boolean] If set to true, a rectangle will be drawn around the given image. If 'SubW' or 'SubH' are specified, these
			values will be used instead of the image's dimensions.
		OutlineColor: [Table] The color used to draw the outline. Default color is black.
		OutlineW: [Number] The width used for the outline. Default value is 1.
		W: [Number] The width the image should be resized to.
		H: [Number] The height the image should be resized to.

	Return: None.
--]]
function Slab.Image(Id, Options)
	Image.Begin(Id, Options)
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
	LayoutManager.SameLine(Options)
end

--[[
	NewLine

	This forces the cursor to advance to the next line based on the height of the current font.

	Count: [Number] Specify how many new lines to insert, defaults to 1

	Return: None.
--]]
function Slab.NewLine(Count)
	Count = Count or 1
	for i = 1, Count do
		LayoutManager.NewLine()
	end
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
	Indent

	Advances the anchored X position of the cursor. All subsequent lines will begin at the new cursor position. This function
	has no effect when columns are present.

	Width: [Number] How far in pixels to advance the cursor. If nil, then the default value identified by the 'Indent'
		property in the current style is used.

	Return: None.
--]]
function Slab.Indent(Width)
	Width = Width == nil and Style.Indent or Width
	Cursor.Indent(Width)
end

--[[
	Unindent

	Retreats the anchored X position of the cursor. All subsequent lines will begin at the new cursor position. This function
	has no effect when columns are present.

	Width: [Number] How far in pixels to retreat the cursor. If nil, then the default value identified by the 'Indent'
		property in the current style is used.

	Return: None.
--]]
function Slab.Unindent(Width)
	Width = Width == nil and Style.Indent or Width
	Cursor.Unindent(Width)
end

--[[
	Properties

	Iterates through the table's key-value pairs and adds them to the active window. This currently only does
	a shallow loop and will not iterate through nested tables.

	TODO: Iterate through nested tables.

	Table: [Table] The list of properties to build widgets for.
	Options: [Table] List of options that can applied to a specific property. The key should match an entry in the
		'Table' argument and will apply any additional options to the property control.
	Fallback: [Table] List of options that can be applied to any property if an entry was not found in the 'Options'
		argument.

	Return: None.
--]]
function Slab.Properties(Table, Options, Fallback)
	Options = Options or {}
	Fallback = Fallback or {}

	if Table ~= nil then
		for I, T in ipairs(Table) do
			local V = T.Value
			local Type = type(V)
			local ID = T.ID
			local ItemOptions = Options[ID] or Fallback
			if Type == "boolean" then
				if Slab.CheckBox(V, ID, ItemOptions) then
					T.Value = not T.Value
				end
			elseif Type == "number" then
				Slab.Text(ID .. ": ")
				Slab.SameLine()
				ItemOptions.Text = V
				ItemOptions.NumbersOnly = true
				ItemOptions.ReturnOnText = false
				ItemOptions.UseSlider = ItemOptions.MinNumber and ItemOptions.MaxNumber
				if Slab.Input(ID, ItemOptions) then
					T.Value = Slab.GetInputNumber()
				end
			elseif Type == "string" then
				Slab.Text(ID .. ": ")
				Slab.SameLine()
				ItemOptions.Text = V
				ItemOptions.NumbersOnly = false
				ItemOptions.ReturnOnText = false
				if Slab.Input(ID, ItemOptions) then
					T.Value = Slab.GetInputText()
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
		W: [Number] The width of the list box. If nil, a default value of 150 is used.
		H: [Number] The height of the list box. If nil, a default value of 150 is used.
		Clear: [Boolean] Clears out the items in the list. It is recommended to only call this if the list items
			has changed and should not be set to true on every frame.
		Rounding: [Number] Amount of rounding to apply to the corners of the list box.
		StretchW: [Boolean] Stretch the list box to fill the remaining width of the window.
		StretchH: [Boolean] Stretch the list box to fill the remaining height of the window.

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
		IncludeParent: [Boolean] This option will include the parent '..' directory item in the file/dialog list. This option is
			true by default.

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
		Button: [Number] The button the user clicked. 1 - OK. 0 - No Interaction. -1 - Cancel.
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
	return Mouse.IsDown(Button and Button or 1)
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
	GetMousePositionWindow

	Retrieves the current mouse position within the current window. This position will include any transformations
	added to the window such as scrolling.

	Return: [Number], [Number] The X and Y coordinates of the mouse position within the window.
--]]
function Slab.GetMousePositionWindow()
	return Window.GetMousePosition()
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
	SetCustomMouseCursor

	Overrides a system mouse cursor of the given type to render a custom image instead.

	Type: [String] The system cursor type to replace. This can be one of the following values: 'arrow', 'sizewe', 'sizens', 'sizenesw', 'sizenwse', 'ibeam', 'hand'.
	Image: [Table] An 'Image' object created from love.graphics.newImage. If this is nil, then an empty image is created and is drawn when the system cursor is activated.
	Quad: [Table] A 'Quad' object created from love.graphics.newQuad. This allows support for setting UVs of an image to render.
--]]
function Slab.SetCustomMouseCursor(Type, Image, Quad)
	Mouse.SetCustomCursor(Type, Image, Quad)
end

--[[
	ClearCustomMouseCursor

	Removes any override of a system mouse cursor with the given type and defaults to the OS specific mouse cursor.

	Type: [String] The system cursor type to remove. This can be one of the following values: 'arrow', 'sizewe', 'sizens', 'sizenesw', 'sizenwse', 'ibeam', 'hand'.
--]]
function Slab.ClearCustomMouseCursor(Type)
	Mouse.ClearCustomCursor(Type)
end

--[[
	IsControlHovered

	Checks to see if the last control added to the window is hovered by the mouse.

	Return: [Boolean] True if the last control is hovered, false otherwise.
--]]
function Slab.IsControlHovered()
	-- Prevent hovered checks on mobile if user is not dragging a touch.
	if Utility.IsMobile() and not Slab.IsMouseDown() then
		return false
	end

	local Result = Window.IsItemHot()

	if not Result and not Window.IsObstructedAtMouse() then
		local X, Y = Slab.GetMousePositionWindow()
		Result = Cursor.IsInItemBounds(X, Y)
	end

	return Result
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
	GetControlSize

	Retrieves the last declared control's size.

	Return: [Number], [Number] The width and height of the last control declared.
--]]
function Slab.GetControlSize()
	local X, Y, W, H = Cursor.GetItemBounds()
	return W, H
end

--[[
	IsVoidHovered

	Checks to see if any non-Slab area of the viewport is hovered.

	Return: [Boolean] True if any non-Slab area of the viewport is hovered. False otherwise.
--]]
function Slab.IsVoidHovered()
	-- Prevent hovered checks on mobile if user is not dragging a touch.
	if Utility.IsMobile() and not Slab.IsMouseDown() then
		return false
	end

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

	Checks to see if a specific key is held down. The key should be one of the love defined Scancode which the list can
	be found at https://love2d.org/wiki/Scancode.

	Key: [String] A love defined key scancode.

	Return: [Boolean] True if the key is held down. False otherwise.
--]]
function Slab.IsKeyDown(Key)
	return Keyboard.IsDown(Key)
end

--[[
	IsKeyPressed

	Checks to see if a specific key state went from up to down this frame. The key should be one of the love defined Scancode which the list can
	be found at https://love2d.org/wiki/Scancode.

	Key: [String] A love defined scancode.

	Return: [Boolean] True if the key state went from up to down this frame. False otherwise.
--]]
function Slab.IsKeyPressed(Key)
	return Keyboard.IsPressed(Key)
end

--[[
	IsKeyPressed

	Checks to see if a specific key state went from down to up this frame. The key should be one of the love defined Scancode which the list can
	be found at https://love2d.org/wiki/Scancode.

	Key: [String] A love defined scancode.

	Return: [Boolean] True if the key state went from down to up this frame. False otherwise.
--]]
function Slab.IsKeyReleased(Key)
	return Keyboard.IsReleased(Key)
end

--[[
	Rectangle

	Draws a rectangle at the current cursor position for the active window.

	Options: [Table] List of options that control how this rectangle is displayed.
		Mode: [String] Whether this rectangle should be filled or outlined. The default value is 'fill'.
		W: [Number] The width of the rectangle.
		H: [Number] The height of the rectangle.
		Color: [Table] The color to use for this rectangle.
		Rounding: [Number] or [Table]
			[Number] Amount of rounding to apply to all corners.
			[Table] Define the rounding for each corner. The order goes top left, top right, bottom right, and bottom left.
		Outline: [Boolean] If the Mode option is 'fill', this option will allow an outline to be drawn.
		OutlineColor: [Table] The color to use for the outline if requested.
		Segments: [Number] Number of points to add for each corner if rounding is requested.

	Return: None.
--]]
function Slab.Rectangle(Options)
	Shape.Rectangle(Options)
end

--[[
	Circle

	Draws a circle at the current cursor position plus the radius for the active window.

	Options: [Table] List of options that control how this circle is displayed.
		Mode: [String] Whether this circle should be filled or outlined. The default value is 'fill'.
		Radius: [Number] The size of the circle.
		Color: [Table] The color to use for the circle.
		Segments: [Number] The number of segments used for drawing the circle.

	Return: None.
--]]
function Slab.Circle(Options)
	Shape.Circle(Options)
end

--[[
	Triangle

	Draws a triangle at the current cursor position plus the radius for the active window.

	Option: [Table] List of options that control how this triangle is displayed.
		Mode: [String] Whether this triangle should be filled or outlined. The default value is 'fill'.
		Radius: [Number] The distance from the center of the triangle.
		Rotation: [Number] The rotation of the triangle in degrees.
		Color: [Table] The color to use for the triangle.

	Return: None.
--]]
function Slab.Triangle(Options)
	Shape.Triangle(Options)
end

--[[
	Line

	Draws a line starting at the current cursor position and going to the defined points in this function.

	X2: [Number] The X coordinate for the destination.
	Y2: [Number] The Y coordinate for the destination.
	Option: [Table] List of options that control how this line is displayed.
		Width: [Number] How thick the line should be.
		Color: [Table] The color to use for the line.

	Return: None.
--]]
function Slab.Line(X2, Y2, Options)
	Shape.Line(X2, Y2, Options)
end

--[[
	Curve

	Draws a bezier curve with the given points as control points. The points should be defined in local space. Slab will translate the curve to the
	current cursor position. There should two or more points defined for a proper curve.

	Points: [Table] List of points to define the control points of the curve.
	Options: [Table] List of options that control how this curve is displayed.
		Color: [Table] The color to use for this curve.
		Depth: [Number] The number of recursive subdivision steps to use when rendering the curve. If nil, the default LÖVE 2D value is used which is 5.

	Return: None.
--]]
function Slab.Curve(Points, Options)
	Shape.Curve(Points, Options)
end

--[[
	GetCurveControlPointCount

	Returns the number of control points defined with the last call to Curve.

	Return: [Number] The number of control points defined for the previous curve.
--]]
function Slab.GetCurveControlPointCount()
	return Shape.GetCurveControlPointCount()
end

--[[
	GetCurveControlPoint

	Returns the point for the given control point index. This point by default will be in local space defined by the points given in the Curve function.
	The translated position can be requested by setting the LocalSpace option to false.

	Index: [Number] The index of the control point to retrieve.
	Options: [Table] A list of options that control what is returned by this function.
		LocalSpace: [Boolean] Returns either the translated or untranslated control point. This is true by default.

	Return: [Number], [Number] The translated X, Y coordinates of the given control point.
--]]
function Slab.GetCurveControlPoint(Index, Options)
	return Shape.GetCurveControlPoint(Index, Options)
end

--[[
	EvaluateCurve

	Returns the point at the given time. The time value should be between 0 and 1 inclusive. The point returned will be in local space. For the translated
	position, set the LocalSpace option to false.

	Time: [Number] The time on the curve between 0 and 1.
	Options: [Table] A list of options that control what is returned by this function.
		LocalSpace: [Boolean] Returnes either the translated or untranslated control point. This is true by default.

	Return: [Number], [Number] The X and Y coordinates at the given time on the curve.
--]]
function Slab.EvaluateCurve(Time, Options)
	return Shape.EvaluateCurve(Time, Options)
end

--[[
	EvaluateCurveMouse

	Returns the point on the curve at the given X-coordinate of the mouse relative to the end points of the curve.

	Options: [Table] A list of options that control what is returned by this function.
		Refer to the documentation for EvaluateCurve for the list of options.

	Return: [Number], [Number] The X and Y coordinates at the given X mouse position on the curve.
--]]
function Slab.EvaluateCurveMouse(Options)
	local X1, Y1 = Slab.GetCurveControlPoint(1, {LocalSpace = false})
	local X2, Y2 = Slab.GetCurveControlPoint(Slab.GetCurveControlPointCount(), {LocalSpace = false})
	local Left = math.min(X1, X2)
	local W = math.abs(X2 - X1)
	local X, Y = Slab.GetMousePositionWindow()
	local Offset = math.max(X - Left, 0.0)
	Offset = math.min(Offset, W)

	return Slab.EvaluateCurve(Offset / W, Options)
end

--[[
	Polygon

	Renders a polygon with the given points. The points should be defined in local space. Slab will translate the position to the current cursor position.

	Points: [Table] List of points that define this polygon.
	Options: [Table] List of options that control how this polygon is drawn.
		Color: [Table] The color to render this polygon.
		Mode: [String] Whether to use 'fill' or 'line' to draw this polygon. The default is 'fill'.

	Return: None.
--]]
function Slab.Polygon(Points, Options)
	Shape.Polygon(Points, Options)
end

--[[
	BeginStat

	Starts the timer for the specific stat in the given category.

	Name: [String] The name of the stat to capture.
	Category: [String] The category this stat belongs to.

	Return: [Number] The handle identifying this stat capture.
--]]
function Slab.BeginStat(Name, Category)
	return Stats.Begin(Name, Category)
end

--[[
	EndStat

	Ends the timer for the stat assigned to the given handle.

	Handle: [Number] The handle identifying a BeginStat call.

	Return: None.
--]]
function Slab.EndStat(Handle)
	Stats.End(Handle)
end

--[[
	EnableStats

	Sets the enabled state of the stats system. The system is disabled by default.

	Enable: [Boolean] The new state of the states system.

	Return: None.
--]]
function Slab.EnableStats(Enable)
	Stats.SetEnabled(Enable)
end

--[[
	IsStatsEnabled

	Query whether the stats system is enabled or disabled.

	Return: [Boolean] Returns whether the stats system is enabled or disabled.
--]]
function Slab.IsStatsEnabled()
	return Stats.IsEnabled()
end

--[[
	FlushStats

	Resets the stats system to an empty state.

	Return: None.
--]]
function Slab.FlushStats()
	Stats.Flush()
end

--[[
	GetStats

	Get the love.graphics.getStats of the Slab.
	Stats.SetEnabled(true) must be previously set to enable this.
	Must be called in love.draw (recommended at the end of draw)

	Return: Table.
--]]

function Slab.GetStats()
	return StatsData
end

--[[
	CalculateStats

	Calculate the passed love.graphics.getStats table of love by subtracting
	the stats of Slab.
	Stats.SetEnabled(true) must be previously set to enable this.
	Must be called in love.draw (recommended at the end of draw)

	Return: Table.
--]]

function Slab.CalculateStats(LoveStats)
	for k, v in pairs(LoveStats) do
		if StatsData[k] then
			LoveStats[k] = v - StatsData[k]
		end
	end
	return LoveStats
end

--[[
	BeginLayout

	Enables the layout manager and positions the controls between this call and EndLayout based on the given options. The anchor
	position for the layout is determined by the current cursor position on the Y axis. The horizontal position is not anchored.
	Layouts are stacked, so there can be layouts within parent layouts.

	Id: [String] The Id of this layout.
	Options: [Table] List of options that control how this layout behaves.
		AlignX: [String] Defines how the controls should be positioned horizontally in the window. The available options are
			'left', 'center', or 'right'. The default option is 'left'.
		AlignY: [String] Defines how the controls should be positioned vertically in the window. The available options are
			'top', 'center', or 'bottom'. The default option is 'top'. The top is determined by the current cursor position.
		AlignRowY: [String] Defines how the controls should be positioned vertically within a row. The available options are
			'top', 'center', or 'bottom'. The default option is 'top'.
		Ignore: [Boolean] Should this layout ignore positioning of controls. This is useful if certain controls need custom
			positioning within a layout.
		ExpandW: [Boolean] If true, will expand all controls' width within the row to the size of the window.
		ExpandH: [Boolean] If true, will expand all controls' height within the row and the size of the window.
		AnchorX: [Boolean] Anchors the layout management at the current X cursor position. The size is calculated using this position.
			The default value for this is false.
		AnchorY: [Boolean] Anchors the layout management at the current Y cursor position. The size is calculated using this position.
			The default value for this is true.
		Columns: [Number] The number of columns to use for this layout. The default value is 1.

	Return: None.
--]]
function Slab.BeginLayout(Id, Options)
	LayoutManager.Begin(Id, Options)
end

--[[
	EndLayout

	Ends the currently active layout. Each BeginLayout call must have a matching EndLayout. Failure to do so will result in
	an assertion.

	Return: None.
--]]
function Slab.EndLayout()
	LayoutManager.End()
end

--[[
	SetLayoutColumn

	Sets the current active column.

	Index: [Number] The index of the column to be active.

	Return: None.
--]]
function Slab.SetLayoutColumn(Index)
	LayoutManager.SetColumn(Index)
end

--[[
	GetLayoutSize

	Retrieves the size of the active layout. If there are columns, then the size of the column is returned.

	Return: [Number], [Number] The width and height of the active layout. 0 is returned if no layout is active.
--]]
function Slab.GetLayoutSize()
	return LayoutManager.GetActiveSize()
end

--[[
	GetCurrentColumnIndex

	Retrieves the current index of the active column.

	Return: [Number] The current index of the active column of the active layout. 0 is returned if no layout or column is active.
--]]
function Slab.GetCurrentColumnIndex()
	return LayoutManager.GetCurrentColumnIndex()
end

--[[
	SetScrollSpeed

	Sets the speed of scrolling when using the mouse wheel.

	Return: None.
--]]
function Slab.SetScrollSpeed(Speed)
	Region.SetWheelSpeed(Speed)
end

--[[
	GetScrollSpeed

	Retrieves the speed of scrolling for the mouse wheel.

	Return: [Number] The current wheel scroll speed.
--]]
function Slab.GetScrollSpeed()
	return Region.GetWheelSpeed()
end

--[[
	PushShader

	Pushes a shader effect to be applied to any following controls before a call to PopShader. Any shader effect that is still active
	will be cleared at the end of Slab's draw call.

	Shader: [Object] The shader object created with the love.graphics.newShader function. This object should be managed by the caller.

	Return: None.
--]]
function Slab.PushShader(Shader)
	DrawCommands.PushShader(Shader)
end

--[[
	PopShader

	Pops the currently active shader effect. Will enable the next active shader on the stack. If none exists, no shader is applied.

	Return: None.
--]]
function Slab.PopShader()
	DrawCommands.PopShader()
end

--[[
	EnableDocks

	Enables the docking functionality for a particular side of the viewport.

	List: [String/Table] A single item or list of items to enable for docking. The valid options are 'Left', 'Right', or 'Bottom'.

	Return: None.
--]]
function Slab.EnableDocks(List)
	Dock.Toggle(List, true)
end

--[[
	DisableDocks

	Disables the docking functionality for a particular side of the viewport.

	List: [String/Table] A single item or list of items to disable for docking. The valid options are 'Left', 'Right', or 'Bottom'.

	Return: None.
--]]
function Slab.DisableDocks(List)
	Dock.Toggle(List, false)
end

--[[
	SetDockOptions

	Set options for a dock type.

	Type: [String] The type of dock to set options for. This can be 'Left', 'Right', or 'Bottom'.
	Options: [Table] List of options that control how a dock behaves.
		NoSavedSettings: [Boolean] Flag to disable saving a dock's settings to the state INI file.
--]]
function Slab.SetDockOptions(Type, Options)
	Dock.SetOptions(Type, Options)
end

--[[
	WindowToDoc

	Programatically set a window to dock.

	Type: [String] The type of dock to set options for. This can be 'Left', 'Right', or 'Bottom'.
--]]
function Slab.WindowToDock(Type)
	Window.ToDock(Type)
end

--[[
	ToLoveFile

	Moves a file to a temporary location and returns a Love2D friendly way to access the file. The returned string can be used in
	any Love2D function that takes a Filename

	Source: [String] An absolute path to a file on the disk, can take a value from FileDialog

	Return: [String] A Love2D Filename
]]
function Slab.ToLoveFile(Source)
	return FileSystem.ToLove(Source)
end

return Slab
