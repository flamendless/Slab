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
local format = string.format
local min = math.min

local Cursor = require(SLAB_PATH .. ".Internal.Core.Cursor")
local DrawCommands = require(SLAB_PATH .. ".Internal.Core.DrawCommands")
local Enums = require(SLAB_PATH .. ".Internal.Core.Enums")
local LayoutManager = require(SLAB_PATH .. ".Internal.UI.LayoutManager")
local Mouse = require(SLAB_PATH .. ".Internal.Input.Mouse")
local Style = require(SLAB_PATH .. ".Style")
local Text = require(SLAB_PATH .. ".Internal.UI.Text")
local Window = require(SLAB_PATH .. ".Internal.UI.Window")
local Utility = require(SLAB_PATH .. ".Internal.Core.Utility")

local Tooltip = {}
local last_dt, accum_dt = 0, 0
local time = 0.75
local exp_time = 0.025
local alpha, oy = 0, 0
local reset_size = false

local STR_EMPTY = ""
local TBL_IGNORE = {Ignore = true}
local tbl_color = {}

function Tooltip.Begin(tip)
	if not tip or tip == STR_EMPTY then return end
	local elapsed = love.timer.getTime() - last_dt
	if elapsed > exp_time then
		accum_dt = 0
		alpha = 0
		reset_size = true
	end

	last_dt = love.timer.getDelta()
	local dt = love.timer.getDelta()
	accum_dt = accum_dt + dt
	if accum_dt <= time then return end

	local mx, my = Mouse.Position()
	alpha = min(alpha + dt * 4, 1)
	local text_color = Utility.MakeColor(Style.TextColor, alpha)
	local cx, cy = Cursor.GetPosition()
	LayoutManager.Begin("Ignore", TBL_IGNORE)
	Window.Begin("tooltip", {
		X = mx, Y = my - oy,
		W = 0, H = 0,
		AutoSizeWindow = true,
		AutoSizeContent = false,
		AllowResize = false,
		AllowFocus = false,
		Layer = Enums.layers.context_menu,
		ResetWindowSize = reset_size,
		CanObstruct = false,
		NoSavedSettings = true
	})
	tbl_color.Color = text_color
	Text.BeginFormatted(tip, tbl_color)
	oy = Window.GetHeight()
	Window.End()
	LayoutManager.End()
	Cursor.SetPosition(cx, cy)
	reset_size = false
end

function Tooltip.GetDebugInfo()
	local info = {}
	local elapsed = love.timer.getTime() - last_dt
	insert(info, format("Time: %.2f", accum_dt))
	insert(info, format("Is Visible: %s", tostring(accum_dt > time and elapsed <= exp_time)))
	insert(info, format("Time to Display: %.2f", time))
	insert(info, format("Expire Time: %f", exp_time))
	return info
end

return Tooltip
