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

local BasicWindow_Input = "This is some text!"
local BasicWindow_Input_Numbers = ""
local BasicWindow_CheckBox = false
local BasicWindow_Options = {"Apple", "Banana", "Orange", "Pear", "Lemon"}
local BasicWindow_Options_Selected = ""
local BasicWindow_Properties =
{
	X = 100.0,
	Y = 100.0,
	HasCollision = true,
	Name = "Player Name"
}
local BasicWindow_RadioButton = 1

local ResetLayout = false
local ListBoxIndex = 1
local SlabTest_MessageBox = false
local SlabTest_FileDialog = false
local SlabTest_FileDialogType = 'openfile'
local SlabTest_ColorPicker = false
local SlabTest_ColorPicker_Color = {1.0, 1.0, 1.0, 1.0}

function SlabTest.BasicWindow()
	Slab.BeginWindow('SlabTest_Basic', {Title = "Basic Window", X = 100.0, Y = 100.0, ResetLayout = ResetLayout})

	Slab.Text("Hello World!")

	if Slab.Button("Button!") then
		-- Perform logic here when button is clicked
	end

	if Slab.Button("Disabled!", {Disabled = true}) then
	end

	if Slab.BeginContextMenuItem() then
		Slab.MenuItem("Button Item 1")
		Slab.MenuItem("Button Item 2")

		Slab.EndContextMenu()
	end

	if Slab.Input('BasicWindow_Name', {Text = BasicWindow_Input}) then
		BasicWindow_Input = Slab.GetInputText()
	end

	if Slab.Input('BasicWindow_Numbers', {Text = BasicWindow_Input_Numbers, NumbersOnly = true}) then
		BasicWindow_Input_Numbers = Slab.GetInputText()
	end

	Slab.Separator()

	if Slab.CheckBox(BasicWindow_CheckBox, "Check Box") then
		BasicWindow_CheckBox = not BasicWindow_CheckBox
	end

	if Slab.BeginComboBox('BasicWindow_Fruits', {Selected = BasicWindow_Options_Selected}) then
		for K, V in pairs(BasicWindow_Options) do
			if Slab.TextSelectable(V) then
				BasicWindow_Options_Selected = V
			end
		end

		Slab.EndComboBox()
	end

	if Slab.BeginContextMenuWindow() then
		Slab.MenuItem("BasicWindow Item 1")
		Slab.MenuItem("BasicWindow Item 2")
		Slab.MenuItem("BasicWindow Item 3")

		Slab.EndContextMenu()
	end

	Slab.Properties(BasicWindow_Properties)

	for I = 1, 4, 1 do
		if Slab.RadioButton("Radio " .. I, {Index = I, SelectedIndex = BasicWindow_RadioButton}) then
			BasicWindow_RadioButton = I
		end
	end

	Slab.EndWindow()
end

function SlabTest.ResizableWindow()
	Slab.BeginWindow('SlabTest_Resizable', {Title = "Resizable Window", X = 350.0, Y = 100.0, AutoSizeWindow = false, ResetLayout = ResetLayout})
	Slab.Textf("This is a resizable window. This text will automatically wrap based on the window's dimensions.")
	Slab.NewLine()
	Slab.Textf("There is a new line separating these two texts.")
	Slab.EndWindow()
end

function SlabTest.TreeWindow()
	Slab.BeginWindow('SlabTest_Tree', {Title = "Tree Window", X = 600.0, Y = 100.0, AutoSizeWindow = false, ResetLayout = ResetLayout})
	
	if Slab.BeginTree('SlabTest_TreeRoot1', {Label = "Can be opened within rect", IconPath = SLAB_PATH .. "/Internal/Resources/Textures/Folder.png"}) then
		Slab.BeginTree('SlabTest_Child1_Leaf', {Label = "Leaf 1", IsLeaf = true})

		if Slab.BeginTree('SlabTest_Child1', {Label = "Child 1"}) then
			Slab.BeginTree('SlabTest_Child1_Leaf1', {Label = "Leaf 2", IsLeaf = true})
			Slab.BeginTree('SlabTest_Child1_Leaf2', {Label = "Leaf 3", IsLeaf = true})

			Slab.EndTree()
		end

		Slab.EndTree()
	end
	if Slab.BeginTree('SlabTest_TreeRoot2', {Label = "Only opened with arrow.", OpenWithHighlight = false}) then
		Slab.BeginTree('SlabTest_Child1_leaf', {Label = "Leaf 1", IsLeaf = true})
		Slab.EndTree()
	end
	
	local Path = "/Internal/Resources/Textures/power.png"
	local ImageOptions =
	{
		Path = SLAB_PATH .. Path,
		Scale = 0.5,
		Color = {1.0, 0.0, 0.0, 1.0},
		ReturnOnClick = true,
		Tooltip = "This is a sample image."
	}

	if Slab.Image('SlabTest_Image', ImageOptions) then
		-- Perform logic when clicked
	end
	
	Slab.BeginListBox('SlabTest_ListBox')
	for I = 1, 10, 1 do
		Slab.BeginListBoxItem('Item ' .. I, {Selected = I == ListBoxIndex})
		Slab.Text("Item " .. I)
		if Slab.IsListBoxItemClicked() then
			ListBoxIndex = I
		end
		Slab.EndListBoxItem()
	end
	Slab.EndListBox()
	Slab.Text("After List Box")
	Slab.EndWindow()
end

function SlabTest.MainMenuBar()
	if Slab.BeginMainMenuBar() then
		if Slab.BeginMenu("File") then
			if Slab.BeginMenu("New") then
				if Slab.MenuItem("File") then
					-- Create a new file.
				end

				if Slab.MenuItem("Project") then
					-- Create a new project.
				end

				Slab.EndMenu()
			end

			if Slab.MenuItem("Open") then
				SlabTest_FileDialog = true
				SlabTest_FileDialogType = 'openfile'
			end

			if Slab.MenuItem("Save") then
				SlabTest_FileDialog = true
				SlabTest_FileDialogType = 'savefile'
			end

			Slab.MenuItem("Save As")

			Slab.Separator()

			if Slab.MenuItem("Quit") then
				love.event.quit()
			end

			Slab.EndMenu()
		end

		if Slab.BeginMenu("Windows") then
			if Slab.MenuItem("Reset Layout") then
				ResetLayout = true
			end

			if Slab.MenuItemChecked("Message Box", SlabTest_MessageBox) then
				SlabTest_MessageBox = not SlabTest_MessageBox
			end

			if Slab.MenuItemChecked("Color Picker", SlabTest_ColorPicker) then
				SlabTest_ColorPicker = not SlabTest_ColorPicker
			end

			Slab.EndMenu()
		end

		SlabDebug.Menu()

		Slab.EndMainMenuBar()
	end
end

function SlabTest.GlobalContextMenu()
	if Slab.BeginContextMenuWindow() then
		Slab.MenuItem("Global Item 1")
		Slab.MenuItem("Global Item 2")
		Slab.MenuItem("Global Item 3")

		Slab.EndContextMenu()
	end
end

function SlabTest.Begin()
	SlabTest.MainMenuBar()
	SlabTest.BasicWindow()
	SlabTest.ResizableWindow()
	SlabTest.TreeWindow()
	SlabTest.GlobalContextMenu()
	ResetLayout = false

	if SlabTest_MessageBox then
		local Result = Slab.MessageBox("Test", "This is a test message box.")

		if Result ~= "" then
			SlabTest_MessageBox = false
		end
	end

	if SlabTest_FileDialog then
		local Result = Slab.FileDialog({Type = SlabTest_FileDialogType, Filters = {{"*.*", "All Files"}, {"*.lua", "Lua Files"}, {"*.txt", "Text Files"}}})

		if Result.Button ~= "" then
			print("Button: " .. Result.Button)
			print("Files: " .. #Result.Files)
			for I, V in ipairs(Result.Files) do
				print("   " .. V)
			end
			SlabTest_FileDialog = false
		end
	end

	if SlabTest_ColorPicker then
		local Result = Slab.ColorPicker({Color = SlabTest_ColorPicker_Color})

		if Result.Button ~= "" then
			SlabTest_ColorPicker = false

			if Result.Button == "OK" then
				SlabTest_ColorPicker_Color = Result.Color
			end
		end
	end

	SlabDebug.Begin()
end

return SlabTest
