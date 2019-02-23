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

local Cursor = require(SLAB_PATH .. ".Internal.Core.Cursor")
local DrawCommands = require(SLAB_PATH .. ".Internal.Core.DrawCommands")
local MenuState = require(SLAB_PATH .. ".Internal.UI.MenuState")
local Mouse = require(SLAB_PATH .. ".Internal.Input.Mouse")
local Style = require(SLAB_PATH .. ".Style")
local Utility = require(SLAB_PATH .. ".Internal.Core.Utility")

local Window = {}

local Instances = {}
local Stack = {}
local PendingStack = {}
local ActiveInstance = nil
local FocusedInstance = nil
local TopInstances = nil

local ScrollPad = 3.0
local ScrollBarSize = 10.0
local WheelX = 0.0
local WheelY = 0.0
local WheelSpeed = 3.0

local SizerType =
{
	None = 0,
	N = 1,
	E = 2,
	S = 3,
	W = 4,
	NE = 5,
	SE = 6,
	SW = 7,
	NW = 8
}

local function GetXScrollSize(Instance)
	if Instance ~= nil then
		return math.max(Instance.W - (Instance.ContentW - Instance.W), 20.0)
	end
	return 0.0
end

local function GetYScrollSize(Instance)
	if Instance ~= nil then
		return math.max(Instance.H - (Instance.ContentH - Instance.H), 20.0)
	end
	return 0.0
end

local function NewInstance(Id)
	local Instance = {}
	Instance.Id = Id
	Instance.X = 0.0
	Instance.Y = 0.0
	Instance.W = 200.0
	Instance.H = 200.0
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
	Instance.Title = ""
	Instance.IsMoving = false
	Instance.TitleDeltaX = 0.0
	Instance.TitleDeltaY = 0.0
	Instance.AllowMove = true
	Instance.AllowResize = true
	Instance.AllowFocus = true
	Instance.SizerType = SizerType.None
	Instance.SizeDeltaX = 0.0
	Instance.SizeDeltaY = 0.0
	Instance.DeltaContentW = 0.0
	Instance.DeltaContentH = 0.0
	Instance.BackgroundColor = Style.WindowBackgroundColor
	Instance.Transform = love.math.newTransform()
	Instance.Transform:reset()
	Instance.Border = 4.0
	Instance.CanObstruct = true
	Instance.Children = {}
	Instance.LastItem = nil
	Instance.HotItem = nil
	Instance.ContextHotItem = nil
	Instance.LastVisibleTime = 0.0
	Instance.Items = {}
	return Instance
end

local function GetInstance(Id)
	for K, V in pairs(Instances) do
		if V.Id == Id then
			return V
		end
	end
	local Instance = NewInstance(Id)
	table.insert(Instances, Instance)
	return Instance
end

local function Contains(Instance, X, Y)
	if Instance ~= nil then
		local OffsetY = 0.0
		if Instance.Title ~= "" then
			OffsetY = Style.Font:getHeight()
		end
		return Instance.X <= X and X <= Instance.X + Instance.W and Instance.Y - OffsetY <= Y and Y <= Instance.Y + Instance.H
	end
	return false
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

local function UpdateScrollBars(Instance)
	Instance.HasScrollX = Instance.ContentW > Instance.W
	Instance.HasScrollY = Instance.ContentH > Instance.H

	local X, Y = Mouse.Position()
	Instance.HoverScrollX, Instance.HoverScrollY = IsScrollHovered(Instance, X, Y)
	local XSize = Instance.W - GetXScrollSize(Instance)
	local YSize = Instance.H - GetYScrollSize(Instance)

	local IsMouseDragging = Mouse.IsDragging(1)
	local IsMouseReleased = Mouse.IsReleased(1)

	local DeltaX, DeltaY = Mouse.GetDelta()

	if not Window.IsObstructed(X, Y) and Contains(Instance, X, Y) or Instance.HoverScrollX or Instance.HoverScrollY then
		Instance.ScrollAlphaX = 1.0
		Instance.ScrollAlphaY = 1.0

		if WheelX ~= 0.0 then
			Instance.ScrollPosX = Instance.ScrollPosX + WheelX
			Instance.IsScrollingX = true
			IsMouseDragging = true
			IsMouseReleased = true
			WheelX = 0.0
		end

		if WheelY ~= 0.0 then
			Instance.ScrollPosY = Instance.ScrollPosY - WheelY
			Instance.IsScrollingY = true
			IsMouseDragging = true
			IsMouseReleased = true
			WheelY = 0.0
		end
	else
		local dt = love.timer.getDelta()
		Instance.ScrollAlphaX = math.max(Instance.ScrollAlphaX - dt, 0.0)
		Instance.ScrollAlphaY = math.max(Instance.ScrollAlphaY - dt, 0.0)
	end

	if Instance.HasScrollX then
		if Instance.HasScrollY then
			XSize = XSize - ScrollBarSize - ScrollPad
		end
		if Instance.HoverScrollX or Instance.IsScrollingX then
			MenuState.RequestClose = false

			if IsMouseDragging then
				Instance.IsScrollingX = true

				Instance.ScrollPosX = math.max(Instance.ScrollPosX + DeltaX, 0.0)
				Instance.ScrollPosX = math.min(Instance.ScrollPosX, XSize)
			end

			if Instance.IsScrollingX and IsMouseReleased then
				Instance.IsScrollingX = false
			end
		end
	end

	if Instance.HasScrollY then
		if Instance.HasScrollX then
			YSize = YSize - ScrollBarSize - ScrollPad
		end
		if Instance.HoverScrollY or Instance.IsScrollingY then
			MenuState.RequestClose = false

			if IsMouseDragging then
				Instance.IsScrollingY = true
				
				Instance.ScrollPosY = math.max(Instance.ScrollPosY + DeltaY, 0.0)
				Instance.ScrollPosY = math.min(Instance.ScrollPosY, YSize)
			end

			if Instance.IsScrollingY and IsMouseReleased then
				Instance.IsScrollingY = false
			end
		end
	end

	local XRatio, YRatio = 0.0, 0.0
	if XSize ~= 0.0 then
		XRatio = math.max(Instance.ScrollPosX / XSize, 0.0)
	end
	if YSize ~= 0.0 then
		YRatio = math.max(Instance.ScrollPosY / YSize, 0.0)
	end

	local TX = math.max(Instance.ContentW - Instance.W, 0.0) * -XRatio
	local TY = math.max(Instance.ContentH - Instance.H, 0.0) * -YRatio
	Instance.Transform:setTransformation(TX, TY)
end

local function DrawScrollBars(Instance)
	if not Instance.HasScrollX and not Instance.HasScrollY then
		return
	end

	if Instance.HasScrollX then
		local XSize = GetXScrollSize(Instance)
		local Color = Utility.MakeColor(Style.ScrollBarColor)
		if Instance.HoverScrollX or Instance.IsScrollingX then
			Color = Utility.MakeColor(Style.ScrollBarHoveredColor)
		end
		Color[4] = Instance.ScrollAlphaX
		local XPos = Instance.ScrollPosX
		DrawCommands.Rectangle('fill', Instance.X + XPos, Instance.Y + Instance.H - ScrollPad - ScrollBarSize, XSize, ScrollBarSize, Color)
	end

	if Instance.HasScrollY then
		local YSize = GetYScrollSize(Instance)
		local Color = Utility.MakeColor(Style.ScrollBarColor)
		if Instance.HoverScrollY or Instance.IsScrollingY then
			Color = Utility.MakeColor(Style.ScrollBarHoveredColor)
		end
		Color[4] = Instance.ScrollAlphaY
		local YPos = Instance.ScrollPosY
		DrawCommands.Rectangle('fill', Instance.X + Instance.W - ScrollPad - ScrollBarSize, Instance.Y + YPos, ScrollBarSize, YSize, Color)
	end
end

local function UpdateTitleBar(Instance)
	if Instance ~= nil and Instance.Title ~= "" and Instance.SizerType == SizerType.None and Instance.AllowMove then
		local W = Instance.W
		local H = Style.Font:getHeight()
		local X = Instance.X
		local Y = Instance.Y - H

		local MouseX, MouseY = Mouse.Position()

		if Mouse.IsClicked(1) and not Window.IsObstructed(MouseX, MouseY) then
			if X <= MouseX and MouseX <= X + W and Y <= MouseY and MouseY <= Y + H then
				Instance.IsMoving = true
				if Instance.AllowFocus then
					FocusedInstance = Instance
				end
			end
		elseif Mouse.IsReleased(1) then
			Instance.IsMoving = false
		end

		if Instance.IsMoving then
			local DeltaX, DeltaY = Mouse.GetDelta()
			Instance.TitleDeltaX = Instance.TitleDeltaX + DeltaX
			Instance.TitleDeltaY = Instance.TitleDeltaY + DeltaY
		end
	end
end

local function UpdateSize(Instance)
	if Instance ~= nil and Instance.AllowResize then
		if Instance.HoverScrollX or Instance.HoverScrollY then
			return
		end

		local X = Instance.X
		local Y = Instance.Y
		local W = Instance.W
		local H = Instance.H

		if Instance.Title ~= "" then
			local Offset = Style.Font:getHeight()
			Y = Y - Offset
			H = H + Offset
		end

		local MouseX, MouseY = Mouse.Position()
		local NewSizerType = SizerType.None

		if X <= MouseX and MouseX <= X + W and Y <= MouseY and MouseY <= Y + H then
			if X <= MouseX and MouseX <= X + ScrollPad and Y <= MouseY and MouseY <= Y + ScrollPad then
				Mouse.SetCursor('sizenwse')
				NewSizerType = SizerType.NW
			elseif X + W - ScrollPad <= MouseX and MouseX <= X + W and Y <= MouseY and MouseY <= Y + ScrollPad then
				Mouse.SetCursor('sizenesw')
				NewSizerType = SizerType.NE
			elseif X + W - ScrollPad <= MouseX and MouseX <= X + W and Y + H - ScrollPad <= MouseY and MouseY <= Y + H then
				Mouse.SetCursor('sizenwse')
				NewSizerType = SizerType.SE
			elseif X <= MouseX and MouseX <= X + ScrollPad and Y + H - ScrollPad <= MouseY and MouseY <= Y + H then
				Mouse.SetCursor('sizenesw')
				NewSizerType = SizerType.SW
			elseif X <= MouseX and MouseX <= X + ScrollPad then
				Mouse.SetCursor('sizewe')
				NewSizerType = SizerType.W
			elseif X + W - ScrollPad <= MouseX and MouseX <= X + W then
				Mouse.SetCursor('sizewe')
				NewSizerType = SizerType.E
			elseif Y <= MouseY and MouseY <= Y + ScrollPad then
				Mouse.SetCursor('sizens')
				NewSizerType = SizerType.N
			elseif Y + H - ScrollPad <= MouseY and MouseY <= Y + H then
				Mouse.SetCursor('sizens')
				NewSizerType = SizerType.S
			end
		end

		if Mouse.IsClicked(1) then
			Instance.SizerType = NewSizerType
		elseif Mouse.IsReleased(1) then
			Instance.SizerType = SizerType.None
		end

		if Instance.SizerType ~= SizerType.None then
			local DeltaX, DeltaY = Mouse.GetDelta()
			if Instance.SizerType == SizerType.N then
				Instance.TitleDeltaY = Instance.TitleDeltaY + DeltaY
				Instance.SizeDeltaY = Instance.SizeDeltaY - DeltaY
			elseif Instance.SizerType == SizerType.E then
				Instance.SizeDeltaX = Instance.SizeDeltaX + DeltaX
			elseif Instance.SizerType == SizerType.S then
				Instance.SizeDeltaY = Instance.SizeDeltaY + DeltaY
			elseif Instance.SizerType == SizerType.W then
				Instance.TitleDeltaX = Instance.TitleDeltaX + DeltaX
				Instance.SizeDeltaX = Instance.SizeDeltaX - DeltaX
			elseif Instance.SizerType == SizerType.NW then
				Instance.TitleDeltaX = Instance.TitleDeltaX + DeltaX
				Instance.SizeDeltaX = Instance.SizeDeltaX - DeltaX
				Instance.TitleDeltaY = Instance.TitleDeltaY + DeltaY
				Instance.SizeDeltaY = Instance.SizeDeltaY - DeltaY
			elseif Instance.SizerType == SizerType.NE then
				Instance.SizeDeltaX = Instance.SizeDeltaX + DeltaX
				Instance.TitleDeltaY = Instance.TitleDeltaY + DeltaY
				Instance.SizeDeltaY = Instance.SizeDeltaY - DeltaY
			elseif Instance.SizerType == SizerType.SE then
				Instance.SizeDeltaX = Instance.SizeDeltaX + DeltaX
				Instance.SizeDeltaY = Instance.SizeDeltaY + DeltaY
			elseif Instance.SizerType == SizerType.SW then
				Instance.TitleDeltaX = Instance.TitleDeltaX + DeltaX
				Instance.SizeDeltaX = Instance.SizeDeltaX - DeltaX
				Instance.SizeDeltaY = Instance.SizeDeltaY + DeltaY
			end
		end
	end
end

local function GetHoveredInstance(Instance, X, Y)
	local Result = nil
	if Instance ~= nil then
		local Time = love.timer.getTime() - Instance.LastVisibleTime
		if Instance.CanObstruct and Contains(Instance, X, Y) and Time <= 0.25 then
			Result = Instance
			local Child = nil
			for K, V in pairs(Instance.Children) do
				Child = GetHoveredInstance(V, X, Y)
			end
			if Child ~= nil then
				Result = Child
			end
		end
	end
	return Result
end

function Window.Top()
	return ActiveInstance
end

function Window.IsObstructed(X, Y)
	local X, Y = Mouse.Position()
	local Instance = nil

	if TopInstances ~= nil then
		for K, V in pairs(TopInstances) do
			Instance = GetHoveredInstance(V, X, Y)
		end
	end

	if Instance == nil and FocusedInstance ~= nil then
		Instance = GetHoveredInstance(FocusedInstance, X, Y)
	end

	if Instance == nil then
		for I, V in ipairs(Instances) do
			local Child = GetHoveredInstance(V, X, Y)
			if Child ~= nil then
				Instance = Child
			end
		end
	end

	if Instance ~= nil then
		if Instance.HoverScrollX or Instance.HoverScrollY then
			return true
		end

		return ActiveInstance ~= Instance
	end

	return false
end

function Window.IsObstructedAtMouse()
	local X, Y = Mouse.Position()
	return Window.IsObstructed(X, Y)
end

function Window.Reset()
	Stack = {}
	PendingStack = {}
	ActiveInstance = GetInstance('Global')
	ActiveInstance.CanObstruct = false
	ActiveInstance.W = love.graphics.getWidth()
	ActiveInstance.H = love.graphics.getHeight()
	ActiveInstance.Border = 0.0
	table.insert(PendingStack, 1, ActiveInstance)
end

function Window.Begin(Id, Options)
	Options = Options == nil and {} or Options
	Options.X = Options.X == nil and 50.0 or Options.X
	Options.Y = Options.Y == nil and 50.0 or Options.Y
	Options.W = Options.W == nil and 200.0 or Options.W
	Options.H = Options.H == nil and 200.0 or Options.H
	Options.ContentW = Options.ContentW == nil and 0.0 or Options.ContentW
	Options.ContentH = Options.ContentH == nil and 0.0 or Options.ContentH
	Options.BgColor = Options.BgColor == nil and Style.WindowBackgroundColor or Options.BgColor
	Options.Title = Options.Title == nil and "" or Options.Title
	Options.AllowMove = Options.AllowMove == nil and true or Options.AllowMove
	Options.AllowResize = Options.AllowResize == nil and true or Options.AllowResize
	Options.AllowFocus = Options.AllowFocus == nil and true or Options.AllowFocus
	Options.Border = Options.Border == nil and 4.0 or Options.Border
	Options.NoOutline = Options.NoOutline == nil and false or Options.NoOutline
	Options.IsMenuBar = Options.IsMenuBar == nil and false or Options.IsMenuBar
	Options.AutoSizeWindow = Options.AutoSizeWindow == nil and true or Options.AutoSizeWindow
	Options.AutoSizeWindowW = Options.AutoSizeWindowW == nil and Options.AutoSizeWindow or Options.AutoSizeWindowW
	Options.AutoSizeWindowH = Options.AutoSizeWindowH == nil and Options.AutoSizeWindow or Options.AutoSizeWindowH
	Options.AutoSizeContent = Options.AutoSizeContent == nil and true or Options.AutoSizeContent
	Options.Layer = Options.Layer == nil and 'Normal' or Options.Layer
	Options.ResetPosition = Options.ResetPosition == nil and false or Options.ResetPosition
	Options.ResetSize = Options.ResetSize == nil and false or Options.ResetSize
	Options.ResetContent = Options.ResetContent == nil and false or Options.ResetContent
	Options.ResetLayout = Options.ResetLayout == nil and false or Options.ResetLayout

	local Instance = GetInstance(Id)
	table.insert(Stack, 1, Instance)
	table.insert(PendingStack, 1, Instance)

	if ActiveInstance ~= nil then
		ActiveInstance.Children[Id] = Instance
	end

	ActiveInstance = Instance
	if Options.ResetWindowSize then
		ActiveInstance.SizeDeltaX = 0.0
		ActiveInstance.SizeDeltaY = 0.0
	end

	if Options.AutoSizeWindowW then
		Options.W = 0.0
	end

	if Options.AutoSizeWindowH then
		Options.H = 0.0
	end

	if Options.ResetPosition or Options.ResetLayout then
		ActiveInstance.TitleDeltaX = 0.0
		ActiveInstance.TitleDeltaY = 0.0
	end

	if Options.ResetSize or Options.ResetLayout then
		ActiveInstance.SizeDeltaX = 0.0
		ActiveInstance.SizeDeltaY = 0.0
	end

	if Options.ResetContent or Options.ResetLayout then
		ActiveInstance.DeltaContentW = 0.0
		ActiveInstance.DeltaContentH = 0.0
	end

	ActiveInstance.X = ActiveInstance.TitleDeltaX + Options.X
	ActiveInstance.Y = ActiveInstance.TitleDeltaY + Options.Y
	ActiveInstance.W = ActiveInstance.SizeDeltaX + Options.W + Options.Border
	ActiveInstance.H = ActiveInstance.SizeDeltaY + Options.H + Options.Border
	ActiveInstance.ContentW = Options.ContentW
	ActiveInstance.ContentH = Options.ContentH
	ActiveInstance.BackgroundColor = Options.BgColor
	ActiveInstance.Title = Options.Title
	ActiveInstance.AllowMove = Options.AllowMove
	ActiveInstance.AllowResize = Options.AllowResize and not Options.AutoSizeWindow
	ActiveInstance.AllowFocus = Options.AllowFocus
	ActiveInstance.Border = Options.Border
	ActiveInstance.IsMenuBar = Options.IsMenuBar
	ActiveInstance.AutoSizeWindow = Options.AutoSizeWindow
	ActiveInstance.AutoSizeWindowW = Options.AutoSizeWindowW
	ActiveInstance.AutoSizeWindowH = Options.AutoSizeWindowH
	ActiveInstance.AutoSizeContent = Options.AutoSizeContent
	ActiveInstance.Layer = ActiveInstance == FocusedInstance and 'Focused' or Options.Layer
	ActiveInstance.HotItem = nil
	ActiveInstance.LastVisibleTime = love.timer.getTime()

	if ActiveInstance.AutoSizeContent then
		ActiveInstance.ContentW = math.max(Options.ContentW, ActiveInstance.DeltaContentW)
		ActiveInstance.ContentH = math.max(Options.ContentH, ActiveInstance.DeltaContentH)
	end

	local OffsetY = 0.0
	if ActiveInstance.Title ~= "" then
		OffsetY = Style.Font:getHeight()
		ActiveInstance.Y = ActiveInstance.Y + OffsetY

		local TitleW = Style.Font:getWidth(ActiveInstance.Title)
		Window.AddItem(ActiveInstance.X, ActiveInstance.Y, TitleW, 0.0)
	end

	UpdateSize(ActiveInstance)
	UpdateScrollBars(ActiveInstance)
	UpdateTitleBar(ActiveInstance)

	local MouseX, MouseY = Mouse.Position()
	if ActiveInstance.AllowFocus and Mouse.IsClicked(1) and not Window.IsObstructed(MouseX, MouseY) then
		FocusedInstance = ActiveInstance
	end

	DrawCommands.SetLayer(ActiveInstance.Layer)

	Cursor.SetPosition(ActiveInstance.X + ActiveInstance.Border, ActiveInstance.Y + ActiveInstance.Border)
	Cursor.SetAnchor(ActiveInstance.X + ActiveInstance.Border, ActiveInstance.Y + ActiveInstance.Border)

	DrawCommands.Begin()
	DrawCommands.Scissor(ActiveInstance.X, ActiveInstance.Y - OffsetY, ActiveInstance.W, ActiveInstance.H + OffsetY)
	DrawCommands.Rectangle('fill', ActiveInstance.X, ActiveInstance.Y, ActiveInstance.W, ActiveInstance.H, ActiveInstance.BackgroundColor)
	if not Options.NoOutline then
		DrawCommands.Rectangle('line', ActiveInstance.X, ActiveInstance.Y - OffsetY, ActiveInstance.W, ActiveInstance.H + OffsetY)
	end
	DrawCommands.TransformPush()
	DrawCommands.ApplyTransform(ActiveInstance.Transform)
end

function Window.End()
	if ActiveInstance ~= nil then
		DrawCommands.TransformPop()
		if ActiveInstance.Title ~= "" then
			local OffsetY = Style.Font:getHeight()
			local TitleX = math.floor(ActiveInstance.X + (ActiveInstance.W * 0.5) - (Style.Font:getWidth(ActiveInstance.Title) * 0.5))
			local TitleColor = ActiveInstance.BackgroundColor
			if ActiveInstance == FocusedInstance then
				TitleColor = Style.WindowTitleFocusedColor
			end
			DrawCommands.Rectangle('fill', ActiveInstance.X, ActiveInstance.Y - OffsetY, ActiveInstance.W, OffsetY, TitleColor)
			DrawCommands.Print(ActiveInstance.Title, TitleX, ActiveInstance.Y - OffsetY)
			DrawCommands.Line(ActiveInstance.X, ActiveInstance.Y, ActiveInstance.X + ActiveInstance.W, ActiveInstance.Y, 0.5)
		end
		DrawScrollBars(ActiveInstance)
		DrawCommands.End()
		table.remove(PendingStack, 1)

		ActiveInstance = nil
		if #PendingStack > 0 then
			ActiveInstance = PendingStack[1]
			Cursor.SetAnchor(ActiveInstance.X + ActiveInstance.Border, ActiveInstance.Y + ActiveInstance.Border)
			DrawCommands.SetLayer(ActiveInstance.Layer)
		end
	end
end

function Window.SetCanObstruct(CanObstruct)
	if ActiveInstance ~= nil then
		ActiveInstance.CanObstruct = CanObstruct
	end
end

function Window.GetMousePosition()
	local X, Y = Mouse.Position()
	if ActiveInstance ~= nil then
		X, Y = ActiveInstance.Transform:inverseTransformPoint(X, Y)
	end
	return X, Y
end

function Window.GetWidth()
	if ActiveInstance ~= nil then
		return ActiveInstance.W
	end
	return 0.0
end

function Window.GetHeight()
	if ActiveInstance ~= nil then
		return ActiveInstance.H
	end
	return 0.0
end

function Window.GetBorder()
	if ActiveInstance ~= nil then
		return ActiveInstance.Border
	end
	return 0.0
end

function Window.GetBounds()
	if ActiveInstance ~= nil then
		local OffsetY = ActiveInstance.Title ~= "" and Style.Font:getHeight() or 0.0
		return ActiveInstance.X, ActiveInstance.Y - OffsetY, ActiveInstance.W, ActiveInstance.H + OffsetY
	end
	return 0.0, 0.0, 0.0, 0.0
end

function Window.GetPosition()
	if ActiveInstance ~= nil then
		return ActiveInstance.X, ActiveInstance.Y
	end
	return 0.0, 0.0
end

function Window.GetSize()
	if ActiveInstance ~= nil then
		return ActiveInstance.W, ActiveInstance.H
	end
	return 0.0, 0.0
end

function Window.GetContentSize()
	if ActiveInstance ~= nil then
		return ActiveInstance.ContentW, ActiveInstance.ContentH
	end
	return 0.0, 0.0
end

function Window.IsMenuBar()
	if ActiveInstance ~= nil then
		return ActiveInstance.IsMenuBar
	end
	return false
end

function Window.GetId()
	if ActiveInstance ~= nil then
		return ActiveInstance.Id
	end
	return ''
end

function Window.GetWindowAtMouse()
	local X, Y = Mouse.Position()
	local Instance = nil
	for I, V in ipairs(Instances) do
		local Child = GetHoveredInstance(V, X, Y)
		if Child ~= nil then
			Instance = Child
		end
	end
	return Instance == nil and 'None' or Instance.Id
end

function Window.AddItem(X, Y, W, H, Id)
	if ActiveInstance ~= nil then
		ActiveInstance.LastItem = Id
		if ActiveInstance.AutoSizeWindowW then
			ActiveInstance.SizeDeltaX = math.max(ActiveInstance.SizeDeltaX, X + W + ActiveInstance.Border - ActiveInstance.X)
		end

		if ActiveInstance.AutoSizeWindowH then
			ActiveInstance.SizeDeltaY = math.max(ActiveInstance.SizeDeltaY, Y + H + ActiveInstance.Border - ActiveInstance.Y)
		end

		if ActiveInstance.AutoSizeContent then
			ActiveInstance.DeltaContentW = math.max(ActiveInstance.DeltaContentW, X + W + ActiveInstance.Border - ActiveInstance.X)
			ActiveInstance.DeltaContentH = math.max(ActiveInstance.DeltaContentH, Y + H + ActiveInstance.Border - ActiveInstance.Y)
		end
	end
end

function Window.WheelMoved(X, Y)
	WheelX = X * WheelSpeed
	WheelY = Y * WheelSpeed
end

function Window.TransformPoint(X, Y)
	if ActiveInstance ~= nil then
		return ActiveInstance.Transform:transformPoint(X, Y)
	end
	return 0.0, 0.0
end

function Window.ResetContentSize()
	if ActiveInstance ~= nil then
		ActiveInstance.DeltaContentW = 0.0
		ActiveInstance.DeltaContentH = 0.0
	end
end

function Window.SetHotItem(HotItem)
	if ActiveInstance ~= nil then
		ActiveInstance.HotItem = HotItem
	end
end

function Window.SetContextHotItem(HotItem)
	if ActiveInstance ~= nil then
		ActiveInstance.ContextHotItem = HotItem
	end
end

function Window.GetHotItem()
	if ActiveInstance ~= nil then
		return ActiveInstance.HotItem
	end
	return nil
end

function Window.GetContextHotItem()
	if ActiveInstance ~= nil then
		return ActiveInstance.ContextHotItem
	end
	return nil
end

function Window.IsMouseHovered()
	if ActiveInstance ~= nil then
		local X, Y = Mouse.Position()
		return Contains(ActiveInstance, X, Y)
	end
	return false
end

function Window.GetItemId(Id)
	if ActiveInstance ~= nil then
		if ActiveInstance.Items[Id] == nil then
			ActiveInstance.Items[Id] = ActiveInstance.Id .. '.' .. Id
		end
		return ActiveInstance.Items[Id]
	end
	return nil
end

function Window.GetLastItem()
	if ActiveInstance ~= nil then
		return ActiveInstance.LastItem
	end
	return nil
end

function Window.PushToTop()
	if TopInstances == nil then
		TopInstances = {}
	end

	if ActiveInstance ~= nil then
		TopInstances[ActiveInstance.Id] = ActiveInstance
	end
end

function Window.ClearTopInstances()
	TopInstances = nil
end

function Window.Validate()
	if #PendingStack > 1 then
		assert(false, "EndWindow was not called for: " .. PendingStack[1].Id)
	end
end

return Window
