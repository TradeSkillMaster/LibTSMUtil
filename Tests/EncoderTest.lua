local TSM, Locals = ... ---@type TSM, table<string,table<string,any>>
local LibTSMUtil = TSM.LibTSMUtil
local Encoder = LibTSMUtil:IncludeClassType("Encoder")
local encoderPrivate = Locals["LibTSMUtil.BaseType.Encoder"].private



-- ============================================================================
-- Tests
-- ============================================================================

TestEncoder = {}

function TestEncoder:TestRawBase64()
	local data = "TEST STRING TO B64 ENCODE"
	local encoded = encoderPrivate.EncodeBase64(data)
	assertEquals(encoded, "VEVTVCBTVFJJTkcgVE8gQjY0IEVOQ09ERQ==")
	assertEquals(encoderPrivate.DecodeBase64(encoded), data)
end

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
