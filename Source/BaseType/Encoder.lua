-- ------------------------------------------------------------------------------ --
--                                   LibTSMUtil                                   --
--                 https://github.com/TradeSkillMaster/LibTSMUtil                 --
--         Licensed under the MIT license. See LICENSE.txt for more info.         --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local Encoder = LibTSMUtil:DefineClassType("Encoder")
local LibDeflate = LibStub("LibDeflate")
local LibSerialize = LibStub("LibSerialize")
local private = {
	serializationOptions = {
		errorOnUnserializableType = true,
		stable = false,
		filter = nil,
	},
}

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
---@return self
function Encoder:SetEncodingType(encodingType)
	assert(not self._encodingType)
	assert(encodingType == "PRINT" or encodingType == "ADDON" or encodingType == "BASE64")
	self._encodingType = encodingType
	return self
end

---Sets the serialization type to use.
---@param serializationType EncoderSerializationType
---@return self
function Encoder:SetSerializationType(serializationType)
	assert(not self._serializationType)
	assert(serializationType == "FAST" or serializationType == "STABLE" or serializationType == "CBOR" or serializationType == "NONE")
	self._serializationType = serializationType
	return self
end

---Sets a serialization filter function.
---@param func fun(tbl: table, k: any, v: any): boolean The filter function
---@return self
function Encoder:SetSerializationFilter(func)
	assert(not self._serializeFilterFunc)
	assert(self._serializationType == "FAST" or self._serializationType == "STABLE")
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
		return C_EncodingUtil.EncodeBase64(str)
	else
		error("Invalid encoding type: "..tostring(self._encodingType))
	end
end

function Encoder.__private:_Compress(str)
	return C_EncodingUtil.CompressString(str)
end

function Encoder.__private:_Decompress(str)
	local success, result = pcall(C_EncodingUtil.DecompressString, str)
	if not success then
		return nil
	end
	return result
end

function Encoder.__private:_Decode(str)
	if self._encodingType == "PRINT" then
		return LibDeflate:DecodeForPrint(str)
	elseif self._encodingType == "ADDON" then
		return LibDeflate:DecodeForWoWAddonChannel(str)
	elseif self._encodingType == "BASE64" then
		return C_EncodingUtil.DecodeBase64(str)
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
