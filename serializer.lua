--[[
#saveTableBinary.lua
by Luke100000
version 1.0

modified by: Brandon Blanker Lim-it @flamendless

encodes lua tables
supports numbers, strings and boolean as index or value
supports sub-tables
full support for binary values in index and value
minimal structure size, further compressionable
inbuilt super-fast base64 encoding

#format

#first byte
A for array
B for key-value table

#second byte
bit 1-2: length of value
bit 3-4: value type
bit 5-6: length of index
bit 7-8: index type

types:
0	number
1	string
2	boolean
3	table
--]]

local mime = require("mime")

local string_char = string.char

string.base64_encode = mime.encode("base64")
string.encode = function(self, d)
	local r = #d % 3
	if r == 0 then
		d = "3==" .. d
	elseif r == 1 then
		d = "2=" .. d
	else
		d = "1" .. d
	end
	return self.base64_encode(d)
end

string.base64_decode = mime.decode("base64")
string.decode = function(self, d)
	local r = self.base64_decode(d)
	local f = r:sub(1, 1)
	if f == "3" then
		return r:sub(4)
	elseif f == "2" then
		return r:sub(3)
	else
		return r:sub(2)
	end
end

local serializer = {}
local floor = math.floor
local byte = string.byte
local concat = table.concat
local rshift = bit.rshift

function serializer.packNumber(n)
	n = n + 1
	local o = ""
	while n > 0 do
		o = o .. string_char(n % 256)
		n = floor(n / 256)
	end
	return o
end
function serializer.unpackNumber(p, l)
	local n = 0
	for i = 1, l do
		n = n + byte(serializer._s:sub(p + i - 1)) * 256 ^ (i-1)
	end
	return n - 1
end

function serializer.saveBinary(t)
	serializer.concatBuffer = { }
	serializer.saveBinary_(t)
	return concat(serializer.concatBuffer)
end

function serializer.saveBinary_(t)
	if serializer.isArray(t) then
		serializer.concatBuffer[#serializer.concatBuffer+1] = "A"
		for d,s in ipairs(t) do
			local typ = type(s)
			if typ == "number" then
				local v = tostring(s)
				local l = serializer.packNumber(#v)
				serializer.concatBuffer[#serializer.concatBuffer+1] = string_char(#l-1) .. l .. v
			elseif typ == "string" then
				local l = serializer.packNumber(#s)
				serializer.concatBuffer[#serializer.concatBuffer+1] = string_char(#l-1 + 1 * 4) .. l .. s
			elseif typ == "boolean" then
				serializer.concatBuffer[#serializer.concatBuffer+1] = string_char((s == true and 1 or s == false and 2 or s == nil and 0) + 2 * 4)
			elseif typ == "table" then
				serializer.concatBuffer[#serializer.concatBuffer+1] = string_char(0 + 3 * 4)
				serializer.saveBinary_(s)
				serializer.concatBuffer[#serializer.concatBuffer+1] = string_char(1 + 3 * 4)
			end
		end
	else
		serializer.concatBuffer[#serializer.concatBuffer+1] = "B"
		for d,s in pairs(t) do
			--index
			local typ, typI, lT, indexL, index = type(d)
			if typ == "number" then
				typI = 0
				index = tostring(d)
				indexL = serializer.packNumber(#index)
				lT = #indexL - 1
			elseif typ == "string" then
				typI = 1
				index = tostring(d)
				indexL = serializer.packNumber(#index)
				lT = #indexL - 1
			elseif typ == "boolean" then
				typI = 2
				index = ""
				indexL = ""
				lT = (d == true and 1 or d == false and 2 or d == nil and 0)
			end

			--value (and index combined)
			local typ = type(s)
			if typ == "number" then
				local v = tostring(s)
				local l = serializer.packNumber(#v)
				serializer.concatBuffer[#serializer.concatBuffer+1] = string_char(#l-1 + lT * 16 + typI * 64) .. indexL .. index .. l .. v
			elseif typ == "string" then
				local l = serializer.packNumber(#s)
				serializer.concatBuffer[#serializer.concatBuffer+1] = string_char(#l-1 + 1 * 4 + lT * 16 + typI * 64) .. indexL .. index .. l .. s
			elseif typ == "boolean" then
				serializer.concatBuffer[#serializer.concatBuffer+1] = string_char((s == true and 1 or s == false and 2 or s == nil and 0) + 2 * 4 + lT * 16 + typI * 64)
				serializer.concatBuffer[#serializer.concatBuffer+1] = indexL .. index
			elseif typ == "table" then
				serializer.concatBuffer[#serializer.concatBuffer+1] = string_char(0 + 3 * 4 + lT * 16 + typI * 64)
				serializer.concatBuffer[#serializer.concatBuffer+1] = indexL .. index
				serializer.saveBinary_(s)
				serializer.concatBuffer[#serializer.concatBuffer+1] = string_char(1 + 3 * 4 + lT * 16 + typI * 64)
			end
		end
	end
end

function serializer.loadBinary(s)
	serializer._s = s
	return serializer.loadBinary_(2)
end

function serializer.loadBinary_(i)
	local t = { }
	if serializer._s:sub(i-1, i-1) == "A" then
		while true do
			local b = byte(serializer._s:sub(i, i))
			if not b then
				return t, #serializer._s
			end
			local l, typ = b % 4, rshift(b, 2) % 4
			if typ == 0 then
				local ni = i+1+l+serializer.unpackNumber(i+1, l+1)
				t[#t+1] = tonumber(serializer._s:sub(i+2+l, ni))
				i = ni+1
			elseif typ == 1 then
				local ni = i+1+l+serializer.unpackNumber(i+1, l+1)
				t[#t+1] = serializer._s:sub(i+2+l, ni)
				i = ni+1
			elseif typ == 2 then
				if l == 1 then
					t[#t+1] = true
				elseif l == 2 then
					t[#t+1] = false
				else
					t[#t+1] = nil
				end
				i = i + 1
			else
				if l == 1 then
					return t, i + 1
				else
					t[#t+1], i = serializer.loadBinary_(i+2)
				end
			end
		end
	else
		while true do
			local b = byte(serializer._s:sub(i, i))
			if not b then
				return t, #serializer._s
			end
			local l, typ, lI, typI = b % 4, rshift(b, 2) % 4, rshift(b, 4) % 4, rshift(b, 6) % 4

			if typ == 3 and l == 1 then
				return t, i+1
			end

			--index
			local index
			if typI == 0 then
				local ni = i+1+lI+serializer.unpackNumber(i+1, lI+1)
				index = tonumber(serializer._s:sub(i+2+lI, ni))
				i = ni
			elseif typI == 1 then
				local ni = i+1+lI+serializer.unpackNumber(i+1, lI+1)
				index = serializer._s:sub(i+2+lI, ni)
				i = ni
			elseif typI == 2 then
				if lI == 1 then
					index = true
				elseif lI == 2 then
					index = false
				else
					index = nil
				end
			end

			--value
			if typ == 0 then
				local ni = i+1+l+serializer.unpackNumber(i+1, l+1)
				t[index] = tonumber(serializer._s:sub(i+2+l, ni))
				i = ni+1
			elseif typ == 1 then
				local ni = i+1+l+serializer.unpackNumber(i+1, l+1)
				t[index] = serializer._s:sub(i+2+l, ni)
				i = ni+1
			elseif typ == 2 then
				if l == 1 then
					t[index] = true
				elseif l == 2 then
					t[index] = false
				else
					t[index] = nil
				end
				i = i + 1
			else
				t[index], i = serializer.loadBinary_(i+2)
			end
		end
	end
end

--provided by kikito at stackoverflow
function serializer.isArray(t)
	local i = 0
	for _ in pairs(t) do
		i = i + 1
		if t[i] == nil then return false end
	end
	return true
end

return serializer
