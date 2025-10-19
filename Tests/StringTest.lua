local TSM = ... ---@type TSM
local LibTSMUtil = TSM.LibTSMUtil
local String = LibTSMUtil:Include("Lua.String")



-- ============================================================================
-- Tests
-- ============================================================================

TestSafeStrSplit = {}

function TestSafeStrSplit:TestSplit()
	assertItemsEquals(String.SafeSplit("a,b,c,d",","), {"a","b","c","d"})
end

function TestSafeStrSplit:TestSplitPeriods()
	assertItemsEquals(String.SafeSplit("a.b.c.d","."), {"a","b","c","d"})
end

function TestSafeStrSplit:TestSplitNotFound()
	assertItemsEquals(String.SafeSplit("a,b,c,d",":"), {"a,b,c,d"})
end

function TestSafeStrSplit:TestSplitEmptySplit()
	assertItemsEquals(String.SafeSplit("abcd",""), {"abcd"})
end
