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
local Tooltip = require(SLAB_PATH .. '.Internal.UI.Tooltip')
local Window = require(SLAB_PATH .. '.Internal.UI.Window')

local SlabDebug = {}
local SlabDebug_About = 'SlabDebug_About'
local SlabDebug_Mouse = false
local SlabDebug_Windows = false
local SlabDebug_Tooltip = false
local SlabDebug_DrawCommands = false

local SlabDebug_Windows_Categories = {"Inspector", "Stack"}
local SlabDebug_Windows_Category = "Inspector"

local Selected_Window = ""

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

function SlabDebug.Mouse()
	Slab.BeginWindow('SlabDebug_Mouse', {Title = "Mouse"})
	local X, Y = Mouse.Position()
	Slab.Text("X: " .. X)
	Slab.Text("Y: " .. Y)

	for I = 1, 3, 1 do
		Slab.Text("Button " .. I .. ": " .. (Mouse.IsPressed(I) and "Pressed" or "Released"))
	end
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

function SlabDebug.Menu()
	if Slab.BeginMenu("Debug") then
		if Slab.MenuItem("About") then
			Slab.OpenDialog(SlabDebug_About)
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
end

return SlabDebug
