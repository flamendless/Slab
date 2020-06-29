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
local ScrollPad = 3.0
local ScrollBarSize = 10.0
local WheelX = 0.0
local WheelY = 0.0
local WheelSpeed = 3.0
local HotInstance = nil
local WheelInstance = nil
local ScrollInstance = nil

local function GetXScrollSize(Instance)
	if Instance ~= nil then
		return max(Instance.W - (Instance.ContentW - Instance.W), 10.0)
	end
	return 0.0
end

local function GetYScrollSize(Instance)
	if Instance ~= nil then
		return max(Instance.H - (Instance.ContentH - Instance.H), 10.0)
	end
	return 0.0
end

local function IsScrollHovered(Instance, X, Y)
	local HasScrollX, HasScrollY = false, false

	if Instance ~= nil then
		if Instance.HasScrollX then
			local PosY = Instance.Y + Instance.H - ScrollPad - ScrollBarSize
			local SizeX = GetXScrollSize(Instance)
			local PosX = Instance.ScrollPosX
			HasScrollX = Instance.X + PosX <= X and X < Instance.X + PosX + SizeX and PosY <= Y and Y < PosY + ScrollBarSize
		end

		if Instance.HasScrollY then
			local PosX = Instance.X + Instance.W - ScrollPad - ScrollBarSize
			local SizeY = GetYScrollSize(Instance)
			local PosY = Instance.ScrollPosY
			HasScrollY = PosX <= X and X < PosX + ScrollBarSize and Instance.Y + PosY <= Y and Y < Instance.Y + PosY + SizeY
		end
	end
	return HasScrollX, HasScrollY
end

local function Contains(Instance, X, Y)
	if Instance ~= nil then
		return Instance.X <= X and X <= Instance.X + Instance.W and Instance.Y <= Y and Y <= Instance.Y + Instance.H
	end
	return false
end

local function UpdateScrollBars(Instance, IsObstructed)
	if Instance.IgnoreScroll then
		return
	end

	Instance.HasScrollX = Instance.ContentW > Instance.W
	Instance.HasScrollY = Instance.ContentH > Instance.H

	local X, Y = Instance.MouseX, Instance.MouseY
	Instance.HoverScrollX, Instance.HoverScrollY = IsScrollHovered(Instance, X, Y)
	local XSize = Instance.W - GetXScrollSize(Instance)
	local YSize = Instance.H - GetYScrollSize(Instance)

	if IsObstructed then
		Instance.HoverScrollX = false
		Instance.HoverScrollY = false
	end

	local IsMouseReleased = Mouse.IsReleased(1)
	local IsMouseClicked = Mouse.IsClicked(1)

	local DeltaX, DeltaY = Mouse.GetDelta()

	if WheelInstance == Instance then
		Instance.HoverScrollX = WheelX ~= 0.0
		Instance.HoverScrollY = WheelY ~= 0.0
	end

	if not IsObstructed and Contains(Instance, X, Y) or (Instance.HoverScrollX or Instance.HoverScrollY) then
		if WheelInstance == Instance then
			if WheelX ~= 0.0 then
				Instance.ScrollPosX = max(Instance.ScrollPosX + WheelX, 0.0)
				Instance.IsScrollingX = true
				IsMouseReleased = true
				WheelX = 0.0
			end

			if WheelY ~= 0.0 then
				Instance.ScrollPosY = max(Instance.ScrollPosY - WheelY, 0.0)
				Instance.IsScrollingY = true
				IsMouseReleased = true
				WheelY = 0.0
			end

			WheelInstance = nil
			ScrollInstance = Instance
		end

		if ScrollInstance == nil and IsMouseClicked and (Instance.HoverScrollX or Instance.HoverScrollY) then
			ScrollInstance = Instance
			ScrollInstance.IsScrollingX = Instance.HoverScrollX
			ScrollInstance.IsScrollingY = Instance.HoverScrollY
		end
	end

	if ScrollInstance == Instance and IsMouseReleased then
		Instance.IsScrollingX = false
		Instance.IsScrollingY = false
		ScrollInstance = nil
	end

	if Instance.HasScrollX then
		if Instance.HasScrollY then
			XSize = XSize - ScrollBarSize - ScrollPad
		end
		XSize = max(XSize, 0.0)
		if ScrollInstance == Instance then
			MenuState.RequestClose = false

			if Instance.IsScrollingX then
				Instance.ScrollPosX = max(Instance.ScrollPosX + DeltaX, 0.0)
			end
		end
		Instance.ScrollPosX = min(Instance.ScrollPosX, XSize)
	end

	if Instance.HasScrollY then
		if Instance.HasScrollX then
			YSize = YSize - ScrollBarSize - ScrollPad
		end
		YSize = max(YSize, 0.0)
		if ScrollInstance == Instance then
			MenuState.RequestClose = false

			if Instance.IsScrollingY then
				Instance.ScrollPosY = max(Instance.ScrollPosY + DeltaY, 0.0)
			end
		end
		Instance.ScrollPosY = min(Instance.ScrollPosY, YSize)
	end

	local XRatio, YRatio = 0.0, 0.0
	if XSize ~= 0.0 then
		XRatio = max(Instance.ScrollPosX / XSize, 0.0)
	end
	if YSize ~= 0.0 then
		YRatio = max(Instance.ScrollPosY / YSize, 0.0)
	end

	local TX = max(Instance.ContentW - Instance.W, 0.0) * -XRatio
	local TY = max(Instance.ContentH - Instance.H, 0.0) * -YRatio
	Instance.Transform:setTransformation(floor(TX), floor(TY))
end

local function DrawScrollBars(Instance)
	if not Instance.HasScrollX and not Instance.HasScrollY then
		return
	end

	if HotInstance ~= Instance and ScrollInstance ~= Instance then
		local dt = love.timer.getDelta()
		Instance.ScrollAlphaX = max(Instance.ScrollAlphaX - dt, 0.0)
		Instance.ScrollAlphaY = max(Instance.ScrollAlphaY - dt, 0.0)
	else
		Instance.ScrollAlphaX = 1.0
		Instance.ScrollAlphaY = 1.0
	end

	if Instance.HasScrollX then
		local XSize = GetXScrollSize(Instance)
		local Color = Utility.MakeColor(Style.ScrollBarColor)
		if Instance.HoverScrollX or Instance.IsScrollingX then
			Color = Utility.MakeColor(Style.ScrollBarHoveredColor)
		end
		Color[4] = Instance.ScrollAlphaX
		local XPos = Instance.ScrollPosX
		DrawCommands.Rectangle('fill', Instance.X + XPos, Instance.Y + Instance.H - ScrollPad - ScrollBarSize, XSize, ScrollBarSize, Color, Style.ScrollBarRounding)
	end

	if Instance.HasScrollY then
		local YSize = GetYScrollSize(Instance)
		local Color = Utility.MakeColor(Style.ScrollBarColor)
		if Instance.HoverScrollY or Instance.IsScrollingY then
			Color = Utility.MakeColor(Style.ScrollBarHoveredColor)
		end
		Color[4] = Instance.ScrollAlphaY
		local YPos = Instance.ScrollPosY
		DrawCommands.Rectangle('fill', Instance.X + Instance.W - ScrollPad - ScrollBarSize, Instance.Y + YPos, ScrollBarSize, YSize, Color, Style.ScrollBarRounding)
	end
end

local function GetInstance(Id)
	if Id == nil then
		return ActiveInstance
	end

	if Instances[Id] == nil then
		local Instance = {}
		Instance.Id = Id
		Instance.X = 0.0
		Instance.Y = 0.0
		Instance.W = 0.0
		Instance.H = 0.0
		Instance.SX = 0.0
		Instance.SY = 0.0
		Instance.ContentW = 0.0
		Instance.ContentH = 0.0
		Instance.HasScrollX = false
		Instance.HasScrollY = false
		Instance.HoverScrollX = false
		Instance.HoverScrollY = false
		Instance.IsScrollingX = false
		Instance.IsScrollingY = false
		Instance.ScrollPosX = 0.0
		Instance.ScrollPosY = 0.0
		Instance.ScrollAlphaX = 0.0
		Instance.ScrollAlphaY = 0.0
		Instance.Intersect = false
		Instance.AutoSizeContent = false
		Instance.Transform = love.math.newTransform()
		Instance.Transform:reset()
		Instances[Id] = Instance
	end
	return Instances[Id]
end

function Region.Begin(Id, Options)
	Options = Options == nil and {} or Options
	Options.X = Options.X == nil and 0.0 or Options.X
	Options.Y = Options.Y == nil and 0.0 or Options.Y
	Options.W = Options.W == nil and 0.0 or Options.W
	Options.H = Options.H == nil and 0.0 or Options.H
	Options.SX = Options.SX == nil and Options.X or Options.SX
	Options.SY = Options.SY == nil and Options.Y or Options.SY
	Options.ContentW = Options.ContentW == nil and 0.0 or Options.ContentW
	Options.ContentH = Options.ContentH == nil and 0.0 or Options.ContentH
	Options.AutoSizeContent = Options.AutoSizeContent == nil and false or Options.AutoSizeContent
	Options.BgColor = Options.BgColor == nil and Style.WindowBackgroundColor or Options.BgColor
	Options.NoOutline = Options.NoOutline == nil and false or Options.NoOutline
	Options.NoBackground = Options.NoBackground == nil and false or Options.NoBackground
	Options.IsObstructed = Options.IsObstructed == nil and false or Options.IsObstructed
	Options.Intersect = Options.Intersect == nil and false or Options.Intersect
	Options.IgnoreScroll = Options.IgnoreScroll == nil and false or Options.IgnoreScroll
	Options.MouseX = Options.MouseX == nil and 0.0 or Options.MouseX
	Options.MouseY = Options.MouseY == nil and 0.0 or Options.MouseY
	Options.ResetContent = Options.ResetContent == nil and false or Options.ResetContent
	Options.Rounding = Options.Rounding == nil and 0.0 or Options.Rounding

	local Instance = GetInstance(Id)
	Instance.X = Options.X
	Instance.Y = Options.Y
	Instance.W = Options.W
	Instance.H = Options.H
	Instance.SX = Options.SX
	Instance.SY = Options.SY
	Instance.Intersect = Options.Intersect
	Instance.IgnoreScroll = Options.IgnoreScroll
	Instance.MouseX = Options.MouseX
	Instance.MouseY = Options.MouseY
	Instance.AutoSizeContent = Options.AutoSizeContent

	if Options.ResetContent then
		Instance.ContentW = 0.0
		Instance.ContentH = 0.0
	end

	if not Options.AutoSizeContent then
		Instance.ContentW = Options.ContentW
		Instance.ContentH = Options.ContentH
	end

	ActiveInstance = Instance
	table.insert(Stack, 1, ActiveInstance)

	UpdateScrollBars(Instance, Options.IsObstructed)

	if Options.AutoSizeContent then
		Instance.ContentH = 0.0
		Instance.ContentW = 0.0
	end

	if HotInstance == Instance and (not Contains(Instance, Instance.MouseX, Instance.MouseY) or Options.IsObstructed) then
		HotInstance = nil
	end

	if not Options.IsObstructed then
		if Contains(Instance, Instance.MouseX, Instance.MouseY) or (Instance.HoverScrollX or Instance.HoverScrollY) then
			if ScrollInstance == nil then
				HotInstance = Instance
			else
				HotInstance = ScrollInstance
			end
		end
	end

	if not Options.NoBackground then
		DrawCommands.Rectangle('fill', Instance.X, Instance.Y, Instance.W, Instance.H, Options.BgColor, Options.Rounding)
	end
	if not Options.NoOutline then
		DrawCommands.Rectangle('line', Instance.X, Instance.Y, Instance.W, Instance.H, nil, Options.Rounding)
	end
	DrawCommands.TransformPush()
	DrawCommands.ApplyTransform(Instance.Transform)
	Region.ApplyScissor()
end

function Region.End()
	DrawCommands.TransformPop()
	DrawScrollBars(ActiveInstance)

	if HotInstance == ActiveInstance
		and WheelInstance == nil 
		and (WheelX ~= 0.0 or WheelY ~= 0.0)
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

function Region.IsHoverScrollBar(Id)
	local Instance = GetInstance(Id)
	if Instance ~= nil then
		return Instance.HoverScrollX or Instance.HoverScrollY
	end
	return false
end

function Region.Translate(Id, X, Y)
	local Instance = GetInstance(Id)
	if Instance ~= nil then
		Instance.Transform:translate(X, Y)
		local TX, TY = Instance.Transform:inverseTransformPoint(0, 0)

		if not Instance.IgnoreScroll then
			if X ~= 0.0 and Instance.HasScrollX then
				local XSize = Instance.W - GetXScrollSize(Instance)
				local ContentW = Instance.ContentW - Instance.W

				if Instance.HasScrollY then
					XSize = XSize - ScrollPad - ScrollBarSize
				end

				XSize = max(XSize, 0.0)

				Instance.ScrollPosX = (TX / ContentW) * XSize
				Instance.ScrollPosX = max(Instance.ScrollPosX, 0.0)
				Instance.ScrollPosX = min(Instance.ScrollPosX, XSize)
			end

			if Y ~= 0.0 and Instance.HasScrollY then
				local YSize = Instance.H - GetYScrollSize(Instance)

				if Instance.HasScrollX then
					YSize = YSize - ScrollPad - ScrollBarSize
				end

				YSize = max(YSize, 0.0)

				local ContentH = Instance.ContentH - Instance.H

				Instance.ScrollPosY = (TY / ContentH) * YSize
				Instance.ScrollPosY = max(Instance.ScrollPosY, 0.0)
				Instance.ScrollPosY = min(Instance.ScrollPosY, YSize)
			end
		end
	end
end

function Region.Transform(Id, X, Y)
	local Instance = GetInstance(Id)
	if Instance ~= nil then
		return Instance.Transform:transformPoint(X, Y)
	end
	return X, Y
end

function Region.InverseTransform(Id, X, Y)
	local Instance = GetInstance(Id)
	if Instance ~= nil then
		return Instance.Transform:inverseTransformPoint(X, Y)
	end
	return X, Y
end

function Region.ResetTransform(Id)
	local Instance = GetInstance(Id)
	if Instance ~= nil then
		Instance.Transform:reset()
		Instance.ScrollPosX = 0.0
		Instance.ScrollPosY = 0.0
	end
end

function Region.IsActive(Id)
	if ActiveInstance ~= nil then
		return ActiveInstance.Id == Id
	end
	return false
end

function Region.AddItem(X, Y, W, H)
	if ActiveInstance ~= nil and ActiveInstance.AutoSizeContent then
		local NewW = X + W - ActiveInstance.X
		local NewH = Y + H - ActiveInstance.Y
		ActiveInstance.ContentW = max(ActiveInstance.ContentW, NewW)
		ActiveInstance.ContentH = max(ActiveInstance.ContentH, NewH)
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
	return 0.0, 0.0, 0.0, 0.0
end

function Region.GetContentSize()
	if ActiveInstance ~= nil then
		return ActiveInstance.ContentW, ActiveInstance.ContentH
	end
	return 0.0, 0.0
end

function Region.Contains(X, Y)
	if ActiveInstance ~= nil then
		return ActiveInstance.X <= X and X <= ActiveInstance.X + ActiveInstance.W and ActiveInstance.Y <= Y and Y <= ActiveInstance.Y + ActiveInstance.H
	end
	return false
end

function Region.ResetContentSize(Id)
	local Instance = GetInstance(Id)
	if Instance ~= nil then
		Instance.ContentW = 0.0
		Instance.ContentH = 0.0
	end
end

function Region.GetScrollPad()
	return ScrollPad
end

function Region.GetScrollBarSize()
	return ScrollBarSize
end

function Region.WheelMoved(X, Y)
	WheelX = X * WheelSpeed
	WheelY = Y * WheelSpeed
end

function Region.GetWheelDelta()
	return WheelX, WheelY
end

function Region.IsScrolling(Id)
	if Id ~= nil then
		local Instance = GetInstance(Id)
		return ScrollInstance == Instance or WheelInstance == Instance
	end

	return ScrollInstance ~= nil or WheelInstance ~= nil
end

function Region.GetHotInstanceId()
	if HotInstance ~= nil then
		return HotInstance.Id
	end

	return ''
end

function Region.ClearHotInstance(Id)
	if HotInstance ~= nil then
		if Id ~= nil then
			if HotInstance.Id == Id then
				HotInstance = nil
			end
		else
			HotInstance = nil
		end
	end
end

function Region.GetInstanceIds()
	local Result = {}

	for K, V in pairs(Instances) do
		table.insert(Result, K)
	end

	return Result
end

function Region.GetDebugInfo(Id)
	local Result = {}
	local Instance = nil

	for K, V in pairs(Instances) do
		if K == Id then
			Instance = V
			break
		end
	end

	table.insert(Result, "ScrollInstance: " .. (ScrollInstance ~= nil and ScrollInstance.Id or "nil"))
	table.insert(Result, "WheelInstance: " .. (WheelInstance ~= nil and WheelInstance.Id or "nil"))
	table.insert(Result, "WheelX: " .. WheelX)
	table.insert(Result, "WheelY: " .. WheelY)
	table.insert(Result, "Wheel Speed: " .. WheelSpeed)

	if Instance ~= nil then
		table.insert(Result, "Id: " .. Instance.Id)
		table.insert(Result, "W: " .. Instance.W)
		table.insert(Result, "H: " .. Instance.H)
		table.insert(Result, "ContentW: " .. Instance.ContentW)
		table.insert(Result, "ContentH: " .. Instance.ContentH)
		table.insert(Result, "ScrollPosX: " .. Instance.ScrollPosX)
		table.insert(Result, "ScrollPosY: " .. Instance.ScrollPosY)

		local TX, TY = Instance.Transform:transformPoint(0, 0)
		table.insert(Result, "TX: " .. TX)
		table.insert(Result, "TY: " .. TY)
		table.insert(Result, "Max TX: " .. Instance.ContentW - Instance.W)
		table.insert(Result, "Max TY: " .. Instance.ContentH - Instance.H)
	end

	return Result
end

function Region.SetWheelSpeed(Speed)
	WheelSpeed = Speed == nil and 3.0 or Speed
end

function Region.GetWheelSpeed()
	return WheelSpeed
end

return Region
