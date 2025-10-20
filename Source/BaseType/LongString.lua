-- ------------------------------------------------------------------------------ --
--                                   LibTSMUtil                                   --
--                 https://github.com/TradeSkillMaster/LibTSMUtil                 --
--         Licensed under the MIT license. See LICENSE.txt for more info.         --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local LongString = LibTSMUtil:Init("BaseType.LongString")
local Encoder = LibTSMUtil:IncludeClassType("Encoder")
local private = {
	encoder = nil
}
local MAX_STRING_LENGTH = 100000

---@alias EncodedLongString string[]|{compressed: true}



-- ============================================================================
-- Module Loading
-- ============================================================================

LongString:OnModuleLoad(function()
	private.encoder = Encoder.Create()
		:SetEncodingType("BASE64")
		:SetSerializationType("NONE")
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Encodes a long string into a value which is safe to store in WoW's SV file.
---@param str string The string to encode
---@return EncodedLongString
function LongString.Encode(str)
	assert(type(str) == "string")
	str = private.encoder:Serialize(str)
	local len = #str
	local index = 1
	local result = { compressed = true }
	while index <= len do
		local partLen = min(len - index + 1, MAX_STRING_LENGTH)
		local part = strsub(str, index, index + partLen - 1)
		tinsert(result, part)
		index = index + partLen
	end
	return result
end

---Decodes a previously-encoded value back into a long string.
---@param value EncodedLongString The value to decode
---@return string
function LongString.Decode(value)
	local result = table.concat(value)
	if value.compressed then
		local success = nil
		success, result = private.encoder:Deserialize(result)
		if not success then
			return ""
		end
	end
	return result
end
