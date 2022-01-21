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

local find = string.find
local sort = table.sort
local sub = string.sub
local match = string.match
local gmatch = string.gmatch
local gsub = string.gsub
local insert = table.insert
local remove = table.remove

local FileSystem = {}

local Syscalls = {}
local Bit = require("bit")
local FFI = require("ffi")

local GetDirectoryItems, Exists, IsDirectory

local function ShouldFilter(name, filter)
	filter = filter or "*.*"
	if filter == "*.*" then return false end
	local ext = FileSystem.GetExtension(name)
	local filter_ex = FileSystem.GetExtension(filter)
	return ext ~= filter_ex
end

local function Access(tbl, param) return tbl[param]; end
local function ErrorAtAccess(tbl, param) return not pcall(Access, tbl, param); end

--[[
	The following code is based on the following sources:

	LoveFS v1.1
	https://github.com/linux-man/lovefs
	Pure Lua FileSystem Access
	Under the MIT license.
	copyright(c) 2016 Caldas Lopes aka linux-man

	luapower/fs_posix
	https://github.com/luapower/fs
	portable filesystem API for LuaJIT / Linux & OSX backend
	Written by Cosmin Apreutesei. Public Domain.
--]]

if FFI.os == "Windows" then
	FFI.cdef[[
		#pragma pack(push)
		#pragma pack(1)
		struct WIN32_FIND_DATAW {
			uint32_t dwFileAttributes;
			uint64_t ftCreationTime;
			uint64_t ftLastAccessTime;
			uint64_t ftLastWriteTime;
			uint32_t dwReserved[4];
			wchar_t cFileName[520];
			wchar_t cAlternateFileName[28];
		};
		#pragma pack(pop)

		typedef unsigned long DWORD;
		static const DWORD FILE_ATTRIBUTE_DIRECTORY = 0x10;
		static const DWORD INVALID_FILE_ATTRIBUTES = -1;

		void* FindFirstFileW(const wchar_t* pattern, struct WIN32_FIND_DATAW* fd);
		bool FindNextFileW(void* ff, struct WIN32_FIND_DATAW* fd);
		bool FindClose(void* ff);
		DWORD GetFileAttributesW(const wchar_t* Path);

		int MultiByteToWideChar(unsigned int CodePage, uint32_t dwFlags, const char* lpMultiByteStr,
			int cbMultiByte, const wchar_t* lpWideCharStr, int cchWideChar);
		int WideCharToMultiByte(unsigned int CodePage, uint32_t dwFlags, const wchar_t* lpWideCharStr,
			int cchWideChar, const char* lpMultiByteStr, int cchMultiByte,
			const char* default, int* used);
	]]

	local WIN32_FIND_DATA = FFI.typeof("struct WIN32_FIND_DATAW")
	local INVALID_HANDLE = FFI.cast("void*", -1)

	local function u2w(str, code)
		local size = FFI.C.MultiByteToWideChar(code or 65001, 0, str, #str, nil, 0)
		local buf = FFI.new("wchar_t[?]", size * 2 + 2)
		FFI.C.MultiByteToWideChar(code or 65001, 0, str, #str, buf, size * 2)
		return buf
	end

	local function w2u(wstr, code)
		local size = FFI.C.WideCharToMultiByte(code or 65001, 0, wstr, -1, nil, 0, nil, nil)
		local buf = FFI.new("char[?]", size + 1)
		size = FFI.C.WideCharToMultiByte(code or 65001, 0, wstr, -1, buf, size, nil, nil)
		return FFI.string(buf)
	end

	GetDirectoryItems = function(dir, opt)
		local find_data = FFI.new(WIN32_FIND_DATA)
		local handle = FFI.C.FindFirstFileW(u2w(dir .. "\\*"), find_data)
		FFI.gc(handle, FFI.C.FindClose)

		local res = {}
		if handle then
			repeat
				local name = w2u(find_data.cFileName)
				if name ~= "." and name ~= ".." then
					local add_dir = (find_data.dwFileAttributes == 16 or find_data.dwFileAttributes == 17) and opt.dirs
					local add_file = find_data.dwFileAttributes == 32 and opt.files

					if (add_dir or add_file) and not ShouldFilter(name, opt.filter) then
						table.insert(res, name)
					end
				end
			until not FFI.C.FindNextFileW(handle, find_data)
		end
		FFI.C.FindClose(FFI.gc(handle, nil))
		return res
	end

	Exists = function(path)
		local attr = FFI.C.GetFileAttributesW(u2w(path))
		return attr ~= FFI.C.INVALID_FILE_ATTRIBUTES
	end

	IsDirectory = function(path)
		local attr = FFI.C.GetFileAttributesW(u2w(path))
		return attr ~= FFI.C.INVALID_FILE_ATTRIBUTES and Bit.band(attr, FFI.C.FILE_ATTRIBUTE_DIRECTORY) ~= 0
	end
else
	FFI.cdef[[
		typedef struct DIR DIR;
		typedef size_t time_t;
		static const int S_IFREG = 0x8000;
		static const int S_IFDIR = 0x4000;

		DIR* opendir(const char* name);
		int closedir(DIR* dirp);
	]]

	if FFI.os == "OSX" then
		FFI.cdef[[
			struct dirent {
				uint64_t	d_ino;
				uint64_t	d_off;
				uint16_t	d_reclen;
				uint16_t	d_namlen;
				uint8_t		d_type;
				char		d_name[1024];
			};

			struct stat {
				uint32_t	st_dev;
				uint16_t	st_mode;
				uint16_t	st_nlink;
				uint64_t	st_ino;
				uint32_t	st_uid;
				uint32_t	st_gid;
				uint32_t	st_rdev;
				time_t		st_atime;
				long		st_atime_nsec;
				time_t		st_mtime;
				long		st_mtime_nsec;
				time_t		st_ctime;
				long		st_ctime_nsec;
				time_t		st_btime;
				long		st_btime_nsec;
				int64_t		st_size;
				int64_t		st_blocks;
				int32_t		st_blksize;
				uint32_t	st_flags;
				uint32_t	st_gen;
				int32_t		st_lspare;
				int64_t		st_qspare[2];
			};

			struct dirent* readdir(DIR* dirp) asm("readdir$INODE64");
			int stat64(const char* path, struct stat* buf);
		]]
	else
		FFI.cdef[[
			struct dirent {
				uint64_t		d_ino;
				int64_t			d_off;
				unsigned short	d_reclen;
				unsigned char	d_type;
				char			d_name[256];
			};

			struct stat {
				uint64_t	st_dev;
				uint64_t	st_ino;
				uint64_t	st_nlink;
				uint32_t	st_mode;
				uint32_t	st_uid;
				uint32_t	st_gid;
				uint32_t	__pad0;
				uint64_t	st_rdev;
				int64_t		st_size;
				int64_t		st_blksize;
				int64_t		st_blocks;
				uint64_t	st_atime;
				uint64_t	st_atime_nsec;
				uint64_t	st_mtime;
				uint64_t	st_mtime_nsec;
				uint64_t	st_ctime;
				uint64_t	st_ctime_nsec;
				int64_t		__unused[3];
			};

			struct dirent* readdir(DIR* dirp) asm("readdir64");
			int syscall(int number, ...);
			int stat64(const char* path, struct stat* buf);
		]]
	end

	local stat = FFI.typeof("struct stat");

	if FFI.arch == "x86" then
		Syscalls.SYS_stat = 106
	elseif FFI.arch == "arm" and FFI.abi("eabi") then
		Syscalls.SYS_stat = 106
	elseif FFI.arch == "x64" then
		Syscalls.SYS_stat = 4
	end

	if (ErrorAtAccess(FFI.C, "stat64")) then
		local function SysStat(path, buffer)
			return FFI.C.syscall(Syscalls.SYS_stat, path, buffer)
		end

		Exists = function(path)
			local buffer = stat()
			return SysStat(path, buffer) == 0
		end

		IsDirectory = function(path)
			local buffer = stat()
			if SysStat(path, buffer) == 0 then
				return Bit.band(buffer.st_mode, 0xf000) == FFI.C.S_IFDIR
			end
			return false
		end
	else
		Exists = function(path)
			local buffer = stat()
			return FFI.C.stat64(path, buffer) == 0
		end

		IsDirectory = function(path)
			local buffer = stat()
			if FFI.C.stat64(path, buffer) == 0 then
				return Bit.band(buffer.st_mode, 0xf000) == FFI.C.S_IFDIR
			end
			return false
		end
	end

	GetDirectoryItems = function(dir, opt)
		local DIR = FFI.C.opendir(dir)
		if DIR then
			local res = {}
			local entry = FFI.C.readdir(DIR)
			while entry ~= nil do
				local name = FFI.string(entry.d_name)
				if name ~= "." and name ~= ".." and sub(name, 1, 1) ~= "." then
					local add_dir = entry.d_type == 4 and opt.dirs
					local add_file = entry.d_type == 8 and opt.files

					if (add_dir or add_file) and not ShouldFilter(name, opt.filter) then
						table.insert(res, name)
					end
				end
				entry = FFI.C.readdir(DIR)
			end
			FFI.C.closedir(DIR)
			return res
		end
	end
end

function FileSystem.Separator()
	-- Lua/Love2D returns all paths with back slashes.
	return "/"
end

local DEF_OPT = {
	files = true,
	dirs = true,
	filter = "*.*"
}

function FileSystem.GetDirectoryItems(dir, opt)
	opt = opt or DEF_OPT

	local len = #dir
	if sub(dir, len, len) ~= FileSystem.Separator() then
		dir = dir .. FileSystem.Separator()
	end

	local res = GetDirectoryItems(dir, opt)
	sort(res)
	return res
end

function FileSystem.Exists(path)
	return Exists(path)
end

function FileSystem.IsDirectory(path)
	return IsDirectory(path)
end

function FileSystem.Parent(path)
	local index = 1
	local i = index
	repeat
		index = i
		i = find(path, FileSystem.Separator(), index + 1, true)
	until i == nil

	local res = (index > 1) and sub(path, 1, index - 1) or path
	return res
end

--[[
	IsAbsolute

	Determines if the given path is an absolute path or a relative path. This is determined by checking if the
	path starts with a drive letter on Windows, or the Unix root character '/'.

	Path: [String] The path to check.

	Return: [Boolean] True if the path is absolute, false if it is relative.
--]]
function FileSystem.IsAbsolute(path)
	if (not path) or (path == "") then return false end
	if FFI.os == "Windows" then
		return match(path, "(.:-)\\") ~= nil
	end
	return sub(path, 1, 1) == FileSystem.Separator()
end

--[[
	GetDrive

	Attempts to retrieve the drive letter from the given absolute path. This function is targeted for
	paths on Windows. Unix style paths will just return the root '/'.

	Path: [String] The absolute path containing the drive letter.

	Return: [String] The drive letter, colon, and path separator are returned. On Unix platforms, just the '/'
		character is returned.
--]]
function FileSystem.GetDrive(path)
	if not FileSystem.IsAbsolute(path) then return "" end
	if FFI.os == "Windows" then
		local res = match(path, "(.:-)\\")
		if not res then
			res = match(path, "(.:-)" .. FileSystem.Separator())
		end
		if res then
			return res .. FileSystem.Separator()
		end
	end
	return FileSystem.Separator()
end

--[[
	Determines if the given path is a drive letter on Windows or the root directory on Unix.

	Path: [String] The absolute path containing the drive letter.

	Return: [Boolean] True if the given path is a drive.
--]]
function FileSystem.IsDrive(path)
	if not path then return false end
	return FileSystem.GetDrive(path) == path
end

--[[
	Sanitize

	This function will attempt to remove any '.' or '..' components in the path and will appropriately modify
	the result to represent changes to the path based on if a '..' component is found. This function will keep
	the path's scope (relative/absolute) during sanitization.

	Path: [String] The path to be sanitized.

	Return: [String] The sanitized path string.
--]]
function FileSystem.Sanitize(path)
	local items = {}

	for item in gmatch(path, "([^" .. FileSystem.Separator() .. "]+)") do
		if #items == 0 then
			insert(items, item)
		else
			if item == ".." then
				remove(items, #items)
			elseif item ~= "." then
				insert(items, item)
			end
		end
	end

	local res = ""
	for i, item in ipairs(items) do
		if res == "" then
			if item == "." or item == ".." then
			else
				if FileSystem.IsAbsolute(path) then
					res = FileSystem.GetDrive(path) .. item
				else
					res = item
				end
			end
		else
			res = res .. FileSystem.Separator() .. item
		end
	end
	return res
end

function FileSystem.GetBaseName(path, remove_ext)
	local res = match(path, "^.+/(.+)$")
	res = (not res) and path or res
	res = remove_ext and FileSystem.RemoveExtension(res) or res
	return res
end

function FileSystem.GetDirectory(path)
	local res = match(path, "(.+)/")
	res = (not res) and path or res
	return res
end

function FileSystem.GetRootDirectory(path)
	local index = find(path, FileSystem.Separator(), 1, true)
	local res = index and sub(path, 1, index - 1) or path
	return res
end

function FileSystem.GetSlabPath()
	local path = love.filesystem.getSource()
	if not FileSystem.IsDirectory(path) then
		path = love.filesystem.getSourceBaseDirectory()
	end
	return path .. "/Slab"
end

function FileSystem.GetExtension(path)
	local res = match(path, "[^.]+$")
	res = (not res) and "" or res
	return res
end

function FileSystem.RemoveExtension(path)
	local res = match(path, "(.+)%.")
	res = (not res) and path or res
	return res
end

function FileSystem.ReadContents(path, is_binary, is_default)
	local res, err
	if is_default then
		res, err = love.filesystem.read(path)
	else
		local handle
		local mode = is_binary and "rb" or "r"
		handle, error = io.open(path, mode)
		if handle then
			res = handle:read("*a")
			handle:close()
		end
	end
	return res, err
end

function FileSystem.SaveContents(path, contents, is_default)
	local res, err
	if is_default then
		res, err = love.filesystem.write(path, contents)
	else
		local handle
		handle, error = io.open(path, "w")
		if handle then
			handle:write(contents)
			handle:close()
			ers = true
		end
	end
	return res, err
end

function FileSystem.GetClipboard()
	local contents = love.system.getClipboardText()
	if contents then
		contents = gsub(contents, "\r\n", "\n")
	end
	return contents
end

return FileSystem
