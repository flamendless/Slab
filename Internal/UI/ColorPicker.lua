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
local ceil = math.ceil
local max = math.max
local min = math.min
local insert = table.insert
local format = string.format

local Button = require(SLAB_PATH .. ".Internal.UI.Button")
local Cursor = require(SLAB_PATH .. ".Internal.Core.Cursor")
local DrawCommands = require(SLAB_PATH .. ".Internal.Core.DrawCommands")
local Image = require(SLAB_PATH .. ".Internal.UI.Image")
local Input = require(SLAB_PATH .. ".Internal.UI.Input")
local LayoutManager = require(SLAB_PATH .. ".Internal.UI.LayoutManager")
local Mouse = require(SLAB_PATH .. ".Internal.Input.Mouse")
local Style = require(SLAB_PATH .. ".Style")
local Text = require(SLAB_PATH .. ".Internal.UI.Text")
local Utility = require(SLAB_PATH .. ".Internal.Core.Utility")
local Window = require(SLAB_PATH .. ".Internal.UI.Window")

local ColorPicker = {}

local sat_meshes, tint_meshes, alpha_mesh
local sat_size, sat_step, sat_focused = 200, 5, false
local tint_w, tint_h, tint_focused = 30, sat_size, false
local alpha_w, alpha_h, alpha_focused = tint_w, tint_h, false
local current_color = {1, 1, 1, 1}
local color_h = 25

local STR_CP = "ColorPicker_"
local TBL_EMPTY = {}
local TBL_ALIGNX = {AlignX = "right"}
local COLOR_WHITE = {1, 1, 1, 1}
local STR_HASH2 = "##"
local STR_HASH4 = "####"
local STR_NEW = "New"
local STR_OLD = "Old"
local TBL_CP = {Title = "ColorPicker"}
local PATH = SLAB_FILE_PATH .. "/Internal/Resources/Textures/Transparency.png"

local function InputColor(component, value, offset_x)
	local changed = false
	Text.Begin(format("%s ", component))
	Cursor.SameLine()
	Cursor.SetRelativeX(offset_x)
	if Input.Begin(STR_CP .. component, {
		W = 40.0,
		NumbersOnly = true,
		Text = tostring(ceil(value * 255)),
		ReturnOnText = false
	}) then
		local nv = Input.GetNumber()
		if nv then
			nv = max(nv, 0)
			nv = min(nv, 255)
			value = nv/255
			changed = true
		end
	end
	return value, changed
end

local function UpdateSaturationColors()
	if not sat_meshes then return end
	local mesh_index = 1
	local step = sat_step
	local c00 = {1, 1, 1, 1}
	local c10 = {1, 1, 1, 1}
	local c01 = {1, 1, 1, 1}
	local c11 = {1, 1, 1, 1}
	local step_x, step_y = 0, 0
	local hue = Utility.RGBtoHSV(current_color[1], current_color[2], current_color[3])

	for _ = 1, step do
		for _ = 1, step do
			local s0 = step_x/step
			local s1 = (step_x + 1)/step
			local v0 = 1 - (step_y/step)
			local v1 = 1 - ((step_y + 1)/step)

			c00[1], c00[2], c00[3] = Utility.HSVtoRGB(hue, s0, v0)
			c10[1], c10[2], c10[3] = Utility.HSVtoRGB(hue, s1, v0)
			c01[1], c01[2], c01[3] = Utility.HSVtoRGB(hue, s0, v1)
			c11[1], c11[2], c11[3] = Utility.HSVtoRGB(hue, s1, v1)

			local mesh = sat_meshes[mesh_index]
			mesh_index = mesh_index + 1
			mesh:setVertexAttribute(1, 3, c00[1], c00[2], c00[3], c00[4])
			mesh:setVertexAttribute(2, 3, c10[1], c10[2], c10[3], c10[4])
			mesh:setVertexAttribute(3, 3, c11[1], c11[2], c11[3], c11[4])
			mesh:setVertexAttribute(4, 3, c01[1], c01[2], c01[3], c01[4])
			step_x = step_x + 1
		end
		step_x = 0
		step_y = step_y + 1
	end
end

local function InitializeSaturationMeshes()
	if sat_meshes then
		UpdateSaturationColors()
		return
	end

	sat_meshes = {}
	Utility.ClearArray(sat_meshes)
	local step = sat_step
	local x, y = 0, 0
	local size = sat_size/step
	for _ = 1, step do
		for _ = 1, step do
			local verts = {
				{x, y, 0, 0},
				{x + size, y, 1, 0},
				{x + size, y + size, 1, 1},
				{x, y + size, 0, 1}
			}
			local new_mesh = love.graphics.newMesh(verts)
			insert(sat_meshes, new_mesh)
			x = x + size
		end
		x = 0
		y = y + size
	end
	UpdateSaturationColors()
end

local function InitializeTintMeshes()
	if tint_meshes then return end
	tint_meshes = {}
	local step = 6
	local x, y = 0, 0
	local c0, c1
	local colors = {
		{1, 0, 0, 1},
		{1, 1, 0, 1},
		{0, 1, 0, 1},
		{0, 1, 1, 1},
		{0, 0, 1, 1},
		{1, 0, 1, 1},
		{1, 0, 0, 1},
	}

	for index = 1, step do
		c0 = colors[index]
		c1 = colors[index + 1]
		local verts = {
			{x, y, 0, 0, c0[1], c0[2], c0[3], c0[4]},
			{tint_w, y, 1, 0, c0[1], c0[2], c0[3], c0[4]},
			{tint_w, y + tint_h/step, 1, 1, c1[1], c1[2], c1[3], c1[4]},
			{x, y + tint_h/step, 0, 1, c1[1], c1[2], c1[3], c1[4]}
		}
		local new_mesh = love.graphics.newMesh(verts)
		insert(tint_meshes, new_mesh)
		y = y + tint_h/step
	end
end

local function InitializeAlphaMesh()
	if alpha_mesh then return end
	local verts = {
		{0, 0, 0, 0, 1, 1, 1, 1},
		{alpha_w, 0, 1, 0, 1, 1, 1, 1},
		{alpha_w, alpha_h, 1, 1, 0, 0, 0, 1},
		{0, alpha_h, 0, 1, 0, 0, 0, 1},
	}
	alpha_mesh = love.graphics.newMesh(verts)
end

local function DrawSat(x, y, mx, my, s, v, dragging, mouse_clicked)
	for _, v2 in ipairs(sat_meshes) do
		DrawCommands.Mesh(v2, x, y)
	end
	Window.AddItem(x, y, sat_size, sat_size)

	local update_sat = false
	if (x <= mx and mx < x + sat_size and y <= my and my < y + sat_size) and mouse_clicked then
		sat_focused = true
		update_sat = true
	end

	update_sat = sat_focused and dragging or update_sat
	if update_sat then
		local cx = max(mx - x, 0)
		local cy = max(my - y, 0)
		cx = min(cx, sat_size)
		cy = min(cy, sat_size)
		s = cx/sat_size
		v = 1 - (cy/sat_size)
		update_color = true
	end

	local sat_x = s * sat_size
	local sat_y = (1 - v) * sat_size
	DrawCommands.Circle("line", x + sat_x, y + sat_y, 4, COLOR_WHITE)
	x = x + sat_size + Cursor.PadX()
end

local function DrawTint(x, y, mx, my, h, dragging, mouse_clicked)
	for _, v2 in ipairs(tint_meshes) do
		DrawCommands.Mesh(v2, x, y)
	end
	Window.AddItem(x, y, tint_w, tint_h)

	local update_tint = false
	if x <= mx and mx < x + tint_w and y <= my and my < y + tint_h and mouse_clicked then
		tint_focused = true
		update_tint = true
	end
	update_tint = tint_focused and dragging or update_tint

	if update_tint then
		local cy = max(my - y, 0)
		cy = min(cy, tint_h)
		h = cy/tint_h
		update_color = true
	end

	local tint_y = h * tint_h
	DrawCommands.Line(x, y + tint_y, x + tint_w, y + tint_y, 2, COLOR_WHITE)
	x = x + tint_w + Cursor.PadX()
	DrawCommands.Mesh(alpha_mesh, x, y)
	Window.AddItem(x, y, alpha_w, alpha_h)

	local update_alpha = false
	if x <= mx and mx < x + alpha_w and y <= my and my < y + alpha_h and mouse_clicked then
		alpha_focused = true
		update_alpha = true
	end
	update_alpha = alpha_focused and dragging or update_alpha

	if update_alpha then
		local cy = max(my - y, 0)
		cy = min(cy, alpha_w)
		current_color[4] = 1 - cy/alpha_h
		update_color = true
	end
	local a = 1 - current_color[4]
	local ay = a * alpha_h
	DrawCommands.Line(x, y + ay, x + alpha_w, y + ay, 2, {a, a, a, 1})
	-- y = y + alpha_h + Cursor.PadY()
end

function ColorPicker.Begin(opt)
	opt = opt or TBL_EMPTY
	local color = opt.Color or COLOR_WHITE
	local refresh = not not opt.Refresh

	if not sat_meshes then
		InitializeSaturationMeshes()
	end

	if not tint_meshes then
		InitializeTintMeshes()
	end

	if not alpha_mesh then
		InitializeAlphaMesh()
	end

	TBL_CP.X, TBL_CP.Y = opt.X, opt.Y
	Window.Begin("ColorPicker", TBL_CP)
		if Window.IsAppearing() or refresh then
			current_color[1] = color[1] or 0
			current_color[2] = color[2] or 0
			current_color[3] = color[3] or 0
			current_color[4] = color[4] or 1
			UpdateSaturationColors()
		end

		local x, y = Cursor.GetPosition()
		local mx, my = Window.GetMousePosition()
		local h, s, v = Utility.RGBtoHSV(current_color[1], current_color[2], current_color[3])
		local update_color = false
		local mouse_clicked = Mouse.IsClicked(1) and (not Window.IsObstructedAtMouse())
		local dragging = Mouse.IsDragging(1)

		if sat_meshes then
			DrawSat(x, y, mx, my, s, v, dragging, mouse_clicked)
		end

		if tint_meshes then
			DrawTint(x, y, mx, my, h, dragging, mouse_clicked)
		end

		if update_color then
			current_color[1], current_color[2], current_color[3] = Utility.HSVtoRGB(h, s, v)
			UpdateSaturationColors()
		end

		local ox = Text.GetWidth(STR_HASH2)
		Cursor.AdvanceY(sat_size)
		y = Cursor.GetY()
		local r, g, b, a = unpack(current_color)
		current_color[1], changed_r = InputColor("R", r, ox)
		current_color[2], changed_g = InputColor("G", g, ox)
		current_color[3], changed_b = InputColor("B", b, ox)
		current_color[4], changed_a = InputColor("A", a, ox)

		if changed_r or changed_g or changed_b or changed_a then
			UpdateSaturationColors()
		end

		local ix, iy = Cursor.GetPosition()
		Cursor.SameLine()
		x = Cursor.GetX()
		Cursor.SetY(y)

		local wx = Window.GetBounds()
		local ww = Window.GetBorderlessSize()
		ox = Text.GetWidth(STR_HASH4)

		local color_x = x + ox
		local color_w = (wx + ww) - color_x
		Cursor.SetPosition(color_x, y)
		local br = Style.ButtonRounding

		Image.Begin("ColorPicker_CurrentAlpha", {
			Path = PATH,
			SubW = color_w,
			SubH = color_h,
			WrapH = "repeat",
			WrapV = "repeat"
		})
		DrawCommands.Rectangle("fill", color_x, y, color_w, color_h, current_color, br)
		local label_w, label_h = Text.GetSize(STR_NEW)
		Cursor.SetPosition(
			color_x - label_w - Cursor.PadX(),
			y + (color_h * 0.5) - (label_h * 0.5)
		)
		Text.Begin(STR_NEW)
		y = y + color_h + Cursor.PadY()
		Cursor.SetPosition(color_x, y)
		Image.Begin("ColorPicker_CurrentAlpha", {
			Path = PATH,
			SubW = color_w,
			SubH = color_h,
			WrapH = "repeat",
			WrapV = "repeat"
		})
		DrawCommands.Rectangle("fill", color_x, y, color_w, color_h, color, br)

		label_w, label_h = Text.GetSize(STR_OLD)
		Cursor.SetPosition(color_x - label_w - Cursor.PadX(),
			y + (color_h * 0.5) - (label_h * 0.5))
		Text.Begin(STR_OLD)

		if Mouse.IsReleased(1) then
			sat_focused, tint_focused, alpha_focused = false, false, false
		end

		Cursor.SetPosition(ix, iy)
		Cursor.NewLine()

		LayoutManager.Begin("ColorPicker_Buttons_Layout", TBL_ALIGNX)
		local res = {Button = 0, Color = Utility.MakeColor(current_color)}

		if Button.Begin("OK") then
			res.Button = 1
		end

		LayoutManager.SameLine()

		if Button.Begin("Cancel") then
			res.Button = -1
			res.Color = Utility.MakeColor(color)
		end
		LayoutManager.End()
	Window.End()
	return res
end

return ColorPicker
