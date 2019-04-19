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

local Cursor = require(SLAB_PATH .. '.Internal.Core.Cursor')
local DrawCommands = require(SLAB_PATH .. '.Internal.Core.DrawCommands')
local Mouse = require(SLAB_PATH .. '.Internal.Input.Mouse')
local Stats = require(SLAB_PATH .. '.Internal.Core.Stats')
local Style = require(SLAB_PATH .. '.Style')
local Tooltip = require(SLAB_PATH .. '.Internal.UI.Tooltip')
local Window = require(SLAB_PATH .. '.Internal.UI.Window')

local Image = {}
local Instances = {}
local ImageCache = {}

local function GetImage(Path)
	if ImageCache[Path] == nil then
		ImageCache[Path] = love.graphics.newImage(Path)
		local WrapH, WrapV = ImageCache[Path]:getWrap()
	end
	return ImageCache[Path]
end

local function GetInstance(Id)
	local Key = Window.GetId() .. '.' .. Id
	if Instances[Key] == nil then
		local Instance = {}
		Instance.Id = Id
		Instance.Image = nil
		Instances[Key] = Instance
	end
	return Instances[Key]
end

function Image.Begin(Id, Options)
	Stats.Begin('Image')

	Options = Options == nil and {} or Options
	Options.Tooltip = Options.Tooltip == nil and "" or Options.Tooltip
	Options.Rotation = Options.Rotation == nil and 0 or Options.Rotation
	Options.Scale = Options.Scale == nil and 1 or Options.Scale
	Options.ScaleX = Options.ScaleX == nil and Options.Scale or Options.ScaleX
	Options.ScaleY = Options.ScaleY == nil and Options.Scale or Options.ScaleY
	Options.Color = Options.Color == nil and {1.0, 1.0, 1.0, 1.0} or Options.Color
	Options.ReturnOnHover = Options.ReturnOnHover == nil and false or Options.ReturnOnHover
	Options.ReturnOnClick = Options.ReturnOnClick == nil and false or Options.ReturnOnClick
	Options.SubX = Options.SubX == nil and 0.0 or Options.SubX
	Options.SubY = Options.SubY == nil and 0.0 or Options.SubY
	Options.SubW = Options.SubW == nil and 0.0 or Options.SubW
	Options.SubH = Options.SubH == nil and 0.0 or Options.SubH
	Options.WrapH = Options.WrapH == nil and "clamp" or Options.WrapH
	Options.WrapV = Options.WrapV == nil and "clamp" or Options.WrapV

	local Instance = GetInstance(Id)
	local WinItemId = Window.GetItemId(Id)

	if Instance.Image == nil then
		if Options.Image == nil then
			assert(Options.Path ~= nil, "Path to an image is required if no image is set!")
			Instance.Image = GetImage(Options.Path)
		else
			Instance.Image = Options.Image
		end
	end

	Instance.Image:setWrap(Options.WrapH, Options.WrapV)

	local X, Y = Cursor.GetPosition()
	local W = Instance.Image:getWidth() * Options.ScaleX
	local H = Instance.Image:getHeight() * Options.ScaleY
	local Result = false
	local MouseX, MouseY = Window.GetMousePosition()

	local UseSubImage = false
	if Options.SubW > 0.0 and Options.SubH > 0.0 then
		W = Options.SubW
		H = Options.SubH
		UseSubImage = true
	end

	if not Window.IsObstructedAtMouse() and X <= MouseX and MouseX <= X + W and Y <= MouseY and MouseY <= Y + H then
		Result = Options.ReturnOnHover
		Tooltip.Begin(Options.Tooltip)
		Window.SetHotItem(WinItemId)

		if Mouse.IsReleased(1) and Options.ReturnOnClick then
			Result = true
		end
	end

	if UseSubImage then
		DrawCommands.SubImage(
			X,
			Y,
			Instance.Image,
			Options.SubX,
			Options.SubY,
			Options.SubW,
			Options.SubH,
			Options.Rotation,
			Options.ScaleX,
			Options.ScaleY,
			Options.Color)
	else
		DrawCommands.Image(X, Y, Instance.Image, Options.Rotation, Options.ScaleX, Options.ScaleY, Options.Color)
	end

	Cursor.SetItemBounds(X, Y, W, H)
	Cursor.AdvanceY(H)

	Window.AddItem(X, Y, W, H, WinItemId)

	Stats.End('Image')

	return Result
end

return Image
