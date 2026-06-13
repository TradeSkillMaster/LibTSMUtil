local TSM = ... ---@type TSM
local LibTSMUtil = TSM.LibTSMUtil
local Encoder = LibTSMUtil:IncludeClassType("Encoder")



-- ============================================================================
-- Tests
-- ============================================================================

TestEncoder = {}

function TestEncoder:TestBase64()
	local encoder = Encoder.Create()
		:SetEncodingType("BASE64")
		:SetSerializationType("NONE")

	local data = "TEST STRING TO B64 ENCODE"
	local success, result = encoder:Deserialize(encoder:Serialize(data))
	assertTrue(success)
	assertEquals(result, data)
end

function TestEncoder:TestSerialized()
	local encoder = Encoder.Create()
		:SetEncodingType("ADDON")
		:SetSerializationType("FAST")

	local data = {1, 2, 3}
	local success, result = encoder:Deserialize(encoder:Serialize(data))
	assertTrue(success)
	assertEquals(result, data)
end
