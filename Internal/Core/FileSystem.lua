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

local FFI = require('ffi')

local function ShouldFilter(Name, Filter)
	Filter = Filter == nil and "*.*" or Filter

	local Extension = FileSystem.GetExtension(Name)

	if Filter ~= "*.*" then
		local FilterExt = FileSystem.GetExtension(Filter)

		if Extension ~= FilterExt then
			return true
		end
	end

	return false
end

local GetDirectoryItems = nil

if FFI.os == "Windows" then
	-- TODO: Implement on windows platform.

	GetDirectoryItems = function(Directory, Options)
		local Result = {}

		return Result
	end
else
	FFI.cdef[[
		struct dirent {
			uint64_t	d_ino;
			uint64_t	d_off;
			uint16_t	d_reclen;
			uint16_t	d_namlen;
			uint8_t		d_type;
			char		d_name[1024];
		};

		typedef struct DIR DIR;

		DIR* opendir(const char* name);
		struct dirent* readdir(DIR* dirp) asm("readdir$INODE64");
		int closedir(DIR* dirp);
	]]

	GetDirectoryItems = function(Directory, Options)
		local Result = {}

		local DIR = FFI.C.opendir(Directory)

		if DIR ~= nil then
			local Entry = FFI.C.readdir(DIR)

			while Entry ~= nil do
				local Name = FFI.string(Entry.d_name)

				if Name ~= "." and Name ~= ".." and string.sub(Name, 1, 1) ~= "." then
					if (Entry.d_type == 4 and Options.Directories) or (Entry.d_type == 8 and Options.Files) then
						if not ShouldFilter(Name, Options.Filter) then
							table.insert(Result, Name)
						end
					end
				end

				Entry = FFI.C.readdir(DIR)
			end

			FFI.C.closedir(DIR)
		end

		return Result
	end
end

function FileSystem.Separator()
	-- Lua/Love2D returns all paths with back slashes.
	return "/"
end

function FileSystem.GetDirectoryItems(Directory, Options)
	Options = Options == nil and {} or Options
	Options.Files = Options.Files == nil and true or Options.Files
	Options.Directories = Options.Directories == nil and true or Options.Directories
	Options.Filter = Options.Filter == nil and "*.*" or Options.Filter

	if string.sub(Directory, #Directory, #Directory) ~= FileSystem.Separator() then
		Directory = Directory .. FileSystem.Separator()
	end

	local Result = GetDirectoryItems(Directory, Options)

	table.sort(Result)

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

function FileSystem.GetExtension(Path)
	local Result = string.match(Path, "[^.]+$")

	if Result == nil then
		Result = ""
	end

	return Result
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
