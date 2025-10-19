local TSM = ... ---@type TSM
local LibTSMUtil = TSM.LibTSMUtil
local Range = LibTSMUtil:IncludeClassType("Range")
local private = {
	ranges = {},
}



-- ============================================================================
-- Helper Functions
-- ============================================================================

local function AcquireRangeStartEnd(startValue, endValue)
	local range = Range.AcquireStartEnd(startValue, endValue)
	tinsert(private.ranges, range)
	return range
end

local function AcquireRangeStartLength(startValue, length)
	local range = Range.AcquireStartLength(startValue, length)
	tinsert(private.ranges, range)
	return range
end




-- ============================================================================
-- Tests
-- ============================================================================

TestRange = {}

function TestRange:TearDown()
	for _, range in ipairs(private.ranges) do
		range:Release()
	end
	wipe(private.ranges)
end

function TestRange:TestProperties()
	local range1 = AcquireRangeStartEnd(1, 2)
	assertEquals(range1:GetStart(), 1)
	assertEquals(range1:GetEnd(), 2)
	assertEquals(range1:GetLength(), 2)
	assertEquals({range1:GetValues()}, {1, 2})
	assertEquals(tostring(range1), "Range:[1,2]")

	local range2 = AcquireRangeStartLength(3, 2)
	assertEquals(range2:GetStart(), 3)
	assertEquals(range2:GetEnd(), 4)
	assertEquals(range2:GetLength(), 2)
	assertEquals({range2:GetValues()}, {3, 4})
	assertEquals(tostring(range2), "Range:[3,4]")
end

function TestRange:TestIncludes()
	local range = AcquireRangeStartEnd(4, 9)
	assertTrue(range:Includes(4))
	assertTrue(range:Includes(7))
	assertTrue(range:Includes(9))
	assertFalse(range:Includes(3))
	assertFalse(range:Includes(10))
	assertFalse(range:Includes(math.huge))
end

function TestRange:TestContains()
	local range = AcquireRangeStartEnd(4, 9)
	assertTrue(range:Contains(AcquireRangeStartEnd(4, 9)))
	assertTrue(range:Contains(AcquireRangeStartEnd(5, 8)))
	assertTrue(range:Contains(AcquireRangeStartEnd(4, 8)))
	assertTrue(range:Contains(AcquireRangeStartEnd(5, 9)))
	assertTrue(range:Contains(AcquireRangeStartEnd(5, 5)))
	assertFalse(range:Contains(AcquireRangeStartEnd(4, 10)))
	assertFalse(range:Contains(AcquireRangeStartEnd(3, 10)))
	assertFalse(range:Contains(AcquireRangeStartEnd(3, 9)))
	assertFalse(range:Contains(AcquireRangeStartEnd(3, 4)))
end

function TestRange:TestStartsBefore()
	local range = AcquireRangeStartEnd(4, 9)
	assertTrue(range:StartsBefore(AcquireRangeStartEnd(5, 5)))
	assertTrue(range:StartsBefore(AcquireRangeStartEnd(5, 9)))
	assertTrue(range:StartsBefore(AcquireRangeStartEnd(5, 10)))
	assertFalse(range:StartsBefore(AcquireRangeStartEnd(2, 5)))
	assertFalse(range:StartsBefore(AcquireRangeStartEnd(2, 10)))
	assertFalse(range:StartsBefore(AcquireRangeStartEnd(4, 5)))
	assertFalse(range:StartsBefore(AcquireRangeStartEnd(4, 10)))
end

function TestRange:TestIntersectionLength()
	local range = AcquireRangeStartEnd(4, 9)
	assertEquals(range:IntersectionLength(AcquireRangeStartEnd(5, 5)), 1)
	assertEquals(range:IntersectionLength(AcquireRangeStartEnd(5, 9)), 5)
	assertEquals(range:IntersectionLength(AcquireRangeStartEnd(4, 9)), 6)
	assertEquals(range:IntersectionLength(AcquireRangeStartEnd(3, 10)), 6)
	assertEquals(range:IntersectionLength(AcquireRangeStartEnd(1, 4)), 1)
	assertEquals(range:IntersectionLength(AcquireRangeStartEnd(1, 3)), 0)
end

function TestRange:TestInfinite()
	local range = AcquireRangeStartEnd(-math.huge, math.huge)
	assertEquals(range:GetStart(), -math.huge)
	assertEquals(range:GetEnd(), math.huge)
	assertEquals(range:GetLength(), math.huge)
	assertEquals({range:GetValues()}, {-math.huge, math.huge})
	assertEquals(range:IntersectionLength(AcquireRangeStartEnd(1, 5)), 5)
	assertTrue(range:StartsBefore(AcquireRangeStartEnd(4, 10)))
end
