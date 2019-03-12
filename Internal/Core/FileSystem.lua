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

local FileSystem = {}

function FileSystem.GetDirectoryItems(Directory)
	local Cmd = ""
	local OS = love.system.getOS()

	if OS == "Windows" then
		Cmd = 'dir "' .. Directory .. '" /b /ad'
	else
		Cmd = 'ls -a "' .. Directory .. '"'
	end

	local Result = {}
	local Handle = io.popen(Cmd)
	if Handle ~= nil then
		local I = 1
		for Item in Handle:lines() do
			Result[I] = Item
			I = I + 1
		end
	end

	return Result
end

function FileSystem.Exists(Path)
	local Handle = io.open(Path)
	if Handle ~= nil then
		io.close(Handle)
		return true
	end

	return false
end

function FileSystem.IsDirectory(Path)
	return FileSystem.Exists(Path .. "/")
end

function FileSystem.Parent(Path)
	local Result = Path

	local OS = love.system.getOS()
	local Sep = OS == "Windows" and "\\" or "/"

	local Index = 1
	local I = Index
	repeat
		Index = I
		I = string.find(Path, Sep, Index + 1, true)
	until I == nil

	if Index > 1 then
		Result = string.sub(Path, 1, Index - 1)
	end

	return Result
end

return FileSystem
