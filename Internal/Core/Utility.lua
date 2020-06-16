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

local Utility = {}

local abs = math.abs
local remove = table.remove

function Utility.MakeColor(Color)
	local Copy = {0.0, 0.0, 0.0, 1.0}
	if Color ~= nil then
		Copy[1] = Color[1]
		Copy[2] = Color[2]
		Copy[3] = Color[3]
		Copy[4] = Color[4]
	end
	return Copy
end

function Utility.HSVtoRGB(H, S, V)
	if S == 0.0 then
		return V, V, V
	end

	H = math.fmod(H, 1.0) / (60.0/360.0)
	local I = math.floor(H)
	local F = H - I
	local P = V * (1.0 - S)
	local Q = V * (1.0 - S * F)
	local T = V * (1.0 - S * (1.0 - F))

	local R, G, B = 0, 0, 0

	if I == 0 then
		R, G, B = V, T, P
	elseif I == 1 then
		R, G, B = Q, V, P
	elseif I == 2 then
		R, G, B = P, V, T
	elseif I == 3 then
		R, G, B = P, Q, V
	elseif I == 4 then
		R, G, B = T, P, V
	else
		R, G, B = V, P, Q
	end

	return R, G, B
end

function Utility.RGBtoHSV(R, G, B)
	local K = 0.0

	if G < B then
		local T = G
		G = B
		B = T
		K = -1.0
	end

	if R < G then
		local T = R
		R = G
		G = T
		K = -2.0 / 6.0 - K
	end

	local Chroma = R - (G < B and G or B)
	local H = abs(K + (G - B) / (6.0 * Chroma + 1e-20))
	local S = Chroma / (R + 1e-20)
	local V = R

	return H, S, V
end

function Utility.HasValue(Table, Value)
	for I, V in ipairs(Table) do
		if V == Value then
			return true
		end
	end

	return false
end

function Utility.Remove(Table, Value)
	for I, V in ipairs(Table) do
		if V == Value then
			remove(Table, I)
			break
		end
	end
end

function Utility.CopyValues(A, B)
	if type(A) ~= "table" or type(B) ~= "table" then
		return
	end

	for K, V in pairs(A, B) do
		local Other = B[K]

		if Other ~= nil then
			A[K] = Utility.Copy(Other)
		end
	end
end

function Utility.Copy(Original)
	local Copy = nil

	if type(Original) == "table" then
		Copy = {}

		for K, V in next, Original, nil do
			Copy[Utility.Copy(K)] = Utility.Copy(V)
		end
	else
		Copy = Original
	end

	return Copy
end

function Utility.Contains(Table, Value)
	if Table == nil then
		return false
	end

	for I, V in ipairs(Table) do
		if Value == V then
			return true
		end
	end

	return false
end

function Utility.TableCount(Table)
	local Result = 0

	if Table ~= nil then
		for K, V in pairs(Table) do
			Result = Result + 1
		end
	end

	return Result
end

function Utility.IsWindows()
	return love.system.getOS() == "Windows"
end

function Utility.IsOSX()
	return love.system.getOS() == "OS X"
end

function Utility.Clamp(Value, Min, Max)
	return Value < Min and Min or (Value > Max and Max or Value)
end

return Utility
