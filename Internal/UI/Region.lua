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

local insert = table.insert
local remove = table.remove
local max = math.max
local min = math.min
local floor = math.floor

local DrawCommands = require(SLAB_PATH .. ".Internal.Core.DrawCommands")
local MenuState = require(SLAB_PATH .. ".Internal.UI.MenuState")
local Mouse = require(SLAB_PATH .. ".Internal.Input.Mouse")
local Style = require(SLAB_PATH .. ".Style")
local Utility = require(SLAB_PATH .. ".Internal.Core.Utility")

local Region = {}
local instances, stack = {}, {}
local active
local scroll_pad = 3
local scrollbar_size = 10
local wheel_x, wheel_y = 0, 0
local wheel_speed = 3
local hot_instance, wheel_instance, scroll_instance

local function GetXScrollSize(instance)
	if not instance then return 0 end
	return max(instance.W - (instance.ContentW - instance.W), 10)
end

local function GetYScrollSize(instance)
	if not instance then return 0 end
	return max(instance.H - (instance.ContentH - instance.H), 10)
end

local function GetScrollSize(instance)
	if not instance then return 0, 0 end
	local x = max(instance.W - (instance.ContentW - instance.W), 10)
	local y = max(instance.H - (instance.ContentH - instance.H), 10)
	return x, y
end

local function IsScrollHovered(instance, x, y)
	local has_sx, has_sy = false, false
	if not instance then return has_sx, has_sy end
	if instance.HasScrollX then
		local pos_x = instance.ScrollPosX
		local pos_y = instance.Y + instance.H - scroll_pad - scrollbar_size
		local sx = GetXScrollSize(instance)
		has_sx = instance.X + pos_x <= x and x < instance.X + pos_x + sx and
			pos_y <= y and y < pos_y + scrollbar_size
	end
	if instance.HasScrollY then
		local pos_x = instance.X + instance.W - scroll_pad - scrollbar_size
		local pos_y = instance.ScrollPosY
		local sy = GetYScrollSize(instance)
		has_sy = pos_x <= x and x < pos_x + scrollbar_size and
			instance.Y + pos_y <= y and y < instance.Y + pos_y + sy
	end
	return has_sx, has_sy
end

local function Contains(instance, x, y)
	if not instance then return false end
	return instance.X <= x and x <= instance.X + instance.W and
		instance.Y <= y and y <= instance.Y + instance.H
end

local function UpdateScrollBars(instance, is_obstructed)
	if instance.IgnoreScroll then return end
	instance.HasScrollX = instance.ContentW > instance.W
	instance.HasScrollY = instance.ContentH > instance.H
	local mx, my = instance.MouseX, instance.MouseY
	instance.HoverScrollX, instance.HoverScrollY = IsScrollHovered(instance, mx, my)
	local ssx, ssy = GetScrollSize(instance)
	local xsize = instance.W - ssx
	local ysize = instance.H - ssy

	if is_obstructed then
		instance.HoverScrollX = false
		instance.HoverScrollY = false
	end
	local is_mouse_released = Mouse.IsReleased(1)
	local is_mouse_clicked = Mouse.IsClicked(1)
	local dx, dy = Mouse.GetDelta()

	if wheel_instance == instance then
		instance.HoverScrollX = wheel_x ~= 0
		instance.HoverScrollY = wheel_y ~= 0
		if not instance.HoverScrollX and instance.HoverScrollY and not instance.HasScrollY then
			instance.HoverScrollX = instance.HoverScrollY
			wheel_x = -wheel_y
		end
	end

	local either_scroll = instance.HasScrollX or instance.HasScrollY

	if not is_obstructed and Contains(instance, mx, my) or either_scroll then
		if wheel_instance == instance then
			if wheel_x ~= 0 then
				instance.ScrollPosX = max(instance.ScrollPosX + wheel_x, 0)
				instance.IsScrollingX = true
				is_mouse_released = true
				wheel_x = 0
			end

			if wheel_y ~= 0 then
				instance.ScrollPosY = max(instance.ScrollPosY - wheel_y, 0)
				instance.IsScrollingY = true
				is_mouse_released = true
				wheel_y = 0
			end
		end

		if not scroll_instance and is_mouse_clicked and either_scroll then
			scroll_instance = instance
		end
	end

	if scroll_instance == instance and is_mouse_released then
		instance.IsScrollingX = false
		instance.IsScrollingY = false
		scroll_instance = nil
	end

	if instance.HasScrollX then
		if instance.HasScrollY then
			xsize = xsize - scrollbar_size - scroll_pad
		end
		xsize = max(xsize, 0)
		if scroll_instance == instance then
			MenuState.RequestClose = false
			if instance.IsScrollingX then
				instance.ScrollPosX = max(instance.ScrollPosX + dx, 0)
			end
		end
		instance.ScrollPosX = min(instance.ScrollPosX, xsize)
	end

	if instance.HasScrollY then
		if instance.HasScrollX then
			ysize = ysize - scrollbar_size - scroll_pad
		end
		ysize = max(ysize, 0)
		if scroll_instance == instance then
			MenuState.RequestClose = false
			if instance.IsScrollingY then
				instance.ScrollPosY = max(instance.ScrollPosY + dy, 0)
			end
		end
		instance.ScrollPosY = min(instance.ScrollPosY, ysize)
	end

	local xratio = xsize ~= 0 and max(instance.ScrollPosX/xsize, 0) or 0
	local yratio = ysize ~= 0 and max(instance.ScrollPosY/ysize, 0) or 0
	local tx = max(instance.ContentW - instance.W, 0) * -xratio
	local ty = max(instance.ContentH - instance.H, 0) * -yratio
	instance.Transform:setTransformation(floor(tx), floor(ty))
end

local function DrawScrollBars(instance)
	if not instance.HasScrollX and not instance.HasScrollY then return end
	if hot_instance ~= instance and scroll_instance ~= instance and
		not Utility.IsMobile() then
		local dt = love.timer.getDelta()
		instance.ScrollAlphaX = max(instance.ScrollAlphaX - dt, 0)
		instance.ScrollAlphaY = max(instance.ScrollAlphaY - dt, 0)
	else
		instance.ScrollAlphaX = 1
		instance.ScrollAlphaY = 1
	end

	local ssx, ssy = GetScrollSize(instance)
	if instance.HasScrollX then
		local color
		if instance.HoverScrollX or instance.IsScrollingX then
			color = Utility.MakeColor(Style.ScrollBarHoveredColor)
		else
			color = Utility.MakeColor(Style.ScrollBarColor)
		end
		color[4] = instance.ScrollAlphaX
		local xpos = instance.ScrollPosX
		DrawCommands.Rectangle("fill",
			instance.X + xpos,
			instance.Y + instance.H - scroll_pad - scrollbar_size,
			ssx, scrollbar_size, color, Style.ScrollBarRounding)
	end

	if instance.HasScrollY then
		local color
		if instance.HoverScrollY or instance.IsScrollingY then
			color = Utility.MakeColor(Style.ScrollBarHoveredColor)
		else
			color = Utility.MakeColor(Style.ScrollBarColor)
		end
		color[4] = instance.ScrollAlphaY
		local ypos = instance.ScrollPosY
		DrawCommands.Rectangle("fill",
			instance.X + instance.W - scroll_pad - scrollbar_size,
			instance.Y + ypos,
			scrollbar_size, ssy, color, Style.ScrollBarRounding)
	end
end

local function GetInstance(id)
	if not id then return active end
	if not instances[id] then
		instances[id] = {
			Id = id,
			X = 0,
			Y = 0,
			W = 0,
			H = 0,
			SX = 0,
			SY = 0,
			ContentW = 0,
			ContentH = 0,
			HasScrollX = false,
			HasScrollY = false,
			HoverScrollX = false,
			HoverScrollY = false,
			IsScrollingX = false,
			IsScrollingY = false,
			ScrollPosX = 0,
			ScrollPosY = 0,
			ScrollAlphaX = 0,
			ScrollAlphaY = 0,
			Intersect = false,
			AutoSizeContent = false,
			Transform = love.math.newTransform():reset(),
		}
	end
	return instances[id]
end

local TBL_DEF = {
	X = 0, Y = 0,
	W = 0, H = 0,
	SX = 0, SY = 0,
	ContentW = 0, ContentH = 0,
	AutoSizeContent = false,
	BgColor = Style.WindowBackgroundColor,
	NoOutline = false,
	IsObstructed = false,
	Intersect = false,
	IgnoreScroll = false,
	MouseX = 0, MouseY = 0,
	ResetContent = false,
	Rounding = 0,
}

function Region.Begin(id, opt)
	opt = opt or TBL_DEF
	opt.X = opt.X or TBL_DEF.X
	opt.Y = opt.Y or TBL_DEF.Y
	opt.W = opt.W or TBL_DEF.W
	opt.H = opt.H or TBL_DEF.H
	opt.SX = opt.SX or TBL_DEF.SX
	opt.SY = opt.SY or TBL_DEF.SY
	opt.ContentW = opt.ContentW or TBL_DEF.ContentW
	opt.ContentH = opt.ContentH or TBL_DEF.ContentH
	opt.AutoSizeContent = opt.AutoSizeContent or TBL_DEF.AutoSizeContent
	opt.BgColor = opt.BgColor or TBL_DEF.BgColor
	opt.NoOutline = opt.NoOutline or TBL_DEF.NoOutline
	opt.NoBackground = opt.NoBackground or TBL_DEF.NoBackground
	opt.IsObstructed = opt.IsObstructed or TBL_DEF.IsObstructed
	opt.Intersect = opt.Intersect or TBL_DEF.Intersect
	opt.IgnoreScroll = opt.IgnoreScroll or TBL_DEF.IgnoreScroll
	opt.MouseX = opt.MouseX or TBL_DEF.MouseX
	opt.MouseY = opt.MouseY or TBL_DEF.MouseY
	opt.ResetContent = opt.ResetContent or TBL_DEF.ResetContent
	opt.Rounding = opt.Rounding or TBL_DEF.Rounding

	local instance = GetInstance(id)
	instance.X = opt.X
	instance.Y = opt.Y
	instance.W = opt.W
	instance.H = opt.H
	instance.SX = opt.SX
	instance.SY = opt.SY
	instance.Intersect = opt.Intersect
	instance.IgnoreScroll = opt.IgnoreScroll
	instance.MouseX = opt.MouseX
	instance.MouseY = opt.MouseY
	instance.AutoSizeContent = opt.AutoSizeContent

	if opt.ResetContent then
		instance.ContentW, instance.ContentH = 0, 0
	end

	if not opt.AutoSizeContent then
		instance.ContentW, instance.ContentH = opt.ContentW, opt.ContentH
	end

	active = instance
	insert(stack, 1, instance)
	UpdateScrollBars(instance, opt.IsObstructed)

	if opt.AutoSizeContent then
		instance.ContentW, instance.ContentH = 0, 0
	end

	if hot_instance == instance and (not Contains(instance, instance.MouseX, instance.MouseY)
		or opt.IsObstructed) then
		hot_instance = nil
	end

	if not opt.IsObstructed and (Contains(instance, instance.MouseX, instance.MouseY) or
		(instance.HoverScrollX or instance.HoverScrollY)) then
		if not scroll_instance then
			hot_instance = instance
		else
			hot_instance = scroll_instance
		end
	end

	if not opt.NoBackground then
		DrawCommands.Rectangle("fill",
			instance.X, instance.Y, instance.W, instance.H, opt.BgColor, opt.Rounding)
	end
	if not opt.NoOutline then
		DrawCommands.Rectangle("line",
			instance.X, instance.Y, instance.W, instance.H, nil, opt.Rounding)
	end
	DrawCommands.TransformPush()
	DrawCommands.ApplyTransform(instance.Transform)
	Region.ApplyScissor()
end

function Region.End()
	DrawCommands.TransformPop()
	DrawScrollBars(active)

	if hot_instance == active
		and not wheel_instance
		and (wheel_x ~= 0 or wheel_y ~= 0)
		and not active.IgnoreScroll then
		wheel_instance = instance
	end

	if active.Intersect then
		DrawCommands.IntersectScissor()
	else
		DrawCommands.Scissor()
	end

	active = nil
	remove(stack, 1)

	if #stack > 0 then
		instance = stack[1]
	end
end

function Region.IsHoverScrollBar(id)
	local instance = GetInstance(id)
	if not instance then return false end
	return instance.HoverScrollX or instance.HoverScrollY
end

function Region.Translate(id, x, y)
	local instance = GetInstance(id)
	if not instance then return end
	instance.Transform:translate(x, y)
	local tx, ty = instance.Transform:inverseTransformPoint(0, 0)
	if instance.IgnoreScroll then return end
	local ssx, ssy = GetScrollSize(instance)
	if x ~= 0 and instance.HasScrollX then
		local xsize = instance.W - ssx
		local cw = instance.ContentW - instance.W
		if instance.HasScrollY then
			xsize = xsize - scroll_pad - scrollbar_size
		end
		xsize = max(xsize, 0)
		instance.ScrollPosX = (tx/cw) * xsize
		instance.ScrollPosX = max(instance.ScrollPosX, 0)
		instance.ScrollPosX = min(instance.ScrollPosX, xsize)
	end

	if y ~= 0 and instance.HasScrollY then
		local ysize = instance.H - ssy
		local ch = instance.ContentH - instance.H
		if instance.HasScrollX then
			ysize = ysize - scroll_pad - scrollbar_size
		end
		ysize = max(ysize, 0)
		instance.ScrollPosY = (ty/ch) * ysize
		instance.ScrollPosY = max(instance.ScrollPosY, 0)
		instance.ScrollPosY = min(instance.ScrollPosY, ysize)
	end
end

function Region.Transform(id, x, y)
	local instance = GetInstance(id)
	if not instance then return x, y end
	return instance.Transform:transformPoint(x, y)
end

function Region.InverseTransform(id, x, y)
	local instance = GetInstance(id)
	if not instance then return x, y end
	return instance.Transform:inverseTransformPoint(x, y)
end

function Region.ResetTransform(id)
	local instance = GetInstance(id)
	if not instance then return end
	instance.Transform:reset()
	instance.ScrollPosX, instance.ScrollPosY = 0, 0
end

function Region.IsActive(id)
	if not active then return false end
	return active.id == id
end

function Region.AddItem(x, y, w, h)
	if not active or not active.AutoSizeContent then return end
	local nw = x + w - active.X
	local nh = y + h - active.Y
	active.ContentW = max(active.ContentW, nw)
	active.ContentH = max(active.ContentH, nh)
end

function Region.ApplyScissor()
	if not active then return end
	if active.Intersect then
		DrawCommands.IntersectScissor(active.SX, active.SY, active.W, active.H)
	else
		DrawCommands.Scissor(active.SX, active.SY, active.W, active.H)
	end
end

function Region.GetBounds()
	if not active then return 0, 0, 0, 0 end
	return active.X, active.Y, active.W, active.H
end

function Region.GetContentSize()
	if not active then return 0, 0 end
	return active.ContentW, active.ContentH
end

function Region.GetContentBounds()
	if not active then return 0, 0, 0, 0 end
	return active.X, active.Y, active.ContentW, active.ContentH
end

function Region.Contains(x, y)
	if not active then return false end
	return active.X <= x and x <= active.X + active.W and
		active.Y <= y and y <= active.Y + active.H
end

function Region.ResetContentSize(id)
	local instance = GetInstance(id)
	if not instance then return end
	instance.ContentW = 0
	instance.ContentH = 0
end

function Region.WheelMoved(x, y)
	wheel_x = x * wheel_speed
	wheel_y = y * wheel_speed
end

function Region.IsScrolling(id)
	if id then return scroll_instance ~= nil or wheel_instance ~= nil end
	local instance = GetInstance(id)
	return scroll_instance == instance or wheel_instance == instance
end

local STR_EMPTY = ""
function Region.GetHotInstanceId()
	if not hot_instance then return STR_EMPTY end
	return hot_instance.id
end

function Region.ClearHotInstance(id)
	if not hot_instance then return end
	if not id then hot_instance = nil end
	if id and (hot_instance.id == id) then
		hot_instance = nil
	end
end

function Region.GetInstanceIds()
	local res = {}
	for k in pairs(instances) do
		insert(res, k)
	end
	return res
end

local STR_NIL = "nil"
function Region.GetDebugInfo(id)
	local res = {}
	local instance

	for k, v in pairs(instances) do
		if k == id then
			instance = v
			break
		end
	end

	insert(res, "ScrollInstance: " .. (scroll_instance and scroll_instance.Id or STR_NIL))
	insert(res, "WheelInstance: " .. (wheel_instance ~= nil and wheel_instance.Id or STR_NIL))
	insert(res, "WheelX: " .. wheel_x)
	insert(res, "WheelY: " .. wheel_y)
	insert(res, "Wheel Speed: " .. wheel_speed)

	if instance then
		insert(res, "Id: " .. instance.Id)
		insert(res, "W: " .. instance.W)
		insert(res, "H: " .. instance.H)
		insert(res, "ContentW: " .. instance.ContentW)
		insert(res, "ContentH: " .. instance.ContentH)
		insert(res, "ScrollPosX: " .. instance.ScrollPosX)
		insert(res, "ScrollPosY: " .. instance.ScrollPosY)
		local tx, ty = instance.Transform:transformPoint(0, 0)
		insert(res, "TX: " .. tx)
		insert(res, "TY: " .. ty)
		insert(res, "Max TX: " .. instance.ContentW - instance.W)
		insert(res, "Max TY: " .. instance.ContentH - instance.H)
	end

	return res
end

function Region.SetWheelSpeed(speed)
	wheel_speed = (not speed) and 3 or speed
end

function Region.GetScrollPad() return scroll_pad end
function Region.GetScrollBarSize() return scrollbar_size end
function Region.GetWheelDelta() return wheel_x, wheel_y end
function Region.GetWheelSpeed() return wheel_speed end

return Region
