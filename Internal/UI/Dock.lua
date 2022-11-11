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

local DrawCommands = require(SLAB_PATH .. '.Internal.Core.DrawCommands')
local MenuState = require(SLAB_PATH .. '.Internal.UI.MenuState')
local Mouse = require(SLAB_PATH .. '.Internal.Input.Mouse')
local Style = require(SLAB_PATH .. '.Style')
local Utility = require(SLAB_PATH .. '.Internal.Core.Utility')
local Scale = require(SLAB_PATH .. ".Internal.Core.Scale")


local Dock = {}

local Instances = {}
local Pending = nil
local PendingWindow = nil

local function IsValid(Id)
	if Id == nil then
		return false
	end

	if type(Id) ~= 'string' then
		return false
	end

	return Id == 'Left' or Id == 'Bottom' or Id == 'Right'
end

local function GetInstance(Id)
	if Instances[Id] == nil then
		local Instance = {}
		Instance.Id = Id
		Instance.Window = nil
		Instance.Reset = false
		Instance.TearX = 0
		Instance.TearY = 0
		Instance.IsTearing = false
		Instance.Torn = false
		Instance.CachedOptions = nil
		Instance.Enabled = true
		Instance.NoSavedSettings = false
		Instances[Id] = Instance
	end
	return Instances[Id]
end

local function GetOverlayBounds(Type)
	local X, Y, W, H = 0, 0, 0, 0
	local ViewW, ViewH = Scale.GetScreenDimensions()
	local Offset = 75

	if Type == 'Left' then
		W = 100
		H = 150
		X = Offset
		Y = ViewH * 0.5 - H * 0.5
	elseif Type == 'Right' then
		W = 100
		H = 150
		X = ViewW - Offset - W
		Y = ViewH * 0.5 - H * 0.5
	elseif Type == 'Bottom' then
		W = ViewW * 0.55
		H = 100
		X = ViewW * 0.5 - W * 0.5
		Y = ViewH - Offset - H
	end

	return X, Y, W, H
end

local function DrawOverlay(Type)
	local Instance = GetInstance(Type)
	if Instance ~= nil and Instance.Window ~= nil then
		return
	end

	if not Instance.Enabled then
		return
	end

	local X, Y, W, H = GetOverlayBounds(Type)
	local Color = {0.29, 0.59, 0.83, 0.65}
	local TitleH = 14
	local Spacing = 6

	local MouseX, MouseY = Mouse.Position()
	if X <= MouseX and MouseX <= X + W and Y <= MouseY and MouseY <= Y + H then
		Color = {0.50, 0.75, 0.96, 0.65}
		Pending = Type
	end

	DrawCommands.Rectangle('fill', X, Y, W, TitleH, Color)
	DrawCommands.Rectangle('line', X, Y, W, TitleH, {0, 0, 0, 1})

	Y = Y + TitleH + Spacing
	H = H - TitleH - Spacing
	DrawCommands.Rectangle('fill', X, Y, W, H, Color)
	DrawCommands.Rectangle('line', X, Y, W, H, {0, 0, 0, 1})
end

function Dock.DrawOverlay()
	Pending = nil

	DrawCommands.SetLayer('Dock')
	DrawCommands.Begin()

	DrawOverlay('Left')
	DrawOverlay('Right')
	DrawOverlay('Bottom')

	DrawCommands.End()

	if Mouse.IsReleased(1) then
		for Id, Instance in pairs(Instances) do
			Instance.IsTearing = false
		end
	end
end

function Dock.Override()
	if Pending ~= nil and PendingWindow ~= nil then
		local Instance = GetInstance(Pending)
		Instance.Window = PendingWindow.Id
		Instance.Reset = true
		PendingWindow = nil
		Pending = nil
	end
end

function Dock.Commit()
	if Pending ~= nil and PendingWindow ~= nil and Mouse.IsReleased(1) then
		local Instance = GetInstance(Pending)
		Instance.Window = PendingWindow.Id
		Instance.Reset = true
		PendingWindow = nil
		Pending = nil
	end
end

function Dock.GetDock(WinId)
	for K, V in pairs(Instances) do
		if V.Window == WinId then
			return K
		end
	end

	return nil
end

function Dock.GetBounds(Type, Options)
	local X, Y, W, H = 0, 0, 0, 0
	local ViewW, ViewH = Scale.GetScreenDimensions()
	local MainMenuBarH = MenuState.MainMenuBarH
	local TitleH = Style.Font:getHeight()

	if Type == 'Left' then
		Y = MainMenuBarH
		W = Options.W or 150
		H = ViewH - Y - TitleH
	elseif Type == 'Right' then
		X = ViewW - 150
		Y = MainMenuBarH
		W = Options.W or 150
		H = ViewH - Y - TitleH
	elseif Type == 'Bottom' then
		Y = ViewH - 150
		W = ViewW
		H = Options.H or 150
	end

	return X, Y, W, H
end

function Dock.AlterOptions(WinId, Options)
	Options = Options == nil and {} or Options

	for Id, Instance in pairs(Instances) do
		if Instance.Window == WinId then

			if Instance.Torn or not Instance.Enabled then
				Instance.Window = nil
				Utility.CopyValues(Options, Instance.CachedOptions)
				Instance.CachedOptions = nil
				Instance.Torn = false
				Options.ResetSize = true
			else
				if Instance.Reset then
					Instance.CachedOptions = {
						X = Options.X,
						Y = Options.Y,
						W = Options.W,
						H = Options.H,
						AllowMove = Options.AllowMove,
						Layer = Options.Layer,
						SizerFilter = Utility.Copy(Options.SizerFilter),
						AutoSizeWindow = Options.AutoSizeWindow,
						AutoSizeWindowW = Options.AutoSizeWindowW,
						AutoSizeWindowH = Options.AutoSizeWindowH,
						AllowResize = Options.AllowResize
					}
				end

				Options.AllowMove = false
				Options.Layer = 'Dock'
				if Id == 'Left' then
					Options.SizerFilter = {'E'}
				elseif Id == 'Right' then
					Options.SizerFilter = {'W'}
				elseif Id == 'Bottom' then
					Options.SizerFilter = {'N'}
				end

				local X, Y, W, H = Dock.GetBounds(Id, Options)
				Options.X = X
				Options.Y = Y
				Options.W = W
				Options.H = H
				Options.AutoSizeWindow = false
				Options.AutoSizeWindowW = false
				Options.AutoSizeWindowH = false
				Options.AllowResize = true
				Options.ResetPosition = Instance.Reset
				Options.ResetSize = Instance.Reset
				Instance.Reset = false
			end

			break
		end
	end
end

function Dock.SetPendingWindow(Instance, Type)
	PendingWindow = Instance
	Pending = Type or Pending
end

function Dock.GetPendingWindow()
	return PendingWindow
end

function Dock.IsTethered(WinId)
	for Id, Instance in pairs(Instances) do
		if Instance.Window == WinId then
			return not Instance.Torn
		end
	end

	return false
end

function Dock.BeginTear(WinId, X, Y)
	for Id, Instance in pairs(Instances) do
		if Instance.Window == WinId then
			Instance.TearX = X
			Instance.TearY = Y
			Instance.IsTearing = true
		end
	end
end

function Dock.UpdateTear(WinId, X, Y)
	for Id, Instance in pairs(Instances) do
		if Instance.Window == WinId and Instance.IsTearing then
			local Threshold = 25.0
			local DistanceX = Instance.TearX - X
			local DistanceY = Instance.TearY - Y
			local DistanceSq = DistanceX * DistanceX + DistanceY * DistanceY

			if DistanceSq >= Threshold * Threshold then
				Instance.IsTearing = false
				Instance.Torn = true
			end
		end
	end
end

function Dock.GetCachedOptions(WinId)
	for Id, Instance in pairs(Instances) do
		if Instance.Window == WinId then
			return Instance.CachedOptions
		end
	end

	return nil
end

function Dock.Toggle(List, Enabled)
	List = List == nil and {} or List
	Enabled = Enabled == nil and true or Enabled

	if type(List) == 'string' then
		List = {List}
	end

	for I, V in ipairs(List) do
		if IsValid(V) then
			local Instance = GetInstance(V)
			Instance.Enabled = Enabled
		end
	end
end

function Dock.SetOptions(Type, Options)
	Options = Options == nil and {} or Options
	Options.NoSavedSettings = Options.NoSavedSettings == nil and false or Options.NoSavedSettings

	if IsValid(Type) then
		local Instance = GetInstance(Type)
		Instance.NoSavedSettings = Options.NoSavedSettings
	end
end

function Dock.Save(Table)
	if Table ~= nil then
		local taken = {}
		local Settings = {}
		for K, V in pairs(Instances) do
			if not V.NoSavedSettings and V.Window and not taken[V.Window] then
				if V.Window then
					taken[V.Window] = true
				end
				Settings[K] = tostring(V.Window)
			end
		end
		Table['Dock'] = Settings
	end
end

function Dock.Load(Table)
	if Table ~= nil then
		local Settings = Table['Dock']
		if Settings ~= nil then
			for K, V in pairs(Settings) do
				local Instance = GetInstance(K)
				Instance.Window = V
			end
		end
	end
end

return Dock

