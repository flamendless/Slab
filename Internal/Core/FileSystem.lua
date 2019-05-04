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

function FileSystem.Separator()
	-- Lua/Love2D returns all paths with back slashes.
	return "/"
end

function FileSystem.GetDirectoryItems(Directory, Options)
	Options = Options == nil and {} or Options
	Options.Files = Options.Files == nil and true or Options.Files
	Options.Directories = Options.Directories == nil and true or Options.Directories
	Options.Filter = Options.Filter == nil and "*.*" or Options.Filter

	local Cmd = ""
	local OS = love.system.getOS()

	if string.sub(Directory, #Directory, #Directory) ~= FileSystem.Separator() then
		Directory = Directory .. FileSystem.Separator()
	end

	if OS == "Windows" then
		Directory = string.gsub(Directory, "/", "\\")
		if Options.Files and not Options.Directories then
			Cmd = 'DIR "' .. Directory .. Options.Filter .. '" /B /A:-D-H'
		elseif Options.Directories and not Options.Files then
			Cmd = 'DIR "' .. Directory .. '" /B /A:D-H'
		else
			Cmd = 'DIR "' .. Directory .. '" /B /A-H'
		end
	else
		if Options.Files and not Options.Directories then
			Cmd = 'find "' .. Directory .. '" \\( ! -regex ".*/\\..*" \\) -maxdepth 1 -type f \\( -iname \\' .. Options.Filter .. ' \\)'
		elseif Options.Directories and not Options.Files then
			Cmd = 'find "' .. Directory .. '" ! -path ' .. Directory .. ' \\( ! -regex ".*/\\..*" \\) -maxdepth 1 -type d'
		else
			Cmd = 'ls -1 ' .. Directory
		end
	end

	local Result = {}
	local Handle, Error = io.popen(Cmd)
	if Handle ~= nil then
		local I = 1
		for Item in Handle:lines() do
			if Item ~= "nil" then
				Result[I] = Item
				I = I + 1
			end
		end
		io.close(Handle)
	end

	return Result
end

function FileSystem.Exists(Path)
	local Handle = io.open(Path)
	if Handle ~= nil then
		io.close(Handle)
		return true
	else
		local OS = love.system.getOS()
		if OS == "Windows" then
			local OK, Error, Code = os.rename(Path, Path)
			if OK then
				return true
			else
				if Code == 13 then
					return true
				end
			end
		end
	end

	return false
end

function FileSystem.IsDirectory(Path)
	return FileSystem.Exists(Path .. FileSystem.Separator())
end

function FileSystem.Parent(Path)
	local Result = Path

	local Index = 1
	local I = Index
	repeat
		Index = I
		I = string.find(Path, FileSystem.Separator(), Index + 1, true)
	until I == nil

	if Index > 1 then
		Result = string.sub(Path, 1, Index - 1)
	end

	return Result
end

function FileSystem.GetBaseName(Path, RemoveExtension)
	local Result = string.match(Path, "^.+/(.+)$")

	if Result == nil then
		Result = Path
	end

	if RemoveExtension then
		Result = FileSystem.RemoveExtension(Result)
	end

	return Result
end

function FileSystem.GetDirectory(Path)
	local Result = string.match(Path, "(.+)/")

	if Result == nil then
		Result = Path
	end

	return Result
end

function FileSystem.GetRootDirectory(Path)
	local Result = Path

	local Index = string.find(Path, FileSystem.Separator(), 1, true)

	if Index ~= nil then
		Result = string.sub(Path, 1, Index - 1)
	end

	return Result
end

function FileSystem.GetSlabPath()
	local Path = love.filesystem.getSource()
	if not FileSystem.IsDirectory(Path) then
		Path = love.filesystem.getSourceBaseDirectory()
	end
	return Path .. "/Slab"
end

function FileSystem.RemoveExtension(Path)
	local Result = string.match(Path, "(.+)%.")

	if Result == nil then
		Result = Path
	end

	return Result
end

function FileSystem.ReadContents(Path, IsBinary)
	local Result = nil

	local Mode = IsBinary and "rb" or "r"
	local Handle, Error = io.open(Path, Mode)
	if Handle ~= nil then
		Result = Handle:read("*a")
		Handle:close()
	end

	return Result, Error
end

function FileSystem.SaveContents(Path, Contents)
	local Result = false
	local Handle, Error = io.open(Path, "w")
	if Handle ~= nil then
		Handle:write(Contents)
		Handle:close()
		Result = true
	end

	return Result, Error
end

return FileSystem
