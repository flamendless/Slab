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
local Mouse = require(SLAB_PATH .. '.Internal.Input.Mouse')

local SlabDebug = {}
local SlabDebug_About = 'SlabDebug_About'
local SlabDebug_Mouse = false

function SlabDebug.About()
	if Slab.BeginDialog(SlabDebug_About, {Title = "About"}) then
		Slab.Text("Slab Version: " .. Slab.GetVersion())
		Slab.Text("Love Version: " .. Slab.GetLoveVersion())
		if Slab.Button("OK") then
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

function SlabDebug.Menu()
	if Slab.BeginMenu("Debug") then
		if Slab.MenuItem("About") then
			Slab.OpenDialog(SlabDebug_About)
		end

		if Slab.MenuItemChecked("Mouse", SlabDebug_Mouse) then
			SlabDebug_Mouse = not SlabDebug_Mouse
		end

		Slab.EndMenu()
	end
end

function SlabDebug.Begin()
	SlabDebug.About()

	if SlabDebug_Mouse then
		SlabDebug.Mouse()
	end
end

return SlabDebug
