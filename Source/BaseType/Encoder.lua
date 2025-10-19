-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local Encoder = LibTSMUtil:DefineClassType("Encoder")
local Table = LibTSMUtil:Include("Lua.Table")
local LibDeflate = LibStub("LibDeflate")
local LibSerialize = LibStub("LibSerialize")
local private = {
	base64Temp = {},
	serializationOptions = {
		errorOnUnserializableType = true,
		stable = false,
		filter = nil,
	},
}
local BASE64_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local BASE64_PAD = "="
local BASE64_ENCODE_LOOKUP = {}
local BASE64_DECODE_BYTES = {}

---@alias EncoderEncodingType "PRINT"|"ADDON"|"BASE64"
---@alias EncoderSerializationType "FAST"|"STABLE"|"CBOR"|"NONE"



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Creates an encoder.
---@return Encoder
function Encoder.__static.Create()
	return Encoder()
end

---Returns whether or not the encoder supports CBOR.
---@return boolean
function Encoder.__static.SupportsCBOR()
	return C_EncodingUtil and true or false
end



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function Encoder.__private:__init()
	self._encodingType = nil
	self._serializationType = nil
	self._serializeFilterFunc = nil
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Sets the encoding type to use.
---@param encodingType EncoderEncodingType
---@return Encoder
function Encoder:SetEncodingType(encodingType)
	assert(encodingType == "PRINT" or encodingType == "ADDON" or encodingType == "BASE64")
	self._encodingType = encodingType
	return self
end

---Sets the serialization type to use.
---@param serializationType EncoderSerializationType
---@return Encoder
function Encoder:SetSerializationType(serializationType)
	assert(serializationType == "FAST" or serializationType == "STABLE" or serializationType == "CBOR" or serializationType == "NONE")
	assert(serializationType ~= "CBOR" or self.SupportsCBOR())
	self._serializationType = serializationType
	return self
end

---Sets a serialization filter function.
---@param func fun(tbl: table, k: any, v: any): boolean The filter function
---@return Encoder
function Encoder:SetSerializationFilter(func)
	assert(func and not self._serializeFilterFunc)
	self._serializeFilterFunc = func
	return self
end

---Serializes, compresses, and encodes the given data.
---@param ... any The data to serialize
---@return string
function Encoder:Serialize(...)
	local str = self:_Serialize(...)
	str = self:_Compress(str)
	str = self:_Encode(str)
	return str
end

---Decodes, decompresses, and deserializes the given data.
---@param str string The data to deserialize
---@return boolean success
---@return ...
function Encoder:Deserialize(str)
	str = self:_Decode(str)
	str = str and self:_Decompress(str)
	if not str then
		return false
	end
	return self:_Deserialize(str)
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function Encoder.__private:_Serialize(...)
	if self._serializationType == "FAST" then
		private.serializationOptions.filter = self._serializeFilterFunc
		private.serializationOptions.stable = false
		return LibSerialize:SerializeEx(private.serializationOptions, ...)
	elseif self._serializationType == "STABLE" then
		private.serializationOptions.filter = self._serializeFilterFunc
		private.serializationOptions.stable = true
		return LibSerialize:SerializeEx(private.serializationOptions, ...)
	elseif self._serializationType == "CBOR" then
		local value = ...
		assert(select("#", ...) == 1 and type(value) == "table")
		return C_EncodingUtil.SerializeCBOR(value)
	elseif self._serializationType == "NONE" then
		local value = ...
		assert(select("#", ...) == 1 and type(value) == "string")
		return value
	else
		error("Invalid serialization type: "..tostring(self._serializationType))
	end
end

function Encoder.__private:_Encode(str)
	if self._encodingType == "PRINT" then
		return LibDeflate:EncodeForPrint(str)
	elseif self._encodingType == "ADDON" then
		return LibDeflate:EncodeForWoWAddonChannel(str)
	elseif self._encodingType == "BASE64" then
		if C_EncodingUtil and C_EncodingUtil.EncodeBase64 then
			return C_EncodingUtil.EncodeBase64(str)
		else
			return private.EncodeBase64(str)
		end
	else
		error("Invalid encoding type: "..tostring(self._encodingType))
	end
end

function Encoder.__private:_Compress(str)
	if C_EncodingUtil and C_EncodingUtil.CompressString then
		return C_EncodingUtil.CompressString(str)
	else
		local result = LibDeflate:CompressDeflate(str)
		return result
	end
end

function Encoder.__private:_Decompress(str)
	if C_EncodingUtil and C_EncodingUtil.DecompressString then
		local success, result = pcall(C_EncodingUtil.DecompressString, str)
		if not success then
			return nil
		end
		return result
	else
		local result, numExtraBytes = LibDeflate:DecompressDeflate(str)
		if not result or numExtraBytes > 0 then
			return nil
		end
		return result
	end
end

function Encoder.__private:_Decode(str)
	if self._encodingType == "PRINT" then
		return LibDeflate:DecodeForPrint(str)
	elseif self._encodingType == "ADDON" then
		return LibDeflate:DecodeForWoWAddonChannel(str)
	elseif self._encodingType == "BASE64" then
		if C_EncodingUtil and C_EncodingUtil.DecodeBase64 then
			return C_EncodingUtil.DecodeBase64(str)
		else
			return private.DecodeBase64(str)
		end
	else
		error("Invalid encoding type: "..tostring(self._encodingType))
	end
end

function Encoder.__private:_Deserialize(str)
	if self._serializationType == "FAST" then
		return LibSerialize:Deserialize(str)
	elseif self._serializationType == "STABLE" then
		return LibSerialize:Deserialize(str)
	elseif self._serializationType == "CBOR" then
		local success, result = pcall(C_EncodingUtil.DeserializeCBOR, str)
		if not result then
			success = false
		end
		return success, result
	elseif self._serializationType == "NONE" then
		return true, str
	else
		error("Invalid serialization type: "..tostring(self._serializationType))
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.EncodeBase64(data)
	if #BASE64_ENCODE_LOOKUP == 0 then
		for i = 1, #BASE64_ALPHABET do
			BASE64_ENCODE_LOOKUP[i - 1] = strsub(BASE64_ALPHABET, i, i)
		end
	end
	assert(not next(private.base64Temp))
	local numEncodedChars = 0
	for i = 1, ceil(#data / 3) do
		local b1, b2, b3 = strbyte(data, (i - 1) * 3 + 1, i * 3)
		local b1Lower = b1 % 4
		private.base64Temp[numEncodedChars + 1] = BASE64_ENCODE_LOOKUP[(b1 - b1Lower) / 4]
		if b2 then
			local b2Lower = b2 and b2 % 16 or nil
			private.base64Temp[numEncodedChars + 2] = BASE64_ENCODE_LOOKUP[b1Lower * 16 + (b2 - b2Lower) / 16]
			if b3 then
				local b3Part2 = b3 % 64
				private.base64Temp[numEncodedChars + 3] = BASE64_ENCODE_LOOKUP[b2Lower * 4 + (b3 - b3Part2) / 64]
				private.base64Temp[numEncodedChars + 4] = BASE64_ENCODE_LOOKUP[b3Part2]
			else
				private.base64Temp[numEncodedChars + 3] = BASE64_ENCODE_LOOKUP[b2Lower * 4]
				private.base64Temp[numEncodedChars + 4] = BASE64_PAD
			end
		else
			private.base64Temp[numEncodedChars + 2] = BASE64_ENCODE_LOOKUP[b1Lower * 16]
			private.base64Temp[numEncodedChars + 3] = BASE64_PAD
			private.base64Temp[numEncodedChars + 4] = BASE64_PAD
		end
		numEncodedChars = numEncodedChars + 4
	end
	local result = table.concat(private.base64Temp)
	Table.WipeAndDeallocate(private.base64Temp)
	return result
end

function private.DecodeBase64(data)
	if #BASE64_DECODE_BYTES == 0 then
		for i = 1, #BASE64_ALPHABET do
			BASE64_DECODE_BYTES[strbyte(strsub(BASE64_ALPHABET, i, i))] = i - 1
		end
	end
	assert(not next(private.base64Temp))
	local numDecodedChars = 0
	local padding = strsub(data, -2) == '==' and 2 or strsub(data, -1) == '=' and 1 or 0
	for i = 1, padding > 0 and #data - 4 or #data, 4 do
		local b1, b2, b3, b4 = strbyte(data, i, i + 3)
		b1 = BASE64_DECODE_BYTES[b1]
		b2 = BASE64_DECODE_BYTES[b2]
		b3 = BASE64_DECODE_BYTES[b3]
		b4 = BASE64_DECODE_BYTES[b4]
		local v3Lower = b4
		local v3Upper = b3 % 4
		local v2Lower = (b3 - v3Upper) / 4
		local v2Upper = b2 % 16
		local v1Lower = (b2 - v2Upper) / 16
		local v1Upper = b1
		private.base64Temp[numDecodedChars + 1] = strchar(v1Upper * 4 + v1Lower)
		private.base64Temp[numDecodedChars + 2] = strchar(v2Upper * 16 + v2Lower)
		private.base64Temp[numDecodedChars + 3] = strchar(v3Upper * 64 + v3Lower)
		numDecodedChars = numDecodedChars + 3
	end
	if padding == 1 then
		local b1, b2, b3 = strbyte(data, #data - 3, #data - 1)
		b1 = BASE64_DECODE_BYTES[b1]
		b2 = BASE64_DECODE_BYTES[b2]
		b3 = BASE64_DECODE_BYTES[b3]
		local v2Lower = b3 / 4
		local v2Upper = b2 % 16
		local v1Lower = (b2 - v2Upper) / 16
		local v1Upper = b1
		private.base64Temp[numDecodedChars + 1] = strchar(v1Upper * 4 + v1Lower)
		private.base64Temp[numDecodedChars + 2] = strchar(v2Upper * 16 + v2Lower)
	elseif padding == 2 then
		local b1, b2 = strbyte(data, #data - 3, #data - 2)
		b1 = BASE64_DECODE_BYTES[b1]
		b2 = BASE64_DECODE_BYTES[b2]
		local v1Lower = b2 / 16
		local v1Upper = b1
		private.base64Temp[numDecodedChars + 1] = strchar(v1Upper * 4 + v1Lower)
	end
	local result = table.concat(private.base64Temp)
	Table.WipeAndDeallocate(private.base64Temp)
	return result
end
