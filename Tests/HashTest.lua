local TSM = ... ---@type TSM
local LibTSMUtil = TSM.LibTSMUtil
local Hash = LibTSMUtil:Include("Util.Hash")



-- ============================================================================
-- Tests
-- ============================================================================

TestHash = {}

function TestHash:TestString()
	assertEquals(Hash.Calculate(""), 5381)
	assertEquals(Hash.Calculate("", 100), 100)
	assertEquals(Hash.Calculate("test"), 10381413)
	assertEquals(Hash.Calculate("test", 1000), 15798472)
	assertEquals(Hash.Calculate(string.rep("abc", 99)), 16679063)
	assertEquals(Hash.Calculate({a = 2, b = 3, d = 5, c = 2}), 10461915)
	assertEquals(Hash.Calculate({1, 2}), 6135915)
	assertEquals(Hash.Calculate({1, 2, nil, 3}), 4679602)
	assertEquals(Hash.Calculate(nil), 177590)
end
