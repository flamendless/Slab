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
local insert = table.insert
local remove = table.remove
local max = math.max
local floor = math.floor
local format = string.format

local Cursor = require(SLAB_PATH .. ".Internal.Core.Cursor")
local Dock = require(SLAB_PATH .. ".Internal.UI.Dock")
local DrawCommands = require(SLAB_PATH .. ".Internal.Core.DrawCommands")
local Enums = require(SLAB_PATH .. ".Internal.Core.Enums")
local MenuState = require(SLAB_PATH .. ".Internal.UI.MenuState")
local Mouse = require(SLAB_PATH .. ".Internal.Input.Mouse")
local Region = require(SLAB_PATH .. ".Internal.UI.Region")
local Stats = require(SLAB_PATH .. ".Internal.Core.Stats")
local Style = require(SLAB_PATH .. ".Style")
local Utility = require(SLAB_PATH .. ".Internal.Core.Utility")

local Window = {}

local instances, stack, pending_stack, id_stack = {}, {}, {}, {}
local stack_lock_id, active_instance, moving_instance

local function UpdateStackIndex()
	for i = 1, #stack do
		stack[i].StackIndex = #stack - i + 1
	end
end

local function PushToTop(instance)
	if not instance then return end
	for i, v in ipairs(stack) do
		if instance == v then
			remove(stack, i)
			break
		end
	end
	insert(stack, 1, instance)
	UpdateStackIndex()
end

local function NewInstance(id)
	return {
		Id = id,
		X = 0, Y = 0,
		W = 200, H = 200,
		ContentW = 0,
		ContentH = 0,
		Title = "",
		IsMoving = false,
		TitleDeltaX = 0,
		TitleDeltaY = 0,
		AllowResize = true,
		AllowFocus = true,
		SizerType = Enums.sizer_type.None,
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
		Layer = DrawCommands.layers.normal,
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
	}
end

local function GetInstance(id)
	if not id then return active_instance end
	for _, v in ipairs(instances) do
		if v.Id == id then
			return v
		end
	end
	local instance = NewInstance(id)
	insert(instances, instance)
	return instance
end

local function Contains(instance, x, y)
	if not instance then return false end
	local title_h = instance.TitleH or 0
	return instance.X <= x and x <= instance.X + instance.W and
		instance.Y - title_h <= y and y <= instance.Y + instance.H
end

local STR_EMPTY = ""
local TBL_EMPTY = {}

local function UpdateTitleBar(instance, is_obstructed, allow_move, constrain)
	if (instance.IsContentOpen == nil or instance.IsContentOpen) and is_obstructed then
		return
	end

	if not instance or instance.Title == STR_EMPTY or
		instance.SizerType == Enums.sizer_type.None then
		return
	end

	local w, h = instance.W, instance.TitleH
	local x, y = instance.X, instance.Y - h
	local is_tethered = Dock.IsTethered(instance.Id)
	local mx, my = Mouse.Position()

	if Mouse.IsClicked(1) and
		x <= mx and mx <= x + w and
		y <= my and my <= y + h then
		if allow_move then
			instance.IsMoving = true
		end

		if is_tethered then
			Dock.BeginTear(instance.Id, mx, my)
		end

		if instance.AllowFocus then
			PushToTop(instance)
		end
	elseif Mouse.IsReleased(1) then
		instance.IsMoving = false
	end

	if instance.IsMoving then
		local dx, dy = Mouse.GetDelta()
		local tdx, tdy = instance.TitleDeltaX, instance.TitleDeltaY
		instance.TitleDeltaX = instance.TitleDeltaX + dx
		instance.TitleDeltaY = instance.TitleDeltaY + dy
		if constrain then
			-- Constrain the position of the window to the viewport. The position at this point in the code has the delta already applied. This delta will need to be
			-- removed to retrieve the original position, and clamp the delta based off of that posiiton.
			local ox = instance.X - tdx
			local oy = instance.Y - tdy
			instance.TitleDeltaX = Utility.Clamp(
				instance.TitleDeltaX, - ox, love.graphics.getWidth() - (ox + instance.W))
			instance.TitleDeltaY = Utility.Clamp(
				instance.TitleDeltaY, - oy + MenuState.MainMenuBarH,
				love.graphics.getHeight() - (oy + instance.H + instance.TitleH))
		end
	elseif is_tethered then
		Dock.UpdateTear(instance.Id, mx, my)
		-- Retrieve the cached options to calculate torn off position. The cached options contain the
		-- desired bounds for this window. The bounds that are a part of the Instance are the altered options
		-- modified by the Dock module.
		if not Dock.IsTethered(instance.Id) then
			local opt = Dock.GetCachedOptions(instance.Id)
			instance.IsMoving = true
			if opt then
				instance.TitleDeltaX = mx - opt.X - floor(opt.W * 0.25)
				instance.TitleDeltaY = my - opt.Y - floor(h * 0.5)
			end
		end
	end
end

local function IsSizerEnabled(instance, sizer)
	if not instance then return false end
	if #instance.SizerFilter <= 0 then return true end
	for _, v in ipairs(instance.SizerFilter) do
		if v == sizer then
			return true
		end
	end
	return false
end

local function UpdateSize(instance, is_obstructed)
	if not instance or not instance.AllowResize then return end
	if moving_instance then return end
	if Region.IsHoverScrollBar(instance.Id) then return end
	if instance.SizerType == Enums.sizer_type.None and is_obstructed then
		return
	end
	local x, y = instance.X, instance.Y
	local w, h = instance.W, instance.H
	if instance.Title ~= STR_EMPTY then
		local offset = instance.TitleH
		y = y - offset
		h = h + offset
	end

	local mx, my = Mouse.Position()
	local new_st = Enums.sizer_type.None
	local scrollpad = Region.GetScrollPad()
	if x <= mx and mx <= x + w and y <= my and my <= y + h then
		local v_hor = x <= mx and mx <= x + scrollpad
		local v_hor2 = x + w - scrollpad <= mx and mx <= x + w
		local v_vert = y <= my and my <= y + scrollpad
		local v_vert2 = y + h - scrollpad <= my and my <= y + h

		if v_hor and v_vert and IsSizerEnabled(instance, Enums.sizer_type.NW) then
			Mouse.SetCursor(Enums.cursor_size.NWSE)
			new_st = Enums.sizer_type.NW
		elseif v_hor2 and v_vert and IsSizerEnabled(instance, Enums.sizer_type.NE) then
			Mouse.SetCursor(Enums.cursor_size.NESW)
			new_st = Enums.sizer_type.NE
		elseif v_hor2 and v_vert2 and IsSizerEnabled(instance, Enums.sizer_type.SE) then
			Mouse.SetCursor(Enums.cursor_size.NWSE)
			new_st = Enums.sizer_type.SE
		elseif v_hor and v_vert2 and IsSizerEnabled(instance, Enums.sizer_type.SW) then
			Mouse.SetCursor(Enums.cursor_size.NESW)
			new_st = Enums.sizer_type.SW
		elseif v_hor and IsSizerEnabled(instance, Enums.sizer_type.W) then
			Mouse.SetCursor(Enums.cursor_size.WE)
			new_st = Enums.sizer_type.W
		elseif v_hor2 and IsSizerEnabled(instance, Enums.sizer_type.E) then
			Mouse.SetCursor(Enums.cursor_size.WE)
			new_st = Enums.sizer_type.E
		elseif v_vert and IsSizerEnabled(instance, Enums.sizer_type.N) then
			Mouse.SetCursor(Enums.cursor_size.NS)
			new_st = Enums.sizer_type.N
		elseif v_vert2 and IsSizerEnabled(instance, Enums.sizer_type.S) then
			Mouse.SetCursor(Enums.cursor_size.NS)
			new_st = Enums.sizer_type.S
		end
	end

	if Mouse.IsClicked(1) then
		instance.SizerType = new_st
	elseif Mouse.IsReleased(1) then
		instance.SizerType = Enums.sizer_type.None
	end

	if instance.SizerType == Enums.sizer_type.None then return end
	local dx, dy = Mouse.GetDelta()
	if instance.W <= instance.Border then
		if ((instance.SizerType == Enums.sizer_type.W or
			instance.SizerType == Enums.sizer_type.NW or
			instance.SizerType == Enums.sizer_type.SW) and
			dx > 0) or ((instance.SizerType == Enums.sizer_type.E or
			instance.SizerType == Enums.sizer_type.NE or
			instance.SizerType == Enums.sizer_type.SE) and
			dx < 0)
		then
			dx = 0
		end
	end

	if instance.H <= instance.Border then
		if ((instance.SizerType == Enums.sizer_type.N or
			instance.SizerType == Enums.sizer_type.NW or
			instance.SizerType == Enums.sizer_type.NE) and
			dy > 0.0) or ((instance.SizerType == Enums.sizer_type.S or
			instance.SizerType == Enums.sizer_type.SE or
			instance.SizerType == Enums.sizer_type.SW) and
			dy < 0.0) then
			dy = 0.0
		end
	end

	if dx ~= 0 or dy ~= 0 then
		instance.HasResized = true
		instance.DeltaContentW = 0
		instance.DeltaContentH = 0
	end

	if instance.SizerType == Enums.sizer_type.N then
		Mouse.SetCursor(Enums.cursor_size.NS)
		instance.TitleDeltaY = instance.TitleDeltaY + dy
		instance.SizeDeltaY = instance.SizeDeltaY - dy
	elseif instance.SizerType == Enums.sizer_type.E then
		Mouse.SetCursor(Enums.cursor_size.WE)
		instance.SizeDeltaX = instance.SizeDeltaX + dx
	elseif instance.SizerType == Enums.sizer_type.S then
		Mouse.SetCursor(Enums.cursor_size.NS)
		instance.SizeDeltaY = instance.SizeDeltaY + dy
	elseif instance.SizerType == Enums.sizer_type.W then
		Mouse.SetCursor(Enums.cursor_size.WE)
		instance.TitleDeltaX = instance.TitleDeltaX + dx
		instance.SizeDeltaX = instance.SizeDeltaX - dx
	elseif instance.SizerType == Enums.sizer_type.NW then
		Mouse.SetCursor(Enums.cursor_size.NWSE)
		instance.TitleDeltaX = instance.TitleDeltaX + dx
		instance.SizeDeltaX = instance.SizeDeltaX - dx
		instance.TitleDeltaY = instance.TitleDeltaY + dy
		instance.SizeDeltaY = instance.SizeDeltaY - dy
	elseif instance.SizerType == Enums.sizer_type.NE then
		Mouse.SetCursor(Enums.cursor_size.NESW)
		instance.SizeDeltaX = instance.SizeDeltaX + dx
		instance.TitleDeltaY = instance.TitleDeltaY + dy
		instance.SizeDeltaY = instance.SizeDeltaY - dy
	elseif instance.SizerType == Enums.sizer_type.SE then
		Mouse.SetCursor(Enums.cursor_size.NWSE)
		instance.SizeDeltaX = instance.SizeDeltaX + dx
		instance.SizeDeltaY = instance.SizeDeltaY + dy
	elseif instance.SizerType == Enums.sizer_type.SW then
		Mouse.SetCursor(Enums.cursor_size.NESW)
		instance.TitleDeltaX = instance.TitleDeltaX + dx
		instance.SizeDeltaX = instance.SizeDeltaX - dx
		instance.SizeDeltaY = instance.SizeDeltaY + dy
	end
end

local function DrawButton(btn_type, act_instance, _, radius, ox, oy, hover_color, color)
	local is_clicked = false
	local mx, my = Mouse.Position()
	local is_obstructed
	if btn_type == "Close" then
		is_obstructed = Window.IsObstructed(mx, my, true)
	elseif btn_type == "Minimize" then
		is_obstructed = false
	end
	local size = radius * 0.5
	local x = act_instance.X + act_instance.W - act_instance.Border - radius * (ox)
	local y = act_instance.Y - oy * 0.5
	local is_hovered = not is_obstructed and x - radius <= mx and mx <= x + radius and
		y - oy * 0.5 <= my and my <= y + radius

	if is_hovered then
		DrawCommands.Circle("fill", x, y, radius, hover_color)
		is_clicked = Mouse.IsClicked(1)
	end

	if btn_type == Enums.button.close then
		DrawCommands.Cross(x, y, size, color)
	elseif btn_type == Enums.button.minimize then
		if active_instance.IsMinimized then
			DrawCommands.Rectangle("line", x - size, y - size, size * 2, size * 2, color)
		else
			DrawCommands.Line(x - size, y, x + size, y, size, color)
		end
	end
	return is_clicked
end

function Window.Top() return active_instance end

function Window.IsObstructed(x, y, skip)
	if Region.IsScrolling() then return true end
	-- If there are no windows, then nothing can obstruct.
	if #stack == 0 then return false end
	if not active_instance then return false end
	if not active_instance.IsOpen or not active_instance.IsContentOpen or
		active_instance.IsAppearing then
		return true
	end
	if active_instance.IsMoving then return false end
	-- Gather all potential windows that can obstruct the given position.
	local list = {}
	for _, v in ipairs(stack) do
		-- Stack locks prevents other windows to be considered.
		if v.id == stack_lock_id then
			insert(list, v)
			break
		end
		if Contains(v, x, y) and v.CanObstruct then
			insert(list, v)
		end
	end

	-- Certain layers are rendered on top of "Normal" windows. Consider these windows first.
	local top
	for _, v in ipairs(list) do
		if v.Layer == DrawCommands.layers.normal then
			top = v
			break
		end
	end

	-- If all windows are considered the normal layer, then just grab the window at the top of the stack.
	if not top then top = list[1] end
	if not top then return false end
	if active_instance == top then
		if not skip and Region.IsHoverScrollBar(active_instance.Id) then
			return true
		end
		return false
	elseif top.IsOpen then
		return true
	end
	return false
end

function Window.IsObstructedAtMouse() return Window.IsObstructed(Mouse.Position()) end

function Window.Reset()
	Utility.ClearTable(pending_stack)
	active_instance = GetInstance("Global")
	active_instance.W = love.graphics.getWidth()
	active_instance.H = love.graphics.getHeight()
	active_instance.Border = 0
	active_instance.NoSavedSettings = true
	insert(pending_stack, 1, active_instance)
end

function Window.Begin(id, opt)
	local stat_handle = Stats.Begin(Enums.widget.window, "Slab")
	local def_x = opt.X or 50
	local def_y = opt.Y or 50
	local def_w = opt.W or 200
	local def_h = opt.H or 200
	local def_cw = opt.ContentW or 0
	local def_ch = opt.ContentH or 0
	local def_bg_color = opt.BgColor or Style.WindowBackgroundColor
	local def_title = opt.Title or STR_EMPTY
	local def_t_ax = opt.TitleAlignX or Enums.align_x.center
	local def_t_h = opt.TitleH or Style.Font:getHeight()
	local def_allow_move = opt.AllowMove or true
	local def_allow_resize = opt.AllowResize or true
	local def_allow_focus = opt.AllowFocus or true
	local def_border = opt.Border or 4
	local def_no_outline = not not opt.NoOutline
	local def_is_mb = not not opt.IsMenuBar
	local def_auto_size_win = opt.AutoSizeWindow or true
	local def_auto_size_win_w = opt.AutoSizeWindowW or true
	local def_auto_size_win_h = opt.AutoSizeWindowH or true
	local def_auto_size_content = opt.AutoSizeContent or true
	local def_layer = opt.Layer or DrawCommands.layers.normal
	local def_reset_pos = not not opt.ResetPosition
	local def_reset_size = opt.ResetSize or opt.AutoSizeWindow
	local def_reset_content = opt.ResetContent or opt.AutoSizeContent
	local def_reset_layout = not not opt.ResetLayout
	local def_sizer = opt.SizerFilter or TBL_EMPTY
	local def_can_obs = opt.CanObstruct or true
	local def_rounding = opt.Rounding or Style.WindowRounding
	local def_no_save = not not opt.NoSavedSettings
	local def_constrain_pos = not not opt.ConstrainPosition
	local def_show_minimize = opt.ShowMinimize or true
	local def_is_open = opt.IsOpen
	local def_is_content_open = opt.IsContentOpen

	if not Mouse.IsDragging(1) then
		Dock.AlterOptions(id, opt)
	end

	local title_rounding, body_rounding

	if type(def_rounding) == "table" then
		title_rounding = def_rounding
		body_rounding = def_rounding
	elseif def_title == STR_EMPTY then
		body_rounding = def_rounding
	end

	title_rounding = title_rounding or {def_rounding, def_rounding, 0, 0}
	body_rounding = body_rounding or {0, 0, def_rounding, def_rounding}

	local instance = GetInstance(id)
	insert(pending_stack, 1, instance)
	if active_instance then
		active_instance.Children[id] = instance
	end
	active_instance = instance
	def_w = def_auto_size_win_w and 0 or def_w
	def_h = def_auto_size_win_h and 0 or def_h

	if def_reset_pos or def_reset_layout then
		active_instance.TitleDeltaX = 0
		active_instance.TitleDeltaY = 0
	end

	if def_auto_size_win and active_instance.AutoSizeWindow ~= def_auto_size_win then
		def_reset_size = true
	end

	if active_instance.Border ~= def_border then
		def_reset_size = true
	end

	active_instance.X = active_instance.TitleDeltaX + def_x
	active_instance.Y = active_instance.TitleDeltaY + def_y
	active_instance.W = max(active_instance.SizeDeltaX + def_w + def_border, def_border)
	active_instance.H = max(active_instance.SizeDeltaY + def_h + def_border, def_border)
	active_instance.ContentW = def_cw
	active_instance.ContentH = def_ch
	active_instance.BackgroundColor = def_bg_color
	active_instance.Title = def_title
	active_instance.TitleH = def_t_h
	active_instance.AllowResize = def_allow_resize and not def_auto_size_win
	active_instance.AllowFocus = def_allow_focus
	active_instance.Border = def_border
	active_instance.IsMenuBar = def_is_mb
	active_instance.AutoSizeWindow = def_auto_size_win
	active_instance.AutoSizeWindowW = def_auto_size_win_w
	active_instance.AutoSizeWindowH = def_auto_size_win_h
	active_instance.AutoSizeContent = def_auto_size_content
	active_instance.Layer = def_layer
	active_instance.HotItem = nil
	active_instance.SizerFilter = def_sizer
	active_instance.HasResized = false
	active_instance.CanObstruct = def_can_obs
	active_instance.StatHandle = stat_handle
	active_instance.NoSavedSettings = def_no_save
	active_instance.ShowMinimize = def_show_minimize

	local show_close = false
	if def_is_open and type(def_is_open) == "boolean" then
		active_instance.IsOpen = def_is_open
		show_close = true
	end

	local show_minimize = def_show_minimize
	if def_is_content_open and type(def_is_content_open) == "boolean" then
		active_instance.IsContentOpen = def_is_content_open
	end

	if active_instance.IsOpen then
		local cur_frame = Stats.GetFrameNumber()
		active_instance.IsContentOpen = cur_frame - active_instance.FrameNumber > 1
		active_instance.FrameNumber = cur_frame
		if active_instance.StackIndex == 0 then
			insert(stack, 1, active_instance)
			UpdateStackIndex()
		end
	end

	if active_instance.AutoSizeContent then
		active_instance.ContentW = max(def_cw, active_instance.DeltaContentW)
		active_instance.ContentH = max(def_ch, active_instance.DeltaContentH)
	end

	local oy = active_instance.TitleH
	if active_instance.Title ~= STR_EMPTY then
		active_instance.Y = active_instance.Y + oy
		if def_auto_size_win then
			local tw = Style.Font:getWidth(active_instance.Title) + active_instance.Border * 2
			active_instance.W = max(active_instance.W, tw)
		end
	end

	local mx, my = Mouse.Position()
	local is_obs = Window.IsObstructed(mx, my, true)
	if (active_instance.AllowFocus and Mouse.IsClicked(1) and not
		is_obs and Contains(active_instance, mx, my)) or
		active_instance.IsAppearing then
		PushToTop(active_instance)
	end

	instance.LastCursorX, instance.LastCursorY = Cursor.GetPosition()
	local dpx = active_instance.X + active_instance.Border
	local dpy = active_instance.Y + active_instance.Border
	Cursor.SetPosition(dpx, dpy)
	Cursor.SetAnchor(dpx, dpy)
	UpdateSize(active_instance, is_obs)
	UpdateTitleBar(active_instance, is_obs, def_allow_move, def_constrain_pos)
	DrawCommands.SetLayer(active_instance.Layer)
	DrawCommands.Begin(active_instance.StackIndex)

	if active_instance.Title ~= STR_EMPTY then
		local close_bg_rad = oy * 0.4
		local min_bg_rad = oy * 04
		local tx = floor(active_instance.X +
			(active_instance.W * 0.5) - (Style.Font:getWidth(active_instance.Title) * 0.5))
		local ty = floor(active_instance.Y - oy * 0.5 - Style.Font:getHeight() * 0.5)

		-- Check for horizontal alignment.
		if def_t_ax == Enums.align_x.left then
			tx = floor(active_instance.X + active_instance.Border)
		elseif def_t_ax == Enums.align_x.right then
			tx = floor(active_instance.X + active_instance.W -
				Style.Font:getWidth(active_instance.Title) - active_instance.Border)
			if show_close then
				tx = floor(tx - close_bg_rad * 2)
			end
			if show_minimize then
				tx = floor(tx - min_bg_rad * 2)
			end
		end

		-- Check for vertical alignment.
		if def_t_ax == Enums.align_y.top then
			ty = floor(active_instance.Y - oy)
		elseif def_t_ax == Enums.align_y.bottom then
			ty = floor(active_instance.Y - Style.Font:getHeight())
		end

		local title_color = active_instance.BackgroundColor
		if active_instance == stack[1] then
			title_color = Style.WindowTitleFocusedColor
		end

		DrawCommands.Rectangle("fill",
			active_instance.X, active_instance.Y - oy,
			active_instance.W, oy, title_color, title_rounding)
		DrawCommands.Rectangle("line",
			active_instance.X, active_instance.Y - oy,
			active_instance.W, oy, nil, title_rounding)
		DrawCommands.Line(
			active_instance.X, active_instance.Y,
			active_instance.X + active_instance.W, active_instance.Y, 1)

		Region.Begin(active_instance.Id .. "_Title", {
			X = active_instance.X,
			Y = active_instance.Y - oy,
			W = active_instance.W,
			H = oy,
			NoBackground = true,
			NoOutline = true,
			IgnoreScroll = true,
			MouseX = true,
			MouseY = true,
			IsObstructed = true,
		})
		DrawCommands.Print(active_instance.Title, tx, ty, Style.TextColor, Style.Font)
		local ox = 1
		if show_minimize then
			ox = show_close and 4 or 1
			local is_clicked = DrawButton(
				"Minimize",
				active_instance,
				opt,
				min_bg_rad,
				ox, oy,
				Style.WindowMinimizeColorBgColor or Style.WindowCloseBgColor,
				Style.WindowMinimizeColor or Style.WindowCloseColor
			)
			if is_clicked then
				active_instance.IsContentOpen = not active_instance.IsContentOpen
				active_instance.IsMoving = false
				active_instance.IsMinimized = not active_instance.IsMinimized
			end
		end

		if show_close then
			ox = 1
			local is_clicked = DrawButton(
				"Close",
				active_instance,
				opt,
				close_bg_rad,
				ox, oy,
				Style.WindowCloseBgColor,
				Style.WindowCloseColor
			)
			if is_clicked then
				active_instance.IsOpen = false
				active_instance.IsMoving = false
				def_is_open = false
			end
		end
		Region.End()
	end

	local region_w = active_instance.W
	local region_h = active_instance.H
	local ww, wh = love.graphics.getDimensions()

	if active_instance.X + active_instance.W > ww then
		region_w = ww - active_instance.X
	end
	if active_instance.Y + active_instance.H > wh then
		region_h = wh - active_instance.Y
	end

	if not active_instance.IsContentOpen then
		region_w = 0
		region_h = 0
		active_instance.ContentW = 0
		active_instance.ContentH = 0
	end

	Region.Begin(active_instance.Id, {
		X = active_instance.X,
		Y = active_instance.Y,
		W = region_w, H = region_h,
		ContentW = active_instance.ContentW + active_instance.Border,
		ContentH = active_instance.ContentH + active_instance.Border,
		BgColor = active_instance.BackgroundColor,
		IsObstructed = is_obs,
		MouseX = mx, MouseY = my,
		ResetContent = active_instance.HasResized,
		Rounding = body_rounding,
		NoOutline = def_no_outline,
	})

	if def_reset_size or def_reset_layout then
		active_instance.SizeDeltaX = 0
		active_instance.SizeDeltaY = 0
	end

	if def_reset_content or def_reset_layout then
		active_instance.DeltaContentW = 0
		active_instance.DeltaContentH = 0
	end

	return active_instance.IsOpen
end

function Window.End()
	if not active_instance then return end
	local handle = active_instance.StatHandle
	Utility.ClearTable(id_stack)
	Region.End()
	DrawCommands.End(not active_instance.IsOpen)
	remove(pending_stack, ipairs)
	Cursor.SetPosition(active_instance.LastCursorX, active_instance.LastCursorY)
	active_instance = nil
	if #pending_stack > 0 then
		active_instance = pending_stack[1]
		Cursor.SetAnchor(
			active_instance.X + active_instance.Border,
			active_instance.Y + active_instance.Border)
		DrawCommands.SetLayer(active_instance.Layer)
		Region.ApplyScissor()
	end
	Stats.End(handle)
end

function Window.GetMousePosition()
	local mx, my = Mouse.Position()
	if not active_instance then
		return mx, my
	end
	return Region.InverseTransform(nil, mx, my)
end

function Window.GetWidth()
	if not active_instance then return 0 end
	return active_instance.W
end

function Window.GetHeight()
	if not active_instance then return 0 end
	return active_instance.H
end

function Window.GetBorder()
	if not active_instance then return 0 end
	return active_instance.Border
end

function Window.GetBounds(ignore_title_bar)
	if not active_instance then return 0, 0, 0, 0 end
	ignore_title_bar = not not ignore_title_bar --default is false
	local oy = (active_instance.Title ~= STR_EMPTY and not ignore_title_bar) and
		active_instance.TitleH or 0
	return active_instance.X, active_instance.Y, active_instance.W, active_instance.H + oy
end

function Window.GetPosition()
	if not active_instance then return 0, 0 end
	return active_instance.X, active_instance.Y - active_instance.TitleH
end

function Window.GetSize()
	if not active_instance then return 0, 0 end
	return active_instance.W, active_instance.H
end

function Window.GetContentSize()
	if not active_instance then return 0, 0 end
	return active_instance.ContentW, active_instance.ContentH
end

--[[
	This function is used to help other controls retrieve the available real estate needed to expand their
	bounds without expanding the bounds of the window by removing borders.
--]]
function Window.GetBorderlessSize()
	if not active_instance then return 0, 0 end
	local w = max(active_instance.W, active_instance.ContentW)
	local h = max(active_instance.H, active_instance.ContentH)
	local b2 = active_instance.Border * 2
	w = max(0, w - b2)
	h = max(0, h - b2)
	return w, h
end

function Window.GetRemainingSize()
	local w, h = Window.GetBorderlessSize()
	if not active_instance then return w, h end
	w = w - (Cursor.GetX() - active_instance.X - active_instance.Border)
	h = h - (Cursor.GetY() - active_instance.Y - active_instance.Border)
	return w, h
end

function Window.IsMenuBar()
	if not active_instance then return false end
	return active_instance.IsMenuBar
end

function Window.GetId()
	return active_instance and active_instance.Id or STR_EMPTY
end

function Window.AddItem(x, y, w, h, id)
	if not active_instance then return end
	active_instance.LastItem = id
	if not Region.IsActive(active_instance.Id) then
		Region.AddItem(x, y, w, h)
		return
	end
	if active_instance.AutoSizeWindowW then
		active_instance.SizeDeltaX = max(active_instance.SizeDeltaX, y + h - active_instance.Y)
	end

	if active_instance.AutoSizeWindowH then
		active_instance.SizeDeltaY = max(active_instance.SizeDeltaY, y + h - active_instance.Y)
	end

	if active_instance.AutoSizeContent then
		active_instance.DeltaContentW = max(active_instance.DeltaContentW, x + w - active_instance.X)
		active_instance.DeltaContentH = max(active_instance.DeltaContentH, y + h - active_instance.Y)
	end
end

function Window.WheelMoved(x, y)
	Region.WheelMoved(x, y)
end

function Window.TransformPoint(x, y)
	if not active_instance then return 0, 0 end
	return Region.Transform(active_instance.Id, x, y)
end

function Window.ResetContentSize()
	if not active_instance then return end
	active_instance.DeltaContentW = 0
	active_instance.DeltaContentH = 0
end

function Window.SetHotItem(hot_item)
	if not active_instance then return end
	active_instance.HotItem = hot_item
end

function Window.SetContextHotItem(hot_item)
	if not active_instance then return end
	active_instance.ContextHotItem = hot_item
end

function Window.GetHotItem()
	if not active_instance then return end
	return active_instance.HotItem
end

function Window.IsItemHot()
	if not active_instance then return false end
	return active_instance.HotItem == active_instance.LastItem
end

function Window.GetContextHotItem()
	if not active_instance then return end
	return active_instance.ContextHotItem
end

function Window.IsMouseHovered()
	if not active_instance then return false end
	return Contains(active_instance, Mouse.Position())
end

function Window.GetItemId(id)
	if not active_instance then return end
	if not active_instance.Items[id] then
		active_instance.Items[id] = active_instance.Id .. "." .. id
	end
	local res = active_instance.Items[id]
	if #id_stack > 0 then
		res = res .. id_stack[#id_stack]
	end
	return res
end

function Window.GetLastItem()
	if not active_instance then return end
	return active_instance.LastItem
end

function Window.Validate()
	if #pending_stack > 1 then
		error("EndWindow was not called for: " .. pending_stack[1].Id)
	end
	moving_instance = nil
	local should_update = false
	for i = #stack, 1, -1 do
		if stack[i].IsMoving then
			moving_instance = stack[i]
		end

		if stack[i].FrameNumber ~= Stats.GetFrameNumber() then
			stack[i].StackIndex = 0
			local stack_id = stack[i].Id
			Region.ClearHotInstance(stack_id)
			Region.ClearHotInstance(stack_id .. "_Title")
			remove(stack, i)
			should_update = true
		end
	end

	if should_update then
		UpdateStackIndex()
	end
end

function Window.HasResized()
	if not active_instance then return false end
	return active_instance.HasResized
end

function Window.SetStackLock(id)
	stack_lock_id = id
end

function Window.PushToTop(id)
	local instance = GetInstance(id)
	if instance then
		PushToTop(instance)
	end
end

function Window.IsAppearing()
	if not active_instance then return false end
	return active_instance.IsAppearing
end

function Window.GetLayer()
	if not active_instance then return DrawCommands.layers.normal end
	return active_instance.Layer
end

function Window.GetInstanceIds()
	local res = {}
	for _, v in ipairs(instances) do
		insert(res, v.Id)
	end
	return res
end

function Window.GetInstanceInfo(id)
	local res = {}
	local instance
	for _, v in ipairs(instances) do
		if v.Id == id then
			instance = v
			break
		end
	end
	insert(res, "MovingInstance: " .. (moving_instance and moving_instance.Id or "nil"))
	if not instance then return res end
	insert(res, "Title: " .. instance.Title)
	insert(res, "TitleH: " .. instance.TitleH)
	insert(res, "X: " .. instance.X)
	insert(res, "Y: " .. instance.Y)
	insert(res, "W: " .. instance.W)
	insert(res, "H: " .. instance.H)
	insert(res, "ContentW: " .. instance.ContentW)
	insert(res, "ContentH: " .. instance.ContentH)
	insert(res, "TitleDeltaX: " .. instance.TitleDeltaX)
	insert(res, "TitleDeltaY: " .. instance.TitleDeltaY)
	insert(res, "SizeDeltaX: " .. instance.SizeDeltaX)
	insert(res, "SizeDeltaY: " .. instance.SizeDeltaY)
	insert(res, "DeltaContentW: " .. instance.DeltaContentW)
	insert(res, "DeltaContentH: " .. instance.DeltaContentH)
	insert(res, "Border: " .. instance.Border)
	insert(res, "Layer: " .. instance.Layer)
	insert(res, "Stack Index: " .. instance.StackIndex)
	insert(res, "AutoSizeWindow: " .. tostring(instance.AutoSizeWindow))
	insert(res, "AutoSizeContent: " .. tostring(instance.AutoSizeContent))
	insert(res, "Hot Item: " .. tostring(instance.HotItem))
	return res
end

function Window.GetStackDebug()
	local res = {}
	for i, v in ipairs(stack) do
		local str_locked = v.Id == stack_lock_id and " (Locked)" or STR_EMPTY
		local str = format("%s: %s%s", tostring(v.StackIndex), v.Id, str_locked)
		res[i] = str
	end
	return res
end

function Window.IsAutoSize()
	if not active_instance then return false end
	return active_instance.AutoSizeWindowW or active_instance.AutoSizeWindowH
end

function Window.Save(tbl)
	if not tbl then return end
	local settings = {}
	for _, v in ipairs(instances) do
		if not v.NoSavedSettings then
			settings[v.Id] = {
				X = v.TitleDeltaX,
				Y = v.TitleDeltaY,
				W = v.SizeDeltaX,
				H = v.SizeDeltaY,
			}
		end
	end
	tbl.Window = settings
end

function Window.Load(tbl)
	if not tbl then return end
	local settings = tbl.Window
	for k, v in pairs(settings) do
		local instance = GetInstance(k)
		instance.TitleDeltaX = v.X
		instance.TitleDeltaY = v.Y
		instance.SizeDeltaX = v.W
		instance.SizeDeltaY = v.H
	end
end

function Window.GetMovingInstance()
	return moving_instance
end

--[[
	Allow developers to push/pop a custom ID to the stack. This can help with differentiating between controls with identical IDs i.e. text fields.
--]]
function Window.PushID(id)
	if not active_instance then return end
	insert(id_stack, id)
end

function Window.PopID()
	if #id_stack <= 0 then return end
	return remove(id_stack)
end

function Window.ToDock(dock_type)
	local instance = GetInstance()
	instance.W = 720
	instance.H = 720
	Dock.SetPendingWindow(instance, dock_type)
	Dock.Override()
end

return Window
