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
local Enums = require(SLAB_PATH .. ".Internal.Core.Enums")
local Stats = require(SLAB_PATH .. ".Internal.Core.Stats")
local Utility = require(SLAB_PATH .. ".Internal.Core.Utility")
local TablePool = require(SLAB_PATH .. ".Internal.Core.TablePool")

local insert = table.insert
local remove = table.remove
local sin = math.sin
local cos = math.cos
local rad = math.rad
local max = math.max
local lg = love.graphics

local DrawCommands = {}

local ordered_layers = {
	"normal", "dock", "context_menu", "main_menu_bar", "dialog", "debug", "mouse"
}

local active_layer = Enums.layers.normal
local stats_category = "Slab Draw"
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
	canvas = 16,
	mesh = 17,
	text_object = 18,
	curve = 19,
	polygon = 20,
	shader_push = 21,
	shader_pop = 22,
}

local layer_table, pool = {}, {}
for _ in pairs(Enums.layers) do insert(layer_table, {}) end
for _ in pairs(types) do insert(pool, TablePool.new()) end

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

local function DrawRect(rect)
	local stat_handle = Stats.Begin("DrawRect", stats_category)
	local prev_line_w = lg.getLineWidth()
	local px_offset = rect.Mode == "line" and 0.5 or 0
	lg.setLineWidth(rect.line_w)
	lg.setColor(rect.color)
	lg.rectangle(rect.mode,
		rect.x + px_offset, rect.y + px_offset,
		rect.width, rect.height, rect.radius, rect.radius)
	lg.setLineWidth(prev_line_w)
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
	lg.setColor(triangle.color)
	lg.polygon(triangle.mode, vertices)
	Stats.End(stat_handle)
end

local function DrawCheck(check)
	local stat_handle = Stats.Begin("DrawCheck", stats_category)
	lg.setColor(check.color)
	local vertices = {
		check.x - check.radius * 0.5, check.y,
		check.x, check.y + check.radius,
		check.x + check.radius, check.y - check.radius
	}
	lg.line(vertices)
	Stats.End(stat_handle)
end

local function DrawText(text)
	local stat_handle = Stats.Begin("DrawText", stats_category)
	lg.setFont(text.font)
	lg.setColor(text.color)
	lg.print(text.text, text.x, text.y)
	Stats.End(stat_handle)
end

local function DrawScissor(v) lg.setScissor(v.x, v.y, v.w, v.h) end
local function TransformPush() lg.push() end
local function TransformPop() lg.pop() end
local function ApplyTransform(v) lg.applyTransform(v.transform) end

local function DrawTextFormatted(text)
	local stat_handle = Stats.Begin("DrawTextFormatted", stats_category)
	lg.setFont(text.font)
	lg.setColor(text.color)
	lg.printf(text.text, text.x, text.y, text.w, text.align)
	Stats.End(stat_handle)
end

local function IntersectScissor(v) lg.intersectScissor(v.x, v.y, v.w, v.h) end

local function DrawTextObject(text)
	local stat_handle = Stats.Begin("DrawTextObject", stats_category)
	lg.setColor(1, 1, 1, 1)
	lg.draw(text.text, text.x, text.y)
	Stats.End(stat_handle)
end

local function DrawLine(line)
	local stat_handle = Stats.Begin("DrawLine", stats_category)
	local prev_line_w = lg.getLineWidth()
	lg.setColor(line.color)
	lg.setLineWidth(line.width)
	lg.line(line.x1, line.y1, line.x2, line.y2)
	lg.setLineWidth(prev_line_w)
	Stats.End(stat_handle)
end

local function DrawCross(cross)
	local stat_handle = Stats.Begin("DrawCross", stats_category)
	local x, y, r = cross.x, cross.y, cross.radius
	lg.setColor(cross.color)
	lg.line(x - r, y - r, x + r, y + r)
	lg.line(x - r, y + r, x + r, y - r)
	Stats.End(stat_handle)
end

local function DrawImage(image)
	local stat_handle = Stats.Begin("DrawImage", stats_category)
	lg.setColor(image.color)
	lg.draw(image.image, image.x, image.y, image.rotation, image.sx, image.sy)
	Stats.End(stat_handle)
end

local function DrawSubImage(image)
	local stat_handle = Stats.Begin("DrawSubImage", stats_category)
	lg.setColor(image.color)
	lg.draw(image.image, image.quad, image.transform)
	Stats.End(stat_handle)
end

local function DrawCircle(circle)
	local stat_handle = Stats.Begin("DrawCircle", stats_category)
	lg.setColor(circle.color)
	lg.circle(circle.mode, circle.x, circle.y, circle.radius, circle.segments)
	Stats.End(stat_handle)
end

local function DrawCurve(curve)
	local stat_handle = Stats.Begin("DrawCurve", stats_category)
	lg.setColor(curve.color)
	lg.line(curve.points)
	Stats.End(stat_handle)
end

local function DrawPolygon(polygon)
	local stat_handle = Stats.Begin("DrawPolygon", stats_category)
	lg.setColor(polygon.color)
	lg.polygon(polygon.mode, polygon.points)
	Stats.End(stat_handle)
end

local function DrawCanvas(canvas)
	local stat_handle = Stats.Begin("DrawCanvas", stats_category)
	lg.setBlendMode("alpha", "premultiplied")
	lg.setColor(1, 1, 1, 1)
	lg.draw(canvas.canvas, canvas.x, canvas.y)
	lg.setBlendMode("alpha")
	Stats.End(stat_handle)
end

local function DrawMesh(mesh)
	local stat_handle = Stats.Begin("DrawMesh", stats_category)
	lg.setColor(1, 1, 1, 1)
	lg.draw(mesh.mesh, mesh.x, mesh.y)
	Stats.End(stat_handle)
end

local function ShaderPush(v)
	insert(shaders, 1, v.shader)
	lg.setShader(v.shader)
end
local function ShaderPop() lg.setShader(remove(shaders, 1)) end

local DrawMethods = {
	DrawRect, DrawTriangle, DrawText, DrawScissor, TransformPush, TransformPop,
	ApplyTransform, DrawCheck, DrawLine, DrawTextFormatted, IntersectScissor,
	DrawCross, DrawImage, DrawSubImage, DrawCircle, DrawCanvas, DrawMesh,
	DrawTextObject, DrawCurve, DrawPolygon, ShaderPush, ShaderPop,
}

local function AssertActiveBatch()
	assert(active_batch ~= nil, "DrawCommands.Begin was not called before commands were issued!")
end

local function DrawLayer(layer, name)
	if not layer then return end
	local stat_handle = Stats.Begin("Draw Layer " .. name, stats_category)
	for _, channel in ipairs(layer) do
		for _, elements in ipairs(channel) do
			local element_stat_handle = Stats.Begin("Draw Elements", stats_category)
			for _, element in ipairs(elements) do
				local e_type = element.type
				DrawMethods[e_type](element)
			end
			Stats.End(element_stat_handle)
		end
	end
	Stats.End(stat_handle)
end

function DrawCommands.Execute()
	local stat_handle = Stats.Begin("Execute", stats_category)
	for _, str_layer in ipairs(ordered_layers) do
		local layer = Enums.layers[str_layer]
		DrawLayer(layer_table[layer], str_layer)
	end
	lg.setShader()
	Stats.End(stat_handle)
end

local function ClearBatch(batch)
	for i = 1, #batch do
		pool[batch[i].type]:push(batch[i])
		batch[i] = nil
	end
end

function DrawCommands.Reset()
	for _, layer in ipairs(layer_table) do
		for j, channel in ipairs(layer) do
			for _, batch in ipairs(channel) do
				ClearBatch(batch)
			end
			layer[j] = nil
		end
	end
	active_layer = Enums.layers.normal
	active_batch = nil
	Utility.ClearArray(shaders)
end

function DrawCommands.Begin(channel)
	local layer = layer_table[active_layer]
	channel = channel or 1
	if not layer[channel] then
		layer[channel] = {}
	end
	active_batch = {}
	insert(layer[channel], active_batch)
	insert(pending_batches, active_batch)
end

function DrawCommands.End(clear_elements)
	if not active_batch then return end
	if clear_elements then
		ClearBatch(active_batch)
	end
	lg.setScissor()
	remove(pending_batches)
	active_batch = pending_batches[#pending_batches]
end

function DrawCommands.SetLayer(layer)
	assert(type(layer) == "number")
	active_layer = layer
end

local function GetLayerDebugInfo(layer)
	local res = {}
	res["Channel Count"] = #layer

	local channels = {}
	for _, channel in pairs(layer) do
		local collection = {}
		collection["Batch Count"] = #channel
		insert(channels, collection)
	end

	res["Channels"] = channels
	return res
end

function DrawCommands.GetDebugInfo()
	local res = {}
	for k, v in pairs(Enums.layers) do
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
		local item = pool[types.rect]:pop()
		item.type = types.rect
		item.mode = mode
		item.x, item.y = x, y
		item.width, item.height = width, height
		item.color = color or COLOR_BLACK
		item.radius = radius or 0
		item.line_w = line_w or lg.getLineWidth()
		insert(active_batch, item)
	end
end

function DrawCommands.Triangle(mode, x, y, radius, rotation, color)
	AssertActiveBatch()
	local item = pool[types.triangle]:pop()
	item.type = types.triangle
	item.mode = mode
	item.x, item.y = x, y
	item.radius = radius
	item.rotation = rotation
	item.color = color or COLOR_BLACK
	insert(active_batch, item)
end

function DrawCommands.Print(text, x, y, color, font)
	AssertActiveBatch()
	local item = pool[types.text]:pop()
	item.type = types.text
	item.text = text
	item.x, item.y = x, y
	item.color = color or COLOR_WHITE
	item.font = font
	insert(active_batch, item)
end

function DrawCommands.Printf(text, x, y, w, align, color, font)
	AssertActiveBatch()
	local item = pool[types.text_formatted]:pop()
	item.type = types.text_formatted
	item.text = text
	item.x, item.y = x, y
	item.w = w
	item.align = align or "left"
	item.color = color or COLOR_WHITE
	item.font = font
	insert(active_batch, item)
end

function DrawCommands.Scissor(x, y, w, h)
	AssertActiveBatch()
	w = w and max(w, 0)
	h = h and max(h, 0)
	local item = pool[types.scissor]:pop()
	item.type = types.scissor
	item.x, item.y = x, y
	item.w, item.h = w, h
	insert(active_batch, item)
end

function DrawCommands.IntersectScissor(x, y, w, h)
	AssertActiveBatch()
	w = w and max(w, 0) or 0
	h = h and max(h, 0) or 0
	local item = pool[types.intersect_scissor]:pop()
	item.type = types.intersect_scissor
	item.x, item.y = x or 0, y or 0
	item.w, item.h = w or 0, h or 0
	insert(active_batch, item)
end

function DrawCommands.TransformPush()
	AssertActiveBatch()
	local item = pool[types.transform_push]:pop()
	item.type = types.transform_push
	insert(active_batch, item)
end

function DrawCommands.TransformPop()
	AssertActiveBatch()
	local item = pool[types.transform_pop]:pop()
	item.type = types.transform_pop
	insert(active_batch, item)
end

function DrawCommands.ApplyTransform(transform)
	AssertActiveBatch()
	local item = pool[types.apply_transform]:pop()
	item.type = types.apply_transform
	item.transform = transform
	insert(active_batch, item)
end

function DrawCommands.Check(x, y, radius, color)
	AssertActiveBatch()
	local item = pool[types.check]:pop()
	item.type = types.check
	item.x, item.y = x, y
	item.radius = radius
	item.color = color or COLOR_BLACK
	insert(active_batch, item)
end

function DrawCommands.Line(x1, y1, x2, y2, width, color)
	AssertActiveBatch()
	local item = pool[types.line]:pop()
	item.type = types.line
	item.x1, item.y1 = x1, y1
	item.x2, item.y2 = x2, y2
	item.width = width
	item.color = color or COLOR_BLACK
	insert(active_batch, item)
end

function DrawCommands.Cross(x, y, radius, color)
	AssertActiveBatch()
	local item = pool[types.cross]:pop()
	item.type = types.cross
	item.x, item.y = x, y
	item.radius = radius
	item.color = color or COLOR_BLACK
	insert(active_batch, item)
end

function DrawCommands.Image(x, y, image, rotation, sx, sy, color)
	AssertActiveBatch()
	local item = pool[types.image]:pop()
	item.type = types.image
	item.x, item.y = x, y
	item.image = image
	item.rotation = rotation
	item.sx, item.sy = sx, sy
	item.color = color or COLOR_WHITE
	insert(active_batch, item)
end

function DrawCommands.SubImage(x, y, image, sub_x, sub_y, sw, sh, rotation, sx, sy, color)
	AssertActiveBatch()
	local item = pool[types.sub_image]:pop()
	item.type = types.sub_image
	item.transform = love.math.newTransform(x, y, rotation, sx, sy)
	item.image = image
	item.quad = lg.newQuad(sub_x, sub_y, sw, sh, image:getDimensions())
	item.color = color or COLOR_WHITE
	insert(active_batch, item)
end

function DrawCommands.Circle(mode, x, y, radius, color, segments)
	AssertActiveBatch()
	local item = pool[types.circle]:pop()
	item.type = types.circle
	item.mode = mode
	item.x, item.y = x, y
	item.radius = radius
	item.color = color or COLOR_BLACK
	item.segments = segments or 24
	insert(active_batch, item)
end

function DrawCommands.DrawCanvas(canvas, x, y)
	AssertActiveBatch()
	local item = pool[types.canvas]:pop()
	item.type = types.canvas
	item.canvas = canvas
	item.x, item.y = x, y
	insert(active_batch, item)
end

function DrawCommands.Mesh(mesh, x, y)
	AssertActiveBatch()
	local item = pool[types.mesh]:pop()
	item.type = types.mesh
	item.x, item.y = x, y
	item.mesh = mesh
	insert(active_batch, item)
end

function DrawCommands.Text(text, x, y)
	AssertActiveBatch()
	local item = pool[types.text_object]:pop()
	item.type = types.text_object
	item.text = text
	item.x, item.y = x, y
	item.color = COLOR_BLACK
	insert(active_batch, item)
end

function DrawCommands.Curve(points, color)
	AssertActiveBatch()
	local item = pool[types.curve]:pop()
	item.type = types.curve
	item.points = points
	item.color = color or COLOR_BLACK
	insert(active_batch, item)
end

function DrawCommands.Polygon(mode, points, color)
	AssertActiveBatch()
	local item = pool[types.polygon]:pop()
	item.type = types.polygon
	item.mode = mode
	item.points = points
	item.color = color or COLOR_BLACK
	insert(active_batch, item)
end

function DrawCommands.PushShader(shader)
	AssertActiveBatch()
	local item = pool[types.shader_push]:pop()
	item.type = types.shader_push
	item.shader = shader
	insert(active_batch, item)
end

function DrawCommands.PopShader()
	AssertActiveBatch()
	local item = pool[types.shader_pop]:pop()
	item.type = types.shader_pop
	insert(active_batch, item)
end

return DrawCommands
