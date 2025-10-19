local TSM = ... ---@type TSM
local LibTSMUtil = TSM.LibTSMUtil
local Math = LibTSMUtil:Include("Lua.Math")



-- ============================================================================
-- Tests
-- ============================================================================

TestRound = {}

function TestRound:TestPositive()
	assertEquals(Math.Round(1.234, 0.01), 1.23)
	assertEquals(Math.Round(1.235, 0.01), 1.24)
	assertEquals(Math.Round(1.236, 0.01), 1.24)
end

function TestRound:TestNegative()
	assertEquals(Math.Round(-1.234, 0.01), -1.23)
	assertEquals(Math.Round(-1.235, 0.01), -1.24)
	assertEquals(Math.Round(-1.236, 0.01), -1.24)
end

function TestRound:TestSingleParameter()
	assertEquals(Math.Round(1.4), 1)
	assertEquals(Math.Round(1.5), 2)
	assertEquals(Math.Round(1.6), 2)
end

TestScale = {}

function TestScale:TestAll()
	assertEquals(Math.Scale(0, 0, 10, 0, 100), 0)
	assertEquals(Math.Scale(2, 0, 10, 0, 100), 20)
	assertEquals(Math.Scale(10, 0, 10, 0, 100), 100)
	assertEquals(Math.Scale(0, 0, 100, 0, 10), 0)
	assertEquals(Math.Scale(20, 0, 100, 0, 10), 2)
	assertEquals(Math.Scale(100, 0, 100, 0, 10), 10)
end
