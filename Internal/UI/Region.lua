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

local max = math.max
local min = math.min
local floor = math.floor

local DrawCommands = require(SLAB_PATH .. ".Internal.Core.DrawCommands")
local MenuState = require(SLAB_PATH .. ".Internal.UI.MenuState")
local Mouse = require(SLAB_PATH .. ".Internal.Input.Mouse")
local Style = require(SLAB_PATH .. ".Style")
local Utility = require(SLAB_PATH .. ".Internal.Core.Utility")

local Region = {}
local Instances = {}
local Stack = {}
local ActiveInstance = nil
local ScrollPad = 3
local ScrollBarSize = 10
local WheelX = 0
local WheelY = 0
local WheelSpeed = 3
local HotInstance = nil
local WheelInstance = nil
local ScrollInstance = nil

local EMPTY = {}
local tempColor = {}

local function GetXScrollSize(instance)
	if instance ~= nil then
		return max(instance.W - (instance.ContentW - instance.W), 10)
	end
	return 0
end

local function GetYScrollSize(instance)
	if instance ~= nil then
		return max(instance.H - (instance.ContentH - instance.H), 10)
	end
	return 0
end

local function IsScrollHovered(instance, x, y)
	local hasScrollX, hasScrollY = false, false
	if not instance then return end

	if instance.HasScrollX then
		local posY = instance.Y + instance.H - ScrollPad - ScrollBarSize
		local sizeX = GetXScrollSize(instance)
		local posX = instance.ScrollPosX
		hasScrollX = instance.X + posX <= x and x < instance.X + posX + sizeX and posY <= y and y < posY + ScrollBarSize
	end

	if instance.HasScrollY then
		local posX = instance.X + instance.W - ScrollPad - ScrollBarSize
		local sizeY = GetYScrollSize(instance)
		local posY = instance.ScrollPosY
		hasScrollY = posX <= x and x < posX + ScrollBarSize and instance.Y + posY <= y and y < instance.Y + posY + sizeY
	end

	return hasScrollX, hasScrollY
end

local function Contains(instance, x, y)
	if instance ~= nil then
		return instance.X <= x and x <= instance.X + instance.W and instance.Y <= y and y <= instance.Y + instance.H
	end
	return false
end

local function UpdateScrollBars(instance, isObstructed)
	if instance.IgnoreScroll then
		return
	end

	instance.HasScrollX = instance.ContentW > instance.W
	instance.HasScrollY = instance.ContentH > instance.H

	local x, y = instance.MouseX, instance.MouseY
	instance.HoverScrollX, instance.HoverScrollY = IsScrollHovered(instance, x, y)
	local xSize = instance.W - GetXScrollSize(instance)
	local ySize = instance.H - GetYScrollSize(instance)

	if isObstructed then
		instance.HoverScrollX = false
		instance.HoverScrollY = false
	end

	local isMouseReleased = Mouse.IsReleased(1)
	local isMouseClicked = Mouse.IsClicked(1)

	local deltaX, deltaY = Mouse.GetDelta()

	if WheelInstance == instance then
		instance.HoverScrollX = WheelX ~= 0
		instance.HoverScrollY = WheelY ~= 0

		if not instance.HoverScrollX and instance.HoverScrollY and not instance.HasScrollY then
			instance.HoverScrollX = instance.HoverScrollY
			WheelX = -WheelY
		end
	end

	if not isObstructed and Contains(instance, x, y) or (instance.HoverScrollX or instance.HoverScrollY) then
		if WheelInstance == instance then
			if WheelX ~= 0 then
				instance.ScrollPosX = max(instance.ScrollPosX + WheelX, 0)
				instance.IsScrollingX = true
				isMouseReleased = true
				WheelX = 0
			end

			if WheelY ~= 0 then
				instance.ScrollPosY = max(instance.ScrollPosY - WheelY, 0)
				instance.IsScrollingY = true
				isMouseReleased = true
				WheelY = 0
			end

			WheelInstance = nil
			ScrollInstance = instance
		end

		if ScrollInstance == nil and isMouseClicked and (instance.HoverScrollX or instance.HoverScrollY) then
			ScrollInstance = instance
			ScrollInstance.IsScrollingX = instance.HoverScrollX
			ScrollInstance.IsScrollingY = instance.HoverScrollY
		end
	end

	if ScrollInstance == instance and isMouseReleased then
		instance.IsScrollingX = false
		instance.IsScrollingY = false
		ScrollInstance = nil
	end

	if instance.HasScrollX then
		if instance.HasScrollY then
			xSize = xSize - ScrollBarSize - ScrollPad
		end
		xSize = max(xSize, 0)
		if ScrollInstance == instance then
			MenuState.RequestClose = false

			if instance.IsScrollingX then
				instance.ScrollPosX = max(instance.ScrollPosX + deltaX, 0)
			end
		end
		instance.ScrollPosX = min(instance.ScrollPosX, xSize)
	end

	if instance.HasScrollY then
		if instance.HasScrollX then
			ySize = ySize - ScrollBarSize - ScrollPad
		end
		ySize = max(ySize, 0)
		if ScrollInstance == instance then
			MenuState.RequestClose = false

			if instance.IsScrollingY then
				instance.ScrollPosY = max(instance.ScrollPosY + deltaY, 0)
			end
		end
		instance.ScrollPosY = min(instance.ScrollPosY, ySize)
	end

	local xRatio, yRatio = 0, 0
	if xSize ~= 0 then
		xRatio = max(instance.ScrollPosX / xSize, 0)
	end
	if ySize ~= 0 then
		yRatio = max(instance.ScrollPosY / ySize, 0)
	end

	local tx = max(instance.ContentW - instance.W, 0) * -xRatio
	local ty = max(instance.ContentH - instance.H, 0) * -yRatio
	instance.Transform:setTransformation(floor(tx), floor(ty))
end

local function DrawScrollBars(instance)
	if not instance.HasScrollX and not instance.HasScrollY then
		return
	end

	if HotInstance ~= instance and ScrollInstance ~= instance and not Utility.IsMobile() then
		local dt = love.timer.getDelta()
		instance.ScrollAlphaX = max(instance.ScrollAlphaX - dt, 0)
		instance.ScrollAlphaY = max(instance.ScrollAlphaY - dt, 0)
	else
		instance.ScrollAlphaX = 1
		instance.ScrollAlphaY = 1
	end

	if instance.HasScrollX then
		local xSize = GetXScrollSize(instance)
		local color = Utility.MakeColor(Style.ScrollBarColor, tempColor)
		if instance.HoverScrollX or instance.IsScrollingX then
			color = Utility.MakeColor(Style.ScrollBarHoveredColor, tempColor)
		end
		color[4] = instance.ScrollAlphaX
		local xPos = instance.ScrollPosX
		DrawCommands.Rectangle('fill', instance.X + xPos, instance.Y + instance.H - ScrollPad - ScrollBarSize, xSize, ScrollBarSize, color, Style.ScrollBarRounding)
	end

	if instance.HasScrollY then
		local ySize = GetYScrollSize(instance)
		local color = Utility.MakeColor(Style.ScrollBarColor, tempColor)
		if instance.HoverScrollY or instance.IsScrollingY then
			color = Utility.MakeColor(Style.ScrollBarHoveredColor, tempColor)
		end
		color[4] = instance.ScrollAlphaY
		local yPos = instance.ScrollPosY
		DrawCommands.Rectangle('fill', instance.X + instance.W - ScrollPad - ScrollBarSize, instance.Y + yPos, ScrollBarSize, ySize, color, Style.ScrollBarRounding)
	end
end

local function GetInstance(id)
	if id == nil then
		return ActiveInstance
	end

	if Instances[id] == nil then
		local instance = {
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
			Transform = love.math.newTransform(),
		}
		Instances[id] = instance
	end
	return Instances[id]
end

function Region.Begin(id, options)
	options = options or EMPTY

	local instance = GetInstance(id)
	instance.X = options.X or 0
	instance.Y = options.Y or 0
	instance.W = options.W or 0
	instance.H = options.H or 0
	instance.SX = options.SX or instance.X
	instance.SY = options.SY or instance.Y
	instance.Intersect = options.Intersect
	instance.IgnoreScroll = options.IgnoreScroll
	instance.MouseX = options.MouseX or 0
	instance.MouseY = options.MouseY or 0
	instance.AutoSizeContent = options.AutoSizeContent

	if options.ResetContent then
		instance.ContentW = 0
		instance.ContentH = 0
	end

	if not options.AutoSizeContent then
		instance.ContentW = options.ContentW or 0
		instance.ContentH = options.ContentH or 0
	end

	ActiveInstance = instance
	table.insert(Stack, 1, ActiveInstance)

	UpdateScrollBars(instance, options.IsObstructed)

	if options.AutoSizeContent then
		instance.ContentH = 0
		instance.ContentW = 0
	end

	if HotInstance == instance and (not Contains(instance, instance.MouseX, instance.MouseY) or options.IsObstructed) then
		HotInstance = nil
	end

	if not options.IsObstructed then
		if Contains(instance, instance.MouseX, instance.MouseY) or (instance.HoverScrollX or instance.HoverScrollY) then
			if ScrollInstance == nil then
				HotInstance = instance
			else
				HotInstance = ScrollInstance
			end
		end
	end

	if not options.NoBackground then
		DrawCommands.Rectangle('fill', instance.X, instance.Y, instance.W, instance.H, options.BgColor or Style.WindowBackgroundColor, options.Rounding or 0)
	end
	if not options.NoOutline then
		DrawCommands.Rectangle('line', instance.X, instance.Y, instance.W, instance.H, nil, options.Rounding or 0)
	end
	DrawCommands.TransformPush()
	DrawCommands.ApplyTransform(instance.Transform)
	Region.ApplyScissor()
end

function Region.End()
	DrawCommands.TransformPop()
	DrawScrollBars(ActiveInstance)

	if HotInstance == ActiveInstance
		and WheelInstance == nil
		and (WheelX ~= 0 or WheelY ~= 0)
		and not ActiveInstance.IgnoreScroll then
		WheelInstance = ActiveInstance
	end

	if ActiveInstance.Intersect then
		DrawCommands.IntersectScissor()
	else
		DrawCommands.Scissor()
	end

	ActiveInstance = nil
	table.remove(Stack, 1)

	if #Stack > 0 then
		ActiveInstance = Stack[1]
	end
end

function Region.IsHoverScrollBar(id)
	local instance = GetInstance(id)
	if instance ~= nil then
		return instance.HoverScrollX or instance.HoverScrollY
	end
	return false
end

function Region.Translate(id, x, y)
	local instance = GetInstance(id)
	if instance ~= nil then
		instance.Transform:translate(x, y)
		local tx, ty = instance.Transform:inverseTransformPoint(0, 0)

		if not instance.IgnoreScroll then
			if x ~= 0 and instance.HasScrollX then
				local xSize = instance.W - GetXScrollSize(instance)
				local ContentW = instance.ContentW - instance.W

				if instance.HasScrollY then
					xSize = xSize - ScrollPad - ScrollBarSize
				end

				xSize = max(xSize, 0)

				instance.ScrollPosX = (tx / ContentW) * xSize
				instance.ScrollPosX = max(instance.ScrollPosX, 0)
				instance.ScrollPosX = min(instance.ScrollPosX, xSize)
			end

			if y ~= 0 and instance.HasScrollY then
				local ySize = instance.H - GetYScrollSize(instance)

				if instance.HasScrollX then
					ySize = ySize - ScrollPad - ScrollBarSize
				end

				ySize = max(ySize, 0)

				local ContentH = instance.ContentH - instance.H

				instance.ScrollPosY = (ty / ContentH) * ySize
				instance.ScrollPosY = max(instance.ScrollPosY, 0)
				instance.ScrollPosY = min(instance.ScrollPosY, ySize)
			end
		end
	end
end

function Region.Transform(id, x, y)
	local instance = GetInstance(id)
	if instance ~= nil then
		return instance.Transform:transformPoint(x, y)
	end
	return x, y
end

function Region.InverseTransform(id, x, y)
	local instance = GetInstance(id)
	if instance ~= nil then
		return instance.Transform:inverseTransformPoint(x, y)
	end
	return x, y
end

function Region.ResetTransform(id)
	local instance = GetInstance(id)
	if instance ~= nil then
		instance.Transform:reset()
		instance.ScrollPosX = 0
		instance.ScrollPosY = 0
	end
end

function Region.IsActive(id)
	if ActiveInstance ~= nil then
		return ActiveInstance.Id == id
	end
	return false
end

function Region.AddItem(x, y, W, H)
	if ActiveInstance ~= nil and ActiveInstance.AutoSizeContent then
		local newW = x + W - ActiveInstance.X
		local newH = y + H - ActiveInstance.Y
		ActiveInstance.ContentW = max(ActiveInstance.ContentW, newW)
		ActiveInstance.ContentH = max(ActiveInstance.ContentH, newH)
	end
end

function Region.ApplyScissor()
	if ActiveInstance ~= nil then
		if ActiveInstance.Intersect then
			DrawCommands.IntersectScissor(ActiveInstance.SX, ActiveInstance.SY, ActiveInstance.W, ActiveInstance.H)
		else
			DrawCommands.Scissor(ActiveInstance.SX, ActiveInstance.SY, ActiveInstance.W, ActiveInstance.H)
		end
	end
end

function Region.GetBounds()
	if ActiveInstance ~= nil then
		return ActiveInstance.X, ActiveInstance.Y, ActiveInstance.W, ActiveInstance.H
	end
	return 0, 0, 0, 0
end

function Region.GetContentSize()
	if ActiveInstance ~= nil then
		return ActiveInstance.ContentW, ActiveInstance.ContentH
	end
	return 0, 0
end

function Region.GetContentBounds()
	if ActiveInstance ~= nil then
		return ActiveInstance.X, ActiveInstance.Y, ActiveInstance.ContentW, ActiveInstance.ContentH
	end
	return 0, 0, 0, 0
end

function Region.Contains(x, y)
	if ActiveInstance ~= nil then
		return ActiveInstance.X <= x and x <= ActiveInstance.X + ActiveInstance.W and ActiveInstance.Y <= y and y <= ActiveInstance.Y + ActiveInstance.H
	end
	return false
end

function Region.ResetContentSize(id)
	local instance = GetInstance(id)
	if instance ~= nil then
		instance.ContentW = 0
		instance.ContentH = 0
	end
end

function Region.GetScrollPad()
	return ScrollPad
end

function Region.GetScrollBarSize()
	return ScrollBarSize
end

function Region.WheelMoved(x, y)
	WheelX = x * WheelSpeed
	WheelY = y * WheelSpeed
end

function Region.GetWheelDelta()
	return WheelX, WheelY
end

function Region.IsScrolling(id)
	if id then
		local instance = GetInstance(id)
		return ScrollInstance == instance or WheelInstance == instance
	end
	if ScrollInstance then
		return ScrollInstance.IsScrollingX or ScrollInstance.IsScrollingY
	end
	if WheelInstance then
		return WheelInstance.IsScrollingX or WheelInstance.IsScrollingY
	end
	return false
end

function Region.GetHotInstanceId()
	return HotInstance and HotInstance.Id or ''
end

function Region.ClearHotInstance(id)
	if not id or (HotInstance and HotInstance.Id == id) then
		HotInstance = nil
	end
end

function Region.GetInstanceIds()
	local result = {}

	for k, v in pairs(Instances) do
		table.insert(result, k)
	end

	return result
end

function Region.GetDebugInfo(id)
	local result = {}
	local instance = Instances[id]

	table.insert(result, "ScrollInstance: " .. (ScrollInstance ~= nil and ScrollInstance.Id or "nil"))
	table.insert(result, "WheelInstance: " .. (WheelInstance ~= nil and WheelInstance.Id or "nil"))
	table.insert(result, "WheelX: " .. WheelX)
	table.insert(result, "WheelY: " .. WheelY)
	table.insert(result, "Wheel Speed: " .. WheelSpeed)

	if instance ~= nil then
		table.insert(result, "Id: " .. instance.Id)
		table.insert(result, "W: " .. instance.W)
		table.insert(result, "H: " .. instance.H)
		table.insert(result, "ContentW: " .. instance.ContentW)
		table.insert(result, "ContentH: " .. instance.ContentH)
		table.insert(result, "ScrollPosX: " .. instance.ScrollPosX)
		table.insert(result, "ScrollPosY: " .. instance.ScrollPosY)

		local tx, ty = instance.Transform:transformPoint(0, 0)
		table.insert(result, "TX: " .. tx)
		table.insert(result, "TY: " .. ty)
		table.insert(result, "Max TX: " .. instance.ContentW - instance.W)
		table.insert(result, "Max TY: " .. instance.ContentH - instance.H)
	end

	return result
end

function Region.SetWheelSpeed(Speed)
	WheelSpeed = Speed or 3
end

function Region.GetWheelSpeed()
	return WheelSpeed
end

return Region
