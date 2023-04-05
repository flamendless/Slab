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

local floor = math.floor
local insert = table.insert
local max = math.max

local Cursor = require(SLAB_PATH .. '.Internal.Core.Cursor')
local DrawCommands = require(SLAB_PATH .. '.Internal.Core.DrawCommands')
local LayoutManager = require(SLAB_PATH .. '.Internal.UI.LayoutManager')
local Mouse = require(SLAB_PATH .. '.Internal.Input.Mouse')
local Region = require(SLAB_PATH .. '.Internal.UI.Region')
local Stats = require(SLAB_PATH .. '.Internal.Core.Stats')
local Style = require(SLAB_PATH .. '.Style')
local Window = require(SLAB_PATH .. '.Internal.UI.Window')
local Scale = require(SLAB_PATH .. ".Internal.Core.Scale")


local Text = {}
local EMPTY = {}

function Text.Begin(label, options)
	local statHandle = Stats.Begin('Text', 'Slab')

	options = options or EMPTY
	local color = options.Color or Style.TextColor
	local pad = options.Pad or 0 -- TODO: rename on next major version?
	local padH = options.PadH or 0
	local isSelectableTextOnly = options.IsSelectableTextOnly
	local isSelectable = options.IsSelectable or isSelectableTextOnly

	if options.URL ~= nil then
		isSelectableTextOnly = true
		color = Style.TextURLColor
	end

	local w = Text.GetWidth(label)
	local h = Style.Font:getHeight()

	LayoutManager.AddControl(w + pad, h + padH, 'Text')

	local result = false
	local winId = Window.GetItemId(label)
	local x, y = Cursor.GetPosition()
	local mouseX, mouseY = Window.GetMousePosition()

	local isObstructed = Window.IsObstructedAtMouse()

	if not isObstructed and x <= mouseX and mouseX <= x + w and y <= mouseY and mouseY <= y + h then
		Window.SetHotItem(winId)
	end

	local winX, winY, winW, winH = Region.GetContentBounds()
	local checkX = isSelectableTextOnly and x or winX
	-- The region's width may have been reset prior to the first control being added. Account for this discrepency.
	local checkW = isSelectableTextOnly and w or max(winW, w)
	local hovered = not isObstructed and checkX <= mouseX and mouseX <= checkX + checkW + pad and y <= mouseY and mouseY <= y + h + padH

	if isSelectable or options.IsSelected then
		if hovered or options.IsSelected then
			DrawCommands.Rectangle('fill', checkX, y, checkW + pad, h + padH, options.HoverColor or Style.TextHoverBgColor)
		end

		result = hovered and (options.SelectOnHover or Mouse.IsClicked(1))
	end

	if hovered and options.URL ~= nil then
		Mouse.SetCursor('hand')

		if Mouse.IsClicked(1) then
			love.system.openURL(options.URL)
		end
	end

	DrawCommands.Print(label, floor(x + pad * 0.5), floor(y + padH * 0.5), color, Style.Font)

	if options.URL ~= nil then
		DrawCommands.Line(x + pad, y + h, x + w, y + h, 1.0, color)
	end

	Cursor.SetItemBounds(x, y, w + pad, h + padH)
	Cursor.AdvanceY(h + padH)

	if options.AddItem ~= false then
		Window.AddItem(x, y, w + pad, h + padH, winId)
	end

	Stats.End(statHandle)

	return result
end

function Text.BeginFormatted(label, options)
	local statHandle = Stats.Begin('Textf', 'Slab')

	local winW, winH = Window.GetBorderlessSize()

	options = options or EMPTY
	local w = options.W or winW
	local h = options.H or 0

	-- TODO: Hack to ensure right-aligned menu hints don't change menu item click area
	local rightPad = options.RightPad or 0

	if Window.IsAutoSize() and options.W == nil then
		w = Scale.GetScreenWidth()
	end

	local width, wrapped = Style.Font:getWrap(label, w)
	local textHeight = #wrapped * Style.Font:getHeight()
	local height = max(h, textHeight)
	local padH = height - textHeight

	if options.W ~= nil then
		width = options.W
	end

	LayoutManager.AddControl(width, height, 'TextFormatted')

	local x, y = Cursor.GetPosition()

	DrawCommands.Printf(label, floor(x), floor(y + padH * 0.5), width, options.Align or 'left', options.Color or Style.TextColor, Style.Font)

	Cursor.SetItemBounds(floor(x), floor(y), width, height)
	Cursor.AdvanceY(height)

	Window.ResetContentSize()
	Window.AddItem(floor(x), floor(y), width + rightPad, height)

	Stats.End(statHandle)
end

function Text.BeginObject(object, options)
	local statHandle = Stats.Begin('TextObject', 'Slab')

	local winW, winH = Window.GetBorderlessSize()

	options = options or EMPTY
	options.Color = options.Color == nil and Style.TextColor or options.Color

	local w, h = object:getDimensions()

	LayoutManager.AddControl(w, h, 'TextObject')

	local x, y = Cursor.GetPosition()

	DrawCommands.Text(object, floor(x), floor(y), options.Color)

	Cursor.SetItemBounds(floor(x), floor(y), w, h)
	Cursor.AdvanceY(y)

	Window.ResetContentSize()
	Window.AddItem(floor(x), floor(y), w, h)

	Stats.End(statHandle)
end

function Text.GetWidth(label)
	return Style.Font:getWidth(label)
end

function Text.GetHeight()
	return Style.Font:getHeight()
end

function Text.GetSize(label)
	return Style.Font:getWidth(label), Style.Font:getHeight()
end

function Text.GetSizeWrap(label, width)
	local w, lines = Style.Font:getWrap(label, width)
	return w, #lines * Text.GetHeight()
end

function Text.GetLines(label, width)
	local w, lines = Style.Font:getWrap(label, width)

	local start = 0
	for i, v in ipairs(lines) do
		if #v == 0 then
			lines[i] = "\n"
		else
			local offset = start + #v + 1
			local ch = string.sub(label, offset, offset)

			if ch == '\n' then
				lines[i] = lines[i] .. "\n"
			end
		end

		start = start + #lines[i]
	end

	if string.sub(label, #label, #label) == '\n' then
		insert(lines, "")
	end

	if #lines == 0 then
		insert(lines, "")
	end

	return lines
end

function Text.CreateObject()
	return love.graphics.newText(Style.Font)
end

return Text
