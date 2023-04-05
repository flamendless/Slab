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

local Slab = require 'Slab'
local SlabTest = require 'SlabTest'

local dontInterceptEventHandlers = true;

function love.load(args)
	love.graphics.setBackgroundColor(0.07, 0.07, 0.07)
	Slab.Initialize(args, dontInterceptEventHandlers)
	if dontInterceptEventHandlers then setCustomHandlers() end
end

function love.update(dt)
	Slab.Update(dt)
	SlabTest.Begin()
end

function love.draw()
	Slab.Draw()
end

function _quit()
	Slab.OnQuit()
end

function _keypressed(key, scancode, isrepeat)
	Slab.OnKeyPressed(key, scancode, isrepeat)
end

function _keyreleased(key, scancode)
	Slab.OnKeyReleased(key, scancode)
end

function _textinput(text)
	Slab.OnTextInput(text)
end

function _wheelmoved(x, y)
	Slab.OnWheelMoved(x, y)
end

function _mousemoved(x, y, dx, dy, istouch)
	Slab.OnMouseMoved(x, y, dx, dy, istouch)
end

function _mousepressed( x, y, button, istouch, presses)
	Slab.OnMousePressed( x, y, button, istouch, presses)
end

function _mousereleased( x, y, button, istouch, presses)
	Slab.OnMouseReleased( x, y, button, istouch, presses)
end

function setCustomHandlers()
	love.handlers['quit'] = _quit;
	love.handlers['keypressed'] = _keypressed;
	love.handlers['keyreleased'] = _keyreleased;
	love.handlers['textinput'] = _textinput;
	love.handlers['mousemoved'] = _mousemoved;
	love.handlers['mousepressed'] = _mousepressed;
	love.handlers['mousereleased'] = _mousereleased;
	love.handlers['wheelmoved'] = _wheelmoved;
end
