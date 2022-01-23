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

local DrawCommands = require(SLAB_PATH .. ".Internal.Core.DrawCommands")
local MenuState = require(SLAB_PATH .. ".Internal.UI.MenuState")
local Mouse = require(SLAB_PATH .. ".Internal.Input.Mouse")
local Style = require(SLAB_PATH .. ".Style")
local Utility = require(SLAB_PATH .. ".Internal.Core.Utility")

local Dock = {}

local instances = {}
local pending, pending_window
local modes = {left = "Left", bottom = "Bottom", right = "Right"}

local function IsValid(id)
	if not id or type(id) ~= "string" then return false end
	for _, v in pairs(modes) do
		if v == id then return true end
	end
	return false
end

local function GetInstance(id)
	if not instances[id] then
		local instance = {
			Id = id,
			Reset = false,
			TearX = 0, TearY = 0,
			Torn = false, Enabled = true,
			NoSavedSettings = false
		}
		instances[id] = instance
	end
	return instances[id]
end

local function GetOverlayBounds(t)
	local x, y, w, h = 0, 0, 0, 0
	local view_w, view_h = love.graphics.getDimensions()
	local offset = 75

	if t == modes.left then
		w, h = 100, 150
		x = offset
		y = view_h * 0.5 - h * 0.5
	elseif t == modes.right then
		w, h = 100, 150
		x = view_w - offset - w
		y = view_h * 0.5 - h * 0.5
	elseif t == modes.bottom then
		w = view_w * 0.55
		h = 100
		x = view_w * 0.5 - w * 0.5
		y = view_h - offset - h
	end
	return x, y, w, h
end

local COLOR = {0.29, 0.59, 0.83, 0.65}
local COLOR2 = {0.5, 0.75, 0.96, 0.65}
local COLOR_BLACK = {0, 0, 0, 1}

local function DrawOverlay(t)
	local instance = GetInstance(t)
	if instance and (instance.Window or instance.Enabled) then return end
	local x, y, w, h = GetOverlayBounds(t)
	local color = COLOR
	local title_h, spacing = 14, 6
	local mx, my = Mouse.Position()

	if x <= mx and mx <= x + w and y <= my and my <= y + h then
		color = COLOR2
		pending = t
	end

	DrawCommands.Rectangle("fill", x, y, w, title_h, color)
	DrawCommands.Rectangle("line", x, y, w, title_h, COLOR_BLACK)
	y = y + title_h + spacing
	h = h - title_h - spacing
	DrawCommands.Rectangle("fill", x, y, w, h, color)
	DrawCommands.Rectangle("line", x, y, w, h, COLOR_BLACK)
end

function Dock.DrawOverlay()
	pending = nil
	DrawCommands.SetLayer(DrawCommands.layers.dock)
	DrawCommands.Begin()
	DrawOverlay(modes.left)
	DrawOverlay(modes.right)
	DrawOverlay(modes.bottom)
	DrawCommands.End()

	if Mouse.IsReleased(1) then
		for _, instance in pairs(instances) do
			instance.IsTearing = false
		end
	end
end

function Dock.Override()
	if not (pending and pending_window) then return end
	local instance = GetInstance(pending)
	instance.Window = pending_window.Id
	instance.Reset = true
	pending_window, pending = nil, nil
end

function Dock.Commit()
	if not (pending and pending_window and Mouse.IsReleased(1)) then return end
	local instance = GetInstance(pending)
	instance.Window = pending_window.Id
	instance.Reset = true
	pending_window, pending = nil, nil
end

function Dock.GetDock(win_id)
	for k, v in pairs(instances) do
		if v.Window == win_id then
			return k
		end
	end
	return nil
end

function Dock.GetBounds(t, opt)
	local x, y, w, h = 0, 0, 0, 0
	local view_w, view_h = love.graphics.getDimensions()
	local main_menu_bar_h = MenuState.MainMenuBarH
	local title_h = Style.Font:getHeight()

	if t == modes.left then
		y = main_menu_bar_h
		w = opt.W or 150
		h = view_h - y - title_h
	elseif t == modes.right then
		x = view_w - 150
		y = main_menu_bar_h
		w = opt.W or 150
		h = view_h - y - title_h
	elseif t == modes.bottom then
		y = view_h - 150
		w = view_w
		h = opt.H or 150
	end
	return x, y, w, h
end

local TBL_EMPTY = {}
local TBL_E = {"E"}
local TBL_W = {"W"}
local TBL_N = {"N"}

function Dock.AlterOptions(win_id, opt)
	opt = opt or TBL_EMPTY
	for id, instance in pairs(instances) do
		if instance.Window == win_id then
			if instance.Torn or not instance.Enabled then
				instance.Window = nil
				Utility.CopyValues(opt, instance.CachedOptions)
				instance.CachedOptions = nil
				instance.Torn = false
				opt.ResetSize = true
			else
				if instance.Reset then
					instance.CachedOptions = {
						X = opt.X,
						Y = opt.Y,
						W = opt.W,
						H = opt.H,
						AllowMove = opt.AllowMove,
						Layer = opt.Layer,
						SizerFilter = Utility.Copy(opt.SizerFilter),
						AutoSizeWindow = opt.AutoSizeWindow,
						AutoSizeWindowW = opt.AutoSizeWindowW,
						AutoSizeWindowH = opt.AutoSizeWindowH,
						AllowResize = opt.AllowResize,
					}
				end

				opt.AllowMove = false
				opt.Layer = DrawCommands.layers.dock
				if id == modes.left then
					opt.SizerFilter = TBL_E
				elseif id == modes.right then
					opt.SizerFilter = TBL_W
				elseif id == modes.bottom then
					opt.SizerFilter = TBL_N
				end

				local x, y, w, h = Dock.GetBounds(id, opt)
				opt.X = x
				opt.Y = y
				opt.W = w
				opt.H = h
				opt.AutoSizeWindow = false
				opt.AutoSizeWindowW = false
				opt.AutoSizeWindowH = false
				opt.AllowResize = true
				opt.ResetPosition = instance.Reset
				opt.ResetSize = instance.Reset
				instance.Reset = false
			end
			break
		end
	end
end

function Dock.SetPendingWindow(instance, t)
	pending_window = instance
	pending = t or pending
end

function Dock.GetPendingWindow()
	return pending_window
end

function Dock.IsTethered(win_id)
	for _, instance in pairs(instances) do
		if instance.Window == win_id then
			return not instance.Torn
		end
	end
	return false
end

function Dock.BeginTear(win_id, x, y)
	for _, instance in pairs(instances) do
		if instance.Window == win_id then
			instance.TearX, instance.TearY = x, y
			instance.IsTearing = true
		end
	end
end

local THRESHOLD = 25 * 25
function Dock.UpdateTear(win_id, x, y)
	for _, instance in pairs(instances) do
		if instance.Window == win_id and instance.IsTearing then
			local dx = instance.TearX - x
			local dy = instance.TearY - y
			local d = dx * dx + dy * dy
			if d >= THRESHOLD then
				instance.IsTearing = false
				instance.Torn = true
			end
		end
	end
end

function Dock.GetCachedOptions(win_id)
	for _, instance in pairs(instances) do
		if instance.Window == win_id then
			return instance.CachedOptions
		end
	end
	return nil
end

function Dock.Toggle(list, enabled)
	list = list or TBL_EMPTY
	enabled = enabled or true

	if type(list) == "string" then
		list = {list}
	end

	for _, v in ipairs(list) do
		if IsValid(v) then
			local instance = GetInstance(v)
			instance.Enabled = enabled
		end
	end
end

function Dock.SetOptions(t, opt)
	if IsValid(t) then
		opt = opt or TBL_EMPTY
		opt.NoSavedSettings = not not opt.NoSavedSettings
		local instance = GetInstance(t)
		instance.NoSavedSettings = opt.NoSavedSettings
	end
end

function Dock.Save(tbl)
	if not tbl then return end
	local taken, settings = {}, {}
	for k, v in pairs(instances) do
		local v_win = v.Window
		if not v.NoSavedSettings and v.Window and not taken[v_win] then
			if v_win then
				taken[v_win] = true
			end
			settings[k] = tostring(v_win)
		end
		tbl.Dock = settings
	end
end

function Dock.Load(tbl)
	if not tbl then return end
	local settings = tbl.Dock
	if not settings then return end
	for k, v in pairs(settings) do
		local instance = GetInstance(k)
		instance.Window = v
	end
end

return Dock

