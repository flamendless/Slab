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

local Stats = require(SLAB_PATH .. ".Internal.Core.Stats")
local Utility = require(SLAB_PATH .. ".Internal.Core.Utility")

local insert = table.insert
local remove = table.remove
local sort = table.sort
local sin = math.sin
local cos = math.cos
local rad = math.rad
local max = math.max

local DrawCommands = {
	layers = {
		normal = 1,
		dock = 2,
		context_menu = 3,
		main_menu_bar = 4,
		dialog = 5,
		debug = 6,
		mouse = 7
	}
}

local active_batch, pending_batches = {}, {}
local shaders = {}

local types = {
	rect = 1,
	triangle = 2,
	text = 3,
	scissor = 4,
	transform_push = 5,
	transform_pop = 6,
	apply_transform = 7,
	check = 8,
	line = 9,
	text_formatted = 10,
	intersect_scissor = 11,
	cross = 12,
	image = 13,
	sub_image = 14,
	circle = 15,
	draw_canvas = 16,
	mesh = 17,
	text_object = 18,
	curve = 19,
	polygon = 20,
	shader_push = 21,
	shader_pop = 22,
}

local layer_table = {}
local active_layer = DrawCommands.layers.normal
local stats_category = "Slab Draw"

local function AddArc(verts, cx, cy, radius, angle1, angle2, segments, x, y)
	local cxx = cx + x
	local cyy = cy + y

	if radius == 0 then
		insert(verts, cxx)
		insert(verts, cyy)
		return
	end

	local step = (angle1 - angle2)/segments
	for theta = angle1, angle2, step do
		local radians = rad(theta)
		insert(verts, sin(radians) * radius + cxx)
		insert(verts, cos(radians) * radius + cyy)
	end
end

local function GetLayerDebugInfo(layer)
	if not layer then return end
	local res = {}
	local channels = {}

	res["Channel Count"] = #layer

	for k, channel in pairs(layer) do
		local collection = {}
		collection["Batch Count"] = #channel
		insert(channels, collection)
	end

	res["Channels"] = channels

	return res
end

local function DrawRect(rect)
	local stat_handle = Stats.Begin("DrawRect", stats_category)
	local prev_line_w = love.graphics.getLineWidth()
	local px_offset = Rect.Mode == "line" and 0.5 or 0

	love.graphics.setLineWidth(rect.line_w)
	love.graphics.setColor(rect.color)
	love.graphics.rectangle(rect.mode,
		rect.x + px_offset, rect.y + px_offset,
		rect.width, rect.height, rect.radius, rect.radius)
	love.graphics.setLineWidth(prev_line_w)
	Stats.End(stat_handle)
end

local function GetTriangleVertices(x, y, radius, rotation)
	local radians = rad(rotation)
	local x1, y1 = 0, -radius
	local x2, y2 = -radius, radius
	local x3, y3 = radius, radius

	local cos_rad = cos(radians)
	local sin_rad = sin(radians)

	local px1 = x1 * cos_rad - y1 * sin_rad
	local py1 = y1 * cos_rad + x1 * sin_rad

	local px2 = x2 * cos_rad - y2 * sin_rad
	local py2 = y2 * cos_rad + x2 * sin_rad

	local px3 = x3 * cos_rad - y3 * sin_rad
	local py3 = y3 * cos_rad + x3 * sin_rad

	return {
		x + px1, y + py1,
		x + px2, y + py2,
		x + px3, y + py3,
	}
end

local function DrawTriangle(triangle)
	local stat_handle = Stats.Begin("DrawTriangle", stats_category)
	local vertices = GetTriangleVertices(triangle.x, triangle.y, triangle.radius, triangle.rotation)
	love.graphics.setColor(triangle.color)
	love.graphics.polygon(triangle.mode, vertices)
	Stats.End(stat_handle)
end

local function DrawCheck(check)
	local stat_handle = Stats.Begin("DrawCheck", stats_category)
	love.graphics.setColor(check.color)
	local vertices = {
		check.x - check.radius * 0.5, check.y,
		check.x, check.y + check.radius,
		check.x + check.radius, check.y - check.radius
	}
	love.graphics.line(vertices)
	Stats.End(stat_handle)
end

local function DrawText(text)
	local stat_handle = Stats.Begin("DrawText", stats_category)
	love.graphics.setFont(text.font)
	love.graphics.setColor(text.color)
	love.graphics.print(text.text, text.x, text.y)
	Stats.End(stat_handle)
end

local function DrawTextFormatted(text)
	local stat_handle = Stats.Begin("DrawTextFormatted", stats_category)
	love.graphics.setFont(text.font)
	love.graphics.setColor(text.color)
	love.graphics.printf(text.text, text.x, text.y, text.w, text.align)
	Stats.End(stat_handle)
end

local function DrawTextObject(text)
	local stat_handle = Stats.Begin("DrawTextObject", stats_category)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(text.text, text.x, text.y)
	Stats.End(stat_handle)
end

local function DrawLine(line)
	local stat_handle = Stats.Begin("DrawLine", stats_category)
	local prev_line_w = love.graphics.getLineWidth()
	love.graphics.setColor(line.color)
	love.graphics.setLineWidth(line.width)
	love.graphics.line(line.x1, line.y1, line.x2, line.y2)
	love.graphics.setLineWidth(prev_line_w)
	Stats.End(stat_handle)
end

local function DrawCross(cross)
	local stat_handle = Stats.Begin("DrawCross", stats_category)
	local x, y, r = cross.x, cross.y, cross.radius
	love.graphics.setColor(cross.color)
	love.graphics.line(x - r, y - r, x + r, y + r)
	love.graphics.line(x - r, y + r, x + r, y - r)
	Stats.End(stat_handle)
end

local function DrawImage(image)
	local stat_handle = Stats.Begin("DrawImage", stats_category)
	love.graphics.setColor(image.color)
	love.graphics.draw(image.image, image.x, image.y, image.rotation, image.sx, image.sy)
	Stats.End(stat_handle)
end

local function DrawSubImage(image)
	local stat_handle = Stats.Begin('DrawSubImage', stats_category)
	love.graphics.setColor(image.color)
	love.graphics.draw(image.image, image.quad, image.transform)
	Stats.End(stat_handle)
end

local function DrawCircle(circle)
	local stat_handle = Stats.Begin('DrawCircle', stats_category)
	love.graphics.setColor(circle.color)
	love.graphics.circle(circle.mode, circle.x, circle.y, circle.radius, circle.segments)
	Stats.End(stat_handle)
end

local function DrawCurve(curve)
	local stat_handle = Stats.Begin("DrawCurve", stats_category)
	love.graphics.setColor(curve.color)
	love.graphics.line(curve.points)
	Stats.End(stat_handle)
end

local function DrawPolygon(polygon)
	local stat_handle = Stats.Begin("DrawPolygon", stats_category)
	love.graphics.setColor(polygon.color)
	love.graphics.polygon(polygon.mode, polygon.points)
	Stats.End(stat_handle)
end

local function DrawCanvas(canvas)
	local stat_handle = Stats.Begin("DrawCanvas", stats_category)
	love.graphics.setBlendMode("alpha", "premultiplied")
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(canvas.canvas, canvas.x, canvas.y)
	love.graphics.setBlendMode("alpha")
	Stats.End(stat_handle)
end

local function DrawMesh(mesh)
	local stat_handle = Stats.Begin("DrawMesh", stats_category)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(mesh.mesh, mesh.x, mesh.y)
	Stats.End(stat_handle)
end

local function DrawElements(elements)
	local stat_handle = Stats.Begin("Draw Elements", stats_category)
	for k, v in pairs(elements) do
		local e_type = v.type
		if e_type == types.rect then
			DrawRect(v)
		elseif e_type == types.triangle then
			DrawTriangle(v)
		elseif e_type == types.text then
			DrawText(v)
		elseif e_type == types.scissor then
			love.graphics.setScissor(v.x, v.y, v.w, v.h)
		elseif e_type == types.transform_push then
			love.graphics.push()
		elseif e_type == types.transform_pop then
			love.graphics.pop()
		elseif e_type == types.apply_transform then
			love.graphics.applyTransform(v.transform)
		elseif e_type == types.check then
			DrawCheck(v)
		elseif e_type == types.line then
			DrawLine(v)
		elseif e_type == types.text_formatted then
			DrawTextFormatted(v)
		elseif e_type == types.intersect_scissor then
			love.graphics.intersectScissor(v.x, v.y, v.w, v.h)
		elseif e_type == types.cross then
			DrawCross(v)
		elseif e_type == types.image then
			DrawImage(v)
		elseif e_type == types.sub_image then
			DrawSubImage(v)
		elseif e_type == types.circle then
			DrawCircle(v)
		elseif e_type == types.draw_canvas then
			DrawCanvas(v)
		elseif e_type == types.mesh then
			DrawMesh(v)
		elseif e_type == types.text_object then
			DrawTextObject(v)
		elseif e_type == types.curve then
			DrawCurve(v)
		elseif e_type == types.polygon then
			DrawPolygon(v)
		elseif e_type == types.shader_push then
			insert(shaders, 1, v.shader)
			love.graphics.setShader(v.shader)
		elseif e_type == types.shader_pop then
			love.graphics.setShader(remove(shaders, 1))
		end
	end
	Stats.End(stat_handle)
end

local function AssertActiveBatch()
	assert(active_batch ~= nil, "DrawCommands.Begin was not called before commands were issued!")
end

local function DrawLayer(layer, name)
	if not layer then return end
	if not layer.channels then return end
	local stat_handle = Stats.Begin("Draw Layer " .. name, stats_category)
	local keys = {}

	for k, channel in pairs(layer.channels) do
		insert(keys, k)
	end
	sort(keys)

	for i, c in ipairs(keys) do
		local channel = layer.channels[c]
		if channel then
			for i, v in ipairs(channel) do
				DrawElements(v.elements)
			end
		end
	end
	Stats.End(stat_handle)
end

function DrawCommands.Reset()
	Utility.ClearTable(layer_table)
	Utility.ClearTable(pending_batches)
	Utility.ClearTable(shaders)
	Utility.ClearTable(active_batch)
	active_layer = DrawCommands.layers.normal

	for _, v in pairs(DrawCommands.layers) do
		layer_table[v] = {}
	end
end

function DrawCommands.Begin(opt)
	opt = opt and {} or opt
	opt.channel = opt.channel or 1

	local active = layer_table[active_layer]
	if not active then
		layer_table[active_layer] = {}
	end
	active = layer_table[active_layer]

	if not active.channels then
		active.channels = {}
	end

	local channels = active.channels
	if not channels[opt.channel] then
		channels[opt.channel] = {}
	end

	local c = channels[opt.channel]
	Utility.ClearTable(active_batch)
	active_batch.elements = {}
	insert(channels, active_batch)
	insert(pending_batches, 1, active_batch)
end

function DrawCommands.End(clear_elements)
	if not active_batch then return end
	if clear_elements then
		Utility.ClearTable(active_batch.elements)
	end
	love.graphics.setScissor()
	remove(pending_batches, 1)
	Utility.ClearTable(active_batch)

	if #pending_batches > 0 then
		active_batch = pending_batches[1]
	end
end

function DrawCommands.SetLayer(layer)
	for k, v in pairs(DrawCommands.layers) do
		if layer == v then
			active_layer = v
			return
		end
	end
end

function DrawCommands.Execute()
	local stat_handle = Stats.Begin("Execute", stats_category)
	DrawLayer(layer_table[DrawCommands.layers.normal], "normal")
	DrawLayer(layer_table[DrawCommands.layers.dock], "dock")
	DrawLayer(layer_table[DrawCommands.layers.context_menu], "context_menu")
	DrawLayer(layer_table[DrawCommands.layers.main_menu_bar], "main_menu_bar")
	DrawLayer(layer_table[DrawCommands.layers.dialog], "dialog")
	DrawLayer(layer_table[DrawCommands.layers.debug], "debug")
	DrawLayer(layer_table[DrawCommands.layers.mouse], "mouse")
	love.graphics.setShader()
	Stats.End(stat_handle)
end

function DrawCommands.GetDebugInfo()
	local res = {}
	for k, v in pairs(DrawCommands.layers) do
		res[k] = GetLayerDebugInfo(layer_table[v])
	end
	return res
end

local COLOR_BLACK = {0, 0, 0, 1}
local COLOR_WHITE = {1, 1, 1, 1}
function DrawCommands.Rectangle(mode, x, y, width, height, color, radius, segments, line_w)
	AssertActiveBatch()
	if type(radius) == "table" then
		local tl = radius[1] or 0
		local tr = radius[2] or 0
		local br = radius[3] or 0
		local bl = radius[4] or 0

		local verts = {}
		segments = segments or 10
		AddArc(verts, width - br, height - br, br, 0, 90, segments, x, y)
		AddArc(verts, width - tr, tr, tr, 90, 180, segments, x, y)
		AddArc(verts, tl, tl, tl, 180, 270, segments, x, y)
		AddArc(verts, bl, height - bl, bl, 270, 360, segments, x, y)
		DrawCommands.Polygon(mode, verts, color)
	else
		local item = {
			type = types.rect,
			mode = mode,
			x = x, y = y,
			width = width, height = height,
			color = color or COLOR_BLACK,
			radius = radius or 0,
			line_w = line_w or love.graphics.getLineWidth()
		}
		insert(active_batch.elements, item)
	end
end

function DrawCommands.Triangle(mode, x, y, radius, rotation, color)
	AssertActiveBatch()
	local item = {
		type = types.triangle,
		mode = mode,
		x = x, y = y,
		radius = radius,
		rotation = rotation,
		color = color or COLOR_BLACK
	}
	insert(active_batch.elements, item)
end

function DrawCommands.Print(text, x, y, color, font)
	AssertActiveBatch()
	local item = {
		type = types.text,
		text = text,
		x = x, y = y,
		color = color or COLOR_BLACK,
		font = font
	}
	insert(active_batch.elements, item)
end

function DrawCommands.Printf(text, x, y, w, align, color, font)
	AssertActiveBatch()
	local item = {
		type = types.text_formatted,
		text = text,
		x = x, y = y, w = w,
		align = align or "left",
		color = color or COLOR_BLACK,
		font = font,
	}
	insert(active_batch.elements, item)
end

function DrawCommands.Scissor(x, y, w, h)
	AssertActiveBatch()
	w = w and max(w, 0)
	h = h and max(h, 0)
	local item = {
		type = types.scissor,
		x = x, y = y,
		w = w, h = h,
	}
	insert(active_batch.elements, item)
end

function DrawCommands.IntersectScissor(x, y, w, h)
	AssertActiveBatch()
	w = w and max(w, 0) or 0
	h = h and max(h, 0) or 0
	local item = {
		type = types.intersect_scissor,
		x = x or 0, y = y or 0,
		w = w, h = h
	}
	insert(active_batch.elements, item)
end

function DrawCommands.TransformPush()
	AssertActiveBatch()
	local item = { type = types.transform_push }
	insert(active_batch.elements, item)
end

function DrawCommands.TransformPop()
	AssertActiveBatch()
	local item = { type = types.transform_pop }
	insert(active_batch.elements, item)
end

function DrawCommands.ApplyTransform(transform)
	AssertActiveBatch()
	local item = {
		type = types.apply_transform,
		transform = transform
	}
	insert(active_batch.elements, item)
end

function DrawCommands.Check(x, y, radius, color)
	AssertActiveBatch()
	local item = {
		type = types.check,
		x = x, y = y,
		radius = radius,
		color = color or COLOR_BLACK
	}
	insert(active_batch.elements, item)
end

function DrawCommands.Line(x1, y1, x2, y2, width, color)
	AssertActiveBatch()
	local item = {
		type = types.line,
		x1 = x1, y1 = y1,
		x2 = x2, y2 = y2,
		width = width,
		color = color or COLOR_BLACK
	}
	insert(active_batch.elements, item)
end

function DrawCommands.Cross(x, y, radius, color)
	AssertActiveBatch()
	local item = {
		type = types.cross,
		x = x, y = y,
		radius = radius,
		color = color or COLOR_BLACK
	}
	insert(active_batch.elements, item)
end

function DrawCommands.Image(x, y, image, rotation, sx, sy, color)
	AssertActiveBatch()
	local item = {
		type = types.image,
		x = x, y = y,
		image = image, rotation = rotation,
		sx = sx, sy = sy,
		color = color or COLOR_WHITE
	}
	insert(active_batch.elements, item)
end

function DrawCommands.SubImage(x, y, image, sub_x, sub_y, sw, sh, rotation, sx, sy, color)
	AssertActiveBatch()
	local item = {
		type = types.sub_image,
		transform = love.math.newTransform(x, y, rotation, sx, sy),
		image = image,
		quad = love.graphics.newQuad(sub_x, sub_y, sw, sh, image:getDimensions()),
		color = color or COLOR_WHITE,
	}
	insert(active_batch.elements, item)
end

function DrawCommands.Circle(mode, x, y, radius, color, segments)
	AssertActiveBatch()
	local item = {
		type = types.circle,
		mode = mode,
		x = x, y = y,
		radius = radius,
		color = color or COLOR_BLACK,
		segments = segments or 24
	}
	insert(active_batch.elements, item)
end

function DrawCommands.DrawCanvas(canvas, x, y)
	AssertActiveBatch()
	local item = {
		type = types.draw_canvas,
		canvas = canvas,
		x = x, y = y,
	}
	insert(active_batch.elements, item)
end

function DrawCommands.Mesh(mesh, x, y)
	AssertActiveBatch()
	local item = {
		type = types.mesh,
		mesh = mesh,
		x = x, y = y,
	}
	insert(active_batch.elements, item)
end

function DrawCommands.Text(text, x, y)
	AssertActiveBatch()
	local item = {
		type = types.text_object,
		text = text,
		x = x, y = y,
		color = COLOR_BLACK,
	}
	insert(active_batch.elements, item)
end

function DrawCommands.Curve(points, color)
	AssertActiveBatch()
	local item = {
		type = types.curve,
		points = points,
		color = color or COLOR_BLACK,
	}
	insert(active_batch.elements, item)
end

function DrawCommands.Polygon(mode, points, color)
	AssertActiveBatch()
	local item = {
		type = types.polygon,
		mode = mode, points = points,
		color = color or COLOR_BLACK,
	}
	insert(active_batch.elements, item)
end

function DrawCommands.PushShader(shader)
	AssertActiveBatch()
	local item = {
		type = types.shader_push,
		shader = shader,
	}
	insert(active_batch.elements, item)
end

function DrawCommands.PopShader()
	AssertActiveBatch()
	local item = { type = types.shader_pop }
	insert(active_batch.elements, item)
end

return DrawCommands
