local TSM, Locals = ... ---@type TSM, table<string,table<string,any>>
local LibTSMUtil = TSM.LibTSMUtil
local TempTable = LibTSMUtil:Include("BaseType.TempTable")



-- ============================================================================
-- Tests
-- ============================================================================

TestTempTable = {}

local function TempTableIsReleased(tbl)
	return Locals["LibTSMUtil.BaseType.TempTable"].private.state[tbl] == nil
end

local function AllTempTablesReleased()
	return next(Locals["LibTSMUtil.BaseType.TempTable"].private.state) == nil
end

function TestTempTable:TearDown()
	for tbl in pairs(Locals["LibTSMUtil.BaseType.TempTable"].private.state) do
		TempTable.Release(tbl)
	end
end

function TestTempTable:TestAcquireRelease()
	local tbl1 = TempTable.Acquire()
	assertEquals(tbl1, {})
	assertFalse(TempTableIsReleased(tbl1))
	TempTable.Release(tbl1)
	assertTrue(TempTableIsReleased(tbl1))

	local tbl2 = TempTable.Acquire(1, 2, 3)
	assertEquals(tbl2, {1, 2, 3})
	assertFalse(TempTableIsReleased(tbl2))
	TempTable.Release(tbl2)
	assertTrue(TempTableIsReleased(tbl2))

	local tbl3 = TempTable.Acquire(1, 2, 3)
	assertEquals(tbl3, {1, 2, 3})
	assertFalse(TempTableIsReleased(tbl3))
	assertEquals({TempTable.UnpackAndRelease(tbl3)}, {1, 2, 3})
	assertTrue(TempTableIsReleased(tbl3))

	local tbl4 = TempTable.Acquire(1, 2, 3)
	assertEquals(tbl4, {1, 2, 3})
	assertFalse(TempTableIsReleased(tbl4))
	assertEquals(TempTable.ConcatAndRelease(tbl4, ","), "1,2,3")
	assertTrue(TempTableIsReleased(tbl4))

	assertTrue(AllTempTablesReleased())
end

function TestTempTable:TestIterator()
	local tbl1 = TempTable.Acquire(1, 2, 3)
	local iterResult1 = {}
	for _, v in TempTable.Iterator(tbl1) do
		tinsert(iterResult1, {v})
	end
	assertEquals(iterResult1, {{1}, {2}, {3}})
	assertTrue(TempTableIsReleased(tbl1))

	local tbl2 = TempTable.Acquire(1, 2, 3, 4)
	local iterResult2 = {}
	for _, v1, v2 in TempTable.Iterator(tbl2, 2) do
		tinsert(iterResult2, {v1, v2})
	end
	assertEquals(iterResult2, {{1, 2}, {3, 4}})
	assertTrue(TempTableIsReleased(tbl2))

	assertTrue(AllTempTablesReleased())
end

function TestTempTable:TestReleaseErrors()
	local tbl1 = TempTable.Acquire()
	TempTable.Release(tbl1)

	-- Double release
	assertErrorMsgContains("Invalid table", function() TempTable.Release(tbl1) end)

	-- Access after release
	assertErrorMsgContains("Attempt to access temp table after release", function() return tbl1.x end)
	assertErrorMsgContains("Attempt to access temp table after release", function() tbl1.x = 2 end)

	assertTrue(AllTempTablesReleased())
end

function TestTempTable:TestOwnership()
	local OWNER1 = {}
	local OWNER2 = {}

	local tbl1 = TempTable.AcquireWithOwner(OWNER1)
	TempTable.Release(tbl1)
	assertTrue(TempTableIsReleased(tbl1))
	TempTable.ReleaseAllOwned(OWNER1)

	local tbl2 = TempTable.AcquireWithOwner(OWNER1)
	local tbl3 = TempTable.AcquireWithOwner(OWNER1)
	local tbl4 = TempTable.AcquireWithOwner(OWNER2)
	local tbl5 = TempTable.AcquireWithOwner(OWNER2)
	TempTable.ReleaseAllOwned(OWNER1)
	assertTrue(TempTableIsReleased(tbl2))
	assertTrue(TempTableIsReleased(tbl3))
	assertFalse(TempTableIsReleased(tbl4))
	assertFalse(TempTableIsReleased(tbl5))

	TempTable.Release(tbl4)
	assertTrue(TempTableIsReleased(tbl4))
	TempTable.ReleaseAllOwned(OWNER2)
	assertTrue(TempTableIsReleased(tbl5))

	assertTrue(AllTempTablesReleased())
end

function TestTempTable:TestAcquireTooMany()
	local OWNER = {}
	for _ = 1, Locals["LibTSMUtil.BaseType.TempTable"].MAX_NUM_TABLES do
		local tbl = TempTable.Acquire()
		assertNotNil(tbl)
		TempTable.TakeOwnership(tbl, OWNER)
	end
	assertErrorMsgContains("Could not acquire temp table", function() TempTable.Acquire() end)
	TempTable.ReleaseAllOwned(OWNER)
	assertTrue(AllTempTablesReleased())
end
