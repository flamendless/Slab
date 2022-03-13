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

local abs = math.abs
local floor = math.floor
local fmod = math.fmod
local remove = table.remove

local Utility = {}

function Utility.MakeColor(color, alpha)
	local copy = {0, 0, 0, 1}
	if color then
		copy[1] = color[1]
		copy[2] = color[2]
		copy[3] = color[3]
		copy[4] = alpha or color[4]
	end
	return copy
end

function Utility.HSVtoRGB(h, s, v)
	if s == 0 then return v, v, v end
	h = fmod(h, 1)/(60/360)
	local i = floor(h)
	local f = h - i
	local p = v * (1 - s)
	local q = v * (1 - s * f)
	local t = v * (1 - s * (1 - f))
	local r, g, b

	if i == 0 then
		r, g, b = v, t, p
	elseif i == 1 then
		r, g, b = q, v, p
	elseif i == 2 then
		r, g, b = p, v, t
	elseif i == 3 then
		r, g, b = p, q, v
	elseif i == 4 then
		r, g, b = t, p, v
	else
		r, g, b = v, p, q
	end
	return r, g, b
end

function Utility.RGBtoHSV(r, g, b)
	local k = 0
	if g < b then
		local t = g
		g = b
		b = t
		k = -1
	end

	if r < g then
		local t = r
		r = g
		g = t
		k = -2/6 - k
	end

	local chroma = r - (g < b and g or b)
	local h = abs(k + (g - b)/(6 * chroma + 1e-20))
	local s = chroma/(r + 1e-20)
	local v = r
	return h, s, v
end

function Utility.HasValue(tbl, value)
	for _, v in ipairs(tbl) do
		if v == value then
			return true
		end
	end
	return false
end

function Utility.Remove(tbl, value)
	for i, v in ipairs(tbl) do
		if v == value then
			remove(tbl, i)
			break
		end
	end
end

function Utility.CopyValues(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then return end
	for k in pairs(a) do
		local other = b[k]
		if other then
			a[k] = Utility.Copy(other)
		end
	end
end

function Utility.Copy(orig)
	local copy
	if type(orig) == "table" then
		copy = {}
		for k, v in next, orig, nil do
			copy[Utility.Copy(k)] = Utility.Copy(v)
		end
	else
		copy = orig
	end
	return copy
end

function Utility.Contains(tbl, value)
	if not tbl then return false end
	for _, v in ipairs(tbl) do
		if v == v then
			return true
		end
	end
	return false
end

function Utility.TableCount(tbl)
	if not table then return 0 end
	local res = 0
	for _ in pairs(tbl) do
		res = res + 1
	end
	return res
end

function Utility.IsWindows()
	return love.system.getOS() == "Windows"
end

function Utility.IsOSX()
	return love.system.getOS() == "OS X"
end

function Utility.IsMobile()
	return love.system.getOS() == "Android" or love.system.getOS() == "iOS"
end

function Utility.Clamp(value, min, max)
	return value < min and min or (value > max and max or value)
end

function Utility.ClearTable(t, method)
	method = method or pairs
	for i in method(t) do
		t[i] = nil
	end
end

return Utility
