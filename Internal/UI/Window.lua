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
local floor = math.floor

local Cursor = require(SLAB_PATH .. ".Internal.Core.Cursor")
local Dock = require(SLAB_PATH .. '.Internal.UI.Dock')
local DrawCommands = require(SLAB_PATH .. ".Internal.Core.DrawCommands")
local MenuState = require(SLAB_PATH .. ".Internal.UI.MenuState")
local Mouse = require(SLAB_PATH .. ".Internal.Input.Mouse")
local Region = require(SLAB_PATH .. ".Internal.UI.Region")
local Stats = require(SLAB_PATH .. ".Internal.Core.Stats")
local Style = require(SLAB_PATH .. ".Style")
local Utility = require(SLAB_PATH .. ".Internal.Core.Utility")
local IdCache = require(SLAB_PATH .. ".Internal.Core.IdCache")
local Scale = require(SLAB_PATH .. ".Internal.Core.Scale")


local Window = {}

local Instances = {}
local Stack = {}
local StackLockId = nil
local PendingStack = {}
local ActiveInstance = nil
local MovingInstance = nil
local IDStack = {}
local idCache = IdCache()
local MenuBarInstance

local SizerNone = 0
local SizerN = 1
local SizerE = 2
local SizerS = 3
local SizerW = 4
local SizerNE = 5
local SizerSE = 6
local SizerSW = 7
local SizerNW = 8

local SizerCursor =
{
	[SizerNW] = 'sizenwse',
	[SizerNE] = 'sizenesw',
	[SizerSE] = 'sizenwse',
	[SizerSW] = 'sizenesw',
	[SizerW]  = 'sizewe',
	[SizerE]  = 'sizewe',
	[SizerN]  = 'sizens',
	[SizerS]  = 'sizens',
}

local EMPTY = {}

local TitleRounding = { 0, 0, 0, 0 }
local BodyRounding = { 0, 0, 0, 0 }

local function UpdateStackIndex()
	for i = 1, #Stack do
		Stack[i].StackIndex = #Stack - i + 1
	end
end

local function PushToTop(instance)
	for i, v in ipairs(Stack) do
		if instance == v then
			remove(Stack, i)
			break
		end
	end

	insert(Stack, 1, instance)

	UpdateStackIndex()
end

local function NewInstance(id)
	local instance = {
		Id = id,
		X = 0,
		Y = 0,
		W = 200,
		H = 200,
		ContentW = 0,
		ContentH = 0,
		Title = "",
		IsMoving = false,
		TitleDeltaX = 0,
		TitleDeltaY = 0,
		AllowResize = true,
		AllowFocus = true,
		SizerType = SizerNone,
		SizerFilter = nil,
		SizeDeltaX = 0,
		SizeDeltaY = 0,
		HasResized = false,
		DeltaContentW = 0,
		DeltaContentH = 0,
		BackgroundColor = Style.WindowBackgroundColor,
		Border = 4,
		Children = {},
		LastItem = nil,
		HotItem = nil,
		ContextHotItem = nil,
		Items = {},
		Layer = 'Normal',
		StackIndex = 0,
		CanObstruct = true,
		FrameNumber = 0,
		LastCursorX = 0,
		LastCursorY = 0,
		StatHandle = nil,
		IsAppearing = false,
		IsOpen = true,
		IsContentOpen = true,
		IsMinimized = false,
		NoSavedSettings = false,
		TitleId = id .. '_Title',
		TitleRegion = {
			NoBackground = true,
			NoOutline = true,
			IgnoreScroll = true,
		},
		InstanceRegion = {},
	}
	return instance
end

local function GetInstance(id)
	if id == nil then
		return ActiveInstance
	end

	for i, v in ipairs(Instances) do
		if v.Id == id then
			return v
		end
	end
	local instance = NewInstance(id)
	insert(Instances, instance)
	return instance
end

local function Contains(instance, x, y)
	if instance ~= nil then
		local titleH = instance.TitleH or 0
		return instance.X <= x and x <= instance.X + instance.W and instance.Y - titleH <= y and y <= instance.Y + instance.H
	end
	return false
end

local function UpdateTitleBar(instance, isObstructed, allowMove, constrain)
	if isObstructed and (instance.IsContentOpen == nil or instance.IsContentOpen) then
		return
	end

	if instance ~= nil and instance.Title ~= "" and instance.SizerType == SizerNone then
		local w = instance.W
		local h = instance.TitleH
		local x = instance.X
		local y = instance.Y - h
		local isTethered = Dock.IsTethered(instance.Id)

		local mouseX, mouseY = Mouse.Position()

		if Mouse.IsClicked(1) then
			if x <= mouseX and mouseX <= x + w and y <= mouseY and mouseY <= y + h then
				if allowMove then
					instance.IsMoving = true
				end

				if isTethered then
					Dock.BeginTear(instance.Id, mouseX, mouseY)
				end

				if instance.AllowFocus then
					PushToTop(instance)
				end
			end
		elseif Mouse.IsReleased(1) then
			instance.IsMoving = false

			-- Prevent window going behind MenuBar
			if MenuBarInstance then
				instance.TitleDeltaY = MenuBarInstance.H
			end
		end

		if instance.IsMoving then
			local deltaX, deltaY = Mouse.GetDelta()
			local titleDeltaX, titleDeltaY = instance.TitleDeltaX, instance.TitleDeltaY
			instance.TitleDeltaX = instance.TitleDeltaX + deltaX
			instance.TitleDeltaY = instance.TitleDeltaY + deltaY

			if constrain then
				-- Constrain the position of the window to the viewport. The position at this point in the code has the delta already applied. This delta will need to be
				-- removed to retrieve the original position, and clamp the delta based off of that posiiton.
				local originX = instance.X - titleDeltaX
				local originY = instance.Y - titleDeltaY - instance.TitleH
				instance.TitleDeltaX = Utility.Clamp(instance.TitleDeltaX, -originX, Scale.GetScreenWidth() - (originX + instance.W))
				instance.TitleDeltaY = Utility.Clamp(instance.TitleDeltaY, -originY + MenuState.MainMenuBarH, Scale.GetScreenHeight() - (originY + instance.H + instance.TitleH))
			end
		elseif isTethered then
			Dock.UpdateTear(instance.Id, mouseX, mouseY)

			-- Retrieve the cached options to calculate torn off position. The cached options contain the
			-- desired bounds for this window. The bounds that are a part of the Instance are the altered options
			-- modified by the Dock module.
			local options = Dock.GetCachedOptions(instance.Id)
			if not Dock.IsTethered(instance.Id) then
				instance.IsMoving = true

				if options ~= nil then
					-- Properly place the window at the mouse position offset by the title width/height.
					instance.TitleDeltaX = mouseX - x - floor(w * 0.25)
					instance.TitleDeltaY = mouseY - y - floor(h * 0.5)
				end
			end
		end
	end
end

local function IsSizerEnabled(instance, sizer)
	if not instance then
		return false
	end

	if #instance.SizerFilter == 0 then
		return true
	end

	for i, v in ipairs(instance.SizerFilter) do
		if v == sizer then
			return true
		end
	end

	return false
end

local function UpdateSize(instance, isObstructed)
	if not instance or not instance.AllowResize then
		return
	end

	if Region.IsHoverScrollBar(instance.Id) then
		return
	end

	if instance.SizerType == SizerNone and isObstructed then
		return
	end

	if MovingInstance ~= nil then
		return
	end

	local x, y, w, h = instance.X, instance.Y, instance.W, instance.H

	if instance.Title ~= "" then
		y = y - instance.TitleH
		h = h + instance.TitleH
	end

	local mouseX, mouseY = Mouse.Position()
	local newSizerType = SizerNone
	local scrollPad = Region.GetScrollPad()

	if x <= mouseX and mouseX <= x + w and y <= mouseY and mouseY <= y + h then
		if x <= mouseX and mouseX <= x + scrollPad and y <= mouseY and mouseY <= y + scrollPad and IsSizerEnabled(instance, "NW") then
			newSizerType = SizerNW
		elseif x + w - scrollPad <= mouseX and mouseX <= x + w and y <= mouseY and mouseY <= y + scrollPad and IsSizerEnabled(instance, "NE") then
			newSizerType = SizerNE
		elseif x + w - scrollPad <= mouseX and mouseX <= x + w and y + h - scrollPad <= mouseY and mouseY <= y + h and IsSizerEnabled(instance, "SE") then
			newSizerType = SizerSE
		elseif x <= mouseX and mouseX <= x + scrollPad and y + h - scrollPad <= mouseY and mouseY <= y + h and IsSizerEnabled(instance, "SW") then
			newSizerType = SizerSW
		elseif x <= mouseX and mouseX <= x + scrollPad and IsSizerEnabled(instance, "W") then
			newSizerType = SizerW
		elseif x + w - scrollPad <= mouseX and mouseX <= x + w and IsSizerEnabled(instance, "E") then
			newSizerType = SizerE
		elseif y <= mouseY and mouseY <= y + scrollPad and IsSizerEnabled(instance, "N") then
			newSizerType = SizerN
		elseif y + h - scrollPad <= mouseY and mouseY <= y + h and IsSizerEnabled(instance, "S") then
			newSizerType = SizerS
		end

		if SizerCursor[newSizerType] then
			Mouse.SetCursor(SizerCursor[newSizerType])
		end
	end

	if Mouse.IsClicked(1) then
		instance.SizerType = newSizerType
	elseif Mouse.IsReleased(1) then
		instance.SizerType = SizerNone
	end

	if instance.SizerType ~= SizerNone then
		local deltaX, deltaY = Mouse.GetDelta()

		if instance.W <= instance.Border then
			if (instance.SizerType == SizerW or
				instance.SizerType == SizerNW or
				instance.SizerType == SizerSW) and
				deltaX > 0 then
				deltaX = 0
			end

			if (instance.SizerType == SizerE or
				instance.SizerType == SizerNE or
				instance.SizerType == SizerSE) and
				deltaX < 0 then
				deltaX = 0
			end
		end

		if instance.H <= instance.Border then
			if (instance.SizerType == SizerN or
				instance.SizerType == SizerNW or
				instance.SizerType == SizerNE) and
				deltaY > 0 then
				deltaY = 0
			end

			if (instance.SizerType == SizerS or
				instance.SizerType == SizerSE or
				instance.SizerType == SizerSW) and
				deltaY < 0 then
				deltaY = 0
			end
		end

		if deltaX ~= 0 or deltaY ~= 0 then
			instance.HasResized = true
			instance.DeltaContentW = 0
			instance.DeltaContentH = 0
		end

		if instance.SizerType == SizerN then
			instance.TitleDeltaY = instance.TitleDeltaY + deltaY
			instance.SizeDeltaY = instance.SizeDeltaY - deltaY
		elseif instance.SizerType == SizerE then
			instance.SizeDeltaX = instance.SizeDeltaX + deltaX
		elseif instance.SizerType == SizerS then
			instance.SizeDeltaY = instance.SizeDeltaY + deltaY
		elseif instance.SizerType == SizerW then
			instance.TitleDeltaX = instance.TitleDeltaX + deltaX
			instance.SizeDeltaX = instance.SizeDeltaX - deltaX
		elseif instance.SizerType == SizerNW then
			instance.TitleDeltaX = instance.TitleDeltaX + deltaX
			instance.SizeDeltaX = instance.SizeDeltaX - deltaX
			instance.TitleDeltaY = instance.TitleDeltaY + deltaY
			instance.SizeDeltaY = instance.SizeDeltaY - deltaY
		elseif instance.SizerType == SizerNE then
			instance.SizeDeltaX = instance.SizeDeltaX + deltaX
			instance.TitleDeltaY = instance.TitleDeltaY + deltaY
			instance.SizeDeltaY = instance.SizeDeltaY - deltaY
		elseif instance.SizerType == SizerSE then
			instance.SizeDeltaX = instance.SizeDeltaX + deltaX
			instance.SizeDeltaY = instance.SizeDeltaY + deltaY
		elseif instance.SizerType == SizerSW then
			instance.TitleDeltaX = instance.TitleDeltaX + deltaX
			instance.SizeDeltaX = instance.SizeDeltaX - deltaX
			instance.SizeDeltaY = instance.SizeDeltaY + deltaY
		end

		if SizerCursor[instance.SizerType] then
			Mouse.SetCursor(SizerCursor[instance.SizerType])
		end
	end
end

local function DrawButton(type, activeInstance, options, radius, offsetX, offsetY, hoverColor, color)
	local isClicked = false
	local mouseX, mouseY = Mouse.Position()
	local isObstructed = false
	if type == "Close" then
		isObstructed = Window.IsObstructed(mouseX, mouseY, true)
	end
	local size = radius * 0.5
	local x = activeInstance.X + activeInstance.W - radius * offsetX
	local y = activeInstance.Y - offsetY * 0.5
	local isHovered =
		x - radius <= mouseX and mouseX <= x + radius and
		y - offsetY * 0.5 <= mouseY and mouseY <= y + radius and
		not isObstructed

	if isHovered then
		DrawCommands.Circle('fill', x, y, radius, hoverColor)

		if Mouse.IsClicked(1) then
			isClicked = true
		end
	end

	if type == "Close" then
		DrawCommands.Cross(x, y, size, color)
	elseif type == "Minimize" then
		if activeInstance.IsMinimized then
			DrawCommands.Rectangle("line", x - size, y - size, size * 2, size * 2, color)
		else
			DrawCommands.Line(x - size, y, x + size, y, 2, color)
		end
	end

	return isClicked
end

function Window.Top()
	return ActiveInstance
end

function Window.IsObstructed(x, y, skipScrollCheck)
	if Region.IsScrolling() then
		return true
	end

	-- If there are no windows, then nothing can obstruct.
	if #Stack == 0 then
		return false
	end

	if ActiveInstance ~= nil then
		if not ActiveInstance.IsOpen then
			return true
		end

		if ActiveInstance.IsContentOpen == false then
			return true
		end

		if ActiveInstance.IsMoving then
			return false
		end

		if ActiveInstance.IsAppearing then
			return true
		end

		-- Gather all potential windows that can obstruct the given position.
		local list = {}
		for i, v in ipairs(Stack) do
			-- Stack locks prevents other windows to be considered.
			if v.Id == StackLockId then
				insert(list, v)
				break
			end

			if Contains(v, x, y) and v.CanObstruct then
				insert(list, v)
			end
		end

		-- Certain layers are rendered on top of 'Normal' windows. Consider these windows first.
		local top = nil
		for i, v in ipairs(list) do
			if v.Layer ~= 'Normal' then
				top = v
				break
			end
		end

		-- If all windows are considered the normal layer, then just grab the window at the top of the stack.
		if top == nil then
			top = list[1]
		end

		if top ~= nil then
			if ActiveInstance == top then
				if not skipScrollCheck and Region.IsHoverScrollBar(ActiveInstance.Id) then
					return true
				end

				return false
			elseif top.IsOpen then
				return true
			end
		end
	end

	return false
end

function Window.IsObstructedAtMouse()
	local x, y = Mouse.Position()
	return Window.IsObstructed(x, y)
end

function Window.Reset()
	for i = 1, #PendingStack do
		PendingStack[i] = nil
	end

	ActiveInstance = GetInstance('Global')
	ActiveInstance.W, ActiveInstance.H = Scale.GetScreenDimensions()
	ActiveInstance.Border = 0
	ActiveInstance.NoSavedSettings = true
	insert(PendingStack, 1, ActiveInstance)
	MenuBarInstance = nil
end

function Window.Begin(id, options)
	local statHandle = Stats.Begin('Window', 'Slab')

	options = options or EMPTY

	if not Mouse.IsDragging(1) then
		Dock.AlterOptions(id, options)
	end

	local x = options.X or 50
	local y = options.Y or 50
	local w = options.W or 200
	local h = options.H or 200
	local contentW = options.ContentW or 0
	local contentH = options.ContentH or 0
	local bgColor = options.BgColor or Style.WindowBackgroundColor
	local title = options.Title or ""
	local titleAlignX = options.TitleAlignX or 'center'
	local titleAlignY = options.TitleAlignY or 'center'
	local titleH = options.TitleH == nil and ((title ~= nil and title ~= "") and max(Style.WindowTitleH, Style.Font:getHeight()) or 0) or options.TitleH
	local allowMove = options.AllowMove == nil or options.AllowMove
	local allowResize = options.AllowResize == nil or options.AllowResize
	local allowFocus = options.AllowFocus == nil or options.AllowFocus
	local border = options.Border or Style.WindowBorder
	local autoSizeWindow = options.AutoSizeWindow == nil or options.AutoSizeWindow
	local autoSizeWindowW = options.AutoSizeWindowW or autoSizeWindow
	local autoSizeWindowH = options.AutoSizeWindowH or autoSizeWindow
	local autoSizeContent = options.AutoSizeContent == nil or options.AutoSizeContent
	local layer = options.Layer or 'Normal'
	local resetSize = options.ResetSize or autoSizeWindow
	local resetContent = options.ResetContent or autoSizeContent
	local sizerFilter = options.SizerFilter or EMPTY
	local canObstruct = options.CanObstruct == nil or options.CanObstruct
	local rounding = options.Rounding or Style.WindowRounding
	local showMinimize = options.ShowMinimize == nil or options.ShowMinimize

	TitleRounding[1], TitleRounding[2] = rounding, rounding
	BodyRounding[3], BodyRounding[4] = rounding, rounding

	local titleRounding, bodyRounding = TitleRounding, BodyRounding

	if type(rounding) == 'table' then
		titleRounding = rounding
		bodyRounding = rounding
	elseif title == "" then
		bodyRounding = rounding
	end

	local instance = GetInstance(id)
	insert(PendingStack, 1, instance)

	if options.IsMenuBar then
		MenuBarInstance = instance
	end

	if ActiveInstance ~= nil then
		ActiveInstance.Children[id] = instance
	end

	ActiveInstance = instance
	if autoSizeWindowW then
		w = 0
	end

	if autoSizeWindowH then
		h = 0
	end

	if options.ResetPosition or options.ResetLayout then
		ActiveInstance.TitleDeltaX = 0
		ActiveInstance.TitleDeltaY = 0
	end

	if ActiveInstance.AutoSizeWindow ~= autoSizeWindow and autoSizeWindow then
		resetSize = true
	end

	if ActiveInstance.Border ~= border then
		resetSize = true
	end

	ActiveInstance.X = ActiveInstance.TitleDeltaX + x
	ActiveInstance.Y = ActiveInstance.TitleDeltaY + y
	ActiveInstance.W = max(ActiveInstance.SizeDeltaX + w + border, border)
	ActiveInstance.H = max(ActiveInstance.SizeDeltaY + h + border, border)
	ActiveInstance.ContentW = contentW
	ActiveInstance.ContentH = contentH
	ActiveInstance.BackgroundColor = bgColor
	ActiveInstance.Title = title
	ActiveInstance.TitleH = titleH
	ActiveInstance.AllowResize = allowResize and not autoSizeWindow
	ActiveInstance.AllowFocus = allowFocus
	ActiveInstance.Border = border
	ActiveInstance.IsMenuBar = options.IsMenuBar
	ActiveInstance.AutoSizeWindow = autoSizeWindow
	ActiveInstance.AutoSizeWindowW = autoSizeWindowW
	ActiveInstance.AutoSizeWindowH = autoSizeWindowH
	ActiveInstance.AutoSizeContent = autoSizeContent
	ActiveInstance.Layer = layer
	ActiveInstance.HotItem = nil
	ActiveInstance.SizerFilter = sizerFilter
	ActiveInstance.HasResized = false
	ActiveInstance.CanObstruct = canObstruct
	ActiveInstance.StatHandle = statHandle
	ActiveInstance.NoSavedSettings = options.NoSavedSettings
	ActiveInstance.ShowMinimize = showMinimize

	local showClose = false
	if options.IsOpen ~= nil and type(options.IsOpen) == 'boolean' then
		ActiveInstance.IsOpen = options.IsOpen
		showClose = true
	end

	if options.IsContentOpen ~= nil and type(options.IsContentOpen) == "boolean" then
		ActiveInstance.IsContentOpen = options.IsContentOpen
	end

	if ActiveInstance.IsOpen then
		local currentFrameNumber = Stats.GetFrameNumber()
		ActiveInstance.IsAppearing = currentFrameNumber - ActiveInstance.FrameNumber > 1
		ActiveInstance.FrameNumber = currentFrameNumber

		if ActiveInstance.StackIndex == 0 then
			insert(Stack, 1, ActiveInstance)
			UpdateStackIndex()
		end
	end

	if ActiveInstance.AutoSizeContent then
		ActiveInstance.ContentW = max(contentW, ActiveInstance.DeltaContentW)
		ActiveInstance.ContentH = max(contentH, ActiveInstance.DeltaContentH)
	end

	local offsetY = ActiveInstance.TitleH
	if ActiveInstance.Title ~= "" then
		ActiveInstance.Y = ActiveInstance.Y + offsetY

		if autoSizeWindow then
			local titleW = Style.Font:getWidth(ActiveInstance.Title) + ActiveInstance.Border * 2
			ActiveInstance.W = max(ActiveInstance.W, titleW)
		end
	end

	local mouseX, mouseY = Mouse.Position()
	local isObstructed = Window.IsObstructed(mouseX, mouseY, true)
	if (ActiveInstance.AllowFocus and Mouse.IsClicked(1) and not isObstructed and Contains(ActiveInstance, mouseX, mouseY)) or
		ActiveInstance.IsAppearing then
		PushToTop(ActiveInstance)
	end

	instance.LastCursorX, instance.LastCursorY = Cursor.GetPosition()
	Cursor.SetPosition(ActiveInstance.X + ActiveInstance.Border, ActiveInstance.Y + ActiveInstance.Border)
	Cursor.SetAnchor(ActiveInstance.X + ActiveInstance.Border, ActiveInstance.Y + ActiveInstance.Border)

	UpdateSize(ActiveInstance, isObstructed)
	UpdateTitleBar(ActiveInstance, isObstructed, allowMove, options.ConstrainPosition)

	DrawCommands.SetLayer(ActiveInstance.Layer)

	DrawCommands.Begin(ActiveInstance.StackIndex)
	if ActiveInstance.Title ~= "" then
		local closeBgRadius = offsetY * 0.4
		local minimizeBgRadius = offsetY * 0.4
		local titleX = floor(ActiveInstance.X + (ActiveInstance.W * 0.5) - (Style.Font:getWidth(ActiveInstance.Title) * 0.5))
		local titleY = floor(ActiveInstance.Y - offsetY * 0.5 - Style.Font:getHeight() * 0.5)

		-- Check for horizontal alignment.
		if titleAlignX == 'left' then
			titleX = floor(ActiveInstance.X + ActiveInstance.Border)
		elseif titleAlignX == 'right' then
			titleX = floor(ActiveInstance.X + ActiveInstance.W - Style.Font:getWidth(ActiveInstance.Title) - ActiveInstance.Border)

			if showClose then
				titleX = floor(titleX - closeBgRadius * 2)
			end
			if showMinimize then
				titleX = floor(titleX - minimizeBgRadius * 2)
			end
		end

		-- Check for vertical alignment
		if titleAlignY == 'top' then
			titleY = floor(ActiveInstance.Y - offsetY)
		elseif titleAlignY == 'bottom' then
			titleY = floor(ActiveInstance.Y - Style.Font:getHeight())
		end

		local titleColor = ActiveInstance.BackgroundColor
		if ActiveInstance == Stack[1] then
			titleColor = Style.WindowTitleFocusedColor
		end
		DrawCommands.Rectangle('fill', ActiveInstance.X, ActiveInstance.Y - offsetY, ActiveInstance.W, offsetY, titleColor, titleRounding)
		DrawCommands.Rectangle('line', ActiveInstance.X, ActiveInstance.Y - offsetY, ActiveInstance.W, offsetY, nil, titleRounding)
		DrawCommands.Line(ActiveInstance.X, ActiveInstance.Y, ActiveInstance.X + ActiveInstance.W, ActiveInstance.Y, 1)

		do
			local titleRegion = ActiveInstance.TitleRegion
			titleRegion.X = ActiveInstance.X
			titleRegion.MouseX = mouseX
			titleRegion.MouseY = mouseY
			titleRegion.IsObstructed = isObstructed
			titleRegion.Y = ActiveInstance.Y - offsetY
			titleRegion.W = ActiveInstance.W
			titleRegion.H = offsetY

			Region.Begin(ActiveInstance.TitleId, titleRegion)
		end

		DrawCommands.Print(ActiveInstance.Title, titleX, titleY, Style.TextColor, Style.Font)

		local offsetX = 1
		if showMinimize then
			offsetX = showClose and 5 or 2
			local isClicked = DrawButton(
				"Minimize",
				ActiveInstance,
				options,
				minimizeBgRadius,
				offsetX,
				offsetY,
				Style.WindowMinimizeColorBgColor or Style.WindowCloseBgColor,
				Style.WindowMinimizeColor or Style.WindowCloseColor
			)
			if isClicked then
				ActiveInstance.IsContentOpen = not ActiveInstance.IsContentOpen
				ActiveInstance.IsMoving = false
				ActiveInstance.IsMinimized = not ActiveInstance.IsMinimized
			end
		end

		if showClose then
			offsetX = 2
			local isClicked = DrawButton(
				"Close",
				ActiveInstance,
				options,
				closeBgRadius,
				offsetX,
				offsetY,
				Style.WindowCloseBgColor,
				Style.WindowCloseColor
			)
			if isClicked then
				ActiveInstance.IsOpen = false
				ActiveInstance.IsMoving = false
				options.IsOpen = false
			end
		end

		Region.End()
	end

	local regionW = ActiveInstance.W
	local regionH = ActiveInstance.H

	if ActiveInstance.X + ActiveInstance.W > Scale.GetScreenWidth() then regionW = Scale.GetScreenWidth() - ActiveInstance.X end
	if ActiveInstance.Y + ActiveInstance.H > Scale.GetScreenHeight() then regionH = Scale.GetScreenHeight() - ActiveInstance.Y end

	if ActiveInstance.IsContentOpen == false then
		regionW = 0
		regionH = 0
		ActiveInstance.ContentW = 0
		ActiveInstance.ContentH = 0
	end

	do
		local region = ActiveInstance.InstanceRegion
		region.X = ActiveInstance.X
		region.Y = ActiveInstance.Y
		region.W = regionW
		region.H = regionH
		region.ContentW = ActiveInstance.ContentW + ActiveInstance.Border
		region.ContentH = ActiveInstance.ContentH + ActiveInstance.Border
		region.BgColor = ActiveInstance.BackgroundColor
		region.IsObstructed = isObstructed
		region.MouseX = mouseX
		region.MouseY = mouseY
		region.ResetContent = ActiveInstance.HasResized
		region.Rounding = bodyRounding
		region.NoOutline = options.NoOutline

		Region.Begin(ActiveInstance.Id, region)
	end

	if resetSize or options.ResetLayout then
		ActiveInstance.SizeDeltaX = 0
		ActiveInstance.SizeDeltaY = 0
	end

	if resetContent or options.ResetLayout then
		ActiveInstance.DeltaContentW = 0
		ActiveInstance.DeltaContentH = 0
	end

	return ActiveInstance.IsOpen
end

function Window.End()
	if not ActiveInstance then
		return
	end

	local handle = ActiveInstance.StatHandle

	-- Clear the ID stack for use with other windows. This information can be kept transient
	for i = 1, #IDStack do
		IDStack[i] = nil
	end

	Region.End()
	DrawCommands.End(not ActiveInstance.IsOpen)
	remove(PendingStack, 1)

	Cursor.SetPosition(ActiveInstance.LastCursorX, ActiveInstance.LastCursorY)
	ActiveInstance = nil
	if #PendingStack > 0 then
		ActiveInstance = PendingStack[1]
		Cursor.SetAnchor(ActiveInstance.X + ActiveInstance.Border, ActiveInstance.Y + ActiveInstance.Border)
		DrawCommands.SetLayer(ActiveInstance.Layer)
		Region.ApplyScissor()
	end

	Stats.End(handle)
end

function Window.GetMousePosition()
	local x, y = Mouse.Position()
	if ActiveInstance ~= nil then
		x, y = Region.InverseTransform(nil, x, y)
	end
	return x, y
end

function Window.GetWidth()
	if ActiveInstance ~= nil then
		return ActiveInstance.W
	end
	return 0
end

function Window.GetHeight()
	if ActiveInstance ~= nil then
		return ActiveInstance.H
	end
	return 0
end

function Window.GetBorder()
	if ActiveInstance ~= nil then
		return ActiveInstance.Border
	end
	return 0
end

function Window.GetBounds(IgnoreTitleBar)
	if ActiveInstance ~= nil then
		IgnoreTitleBar = IgnoreTitleBar == nil and false or IgnoreTitleBar
		local offsetY = (ActiveInstance.Title ~= "" and not IgnoreTitleBar) and ActiveInstance.TitleH or 0
		return ActiveInstance.X, ActiveInstance.Y - offsetY, ActiveInstance.W, ActiveInstance.H + offsetY
	end
	return 0, 0, 0, 0
end

function Window.GetPosition()
	if ActiveInstance ~= nil then
		return ActiveInstance.X, ActiveInstance.Y - ActiveInstance.TitleH
	end
	return 0, 0
end

function Window.GetSize()
	if ActiveInstance ~= nil then
		return ActiveInstance.W, ActiveInstance.H
	end
	return 0, 0
end

function Window.GetContentSize()
	if ActiveInstance ~= nil then
		return ActiveInstance.ContentW, ActiveInstance.ContentH
	end
	return 0, 0
end

--[[
	This function is used to help other controls retrieve the available real estate needed to expand their
	bounds without expanding the bounds of the window by removing borders.
--]]
function Window.GetBorderlessSize()
	local w, h = 0, 0

	if ActiveInstance ~= nil then
		w = max(ActiveInstance.W, ActiveInstance.ContentW)
		h = max(ActiveInstance.H, ActiveInstance.ContentH)

		w = max(0, w - ActiveInstance.Border * 2)
		h = max(0, h - ActiveInstance.Border * 2)
	end

	return w, h
end

function Window.GetRemainingSize()
	local w, h = Window.GetBorderlessSize()

	if ActiveInstance ~= nil then
		w = w - (Cursor.GetX() - ActiveInstance.X - ActiveInstance.Border)
		h = h - (Cursor.GetY() - ActiveInstance.Y - ActiveInstance.Border)
	end

	return w, h
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

function Window.AddItem(x, y, w, h, id)
	if ActiveInstance ~= nil then
		ActiveInstance.LastItem = id
		if Region.IsActive(ActiveInstance.Id) then
			if ActiveInstance.AutoSizeWindowW then
				ActiveInstance.SizeDeltaX = max(ActiveInstance.SizeDeltaX, x + w - ActiveInstance.X)
			end

			if ActiveInstance.AutoSizeWindowH then
				ActiveInstance.SizeDeltaY = max(ActiveInstance.SizeDeltaY, y + h - ActiveInstance.Y)
			end

			if ActiveInstance.AutoSizeContent then
				ActiveInstance.DeltaContentW = max(ActiveInstance.DeltaContentW, x + w - ActiveInstance.X)
				ActiveInstance.DeltaContentH = max(ActiveInstance.DeltaContentH, y + h - ActiveInstance.Y)
			end
		else
			Region.AddItem(x, y, w, h)
		end
	end
end

function Window.WheelMoved(x, y)
	Region.WheelMoved(x, y)
end

function Window.TransformPoint(x, y)
	if ActiveInstance ~= nil then
		return Region.Transform(ActiveInstance.Id, x, y)
	end
	return 0, 0
end

function Window.ResetContentSize()
	if ActiveInstance ~= nil then
		ActiveInstance.DeltaContentW = 0
		ActiveInstance.DeltaContentH = 0
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

function Window.IsItemHot()
	if ActiveInstance ~= nil and ActiveInstance.LastItem ~= nil then
		return ActiveInstance.HotItem == ActiveInstance.LastItem
	end
	return false
end

function Window.GetContextHotItem()
	if ActiveInstance ~= nil then
		return ActiveInstance.ContextHotItem
	end
	return nil
end

function Window.IsMouseHovered()
	if ActiveInstance ~= nil then
		local x, y = Mouse.Position()
		return Contains(ActiveInstance, x, y)
	end
	return false
end

function Window.GetItemId(id)
	if ActiveInstance ~= nil then
		if ActiveInstance.Items[id] == nil then
			ActiveInstance.Items[id] = idCache:get(ActiveInstance.Id, id)
		end

		-- Apply any custom ID to the current item.
		local result = ActiveInstance.Items[id]
		if #IDStack > 0 then
			result = result .. IDStack[#IDStack]
		end

		return result
	end
	return nil
end

function Window.GetLastItem()
	if ActiveInstance ~= nil then
		return ActiveInstance.LastItem
	end
	return nil
end

function Window.Validate()
	if #PendingStack > 1 then
		assert(false, "EndWindow was not called for: " .. PendingStack[1].Id)
	end

	MovingInstance = nil
	local shouldUpdate = false
	for i = #Stack, 1, -1 do
		if Stack[i].IsMoving then
			MovingInstance = Stack[i]
		end

		if Stack[i].FrameNumber ~= Stats.GetFrameNumber() then
			Stack[i].StackIndex = 0
			Region.ClearHotInstance(Stack[i].Id)
			Region.ClearHotInstance(Stack[i].TitleId)
			remove(Stack, i)
			shouldUpdate = true
		end
	end

	if shouldUpdate then
		UpdateStackIndex()
	end
end

function Window.HasResized()
	if ActiveInstance ~= nil then
		return ActiveInstance.HasResized
	end
	return false
end

function Window.SetStackLock(id)
	StackLockId = id
end

function Window.PushToTop(id)
	local instance = GetInstance(id)

	if instance ~= nil then
		PushToTop(instance)
	end
end

function Window.IsAppearing()
	if ActiveInstance ~= nil then
		return ActiveInstance.IsAppearing
	end

	return false
end

function Window.GetLayer()
	if ActiveInstance ~= nil then
		return ActiveInstance.Layer
	end
	return 'Normal'
end

function Window.GetInstanceIds()
	local result = {}

	for i, v in ipairs(Instances) do
		insert(result, v.Id)
	end

	return result
end

function Window.GetInstanceInfo(id)
	local result = {}

	local instance = nil
	for i, v in ipairs(Instances) do
		if v.Id == id then
			instance = v
			break
		end
	end

	insert(result, "MovingInstance: " .. (MovingInstance ~= nil and MovingInstance.Id or "nil"))

	if instance ~= nil then
		insert(result, "Title: " .. instance.Title)
		insert(result, "TitleH: " .. instance.TitleH)
		insert(result, "X: " .. instance.X)
		insert(result, "Y: " .. instance.Y)
		insert(result, "W: " .. instance.W)
		insert(result, "H: " .. instance.H)
		insert(result, "ContentW: " .. instance.ContentW)
		insert(result, "ContentH: " .. instance.ContentH)
		insert(result, "TitleDeltaX: " .. instance.TitleDeltaX)
		insert(result, "TitleDeltaY: " .. instance.TitleDeltaY)
		insert(result, "SizeDeltaX: " .. instance.SizeDeltaX)
		insert(result, "SizeDeltaY: " .. instance.SizeDeltaY)
		insert(result, "DeltaContentW: " .. instance.DeltaContentW)
		insert(result, "DeltaContentH: " .. instance.DeltaContentH)
		insert(result, "Border: " .. instance.Border)
		insert(result, "Layer: " .. instance.Layer)
		insert(result, "Stack Index: " .. instance.StackIndex)
		insert(result, "AutoSizeWindow: " .. tostring(instance.AutoSizeWindow))
		insert(result, "AutoSizeContent: " .. tostring(instance.AutoSizeContent))
		insert(result, "Hot Item: " .. tostring(instance.HotItem))
	end

	return result
end

function Window.GetStackDebug()
	local result = {}

	for i, v in ipairs(Stack) do
		result[i] = tostring(v.StackIndex) .. ": " .. v.Id

		if v.Id == StackLockId then
			result[i] = result[i] .. " (Locked)"
		end
	end

	return result
end

function Window.IsAutoSize()
	if ActiveInstance ~= nil then
		return ActiveInstance.AutoSizeWindowW or ActiveInstance.AutoSizeWindowH
	end

	return false
end

function Window.Save(Table)
	if Table ~= nil then
		local settings = {}
		for i, v in ipairs(Instances) do
			if not v.NoSavedSettings then
				settings[v.Id] = {
					X = v.TitleDeltaX,
					Y = v.TitleDeltaY,
					W = v.SizeDeltaX,
					H = v.SizeDeltaY
				}
			end
		end
		Table['Window'] = settings
	end
end

function Window.Load(Table)
	if Table ~= nil then
		local settings = Table['Window']
		if settings ~= nil then
			for k, v in pairs(settings) do
				local instance = GetInstance(k)
				instance.TitleDeltaX = v.X
				instance.TitleDeltaY = v.Y
				instance.SizeDeltaX = v.W
				instance.SizeDeltaY = v.H
			end
		end
	end
end

function Window.GetMovingInstance()
	return MovingInstance
end

--[[
	Allow developers to push/pop a custom ID to the stack. This can help with differentiating between controls with identical IDs i.e. text fields.
--]]
function Window.PushID(id)
	if ActiveInstance ~= nil then
		insert(IDStack, id)
	end
end

function Window.PopID()
	if #IDStack > 0 then
		return remove(IDStack)
	end

	return nil
end

function Window.ToDock(type)
	local activeInstance = GetInstance()
	activeInstance.W = 720
	activeInstance.H = 720
	Dock.SetPendingWindow(activeInstance, type)
	Dock.Override()
end

return Window
