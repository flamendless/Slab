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

local FileSystem = {}

local Bit = require('bit')
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
local Exists = nil
local IsDirectory = nil

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

	local WIN32_FIND_DATA = FFI.typeof('struct WIN32_FIND_DATAW')
	local INVALID_HANDLE = FFI.cast('void*', -1)

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

	GetDirectoryItems = function(Directory, Options)
		local Result = {}

		local FindData = FFI.new(WIN32_FIND_DATA)
		local Handle = FFI.C.FindFirstFileW(u2w(Directory .. "\\*"), FindData)
		FFI.gc(Handle, FFI.C.FindClose)

		if Handle ~= nil then
			repeat
				local Name = w2u(FindData.cFileName)

				if Name ~= "." and Name ~= ".." then
					local AddDirectory = (FindData.dwFileAttributes == 16 or FindData.dwFileAttributes == 17) and Options.Directories
					local AddFile = FindData.dwFileAttributes == 32 and Options.Files
					
					if (AddDirectory or AddFile) and not ShouldFilter(Name, Options.Filter) then
						table.insert(Result, Name)
					end
				end

			until not FFI.C.FindNextFileW(Handle, FindData)
		end

		FFI.C.FindClose(FFI.gc(Handle, nil))

		return Result
	end

	Exists = function(Path)
		local Attributes = FFI.C.GetFileAttributesW(u2w(Path))
		return Attributes ~= FFI.C.INVALID_FILE_ATTRIBUTES
	end

	IsDirectory = function(Path)
		local Attributes = FFI.C.GetFileAttributesW(u2w(Path))
		return Attributes ~= FFI.C.INVALID_FILE_ATTRIBUTES and Bit.band(Attributes, FFI.C.FILE_ATTRIBUTE_DIRECTORY) ~= 0
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
				uint64_t 	st_nlink;
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
			int stat64(const char* path, struct stat* buf);
		]]
	end

	local Stat = FFI.typeof('struct stat');

	GetDirectoryItems = function(Directory, Options)
		local Result = {}

		local DIR = FFI.C.opendir(Directory)

		if DIR ~= nil then
			local Entry = FFI.C.readdir(DIR)

			while Entry ~= nil do
				local Name = FFI.string(Entry.d_name)

				if Name ~= "." and Name ~= ".." and string.sub(Name, 1, 1) ~= "." then
					local AddDirectory = Entry.d_type == 4 and Options.Directories
					local AddFile = Entry.d_type == 8 and Options.Files

					if (AddDirectory or AddFile) and not ShouldFilter(Name, Options.Filter) then
						table.insert(Result, Name)
					end
				end

				Entry = FFI.C.readdir(DIR)
			end

			FFI.C.closedir(DIR)
		end

		return Result
	end

	Exists = function(Path)
		local Buffer = Stat()
		return FFI.C.stat64(Path, Buffer) == 0
	end

	IsDirectory = function(Path)
		local Buffer = Stat()

		if FFI.C.stat64(Path, Buffer) == 0 then
			return Bit.band(Buffer.st_mode, 0xf000) == FFI.C.S_IFDIR
		end

		return false
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
	return Exists(Path)
end

function FileSystem.IsDirectory(Path)
	return IsDirectory(Path)
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
