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

local insert = table.insert
local format = string.format
local min = math.min

local Cursor = require(SLAB_PATH .. '.Internal.Core.Cursor')
local DrawCommands = require(SLAB_PATH .. '.Internal.Core.DrawCommands')
local LayoutManager = require(SLAB_PATH .. '.Internal.UI.LayoutManager')
local Mouse = require(SLAB_PATH .. '.Internal.Input.Mouse')
local Style = require(SLAB_PATH .. '.Style')
local Text = require(SLAB_PATH .. '.Internal.UI.Text')
local Window = require(SLAB_PATH .. '.Internal.UI.Window')
local Utility = require(SLAB_PATH .. '.Internal.Core.Utility')

local Tooltip = {}
local LastDisplayTime = 0.0
local AccumDisplayTime = 0.0
local TooltipTime = 0.75
local TooltipExpireTime = 0.025
local Alpha = 0.0
local OffsetY = 0.0
local ResetSize = false

function Tooltip.Begin(Tip)
	if Tip == nil or Tip == "" then
		return
	end

	local Elapsed = love.timer.getTime() - LastDisplayTime
	if Elapsed > TooltipExpireTime then
		AccumDisplayTime = 0.0
		Alpha = 0.0
		ResetSize = true
	end

	local DeltaTime = love.timer.getDelta()
	AccumDisplayTime = AccumDisplayTime + DeltaTime
	LastDisplayTime = love.timer.getTime()

	if AccumDisplayTime > TooltipTime then
		local X, Y = Mouse.Position()
		Alpha = min(Alpha + DeltaTime * 4.0, 1.0)
		local BgColor = Utility.MakeColor(Style.WindowBackgroundColor)
		local TextColor = Utility.MakeColor(Style.TextColor)
		BgColor[4] = Alpha
		TextColor[4] = Alpha

		local CursorX, CursorY = Cursor.GetPosition()

		LayoutManager.Begin('Ignore', {Ignore = true})
		Window.Begin('tooltip',
		{
			X = X,
			Y = Y - OffsetY,
			W = 0,
			H = 0,
			AutoSizeWindow = true,
			AutoSizeContent = false,
			AllowResize = false,
			AllowFocus = false,
			Layer = 'ContextMenu',
			ResetWindowSize = ResetSize,
			CanObstruct = false,
			NoSavedSettings = true
		})
		Text.BeginFormatted(Tip, {Color = TextColor})
		OffsetY = Window.GetHeight()
		Window.End()
		LayoutManager.End()
		Cursor.SetPosition(CursorX, CursorY)
		ResetSize = false
	end
end

function Tooltip.GetDebugInfo()
	local Info = {}

	local Elapsed = love.timer.getTime() - LastDisplayTime
	insert(Info, format("Time: %.2f", AccumDisplayTime))
	insert(Info, format("Is Visible: %s", tostring(AccumDisplayTime > TooltipTime and Elapsed <= TooltipExpireTime)))
	insert(Info, format("Time to Display: %.2f", TooltipTime))
	insert(Info, format("Expire Time: %f", TooltipExpireTime))

	return Info
end

return Tooltip
