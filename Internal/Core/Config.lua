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

local love = require("love")
local concat = table.concat
local find = string.find
local gmatch = string.gmatch
local insert = table.insert
local lower = string.lower
local sub = string.sub
local gsub = string.gsub

local FileSystem = require(SLAB_PATH .. ".Internal.Core.FileSystem")

local Config = {}

local fn_decode_value, section

local function IsBasicType(value)
	local t = type(value)
	return t == "number" or t == "boolean" or t == "string"
end

local function IsArray(value)
	if type(value) ~= "table" then return false end

	local n = 0
	for k, v in pairs(value) do
		if type(k) ~= "number" then
			return false
		end

		if not IsBasicType(v) then
			return false
		end

		n = n + 1
	end

	return #value == n
end

local function EncodeValue(value)
	if not value then return "" end
	local t = type(value)
	if t == "string" then
		return value
	elseif t == "boolean" or t == "number" then
		return tostring(value)
	end
end

local function EncodePair(key, value)
	local res = tostring(key) .. " = "
	if not value then return res end

	if IsBasicType(value) then
		res = res .. tostring(value) .. "\n"
	elseif type(value) == "table" then
		if IsArray(value) then
			res = res .. "{" .. concat(value, ",") .. ")\n"
		else
			res = res .. "{"
			local first = true
			for k, v in pairs(value) do
				if not first then
					res = res .. ","
				end
				res = res .. k .. "=" .. EncodeValue(v)
				first = false
			end
			res = res .. "}\n"
		end
	end
	return res
end

local function EncodeSection(sec, values)
	local res = "[" .. sec .. "]\n"
	for k, v in pairs(values) do
		res = res .. EncodePair(k, v)
	end
	return res .. "\n"
end

local function DecodeBoolean(value)
	local l_str = lower(value)
	return l_str == "true" or (l_str ~= "false" and nil)
end

local function DecodeArray(value)
	if sub(value, 1, 1) ~= "(" then return nil end
	local res = {}
	local index = 1
	local buffer = ""

	while index <= #value do
		local ch = sub(value, index, index)
		if ch == "," or ch == ")" then
			local item = fn_decode_value(buffer)
			if item then
				insert(res, item)
			end
			buffer = ""
		elseif ch ~= "(" and ch ~= " " then
			buffer = buffer .. ch
		end

		index = index + 1
	end
	return res
end

local function DecodeTable(value)
	if sub(value, 1, 1) ~= "{" then return end
	local res = {}
	for k, v in gmatch(value, "(%w+)=(%-?%w+)") do
		res[k] = fn_decode_value(v)
	end
	return res
end

local function DecodeValue(value)
	if not (value ~= nil and value ~= "") then return end
	local num = tonumber(value)
	if num then return num end

	local bool = DecodeBoolean(value)
	if bool then return bool end

	if value == "nil" then return nil end

	local array = DecodeArray(value)
	if array then return array end

	local t = DecodeTable(value)
	if t then return t end

	return value
end

fn_decode_value = DecodeValue

local function DecodeLine(line, result)
	local ch = sub(line, 1, 1)
	if ch == ";" then return end

	local len = #line
	if ch == "[" and sub(line, len, len) == "]" then
		local key = sub(line, 2, len - 1)
		result[key] = {}
		section = result[key]
	end

	local index = find(line, "=", 1, true)
	if not index then return end

	local key = sub(line, 1, index - 1)
	key = gsub(key, " ", "")

	local value = sub(line, index + 1)
	value = gsub(value, " ", "")

	if section then
		section[key] = DecodeValue(value)
	else
		result[key] = DecodeValue(value)
	end
end

function Config.Encode(tbl)
	if not (type(tbl) == "table" and not IsArray(tbl)) then return end
	local res = ""
	local sections = {}
	for k, v in pairs(tbl) do
		if type(v) == "table" and not IsArray(v) then
			sections[k] = v
		else
			res = res .. EncodePair(k, v)
		end
	end

	if #res > 0 then
		res = res .. "\n"
	end

	for k, v in pairs(sections) do
		res = res .. EncodeSection(k, v)
	end

	return res
end

function Config.Decode(stream)
	if not stream then return nil, "Invalid stream given to Config.Decode!" end
	if type(stream) ~= "string" then
		return nil, "Invalid type given for stream. Type given is " .. type(stream)
	end

	local res = {}
	local start = 1
	local last = find(stream, "\n", start, true)
	local line

	while last ~= nil do
		line = sub(stream, start, last - 1)
		DecodeLine(line, res)
		start = last + 1
		last = find(stream, "\n", start, true)
	end
	line = sub(stream, start)
	DecodeLine(line, res)

	return res
end

function Config.LoadFile(path, is_default)
	local res
	local contents, err = FileSystem.ReadContents(path, nil, is_default)
	if contents then
		res, err = Config.Decode(contents)
	end
	return res, err
end

function Config.Save(path, tbl, is_default)
	if not tbl then return "Invalid table given to Config.Save!" end
	local contents = Config.Encode(tbl)
	local res, err = FileSystem.SaveContents(path, contents, is_default)
	return res, err
end

return Config
