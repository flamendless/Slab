--[[

MIT License

Copyright (c) 2019 Mitchell Davis <coding.jackalope@gmail.com>

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
			table.remove(Table, I)
			break
		end
	end
end

function Utility.IsWindows()
	return love.system.getOS() == "Windows"
end

return Utility
