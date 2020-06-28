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

local Config = require(SLAB_PATH .. '.Internal.Core.Config')
local Cursor = require(SLAB_PATH .. '.Internal.Core.Cursor')
local FileSystem = require(SLAB_PATH .. '.Internal.Core.FileSystem')
local Utility = require(SLAB_PATH .. '.Internal.Core.Utility')

local API = {}
local Styles = {}
local StylePaths = {}
local DefaultStyles = {}
local CurrentStyle = ""
local FontStack = {}

local Style = 
{
	Font = nil,
	FontSize = 14,
	MenuColor = {0.2, 0.2, 0.2, 1.0},
	ScrollBarColor = {0.4, 0.4, 0.4, 1.0},
	ScrollBarHoveredColor = {0.8, 0.8, 0.8, 1.0},
	SeparatorColor = {0.5, 0.5, 0.5, 0.7},
	WindowBackgroundColor = {0.2, 0.2, 0.2, 1.0},
	WindowTitleFocusedColor = {0.26, 0.53, 0.96, 1.0},
	WindowCloseBgColor = {0.64, 0.64, 0.64, 1.0},
	WindowCloseColor = {0.0, 0.0, 0.0, 1.0},
	ButtonColor = {0.55, 0.55, 0.55, 1.0},
	RadioButtonSelectedColor = {0.2, 0.2, 0.2, 1.0},
	ButtonHoveredColor = {0.7, 0.7, 0.7, 1.0},
	ButtonPressedColor = {0.8, 0.8, 0.8, 1.0},
	ButtonDisabledTextColor = {0.35, 0.35, 0.35, 1.0},
	CheckBoxSelectedColor = {0.0, 0.0, 0.0, 1.0},
	TextColor = {0.875, 0.875, 0.875, 1.0},
	TextHoverBgColor = {0.5, 0.5, 0.5, 1.0},
	TextURLColor = {0.2, 0.2, 1.0, 1.0},
	ComboBoxColor = {0.4, 0.4, 0.4, 1.0},
	ComboBoxHoveredColor = {0.55, 0.55, 0.55, 1.0},
	ComboBoxDropDownColor = {0.4, 0.4, 0.4, 1.0},
	ComboBoxDropDownHoveredColor = {0.55, 0.55, 0.55, 1.0},
	ComboBoxArrowColor = {1.0, 1.0, 1.0, 1.0},
	InputBgColor = {0.4, 0.4, 0.4, 1.0},
	InputEditBgColor = {0.6, 0.6, 0.6, 1.0},
	InputSelectColor = {0.14, 0.29, 0.53, 0.4},
	InputSliderColor = {0.1, 0.1, 0.1, 1.0},
	MultilineTextColor = {0.0, 0.0, 0.0, 1.0},

	WindowRounding = 2.0,
	ButtonRounding = 2.0,
	CheckBoxRounding = 2.0,
	ComboBoxRounding = 2.0,
	InputBgRounding = 2.0,
	ScrollBarRounding = 2.0,
	Indent = 14.0,

	API = API
}

function API.Initialize()
	local StylePath = "/Internal/Resources/Styles/"
	local Path = SLAB_FILE_PATH .. StylePath
	-- Use love's filesystem functions to support both packaged and unpackaged builds
	local Items = love.filesystem.getDirectoryItems(Path)

	local StyleName = nil
	for I, V in ipairs(Items) do
		if string.find(V, Path, 1, true) == nil then
			V = Path .. V
		end

		local LoadedStyle = API.LoadStyle(V, false, true)

		if LoadedStyle ~= nil then
			local Name = FileSystem.GetBaseName(V, true)

			if StyleName == nil then
				StyleName = Name
			end
		end
	end

	if not API.SetStyle("Dark") then
		API.SetStyle(StyleName)
	end

	Style.Font = love.graphics.newFont(Style.FontSize)
	API.PushFont(Style.Font)
	Cursor.SetNewLineSize(Style.Font:getHeight())
end

function API.LoadStyle(Path, Set, IsDefault)
	local Contents, Error = Config.LoadFile(Path, IsDefault)
	if Contents ~= nil then
		local Name = FileSystem.GetBaseName(Path, true)
		Styles[Name] = Contents
		StylePaths[Name] = Path
		if IsDefault then
			table.insert(DefaultStyles, Name)
		end

		if Set then
			API.SetStyle(Name)
		end
	else
		print("Failed to load style '" .. Path .. "'.\n" .. Error)
	end
	return Contents
end

function API.SetStyle(Name)
	if Name == nil then
		return false
	end

	local Other = Styles[Name]
	if Other ~= nil then
		CurrentStyle = Name
		for K, V in pairs(Style) do
			local New = Other[K]
			if New ~= nil then
				if type(V) == "table" then
					Utility.CopyValues(Style[K], New)
				else
					Style[K] = New
				end
			end
		end

		return true
	else
		print("Style '" .. Name .. "' is not loaded.")
	end

	return false
end

function API.GetStyleNames()
	local Result = {}

	for K, V in pairs(Styles) do
		table.insert(Result, K)
	end

	return Result
end

function API.GetCurrentStyleName()
	return CurrentStyle
end

function API.CopyCurrentStyle(Path)
	local NewStyle = Utility.Copy(Styles[CurrentStyle])
	local Result, Error = Config.Save(Path, NewStyle)

	if Result then
		local NewStyleName = FileSystem.GetBaseName(Path, true)
		Styles[NewStyleName] = NewStyle
		StylePaths[NewStyleName] = Path
		API.SetStyle(NewStyleName)
	else
		print("Failed to create new style at path '" .. Path "'. " .. Error)
	end
end

function API.SaveCurrentStyle()
	API.StoreCurrentStyle()
	local Path = StylePaths[CurrentStyle]
	local Settings = Styles[CurrentStyle]
	local Result, Error = Config.Save(Path, Settings)
	if not Result then
		print("Failed to save style '" .. CurrentStyle .. "'. " .. Error)
	end
end

function API.StoreCurrentStyle()
	Utility.CopyValues(Styles[CurrentStyle], Style)
end

function API.IsDefaultStyle(Name)
	return Utility.Contains(DefaultStyles, Name)
end

function API.PushFont(Font)
	if Font ~= nil then
		Style.Font = Font
		table.insert(FontStack, 1, Font)
	end
end

function API.PopFont()
	if #FontStack > 1 then
		table.remove(FontStack, 1)
		Style.Font = FontStack[1]
	end
end

return Style
