local TSM = ... ---@type TSM
local LibTSMUtil = TSM.LibTSMUtil
local NamedTupleList = LibTSMUtil:IncludeClassType("NamedTupleList")



-- ============================================================================
-- Tests
-- ============================================================================

TestNamedTupleList = {}

function TestNamedTupleList:TestSimple()
	local list = NamedTupleList.New("strField", "numField")

	assertEquals(list:GetNumRows(), 0)

	list:InsertRow("a", 1)
	list:InsertRow("b", 2)
	assertEquals(list:GetNumRows(), 2)
	assertEquals({list:GetRow(1)}, {"a", 1})
	assertEquals(list:GetRowField(1, "strField"), "a")
	assertEquals(list:GetRowField(1, "numField"), 1)
	assertEquals({list:GetRow(2)}, {"b", 2})
	assertEquals(list:GetRowField(2, "strField"), "b")
	assertEquals(list:GetRowField(2, "numField"), 2)

	list:RemoveRow(1)
	assertEquals(list:GetNumRows(), 1)
	assertEquals({list:GetRow(1)}, {"b", 2})
	assertEquals(list:GetRowField(1, "strField"), "b")
	assertEquals(list:GetRowField(1, "numField"), 2)

	list:Wipe()
	assertEquals(list:GetNumRows(), 0)
end
