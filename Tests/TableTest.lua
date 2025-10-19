local TSM = ... ---@type TSM
local LibTSMUtil = TSM.LibTSMUtil
local Table = LibTSMUtil:Include("Lua.Table")



-- ============================================================================
-- Tests
-- ============================================================================

TestTable = {}

function TestTable:TestWithValueLookup()
	local tbl = { "a", "b", "c" }
	local valueLookup = { a = 2, b = 1, c = 3 }
	Table.SortWithValueLookup(tbl, valueLookup)
	assertEquals(tbl, { "b", "a", "c" })
end

function TestTable:TestMergeSorted()
	local tbl1 = { 1, 4, 8 }
	local tbl2 = { 1, 5, 6, 7, 7, 7 }
	local valueLookup = { [1] = 11, [4] = 14, [5] = 15, [6] = 16, [7] = 17, [8] = 18 }
	local result = {}
	Table.MergeSortedWithValueLookup(tbl1, tbl2, result, valueLookup)
	assertEquals(result, { 1, 1, 4, 5, 6, 7, 7, 7, 8 })
	assertTrue(Table.IsSortedWithValueLookup(result, valueLookup))
end

function TestTable:TestRotateRight()
	local function RotateRightHelper(tbl, ...)
		Table.RotateRight(tbl, ...)
		return tbl
	end

	assertEquals(RotateRightHelper({ 1, 2, 3, 4, 5, 6, 7 }, 7), { 1, 2, 3, 4, 5, 6, 7 })
	assertEquals(RotateRightHelper({ 1, 2, 3, 4, 5, 6, 7 }, 1), { 7, 1, 2, 3, 4, 5, 6 })
	assertEquals(RotateRightHelper({ 1, 2, 3, 4, 5, 6, 7 }, -1), { 2, 3, 4, 5, 6, 7, 1 })
	assertEquals(RotateRightHelper({ 1, 2, 3, 4, 5, 6, 7 }, 1, 3, 5), { 1, 2, 5, 3, 4, 6, 7 })
	assertEquals(RotateRightHelper({ 1, 2, 3, 4, 5, 6, 7 }, -1, 3, 5), { 1, 2, 4, 5, 3, 6, 7 })
end

function TestTable:TestGetDiffOrdered()
	local function TestGetDiffOrderedHelper(old, new)
		local inserted, removed = {}, {}
		local result = Table.GetDiffOrdered(old, new, inserted, removed)
		return result and { inserted, removed } or false
	end

	assertEquals(TestGetDiffOrderedHelper({ 1, 2, 3 }, { 1, 2, 3 }), { {}, {} })
	assertEquals(TestGetDiffOrderedHelper({ 1, 2, 4, 3 }, { 1, 2, 3 }), { {}, { 3 } })
	assertEquals(TestGetDiffOrderedHelper({ 1, 3 }, { 1, 2, 3 }), { { 2 }, {} })
	assertEquals(TestGetDiffOrderedHelper({ 1, 3 }, { 1, 2, 3, 4, 5 }), { { 2, 4, 5 }, {} })
	assertFalse(TestGetDiffOrderedHelper({ 1, 2 }, { 2, 1 }))
	assertFalse(TestGetDiffOrderedHelper({ 1, 3, 2 }, { 1, 2, 3, 4, 5 }))
end

function TestTable:TestRemoveRange()
	local function RemoveRangeHelper(tbl, startIndex, endIndex)
		Table.RemoveRange(tbl, startIndex, endIndex)
		return tbl
	end

	assertEquals(RemoveRangeHelper({ 1, 2, 3 }, 1, 2), { 3 })
	assertEquals(RemoveRangeHelper({ 1, 2, 3 }, 1, 1), { 2, 3 })
	assertEquals(RemoveRangeHelper({ 1, 2, 3 }, 2, 2), { 1, 3 })
	assertEquals(RemoveRangeHelper({ 1, 2, 3 }, 3, 3), { 1, 2 })
	assertEquals(RemoveRangeHelper({ 1, 2, 3, 4, 5, 6, 7, 8, 9 }, 5, 8), { 1, 2, 3, 4, 9 })
	assertEquals(RemoveRangeHelper({ 1, 2, 3, 4, 5, 6, 7, 8, 9 }, 5, 9), { 1, 2, 3, 4 })
	assertEquals(RemoveRangeHelper({ 1, 2, 3, 4, 5, 6, 7, 8, 9 }, 1, 2), { 3, 4, 5, 6, 7, 8, 9 })
end

function TestTable:TestInsertMultiple()
	local function Helper(tbl, index, ...)
		Table.InsertMultipleAt(tbl, index, ...)
		return tbl
	end

	assertEquals(Helper({ 1, 2, 3, 4, 5 }, 1, -1, -2), { -1, -2, 1, 2, 3, 4, 5 })
	assertEquals(Helper({ 1, 2, 3, 4, 5 }, 3, -1, -2), { 1, 2, -1, -2, 3, 4, 5 })
	assertEquals(Helper({ 1, 2, 3, 4, 5 }, 5, -1, -2), { 1, 2, 3, 4, -1, -2, 5 })
	assertEquals(Helper({ 1, 2, 3, 4, 5 }, 6, -1, -2), { 1, 2, 3, 4, 5, -1, -2 })
end

function TestTable:TestMove()
	local function Helper(tbl, fromIndex, toIndex)
		Table.Move(tbl, fromIndex, toIndex)
		return tbl
	end

	assertEquals(Helper({ 1, 2, 3, 4, 5 }, 1, 1), { 1, 2, 3, 4, 5 })
	assertEquals(Helper({ 1, 2, 3, 4, 5 }, 3, 3), { 1, 2, 3, 4, 5 })
	assertEquals(Helper({ 1, 2, 3, 4, 5 }, 5, 5), { 1, 2, 3, 4, 5 })

	assertEquals(Helper({ 1, 2, 3, 4, 5 }, 1, 2), { 2, 1, 3, 4, 5 })
	assertEquals(Helper({ 1, 2, 3, 4, 5 }, 1, 5), { 2, 3, 4, 5, 1 })
	assertEquals(Helper({ 1, 2, 3, 4, 5 }, 2, 4), { 1, 3, 4, 2, 5 })
	assertEquals(Helper({ 1, 2, 3, 4, 5 }, 2, 5), { 1, 3, 4, 5, 2 })

	assertEquals(Helper({ 1, 2, 3, 4, 5 }, 2, 1), { 2, 1, 3, 4, 5 })
	assertEquals(Helper({ 1, 2, 3, 4, 5 }, 5, 1), { 5, 1, 2, 3, 4 })
	assertEquals(Helper({ 1, 2, 3, 4, 5 }, 4, 2), { 1, 4, 2, 3, 5 })
	assertEquals(Helper({ 1, 2, 3, 4, 5 }, 5, 2), { 1, 5, 2, 3, 4 })
end

function TestTable:TestDiff()
	local function Helper(old, new)
		local result = { inserted = {}, removed = {} }
		if not Table.GetDiffOrdered(old, new, result.inserted, result.removed) then
			return nil
		end
		return result
	end

	assertEquals(Helper({ 1, 2, 3, 4, 5 }, { 5, 4, 3, 2, 1 }), nil)
	assertEquals(Helper({ 1, 2, 3, 4, 5 }, { 1, 2, 3, 5, 4 }), nil)
	assertEquals(Helper({ 1, 2, 3, 4, 4 }, { 1, 2, 3, 3, 4, 4 }), nil)
	assertEquals(Helper({ 1, 2, 3, 4, 4 }, { 1, 2, 3, 4, 4 }), { inserted = {}, removed = {} })
	assertEquals(Helper({ 1, 2, 3, 4, 5 }, { 1, 2, 3, 4, 5 }), { inserted = {}, removed = {} })

	assertEquals(Helper({ 1, 2, 3, 4, 5 }, { 2, 3, 4, 5 }), { inserted = {}, removed = { 1 } })
	assertEquals(Helper({ 1, 2, 3, 4, 5 }, { 1, 2, 3, 4 }), { inserted = {}, removed = { 5 } })
	assertEquals(Helper({ 1, 2, 3, 4, 5 }, { 1, 2, 3, 5 }), { inserted = {}, removed = { 4 } })
	assertEquals(Helper({ 1, 2, 3, 4, 5 }, { 1, 5 }), { inserted = {}, removed = { 2, 3, 4 } })

	assertEquals(Helper({ 1, 2, 3, 4, 5 }, { 1, 2, 3, 4, 5, 6 }), { inserted = { 6 }, removed = {} })
	assertEquals(Helper({ 1, 2, 3, 4, 5 }, { 1, 2, 3, 6, 4, 5 }), { inserted = { 4 }, removed = {} })
	assertEquals(Helper({ 1, 2, 3, 4, 5 }, { 6, 1, 2, 3, 4, 5 }), { inserted = { 1 }, removed = {} })
	assertEquals(Helper({ 1, 2, 3, 4, 5 }, { 6, 1, 2, 7, 3, 4, 5 }), { inserted = { 1, 4 }, removed = {} })

	assertEquals(Helper({ 1, 2, 3, 4, 5 }, { 6, 1, 2, 4, 5 }), { inserted = { 1 }, removed = { 3 } })
	assertEquals(Helper({ 1, 2, 3, 4, 5 }, { 6, 7 }), { inserted = { 1, 2 }, removed = { 1, 2, 3, 4, 5 } })
	assertEquals(Helper({ 1, 2, 3, 4, 5 }, { 6, 5, 7 }), { inserted = { 1, 3 }, removed = { 1, 2, 3, 4 } })
end

function TestTable:TestCommonValues()
	local function Helper(tbls)
		local result = {}
		Table.GetCommonValuesSorted(tbls, result)
		return result
	end

	assertEquals(Helper({{1, 2, 3}, {0}}), {})
	assertEquals(Helper({{1, 2, 3}, {0, 2, 3, 4}}), {2, 3})
	assertEquals(Helper({{1, 2, 3}, {0}, {2, 3}}), {})
	assertEquals(Helper({{1, 2, 3}, {0, 2, 3, 4}, {-1, 0, 2, 8, 9}}), {2})
end
