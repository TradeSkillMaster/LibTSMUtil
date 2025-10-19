local TSM = ... ---@type TSM
local LibTSMUtil = TSM.LibTSMUtil
local Vararg = LibTSMUtil:Include("Lua.Vararg")



-- ============================================================================
-- Tests
-- ============================================================================

TestVararg = {}

function TestVararg:TestIntoTable()
	local function TestCase(...)
		local actual = {}
		local expected = {...}
		Vararg.IntoTable(actual, ...)
		return actual, expected
	end
	assertEquals(TestCase())
	assertEquals(TestCase(1))
	assertEquals(TestCase(1, 2))
	assertEquals(TestCase(1, 2, 3))
	assertEquals(TestCase(1, 2, 3, 4))
	assertEquals(TestCase(1, 2, 3, 4, 5))
	assertEquals(TestCase(1, 2, 3, 4, 5, 6, 7, 8))
	assertEquals(TestCase(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13))
end

function TestVararg:TestIn()
	assertTrue(Vararg.In(1, 1, 2, 3))
	assertTrue(Vararg.In(2, 1, 2, 3))
	assertTrue(Vararg.In(3, 1, 2, 3))
	assertTrue(Vararg.In(9, 1, 2, 3, 4, 5, 6, 7, 8, 9))
	assertTrue(Vararg.In(1, 1, nil, 3))
	assertTrue(Vararg.In(3, 1, nil, 3))
	assertTrue(Vararg.In(3, 1, nil, 3, 3))
	assertTrue(Vararg.In(nil, 1, nil, 3, 3))
	assertFalse(Vararg.In(3))
	assertFalse(Vararg.In(3, 1, 2))
	assertFalse(Vararg.In(9, 1, 2, 3, 4, 5))
end
