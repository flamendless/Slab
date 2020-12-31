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

local Slab = require 'Slab'
local SlabTest = require 'SlabTest'

local spritesheet = love.graphics.newImage("spritesheet.png")
local cols = 4
local rows = 1
local frame_size = 64
local x_offset = 0
local y_offset = 0

function love.load(args)
	love.graphics.setBackgroundColor(0.07, 0.07, 0.07)
	Slab.Initialize(args)
end

function love.update(dt)
	Slab.Update(dt)

	Slab.BeginWindow("Test", {Title = "Spritesheet Test"})
	Slab.Image("Spritesheet", {
		Image = spritesheet,
		SubX = 0,
		SubY = 0,
		SubW = spritesheet:getWidth(),
		SubH = spritesheet:getHeight(),
		RectColor = {1, 1, 1, 1},
		RectLineWidth = 2,
		RectX = x_offset * frame_size,
		RectY = y_offset * frame_size,
		RectW = frame_size,
		RectH = frame_size,
	})

	if Slab.Button("-") then
		x_offset = x_offset - 1
		if x_offset < 0 then
			x_offset = cols - 1
		end
	end

	Slab.SameLine()

	if Slab.Button("+") then
		x_offset = x_offset + 1
		if x_offset > cols - 1 then
			x_offset = 0
		end
	end

	Slab.EndWindow()
	SlabTest.Begin()
end

function love.draw()
	Slab.Draw()
end
