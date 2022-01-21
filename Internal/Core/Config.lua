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

local FileSystem = require(SLAB_PATH .. '.Internal.Core.FileSystem')

local Config = {}
local DecodeValueFn = nil
local Section = nil

local function IsBasicType(Value)
	if Value ~= nil then
		local Type = type(Value)

		return Type == "number" or Type == "boolean" or Type == "string"
	end

	return false
end

local function IsArray(Table)
	if Table ~= nil and type(Table) == "table" then
		local N = 0
		for K, V in pairs(Table) do
			if type(K) ~= "number" then
				return false
			end

			if not IsBasicType(V) then
				return false
			end

			N = N + 1
		end

		return #Table == N
	end

	return false
end

local function EncodeValue(Value)
	local Result = ""

	if Value ~= nil then
		local Type = type(Value)
		if Type == "boolean" then
			Result = Value == true and "true" or "false"
		elseif Type == "number" or Type == "string" then
			Result = tostring(Value)
		end
	end

	return Result
end

local function EncodePair(Key, Value)
	local Result = tostring(Key) .. " = "

	if Value ~= nil then
		if type(Value) == "table" then
			if IsArray(Value) then
				Result = Result .. "(" .. table.concat(Value, ",") .. ")\n"
			else
				Result = Result .. "{"
				local First = true
				for K, V in pairs(Value) do
					if not First then
						Result = Result .. ","
					end
					Result = Result .. K .. "=" .. EncodeValue(V)
					First = false
				end
				Result = Result .. "}\n"
			end
		elseif IsBasicType(Value) then
			Result = Result .. tostring(Value) .. "\n"
		end
	end

	return Result
end

local function EncodeSection(Section, Values)
	local Result = "[" .. Section .. "]\n"

	for K, V in pairs(Values) do
		Result = Result .. EncodePair(K, V)
	end

	return Result .. "\n"
end

local function DecodeBoolean(Value)
	local Lower = string.lower(Value)

	if Lower == "true" then
		return true
	elseif Lower == "false" then
		return false
	end

	return nil
end

local function DecodeArray(Value)
	local Result = nil

	if string.sub(Value, 1, 1) == "(" then
		Result = {}
		local Index = 1
		local Buffer = ""

		while Index <= #Value do
			local Ch = string.sub(Value, Index, Index)

			if Ch == ',' or Ch == ')' then
				local Item = DecodeValueFn(Buffer)
				if Item ~= nil then
					table.insert(Result, Item)
				end
				Buffer = ""
			elseif Ch ~= "(" and Ch ~= " " then
				Buffer = Buffer .. Ch
			end

			Index = Index + 1
		end
	end

	return Result
end

local function DecodeTable(Value)
	local Result = nil

	if string.sub(Value, 1, 1) == "{" then
		Result = {}
		for K, V in string.gmatch(Value, "(%w+)=(%-?%w+)") do
			Result[K] = DecodeValueFn(V)
		end
	end

	return Result
end

local function DecodeValue(Value)
	if Value ~= nil and Value ~= "" then
		local Number = tonumber(Value)
		if Number ~= nil then
			return Number
		end

		local Boolean = DecodeBoolean(Value)
		if Boolean ~= nil then
			return Boolean
		end

		if Value == "nil" then
			return nil
		end

		local Array = DecodeArray(Value)
		if Array ~= nil then
			return Array
		end

		local Table = DecodeTable(Value)
		if Table ~= nil then
			return Table
		end

		return Value
	end

	return nil
end

DecodeValueFn = DecodeValue

local function DecodeLine(Line, Result)
	if string.sub(Line, 1, 1) == ";" then
		return
	end

	if string.sub(Line, 1, 1) == "[" and string.sub(Line, #Line, #Line) == "]" then
		local Key = string.sub(Line, 2, #Line - 1)
		Result[Key] = {}
		Section = Result[Key]
	end

	local Index = string.find(Line, "=", 1, true)

	if Index ~= nil then
		local Key = string.sub(Line, 1, Index - 1)
		Key = string.gsub(Key, " ", "")

		local Value = string.sub(Line, Index + 1)
		Value = string.gsub(Value, " ", "")

		if string.sub(Value, #Value, #Value) == "," then
			Value = string.sub(Value, 1, #Value - 1)
		end

		if Section ~= nil then
			Section[Key] = DecodeValue(Value)
		else
			Result[Key] = DecodeValue(Value)
		end
	end
end

function Config.Encode(Table)
	local Result = ""

	if type(Table) == "table" and not IsArray(Table) then
		local Sections = {}
		for K, V in pairs(Table) do
			if type(V) == "table" and not IsArray(V) then
				Sections[K] = V
			else
				Result = Result .. EncodePair(K, V)
			end
		end

		if string.len(Result) > 0 then
			Result = Result .. "\n"
		end

		for K, V in pairs(Sections) do
			Result = Result .. EncodeSection(K, V)
		end
	end

	return Result
end

function Config.Decode(Stream)
	local Result = nil
	local Error = ""

	if Stream ~= nil then
		if type(Stream) == "string" then
			Result = {}

			local Start = 1
			local End = string.find(Stream, "\n", Start, true)
			local Line = ""

			while End ~= nil do
				Line = string.sub(Stream, Start, End - 1)

				DecodeLine(Line, Result)

				Start = End + 1
				End = string.find(Stream, "\n", Start, true)
			end

			Line = string.sub(Stream, Start)

			DecodeLine(Line, Result)
		else
			Error = "Invalid type given for Stream. Type given is " .. type(Stream) .. "."
		end
	else
		Error = "Invalid stream given to Config.Decode!"
	end

	return Result, Error
end

function Config.LoadFile(Path, IsDefault)
	local Result = nil
	local Contents, Error = FileSystem.ReadContents(Path, nil, IsDefault)
	if Contents ~= nil then
		Result, Error = Config.Decode(Contents)
	end

	return Result, Error
end

function Config.Save(Path, Table, IsDefault)
	local Result, Error = false
	if Table ~= nil then
		local Contents = Config.Encode(Table)
		Result, Error = FileSystem.SaveContents(Path, Contents, IsDefault)
	else
		Error = "Invalid table given to Config.Save!"
	end

	return Result, Error
end

return Config
