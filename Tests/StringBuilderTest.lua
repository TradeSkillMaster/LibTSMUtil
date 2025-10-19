local TSM = ... ---@type TSM
local LibTSMUtil = TSM.LibTSMUtil
local StringBuilder = LibTSMUtil:IncludeClassType("StringBuilder")



-- ============================================================================
-- Tests
-- ============================================================================

TestStringBuilder = {}

function TestStringBuilder:TestSimple()
	local obj = StringBuilder.Create()
	assertEquals(
		obj:SetTemplate("%(strVar)s %(numVar).2f")
			:SetParam("strVar", "test")
			:SetParam("numVar", 1.1234)
			:Commit(),
		"test 1.12")
end
