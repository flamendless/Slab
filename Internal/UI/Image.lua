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

local love = require("love")
local Cursor = require(SLAB_PATH .. ".Internal.Core.Cursor")
local DrawCommands = require(SLAB_PATH .. ".Internal.Core.DrawCommands")
local IdCache = require(SLAB_PATH .. ".Internal.Core.IdCache")
local LayoutManager = require(SLAB_PATH .. ".Internal.UI.LayoutManager")
local Stats = require(SLAB_PATH .. ".Internal.Core.Stats")
local Tooltip = require(SLAB_PATH .. ".Internal.UI.Tooltip")
local Window = require(SLAB_PATH .. ".Internal.UI.Window")

local Image = {}

local instances = {}
local cache = {}
local id_cache = IdCache()

local EMPTY_STR = ""
local TBL_EMPTY = {}
local COLOR_WHITE = {1, 1, 1, 1}
local COLOR_BLACK = {0, 0, 0, 1}

local function GetImage(path)
	if not cache[path] then
		cache[path] = love.graphics.newImage(path)
	end
	return cache[path]
end

local function GetInstance(id)
	local key = id_cache:get(Window.GetId(), id)
	local instance = instances[key]
	if instance then return instance end
	instance = {
		id = id,
		image = nil
	}
	instances[key] = instance
	return instance
end

function Image.Begin(id, opt)
	local stat_handle = Stats.Begin("Image", "Slab")
	opt = opt or TBL_EMPTY
	local rotation = opt.Rotation or 0
	local scale = opt.Scale or 1
	local sx = opt.ScaleX or scale
	local sy = opt.ScaleY or scale
	local color = opt.Color or COLOR_WHITE
	local sub_w = opt.SubW or 0
	local sub_h = opt.SubH or 0

	local instance = GetInstance(id)
	local win_item_id = Window.GetItemId(id)

	if not instance.image then
		if not opt.Image then
			assert(opt.Path ~= nil, "Path to an image is required if no image is set!")
			instance.Image = GetImage(opt.Path)
		else
			instance.Image = opt.Image
		end
	elseif opt.Image then
		if instance.image ~= opt.Image then
			instance.image = opt.Image
		end
	end
	instance.image:setWrap(opt.WrapH or "clamp", opt.WrapV or "clamp")

	local iw, ih = instance.Image:getDimensions()
	local w = opt.W or iw
	local h = opt.H or ih

	-- The final width and height setting will be what the developer
	-- requested if it exists. The scale factor will be calculated here.
	sx = opt.W and (opt.W/iw) or sx
	sy = opt.H and (opt.H/ih) or sy
	w = w * sx
	h = h * sy

	local use_sub_img = sub_w > 0 and sub_h > 0
	if use_sub_img then
		sx = opt.W and (opt.W/sub_w) or sx
		sy = opt.H and (opt.H/sub_h) or sy
		w = opt.W or w
		h = opt.H or h
	end

	w, h = LayoutManager.ComputeSize(w, h)
	LayoutManager.AddControl(w, h, "Image")

	local x, y = Cursor.GetPosition()
	do
		local mx, my = Window.GetMousePosition()
		if not Window.IsObstructedAtMouse() and
			x <= mx and mx <= x + w and
			y <= my and my <= y + h then
			Tooltip.Begin(opt.Tooltip or EMPTY_STR)
			Window.SetHotItem(win_item_id)
		end
	end

	if use_sub_img then
		DrawCommands.SubImage(x, y, instance.image,
			opt.SubX or 0, opt.SubY or 0,
			sub_w, sub_h, rotation, sx, sy, color)
	else
		DrawCommands.Image(x, y, instance.image, rotation, sx, sy, color)
	end

	if opt.UseOutline then
		DrawCommands.Rectangle("line", x, y,
			use_sub_img and sub_w or w,
			use_sub_img and sub_h or h,
			opt.OutlineColor or COLOR_BLACK,
			nil, nil, opt.OutlineW or 1)
	end

	Cursor.SetItemBounds(x, y, w, h)
	Cursor.AdvanceY(h)
	Window.AddItem(x, y, w, h, win_item_id)
	Stats.End(stat_handle)
end

function Image.GetSize(image)
	if not image then return 0, 0 end
	local data = image
	if type(image) == "string" then
		data = GetImage(image)
	end
	if data then
		return data:getDimensions()
	end
end

return Image
