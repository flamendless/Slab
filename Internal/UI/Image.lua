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

local Cursor = require(SLAB_PATH .. '.Internal.Core.Cursor')
local DrawCommands = require(SLAB_PATH .. '.Internal.Core.DrawCommands')
local LayoutManager = require(SLAB_PATH .. '.Internal.UI.LayoutManager')
local Mouse = require(SLAB_PATH .. '.Internal.Input.Mouse')
local Stats = require(SLAB_PATH .. '.Internal.Core.Stats')
local Style = require(SLAB_PATH .. '.Style')
local Tooltip = require(SLAB_PATH .. '.Internal.UI.Tooltip')
local Window = require(SLAB_PATH .. '.Internal.UI.Window')
local IdCache = require(SLAB_PATH .. '.Internal.Core.IdCache')

local Image = {}
local instances = {}
local imageCache = {}
local idCache = IdCache()

local EMPTY = {}
local WHITE = { 1, 1, 1, 1 }
local BLACK = { 0, 0, 0, 1 }

local function GetImage(path)
	if imageCache[path] == nil then
		imageCache[path] = love.graphics.newImage(path)
	end
	return imageCache[path]
end

local function GetInstance(id)
	local key = idCache:get(Window.GetId(), id)
	local instance = instances[key]

	if instance then return instance end

	instance = {}
	instance.Id = id
	instance.Image = nil
	instances[key] = instance

	return instance
end

function Image.Begin(id, options)
	local statHandle = Stats.Begin('Image', 'Slab')

	options = options or EMPTY
	local rotation = options.Rotation or 0
	local scale = options.Scale or 1
	local scaleX = options.ScaleX or scale
	local scaleY = options.ScaleY or scale
	local color = options.Color or WHITE
	local subW = options.SubW or 0.0
	local subH = options.SubH or 0.0

	local instance = GetInstance(id)
	local winItemId = Window.GetItemId(id)


	if instance.Image == nil then
		if options.Image == nil then
			assert(options.Path ~= nil, "Path to an image is required if no image is set!")
			instance.Image = GetImage(options.Path)
		else
			instance.Image = options.Image
		end
	elseif options.Image then
		if instance.Image ~= options.Image then
			instance.Image = options.Image
		end
	end

	instance.Image:setWrap(options.WrapH or "clamp", options.WrapV or "clamp")

	local w = options.W or instance.Image:getWidth()
	local h = options.H or instance.Image:getHeight()

	-- The final width and height setting will be what the developer requested if it exists. The scale factor will be calculated here.
	scaleX = options.W and (options.W / instance.Image:getWidth()) or scaleX
	scaleY = options.H and (options.H / instance.Image:getHeight()) or scaleY

	local hasExplicitSize = options.W and options.H
	if not hasExplicitSize then
		-- if the size isn't explictly defined, then apply scaling to the size.
		-- (If size is explicit, don't apply scaling, because the w,h are already exactly correct.)
		w = w * scaleX
		h = h * scaleY
	end

	local useSubImage = subW > 0.0 and subH > 0.0
	if useSubImage then
		scaleX = options.W and (options.W / subW) or scaleX
		scaleY = options.H and (options.H / subH) or scaleY
	end

	w, h = LayoutManager.ComputeSize(w, h)
	LayoutManager.AddControl(w, h, 'Image')

	local x, y = Cursor.GetPosition()
	do
		local mouseX, mouseY = Window.GetMousePosition()

		if not Window.IsObstructedAtMouse() and x <= mouseX and mouseX <= x + w and y <= mouseY and mouseY <= y + h then
			Tooltip.Begin(options.Tooltip or "")
			Window.SetHotItem(winItemId)
		end
	end

	if useSubImage then
		DrawCommands.SubImage(
			x,
			y,
			instance.Image,
			options.SubX or 0,
			options.SubY or 0,
			subW,
			subH,
			rotation,
			scaleX,
			scaleY,
			color)
	else
		DrawCommands.Image(x, y, instance.Image, rotation, scaleX, scaleY, color)
	end

	if options.UseOutline then
		DrawCommands.Rectangle(
			'line',
			x,
			y,
			useSubImage and subW or w,
			useSubImage and subH or h,
			options.OutlineColor or BLACK,
			nil,
			nil,
			options.OutlineW or 1
		)
	end

	Cursor.SetItemBounds(x, y, w, h)
	Cursor.AdvanceY(h)

	Window.AddItem(x, y, w, h, winItemId)

	Stats.End(statHandle)
end

function Image.GetSize(Image)
	if Image ~= nil then
		local Data = Image
		if type(Image) == 'string' then
			Data = GetImage(Image)
		end

		if Data ~= nil then
			return Data:getWidth(), Data:getHeight()
		end
	end

	return 0, 0
end

return Image
