local TSM, Locals = ... ---@type TSM, table<string,table<string,any>>
local LibTSMUtil = TSM.LibTSMUtil
local Iterator = LibTSMUtil:Include("BaseType.Iterator")



-- ============================================================================
-- Tests
-- ============================================================================

TestIterator = {}

local function CreateIter(...)
	local iter = Iterator.Acquire(...)
	assertNotNil(Locals["LibTSMUtil.BaseType.Iterator"].private.objectPool._state[iter])
	return iter
end

local function CreateFilteredIter(...)
	return CreateIter(...)
		:Filter(function(_, value) return value % 2 == 0 end)
end

local function CreateMappedIter(multiple, ...)
	return CreateIter(...)
		:SetMapFunc(function(_, value) return value * multiple end)
end

local function CheckIterFree(iter)
	assertEquals(Locals["LibTSMUtil.BaseType.Iterator"].private.context[iter], {filterFuncs={}, extraArgs={}})
	assertNil(Locals["LibTSMUtil.BaseType.Iterator"].private.objectPool._state[iter])
end

function TestIterator:TestFiltered()
	local iter1 = CreateFilteredIter(ipairs({7, 6, 5, 4, 3, 2, 1}))
	local result1 = {}
	for i, v, extra in iter1 do
		assertNil(extra)
		tinsert(result1, {i, v})
	end
	assertEquals(result1, {
		{2, 6},
		{4, 4},
		{6, 2},
	})
	CheckIterFree(iter1)

	local iter2 = CreateFilteredIter(pairs({7, 6, 5, 4, 3, 2, 1}))
	local result2 = {}
	for k, v, extra in iter2 do
		assertNil(extra)
		result2[k] = v
	end
	assertEquals(result2, {
		[2] = 6,
		[4] = 4,
		[6] = 2,
	})
	CheckIterFree(iter2)

	local iter3 = CreateFilteredIter(ipairs({7, 3}))
	local result3 = {}
	for i, v, extra in iter3 do
		assertNil(extra)
		tinsert(result3, i)
		tinsert(result3, v)
	end
	assertEquals(result3, {})
	CheckIterFree(iter3)

	local iter4 = CreateFilteredIter(ipairs({}))
	local result4 = {}
	for i, v, extra in iter4 do
		assertNil(extra)
		tinsert(result4, i)
		tinsert(result4, v)
	end
	assertEquals(result4, {})
	CheckIterFree(iter4)
end

function TestIterator:TestMap()
	local iter1 = CreateMappedIter(2, ipairs({1, 2, 3}))
	local result1 = {}
	for i, v, extra in iter1 do
		assertNil(extra)
		tinsert(result1, {i, v})
	end
	assertEquals(result1, {
		{1, 2},
		{2, 4},
		{3, 6},
	})
	CheckIterFree(iter1)

	local iter2 = CreateMappedIter(3, ipairs({1, 2, 3}))
	local result2 = {}
	for i, v, extra in iter2 do
		assertNil(extra)
		tinsert(result2, {i, v})
	end
	assertEquals(result2, {
		{1, 3},
		{2, 6},
		{3, 9},
	})
	CheckIterFree(iter2)
end

function TestIterator:TestManual()
	local iter1 = CreateIter(ipairs({7, 6}))
	assertEquals({iter1:GetValueAndRelease()}, {1, 7})
	CheckIterFree(iter1)

	local iter2 = CreateIter(ipairs({}))
	assertNil(iter2:GetValueAndRelease())
	CheckIterFree(iter2)

	local iter3 = CreateFilteredIter(ipairs({7, 6, 5}))
	assertEquals({iter3:GetValueAndRelease()}, {2, 6})
	CheckIterFree(iter3)

	local iter4 = CreateFilteredIter(ipairs({7, 6, 5, 4}))
	assertEquals({iter4()}, {2, 6})
	assertEquals({iter4()}, {4, 4})
	iter4:Release()
	CheckIterFree(iter4)
end

function TestIterator:TestCleanup()
	local iter1 = CreateIter(ipairs({7, 6}))
	local numCalls1 = 0
	iter1:SetCleanupFunc(function() numCalls1 = numCalls1 + 1 end)
	iter1()
	assertEquals(numCalls1, 0)
	iter1:Release()
	assertEquals(numCalls1, 1)
	CheckIterFree(iter1)

	local iter2 = CreateIter(ipairs({7, 6}))
	local numCalls2 = 0
	iter2:SetCleanupFunc(function() numCalls2 = numCalls2 + 1 end)
	for _ in iter2 do
		assertEquals(numCalls2, 0)
	end
	assertEquals(numCalls2, 1)
	CheckIterFree(iter2)

	local iter3 = CreateIter(ipairs({7, 6}))
	local numCalls3 = 0
	iter3:SetCleanupFunc(function() numCalls3 = numCalls3 + 1 end)
	iter3:Release()
	assertEquals(numCalls3, 1)
	CheckIterFree(iter3)
end

function TestIterator:TestCustomFunc()
	local ITER_OBJ = {}
	local function IterFunc(obj, key, ...)
		assertEquals(obj, ITER_OBJ)
		if key == 0 then
			return 1, "a", ...
		elseif key == 1 then
			return 2, "b", ...
		else
			return
		end
	end

	local iter1 = CreateIter(IterFunc, ITER_OBJ, 0, "extra1", "extra2")
	assertEquals({iter1()}, {1, "a", "extra1", "extra2"})
	assertEquals({iter1()}, {2, "b", "extra1", "extra2"})
	assertEquals({iter1()}, {})
	CheckIterFree(iter1)
end

function TestIterator:TestJoinedString()
	local iter1 = CreateIter(ipairs({"c", "b", "a"}))
	assertEquals(iter1:ToJoinedValueString(","), "c,b,a")
	CheckIterFree(iter1)

	local iter2 = CreateIter(ipairs({"c", "b", "a"}))
	assertEquals(iter2:ToJoinedValueString(",", true), "a,b,c")
	CheckIterFree(iter2)
end
