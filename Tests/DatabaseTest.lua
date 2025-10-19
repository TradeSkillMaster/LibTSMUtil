---@diagnostic disable: invisible
local TSM, Locals = ... ---@type TSM, table<string,table<string,any>>
local LibTSMUtil = TSM.LibTSMUtil
local Database = LibTSMUtil:Include("Database")
local SmartMap = LibTSMUtil:IncludeClassType("SmartMap")
local EnumType = LibTSMUtil:Include("BaseType.EnumType")
local Hash = LibTSMUtil:Include("Util.Hash")
local RESULT_STATE = Locals["LibTSMUtil.Database.Type.Query"].RESULT_STATE
local OPTIMIZAITON_RESULT = Locals["LibTSMUtil.Database.Type.Query"].OPTIMIZAITON_RESULT



-- ============================================================================
-- Tests
-- ============================================================================

TestDatabase = {}

function TestDatabase:SetUp()
	wipe(Locals["LibTSMUtil.BaseType.ObjectPool"].private.instances)
	wipe(Locals["LibTSMUtil.Database.Database"].private.dbByNameLookup)
	LibTSMUtil._moduleContext["Database"].moduleLoadFunc()
end

function TestDatabase:TestInsertRow()
	-- create the DB
	local db = Database.NewSchema("TEST")
		:AddStringField("str")
		:AddNumberField("num")
		:Commit()

	-- add a row
	db:InsertRow("This is a test", 2)
	assertEquals(db:GetRowFields(db._uuids[1], "str"), "This is a test")
	assertEquals(db:GetRowFields(db._uuids[1], "num"), 2)
	assertEquals(#db._data / db._numStoredFields, 1)

	-- add a second row
	db:InsertRow("This is a second test", 3)
	assertEquals(db:GetRowFields(db._uuids[2], "str"), "This is a second test")
	assertEquals(db:GetRowFields(db._uuids[2], "num"), 3)
	assertEquals(#db._data / db._numStoredFields, 2)
end

function TestDatabase:TestEmptyQuery()
	-- create the DB
	local db = Database.NewSchema("TEST")
		:AddNumberField("rowNum")
		:AddStringField("text")
		:Commit()

	-- add two rows
	db:InsertRow(1, "This is a test")
	db:InsertRow(2, "This is a second test")

	local query = db:NewOwnedQuery()
	assertEquals(query:Count(), 2)
	local foundRows = {}
	for _, rowNum in query:Iterator("rowNum") do
		assertTrue(query._optimization.result == OPTIMIZAITON_RESULT.NONE)
		assertTrue(rowNum == 1 or rowNum == 2)
		foundRows[rowNum] = (foundRows[rowNum] or 0) + 1
	end
	assertEquals(foundRows[1], 1)
	assertEquals(foundRows[2], 1)
	query:Release()
end

function TestDatabase:TestEqualQuery()
	-- create the DB
	local db = Database.NewSchema("TEST")
		:AddNumberField("rowNum")
		:AddStringField("text")
		:Commit()

	-- add two rows
	db:InsertRow(1, "This is a test")
	db:InsertRow(2, "This is a second test")

	local query = db:NewOwnedQuery()
		:Equal("text", "This is a test")
	assertEquals(query:Count(), 1)
	local found = false
	for _, rowNum in query:Iterator("rowNum") do
		assertTrue(query._optimization.result == OPTIMIZAITON_RESULT.NONE)
		assertEquals(rowNum, 1)
		assert(not found)
		found = true
	end
	query:Release()
end

function TestDatabase:TestSortQuery()
	-- create the DB
	local db = Database.NewSchema("TEST")
		:AddNumberField("rowNum")
		:AddNumberField("num")
		:Commit()

	-- add some rows
	db:InsertRow(1, 22)
	db:InsertRow(2, 11)
	db:InsertRow(3, 33)
	db:InsertRow(4, math.huge * 0)

	-- ascending order
	local query = db:NewOwnedQuery():OrderBy("num", true)
	local expected = { 2, 1, 3, 4 }
	local expectedIndex = 0
	for _, rowNum in query:Iterator("rowNum") do
		assertTrue(query._optimization.result == OPTIMIZAITON_RESULT.NONE)
		expectedIndex = expectedIndex + 1
		assertEquals(rowNum, expected[expectedIndex])
	end
	assertEquals(expectedIndex, #expected)
	query:Release()

	-- descending order
	local query = db:NewOwnedQuery()
		:OrderBy("num", false)
	local expected = { 3, 1, 2, 4 }
	local expectedIndex = 0
	for _, rowNum in query:Iterator("rowNum") do
		assertTrue(query._optimization.result == OPTIMIZAITON_RESULT.NONE)
		expectedIndex = expectedIndex + 1
		assertEquals(rowNum, expected[expectedIndex])
	end
	assertEquals(expectedIndex, #expected)
	query:Release()
end

function TestDatabase:TestMultipleSortQuery()
	-- create the DB
	local db = Database.NewSchema("TEST")
		:AddNumberField("rowNum")
		:AddNumberField("num1")
		:AddNumberField("num2")
		:Commit()

	-- add three rows
	db:InsertRow(1, 22, 6)
	db:InsertRow(2, 22, 5)
	db:InsertRow(3, 40, 1)

	-- ascending order
	local query = db:NewOwnedQuery()
		:OrderBy("num1", true)
		:OrderBy("num2", true)
	local expectedNum1 = { 5, 6, 1 }
	local index1 = 0
	for _, num2 in query:Iterator("num2") do
		index1 = index1 + 1
		assertTrue(query._optimization.result == OPTIMIZAITON_RESULT.NONE)
		assertEquals(num2, expectedNum1[index1])
	end
	query:Release()

	-- descending order
	local query = db:NewOwnedQuery()
		:OrderBy("num1", false)
		:OrderBy("num2", false)
	local index2 = 0
	local expectedNum2 = { 1, 6, 5 }
	for _, num2 in query:Iterator("num2") do
		index2 = index2 + 1
		assertTrue(query._optimization.result == OPTIMIZAITON_RESULT.NONE)
		assertEquals(num2, expectedNum2[index2])
	end
	query:Release()
end

function TestDatabase:TestQueryUpdateCallback()
	-- create the DB
	local db = Database.NewSchema("TEST")
		:AddNumberField("num1")
		:AddNumberField("num2")
		:Commit()

	-- add a row
	db:InsertRow(22, 32)

	-- create a query and register a callback
	local numUpdateCallbacks = 0
	local query = db:NewOwnedQuery()
	query:SetUpdateCallback(function(self)
		assertTrue(self == query)
		numUpdateCallbacks = numUpdateCallbacks + 1
	end)
	local uuid = query:GetFirstResultWithUUID()
	local query2 = db:NewOwnedQuery()
	local uuid2 = query2:GetFirstResultWithUUID()

	-- don't make any changes
	numUpdateCallbacks = 0
	assertEquals(numUpdateCallbacks, 0)
	assertEquals(query:GetFirstResult("num1"), 22)
	assertEquals(query:GetFirstResult("num2"), 32)
	assertEquals(query2:GetFirstResult("num1"), 22)
	assertEquals(query2:GetFirstResult("num2"), 32)

	-- update the row to the same value
	numUpdateCallbacks = 0
	db:UpdateRow(uuid, "num1", 22)
	assertEquals(numUpdateCallbacks, 0)
	assertEquals(query:GetFirstResult("num1"), 22)
	assertEquals(query:GetFirstResult("num2"), 32)
	assertEquals(query2:GetFirstResult("num1"), 22)
	assertEquals(query2:GetFirstResult("num2"), 32)

	-- update the row to a different value
	numUpdateCallbacks = 0
	db:UpdateRow(uuid, "num1", 24)
	assertEquals(numUpdateCallbacks, 1)
	assertEquals(query:GetFirstResult("num1"), 24)
	assertEquals(query:GetFirstResult("num2"), 32)
	assertEquals(query2:GetFirstResult("num1"), 24)
	assertEquals(query2:GetFirstResult("num2"), 32)

	-- update both fields
	numUpdateCallbacks = 0
	for _ in db:WithQueryUpdatesPaused() do
		db:UpdateRow(uuid, "num1", 24)
		db:UpdateRow(uuid, "num2", -100)
	end
	assertEquals(numUpdateCallbacks, 1)
	assertEquals(query:GetFirstResult("num1"), 24)
	assertEquals(query:GetFirstResult("num2"), -100)
	assertEquals(query2:GetFirstResult("num1"), 24)
	assertEquals(query2:GetFirstResult("num2"), -100)

	-- update each field using a different row object
	numUpdateCallbacks = 0
	db:UpdateRow(uuid, "num1", -1)
	db:UpdateRow(uuid2, "num2", -2)
	assertEquals(numUpdateCallbacks, 2)
	assertEquals(query:GetFirstResult("num1"), -1)
	assertEquals(query:GetFirstResult("num2"), -2)
	assertEquals(query2:GetFirstResult("num1"), -1)
	assertEquals(query2:GetFirstResult("num2"), -2)

	query:Release()
end

function TestDatabase:TestQueryAndOr()
	-- create the DB
	local db = Database.NewSchema("TEST")
		:AddNumberField("rowNum")
		:AddNumberField("num1")
		:AddNumberField("num2")
		:AddNumberField("num3")
		:Commit()

	-- add some rows
	db:InsertRow(1, 1, 2, 3)
	db:InsertRow(2, 11, 12, 13)

	-- (num1 == 1 and num3 == 13) or (num2 == 2 and num3 == 3)
	local query1 = db:NewOwnedQuery()
		:Or()
			:And()
				:Equal("num1", 1)
				:Equal("num3", 13)
			:End()
			:And()
				:Equal("num2", 2)
				:Equal("num3", 3)
			:End()
		:End()
	assertEquals(query1:Count(), 1)
	local expectedIndex = 0
	for _, rowNum in query1:Iterator("rowNum") do
		assertTrue(query1._optimization.result == OPTIMIZAITON_RESULT.NONE)
		expectedIndex = expectedIndex + 1
		assertEquals(rowNum, 1)
	end
	assertEquals(expectedIndex, 1)
	query1:Release()

	-- (num1 == 1 or num1 == 11) and (num2 == 2 or num2 == 12)
	local query2 = db:NewOwnedQuery()
		:And()
			:Or()
				:Equal("num1", 1)
				:Equal("num1", 11)
			:End()
			:Or()
				:Equal("num2", 4)
				:Equal("num2", 5)
				:Equal("num2", 2)
			:End()
			:Or()
				:Equal("num3", 3)
			:End()
		:End()
	assertEquals(query2:Count(), 1)
	local expectedIndex = 0
	for _, rowNum in query2:Iterator("rowNum") do
		assertTrue(query2._optimization.result == OPTIMIZAITON_RESULT.NONE)
		expectedIndex = expectedIndex + 1
		assertEquals(rowNum, 1)
	end
	assertEquals(expectedIndex, 1)
	query2:Release()
end

function TestDatabase:TestQueryComparisons()
	-- create the DB
	local db = Database.NewSchema("TEST")
		:AddNumberField("num")
		:Commit()

	-- add some rows
	db:InsertRow(1)
	db:InsertRow(2)
	db:InsertRow(3)

	local query1 = db:NewOwnedQuery()
		:LessThan("num", 2)
	assertEquals(query1:Count(), 1)
	local expectedIndex = 0
	for _, num in query1:Iterator("num") do
		assertTrue(query1._optimization.result == OPTIMIZAITON_RESULT.NONE)
		expectedIndex = expectedIndex + 1
		assertEquals(num, 1)
	end
	assertEquals(expectedIndex, 1)
	query1:Release()

	local query2 = db:NewOwnedQuery()
		:GreaterThan("num", 2)
	assertEquals(query2:Count(), 1)
	local expectedIndex = 0
	for _, num in query2:Iterator("num") do
		assertTrue(query2._optimization.result == OPTIMIZAITON_RESULT.NONE)
		expectedIndex = expectedIndex + 1
		assertEquals(num, 3)
	end
	assertEquals(expectedIndex, 1)
	query2:Release()

	local query3 = db:NewOwnedQuery()
		:LessThanOrEqual("num", 2)
		:OrderBy("num", true)
	assertEquals(query3:Count(), 2)
	local expected = { 1, 2 }
	local expectedIndex = 0
	for _, num in query3:Iterator("num") do
		assertTrue(query3._optimization.result == OPTIMIZAITON_RESULT.NONE)
		expectedIndex = expectedIndex + 1
		assertEquals(num, expected[expectedIndex])
	end
	assertEquals(expectedIndex, #expected)
	query3:Release()

	local query4 = db:NewOwnedQuery()
		:GreaterThanOrEqual("num", 2)
		:OrderBy("num", true)
	assertEquals(query4:Count(), 2)
	local expected = { 2, 3 }
	local expectedIndex = 0
	for _, num in query4:Iterator("num") do
		assertTrue(query4._optimization.result == OPTIMIZAITON_RESULT.NONE)
		expectedIndex = expectedIndex + 1
		assertEquals(num, expected[expectedIndex])
	end
	assertEquals(expectedIndex, #expected)
	query4:Release()

	local query5 = db:NewOwnedQuery()
		:GreaterThanOrEqual("num", 2)
		:LessThan("num", 3)
	assertEquals(query5:Count(), 1)
	local expectedIndex = 0
	for _, num in query5:Iterator("num") do
		assertTrue(query5._optimization.result == OPTIMIZAITON_RESULT.NONE)
		expectedIndex = expectedIndex + 1
		assertEquals(num, 2)
	end
	assertEquals(expectedIndex, 1)
	query5:Release()
end

function TestDatabase:TestOtherField()
	-- create the DB
	local db = Database.NewSchema("TEST")
		:AddNumberField("num")
		:AddNumberField("num2")
		:Commit()

	-- add some rows
	db:InsertRow(1, 1)
	db:InsertRow(2, 1)
	db:InsertRow(3, 3)

	local query = db:NewOwnedQuery()
		:Equal("num", Database.OtherFieldQueryParam("num2"))
		:OrderBy("num", true)
	local expected = { 1, 3 }
	assertEquals(query:Count(), #expected)
	local expectedIndex = 0
	for _, num in query:Iterator("num") do
		assertTrue(query._optimization.result == OPTIMIZAITON_RESULT.NONE)
		expectedIndex = expectedIndex + 1
		assertEquals(num, expected[expectedIndex])
	end
	assertEquals(expectedIndex, #expected)
	query:Release()

	local query = db:NewOwnedQuery()
		:GreaterThan("num", Database.OtherFieldQueryParam("num2"))
	local expected = { 2 }
	assertEquals(query:Count(), #expected)
	local expectedIndex = 0
	for _, num in query:Iterator("num") do
		assertTrue(query._optimization.result == OPTIMIZAITON_RESULT.NONE)
		expectedIndex = expectedIndex + 1
		assertEquals(num, expected[expectedIndex])
	end
	assertEquals(expectedIndex, #expected)
	query:Release()
end

function TestDatabase:TestFieldIndex()
	-- create the DB
	local db = Database.NewSchema("TEST")
		:AddNumberField("rowNum")
		:AddNumberField("num1")
		:AddNumberField("num2")
		:AddIndex("num1")
		:AddIndex("num2")
		:Commit()

	-- add some rows
	db:InsertRow(1, 1, 10)
	db:InsertRow(2, 3, 20)
	db:InsertRow(3, 2, 20)
	db:InsertRow(4, 3, 30)

	local query1 = db:NewOwnedQuery()
		:Equal("num1", 3)
	local expected = { 4, 2 }
	assertEquals(query1:Count(), #expected)
	local expectedIndex = 0
	for _, rowNum in query1:Iterator("rowNum") do
		assertTrue(query1._optimization.result == OPTIMIZAITON_RESULT.INDEX)
		assertEquals(query1._optimization.field, "num1")
		expectedIndex = expectedIndex + 1
		assertEquals(rowNum, expected[expectedIndex])
	end
	assertEquals(expectedIndex, #expected)
	query1:Release()

	local query2 = db:NewOwnedQuery()
		:Equal("num1", 3)
		:OrderBy("num2", true)
	assertEquals(query2:Count(), 2)
	local expected = { 2, 4 }
	assertEquals(query2:Count(), #expected)
	local expectedIndex = 0
	for _, rowNum in query2:Iterator("rowNum") do
		assertTrue(query2._optimization.result == OPTIMIZAITON_RESULT.INDEX)
		assertEquals(query2._optimization.field, "num1")
		expectedIndex = expectedIndex + 1
		assertEquals(rowNum, expected[expectedIndex])
	end
	assertEquals(expectedIndex, #expected)
	query2:Release()

	local query3 = db:NewOwnedQuery()
		:Equal("num1", 3)
		:OrderBy("num2", false)
	local expected = { 4, 2 }
	assertEquals(query3:Count(), #expected)
	local expectedIndex = 0
	for _, rowNum in query3:Iterator("rowNum") do
		assertTrue(query3._optimization.result == OPTIMIZAITON_RESULT.INDEX)
		assertEquals(query3._optimization.field, "num1")
		expectedIndex = expectedIndex + 1
		assertEquals(rowNum, expected[expectedIndex])
	end
	assertEquals(expectedIndex, #expected)
	query3:Release()

	local query4 = db:NewOwnedQuery()
		:Equal("num1", 3)
		:OrderBy("num1", true)
	local expected = { 4, 2 }
	assertEquals(query4:Count(), #expected)
	local expectedIndex = 0
	for _, rowNum in query4:Iterator("rowNum") do
		assertTrue(query4._optimization.result == OPTIMIZAITON_RESULT.INDEX_AND_ORDER_BY)
		assertEquals(query4._optimization.field, "num1")
		expectedIndex = expectedIndex + 1
		assertEquals(rowNum, expected[expectedIndex])
	end
	assertEquals(expectedIndex, #expected)
	query4:Release()

	local query5 = db:NewOwnedQuery()
		:Equal("num1", 3)
		:GreaterThan("num2", 25)
	local expected = { 4 }
	assertEquals(query5:Count(), #expected)
	local expectedIndex = 0
	for _, rowNum in query5:Iterator("rowNum") do
		assertTrue(query5._optimization.result == OPTIMIZAITON_RESULT.INDEX)
		assertEquals(query5._optimization.field, "num1")
		expectedIndex = expectedIndex + 1
		assertEquals(rowNum, expected[expectedIndex])
	end
	assertEquals(expectedIndex, #expected)
	query5:Release()

	local query6 = db:NewOwnedQuery()
		:OrderBy("num1", true)
	local expected = { 1, 3, 4, 2 }
	assertEquals(query6:Count(), #expected)
	local expectedIndex = 0
	for _, rowNum in query6:Iterator("rowNum") do
		assertTrue(query6._optimization.result == OPTIMIZAITON_RESULT.ORDER_BY)
		assertEquals(query6._optimization.field, "num1")
		expectedIndex = expectedIndex + 1
		assertEquals(rowNum, expected[expectedIndex])
	end
	assertEquals(expectedIndex, #expected)
	query6:Release()

	local query7 = db:NewOwnedQuery()
		:Equal("num1", -1)
	assertEquals(query7:Count(), 0)
	query7:Release()

	local query8 = db:NewOwnedQuery()
		:GreaterThanOrEqual("num2", 25)
	local expected = { 4 }
	assertEquals(query8:Count(), #expected)
	local expectedIndex = 0
	for _, rowNum in query8:Iterator("rowNum") do
		assertTrue(query8._optimization.result == OPTIMIZAITON_RESULT.INDEX)
		assertEquals(query8._optimization.field, "num2")
		expectedIndex = expectedIndex + 1
		assertEquals(rowNum, expected[expectedIndex])
	end
	assertEquals(expectedIndex, #expected)
	query8:Release()
end

function TestDatabase:TestFieldUnique()
	-- create the DB
	local db = Database.NewSchema("TEST")
		:AddNumberField("rowNum")
		:AddUniqueNumberField("uniqueNum")
		:AddNumberField("num2")
		:AddIndex("num2")
		:Commit()

	-- add some rows
	db:InsertRow(1, 1, 10)
	db:InsertRow(2, 3, 20)
	db:InsertRow(3, 2, 20)

	local query1 = db:NewOwnedQuery()
		:Equal("uniqueNum", 3)
	local expected = { 2 }
	assertEquals(query1:Count(), #expected)
	local expectedIndex = 0
	for _, rowNum in query1:Iterator("rowNum") do
		assertTrue(query1._optimization.result == OPTIMIZAITON_RESULT.UNIQUE)
		assertEquals(query1._optimization.field, "uniqueNum")
		expectedIndex = expectedIndex + 1
		assertEquals(rowNum, expected[expectedIndex])
	end
	assertEquals(expectedIndex, #expected)
	query1:Release()

	local query2 = db:NewOwnedQuery()
		:Equal("uniqueNum", -1)
	assertEquals(query2:Count(), 0)
	query2:Release()

	local query3 = db:NewOwnedQuery()
		:Equal("num2", 20)
		:OrderBy("uniqueNum", true)
	local expected = { 3, 2 }
	assertEquals(query3:Count(), #expected)
	local expectedIndex = 0
	for _, rowNum in query3:Iterator("rowNum") do
		assertTrue(query3._optimization.result == OPTIMIZAITON_RESULT.INDEX)
		assertEquals(query3._optimization.field, "num2")
		expectedIndex = expectedIndex + 1
		assertEquals(rowNum, expected[expectedIndex])
	end
	assertEquals(expectedIndex, #expected)
	query3:Release()

	local query4 = db:NewOwnedQuery()
		:OrderBy("uniqueNum", true)
	local expected = { 1, 3, 2 }
	assertEquals(query4:Count(), #expected)
	local expectedIndex = 0
	for _, rowNum in query4:Iterator("rowNum") do
		assertTrue(query4._optimization.result == OPTIMIZAITON_RESULT.NONE)
		expectedIndex = expectedIndex + 1
		assertEquals(rowNum, expected[expectedIndex])
	end
	assertEquals(expectedIndex, #expected)
	query4:Release()

	local query5 = db:NewOwnedQuery()
		:GreaterThanOrEqual("uniqueNum", 2)
		:OrderBy("rowNum", true)
	local expected = { 2, 3 }
	assertEquals(query5:Count(), #expected)
	local expectedIndex = 0
	for _, rowNum in query5:Iterator("rowNum") do
		assertTrue(query5._optimization.result == OPTIMIZAITON_RESULT.NONE)
		expectedIndex = expectedIndex + 1
		assertEquals(rowNum, expected[expectedIndex])
	end
	assertEquals(expectedIndex, #expected)
	query5:Release()

	db:UpdateRow(db:GetUniqueRow("uniqueNum", 1), "rowNum", 1)
	local query6 = db:NewOwnedQuery()
		:Equal("num2", 20)
		:OrderBy("uniqueNum", true)
	local expected = { 3, 2 }
	assertEquals(query6:Count(), #expected)
	local expectedIndex = 0
	for _, rowNum in query6:Iterator("rowNum") do
		assertTrue(query6._optimization.result == OPTIMIZAITON_RESULT.INDEX)
		assertEquals(query6._optimization.field, "num2")
		expectedIndex = expectedIndex + 1
		assertEquals(rowNum, expected[expectedIndex])
	end
	assertEquals(expectedIndex, #expected)
	query6:Release()

	db:UpdateRow(db:GetUniqueRow("uniqueNum", 1), "num2", 20)
	local query7 = db:NewOwnedQuery()
		:Equal("num2", 20)
		:OrderBy("uniqueNum", true)
	local expected = { 1, 3, 2 }
	assertEquals(query7:Count(), #expected)
	local expectedIndex = 0
	for _, rowNum in query7:Iterator("rowNum") do
		assertTrue(query7._optimization.result == OPTIMIZAITON_RESULT.INDEX)
		assertEquals(query7._optimization.field, "num2")
		expectedIndex = expectedIndex + 1
		assertEquals(rowNum, expected[expectedIndex])
	end
	assertEquals(expectedIndex, #expected)
	query7:Release()
end

function TestDatabase:TestBoundParams()
	-- create the DB
	local db = Database.NewSchema("TEST")
		:AddNumberField("rowNum")
		:AddNumberField("num1")
		:AddNumberField("num2")
		:Commit()

	-- add some rows
	db:InsertRow(1, 1, 10)
	db:InsertRow(2, 3, 20)
	db:InsertRow(3, 2, 20)
	db:InsertRow(4, 3, 30)

	local query1 = db:NewOwnedQuery()
		:Equal("num1", Database.BoundQueryParam())
		:And()
			:Equal("num2", Database.BoundQueryParam())
		:End()
		:BindParams(3, 30)
	local expected = {
		4,
	}
	assertEquals(query1:Count(), #expected)
	local expectedIndex = 0
	for _, rowNum in query1:Iterator("rowNum") do
		assertTrue(query1._optimization.result == OPTIMIZAITON_RESULT.NONE)
		expectedIndex = expectedIndex + 1
		assertEquals(rowNum, expected[expectedIndex])
	end
	assertEquals(expectedIndex, #expected)

	query1:BindParams(3, 20)
	local expected = {
		2,
	}
	assertEquals(query1:Count(), #expected)
	local expectedIndex = 0
	for _, rowNum in query1:Iterator("rowNum") do
		assertTrue(query1._optimization.result == OPTIMIZAITON_RESULT.NONE)
		expectedIndex = expectedIndex + 1
		assertEquals(rowNum, expected[expectedIndex])
	end
	assertEquals(expectedIndex, #expected)

	query1:Release()
end

function TestDatabase:TestDelete()
	-- create the DB
	local db = Database.NewSchema("TEST")
		:AddNumberField("rowNum")
		:AddNumberField("num1")
		:AddNumberField("num2")
		:Commit()

	-- add some rows
	db:InsertRow(1, 21, 1)
	db:InsertRow(2, 13, 2)
	db:InsertRow(3, 10, 3)
	db:InsertRow(4, 13, 4)

	-- remove a row
	local query = db:NewOwnedQuery()
		:Equal("rowNum", 2)
	db:DeleteRow(query:GetFirstResultWithUUID())
	query:Release()

	local query1 = db:NewOwnedQuery()
		:Equal("num1", 13)
	local expected = {
		4,
	}
	assertEquals(query1:Count(), #expected)
	local expectedIndex = 1
	for _, rowNum in query1:Iterator("rowNum") do
		assertTrue(query1._optimization.result == OPTIMIZAITON_RESULT.NONE)
		assertEquals(rowNum, expected[expectedIndex])
		expectedIndex = expectedIndex + 1
	end
	assertEquals(expectedIndex, #expected + 1)
	query1:Release()
end

function TestDatabase:TestLeftJoin()
	-- create the DBs
	local itemNameDB = Database.NewSchema("ITEM_NAME")
		:AddUniqueNumberField("itemId")
		:AddStringField("name")
		:Commit()
	local itemSaleDB = Database.NewSchema("ITEM_SALE")
		:AddNumberField("itemId")
		:AddNumberField("salePrice")
		:AddNumberField("timestamp")
		:AddIndex("itemId")
		:Commit()

	-- add some rows
	itemNameDB:InsertRow(1, "Item 1")
	itemNameDB:InsertRow(2, "Item 2")
	itemNameDB:InsertRow(3, "Item 3")
	itemSaleDB:InsertRow(1, 1000, 25)
	itemSaleDB:InsertRow(1, 1200, 30)
	itemSaleDB:InsertRow(1, 1400, 32)
	itemSaleDB:InsertRow(2, 5000, 27)
	itemSaleDB:InsertRow(2, 5000, 29)
	itemSaleDB:InsertRow(4, 5000, 31)

	local query = itemSaleDB:NewOwnedQuery()
		:LeftJoin(itemNameDB, "itemId")
		:OrderBy("timestamp", true)
	local expected = {
		{ timestamp = 25, name = "Item 1" },
		{ timestamp = 27, name = "Item 2" },
		{ timestamp = 29, name = "Item 2" },
		{ timestamp = 30, name = "Item 1" },
		{ timestamp = 31, name = nil },
		{ timestamp = 32, name = "Item 1" },
	}
	assertEquals(query:Count(), #expected)
	local expectedIndex = 0
	for _, timestamp, name in query:Iterator("timestamp", "name") do
		assertTrue(query._optimization.result == OPTIMIZAITON_RESULT.NONE)
		expectedIndex = expectedIndex + 1
		assertEquals(timestamp, expected[expectedIndex].timestamp)
		assertEquals(name, expected[expectedIndex].name)
	end
	assertEquals(expectedIndex, #expected)
	query:Release()

	local query = itemSaleDB:NewOwnedQuery()
		:LeftJoin(itemNameDB, "itemId")
		:Equal("itemId", 2)
		:OrderBy("timestamp", true)
	local expected = {
		{ timestamp = 27, name = "Item 2" },
		{ timestamp = 29, name = "Item 2" },
	}
	assertEquals(query:Count(), #expected)
	local expectedIndex = 0
	for _, timestamp, name in query:Iterator("timestamp", "name") do
		assertTrue(query._optimization.result == OPTIMIZAITON_RESULT.INDEX)
		expectedIndex = expectedIndex + 1
		assertEquals(timestamp, expected[expectedIndex].timestamp)
		assertEquals(name, expected[expectedIndex].name)
	end
	assertEquals(expectedIndex, #expected)
	query:Release()

	local query = itemSaleDB:NewOwnedQuery()
		:LeftJoin(itemNameDB, "itemId")
		:Equal("itemId", 3)
		:OrderBy("timestamp", true)
	local expected = {}
	assertEquals(query:Count(), #expected)
	query:Release()

	local query = itemSaleDB:NewOwnedQuery()
		:LeftJoin(itemNameDB, "itemId")
		:Equal("name", "Item 2")
		:OrderBy("timestamp", true)
	local expected = {
		{ timestamp = 27, name = "Item 2" },
		{ timestamp = 29, name = "Item 2" },
	}
	assertEquals(query:Count(), #expected)
	local expectedIndex = 0
	for _, timestamp, name in query:Iterator("timestamp", "name") do
		assertTrue(query._optimization.result == OPTIMIZAITON_RESULT.NONE)
		expectedIndex = expectedIndex + 1
		assertEquals(timestamp, expected[expectedIndex].timestamp)
		assertEquals(name, expected[expectedIndex].name)
	end
	assertEquals(expectedIndex, #expected)
	query:Release()

	local query = itemSaleDB:NewOwnedQuery()
		:LeftJoin(itemNameDB, "itemId")
		:IsNil("name")
		:OrderBy("timestamp", true)
	local expected = {
		{ timestamp = 31 }
	}
	assertEquals(query:Count(), #expected)
	local expectedIndex = 0
	for _,  name in query:Iterator("name") do
		assertTrue(query._optimization.result == OPTIMIZAITON_RESULT.NONE)
		expectedIndex = expectedIndex + 1
		assertEquals(name, expected[expectedIndex].name)
	end
	assertEquals(expectedIndex, #expected)
	query:Release()
end

function TestDatabase:TestInnerJoin()
	-- create the DBs
	local itemNameDB = Database.NewSchema("ITEM_NAME")
		:AddUniqueNumberField("itemId")
		:AddStringField("name")
		:Commit()
	local itemSaleDB = Database.NewSchema("ITEM_SALE")
		:AddNumberField("itemId")
		:AddNumberField("salePrice")
		:AddNumberField("timestamp")
		:AddIndex("itemId")
		:Commit()
	local itemPriceDB = Database.NewSchema("ITEM_PRICE")
		:AddUniqueNumberField("itemId")
		:AddNumberField("minBuyout")
		:AddNumberField("marketValue")
		:Commit()

	-- add some rows
	itemNameDB:InsertRow(1, "Item 1")
	itemNameDB:InsertRow(2, "Item 2")
	itemNameDB:InsertRow(3, "Item 3")
	itemSaleDB:InsertRow(1, 1000, 25)
	itemSaleDB:InsertRow(1, 1200, 30)
	itemSaleDB:InsertRow(1, 1400, 32)
	itemSaleDB:InsertRow(2, 5000, 27)
	itemSaleDB:InsertRow(2, 5000, 29)
	itemSaleDB:InsertRow(4, 5000, 31)
	itemPriceDB:InsertRow(3, 150, 300)
	itemPriceDB:InsertRow(4, 200, 250)

	local query = itemSaleDB:NewOwnedQuery()
		:InnerJoin(itemNameDB, "itemId")
		:OrderBy("timestamp", true)
	local expected = {
		{ timestamp = 25, name = "Item 1" },
		{ timestamp = 27, name = "Item 2" },
		{ timestamp = 29, name = "Item 2" },
		{ timestamp = 30, name = "Item 1" },
		{ timestamp = 32, name = "Item 1" },
	}
	assertEquals(query:Count(), #expected)
	local expectedIndex = 0
	for _, timestamp, name in query:Iterator("timestamp", "name") do
		assertTrue(query._optimization.result == OPTIMIZAITON_RESULT.NONE)
		expectedIndex = expectedIndex + 1
		assertEquals(timestamp, expected[expectedIndex].timestamp)
		assertEquals(name, expected[expectedIndex].name)
	end
	assertEquals(expectedIndex, #expected)
	query:Release()

	local query = itemSaleDB:NewOwnedQuery()
		:InnerJoin(itemNameDB, "itemId")
		:Equal("itemId", 2)
		:OrderBy("timestamp", true)
	local expected = {
		{ timestamp = 27, name = "Item 2" },
		{ timestamp = 29, name = "Item 2" },
	}
	assertEquals(query:Count(), #expected)
	local expectedIndex = 0
	for _, timestamp, name in query:Iterator("timestamp", "name") do
		assertTrue(query._optimization.result == OPTIMIZAITON_RESULT.INDEX)
		expectedIndex = expectedIndex + 1
		assertEquals(timestamp, expected[expectedIndex].timestamp)
		assertEquals(name, expected[expectedIndex].name)
	end
	assertEquals(expectedIndex, #expected)
	query:Release()

	local query = itemSaleDB:NewOwnedQuery()
		:InnerJoin(itemNameDB, "itemId")
		:Equal("itemId", 3)
		:OrderBy("timestamp", true)
	local expected = {}
	assertEquals(query:Count(), #expected)
	query:Release()

	local query = itemSaleDB:NewOwnedQuery()
		:InnerJoin(itemNameDB, "itemId")
		:Equal("itemId", 4)
		:OrderBy("timestamp", true)
	local expected = {}
	assertEquals(query:Count(), #expected)
	query:Release()

	local query = itemSaleDB:NewOwnedQuery()
		:InnerJoin(itemNameDB, "itemId")
		:InnerJoin(itemPriceDB, "itemId")
		:GreaterThan("minBuyout", 0)
		:OrderBy("timestamp", true)
	local expected = {}
	assertEquals(query:Count(), #expected)
	query:Release()

	local query = itemSaleDB:NewOwnedQuery()
		:InnerJoin(itemNameDB, "itemId")
		:OrderBy("timestamp", true)
	local numUpdateCallbacks = 0
	query:SetUpdateCallback(function(self)
		assertTrue(self == query)
		numUpdateCallbacks = numUpdateCallbacks + 1
	end)
	local expected = {
		{ timestamp = 25, name = "Item 1" },
		{ timestamp = 27, name = "Item 2" },
		{ timestamp = 29, name = "Item 2" },
		{ timestamp = 30, name = "Item 1" },
		{ timestamp = 32, name = "Item 1" },
	}
	assertEquals(query:Count(), #expected)
	local expectedIndex = 0
	for _, timestamp, name in query:Iterator("timestamp", "name") do
		assertTrue(query._optimization.result == OPTIMIZAITON_RESULT.NONE)
		expectedIndex = expectedIndex + 1
		assertEquals(timestamp, expected[expectedIndex].timestamp)
		assertEquals(name, expected[expectedIndex].name)
	end
	itemNameDB:InsertRow(4, "Item 4")
	assert(numUpdateCallbacks == 1)
	local expected = {
		{ timestamp = 25, name = "Item 1" },
		{ timestamp = 27, name = "Item 2" },
		{ timestamp = 29, name = "Item 2" },
		{ timestamp = 30, name = "Item 1" },
		{ timestamp = 31, name = "Item 4" },
		{ timestamp = 32, name = "Item 1" },
	}
	assertEquals(query:Count(), #expected)
	local expectedIndex = 0
	for _, timestamp, name in query:Iterator("timestamp", "name") do
		assertTrue(query._optimization.result == OPTIMIZAITON_RESULT.NONE)
		expectedIndex = expectedIndex + 1
		assertEquals(timestamp, expected[expectedIndex].timestamp)
		assertEquals(name, expected[expectedIndex].name)
	end
	query:Release()
end

function TestDatabase:TestMultiJoin()
	-- create the DBs
	local itemNameDB = Database.NewSchema("ITEM_NAME")
		:AddUniqueNumberField("itemId")
		:AddStringField("name")
		:Commit()
	local itemQuantityDB = Database.NewSchema("ITEM_QUANTITY")
		:AddUniqueNumberField("itemId")
		:AddNumberField("quantity")
		:Commit()
	local itemSaleDB = Database.NewSchema("ITEM_SALE")
		:AddNumberField("itemId")
		:AddNumberField("salePrice")
		:AddNumberField("timestamp")
		:AddIndex("itemId")
		:Commit()

	-- add some rows
	itemNameDB:InsertRow(1, "Item 1")
	itemNameDB:InsertRow(2, "Item 2")
	itemNameDB:InsertRow(3, "Item 3")
	itemQuantityDB:InsertRow(1, 10)
	itemQuantityDB:InsertRow(2, 20)
	itemQuantityDB:InsertRow(3, 30)
	itemQuantityDB:InsertRow(4, 40)
	itemSaleDB:InsertRow(1, 1000, 25)
	itemSaleDB:InsertRow(1, 1200, 30)
	itemSaleDB:InsertRow(1, 1400, 32)
	itemSaleDB:InsertRow(2, 5000, 27)
	itemSaleDB:InsertRow(2, 5000, 29)
	itemSaleDB:InsertRow(4, 5000, 31)

	local query = itemSaleDB:NewOwnedQuery()
		:LeftJoin(itemNameDB, "itemId")
		:InnerJoin(itemQuantityDB, "itemId")
		:OrderBy("timestamp", true)
	local expected = {
		{ timestamp = 25, name = "Item 1", quantity = 10 },
		{ timestamp = 27, name = "Item 2", quantity = 20 },
		{ timestamp = 29, name = "Item 2", quantity = 20 },
		{ timestamp = 30, name = "Item 1", quantity = 10 },
		{ timestamp = 31, name = nil, quantity = 40 },
		{ timestamp = 32, name = "Item 1", quantity = 10 },
	}
	assertEquals(query:Count(), #expected)
	local expectedIndex = 0
	for _, timestamp, name, quantity in query:Iterator("timestamp", "name", "quantity") do
		assertTrue(query._optimization.result == OPTIMIZAITON_RESULT.NONE)
		expectedIndex = expectedIndex + 1
		assertEquals(timestamp, expected[expectedIndex].timestamp)
		assertEquals(name, expected[expectedIndex].name)
		assertEquals(quantity, expected[expectedIndex].quantity)
	end
	assertEquals(expectedIndex, #expected)
	query:Release()
end

function TestDatabase:TestAggregateJoinSummed()
	-- create the DBs
	local itemNameDB = Database.NewSchema("ITEM_NAME")
		:AddUniqueNumberField("itemId")
		:AddStringField("name")
		:Commit()
	local itemLocationDB = Database.NewSchema("ITEM_SALE")
		:AddNumberField("itemId")
		:AddNumberField("slotId")
		:AddNumberField("quantity")
		:AddIndex("itemId")
		:Commit()

	-- add some rows
	itemNameDB:BulkInsertStart()
	itemLocationDB:BulkInsertStart()
	for i = 1, 3 do
		itemNameDB:BulkInsertNewRow(i, format("Item %d", i))
		for j = 1, i do
			itemLocationDB:BulkInsertNewRow(i, i * 10 + j, 5)
		end
	end
	itemLocationDB:BulkInsertEnd()
	itemNameDB:BulkInsertEnd()

	local query = itemNameDB:NewOwnedQuery()
		:AggregateJoinSummed(itemLocationDB, "itemId", "quantity")
		:OrderBy("itemId", true)
	local expected = {
		{ itemId = 1, name = "Item 1", quantity = 5 },
		{ itemId = 2, name = "Item 2", quantity = 10 },
		{ itemId = 3, name = "Item 3", quantity = 15 },
	}
	assertEquals(query:Count(), #expected)
	local expectedIndex = 0
	for _, itemId, name, quantity in query:Iterator("itemId", "name", "quantity") do
		assertTrue(query._optimization.result == OPTIMIZAITON_RESULT.NONE)
		expectedIndex = expectedIndex + 1
		assertEquals(itemId, expected[expectedIndex].itemId)
		assertEquals(name, expected[expectedIndex].name)
		assertEquals(quantity, expected[expectedIndex].quantity)
	end
	assertEquals(expectedIndex, #expected)
	query:Release()

	local query = itemNameDB:NewOwnedQuery()
		:AggregateJoinSummed(itemLocationDB, "itemId", "quantity")
		:OrderBy("itemId", true)
	local numUpdateCallbacks = 0
	query:SetUpdateCallback(function(self)
		assertTrue(self == query)
		numUpdateCallbacks = numUpdateCallbacks + 1
	end)
	itemNameDB:InsertRow(4, "Item 4")
	itemNameDB:InsertRow(5, "Item 5")
	assert(numUpdateCallbacks == 2)
	itemLocationDB:InsertRow(5, 99, 3)
	assert(numUpdateCallbacks == 3)
	local expected = {
		{ itemId = 1, name = "Item 1", quantity = 5 },
		{ itemId = 2, name = "Item 2", quantity = 10 },
		{ itemId = 3, name = "Item 3", quantity = 15 },
		{ itemId = 4, name = "Item 4", quantity = 0 },
		{ itemId = 5, name = "Item 5", quantity = 3 },
	}
	assertEquals(query:Count(), #expected)
	local expectedIndex = 0
	for _, itemId, name, quantity in query:Iterator("itemId", "name", "quantity") do
		assertTrue(query._optimization.result == OPTIMIZAITON_RESULT.NONE)
		expectedIndex = expectedIndex + 1
		assertEquals(itemId, expected[expectedIndex].itemId)
		assertEquals(name, expected[expectedIndex].name)
		assertEquals(quantity, expected[expectedIndex].quantity)
	end
	query:Release()
end

function TestDatabase:TestNestedQuery()
	-- create the DB
	local db = Database.NewSchema("TEST")
		:AddNumberField("rowNum")
		:AddNumberField("num1")
		:AddNumberField("num2")
		:AddIndex("num1")
		:Commit()

	-- add some rows
	db:InsertRow(1, 1, 10)
	db:InsertRow(2, 3, 20)
	db:InsertRow(3, 2, 20)
	db:InsertRow(4, 3, 30)

	db:SetQueryUpdatesPaused(true)
	local query = db:NewOwnedQuery()
		:Equal("num2", 30)
	for uuid in query:Iterator() do
		db:DeleteRow(uuid)
		local query2 = db:NewOwnedQuery()
			:Equal("num1", 3)
		assertEquals(query2:Count(), 1)
		assertEquals(query2:GetFirstResult("rowNum"), 2)
		query2:Release()
	end
	db:SetQueryUpdatesPaused(false)
	query:Release()
end

function TestDatabase:TestQueryUpdates()
	-- Create the DB
	local db = Database.NewSchema("TEST")
		:AddNumberField("num")
		:Commit()

	local query = db:NewOwnedQuery()
	local numUpdateCallbacks = 0
	query:SetUpdateCallback(function(self)
		assertTrue(self == query)
		numUpdateCallbacks = numUpdateCallbacks + 1
	end)

	-- Pause query updates with an auto-pausing query and add a row
	local query2 = db:NewAutoReleaseQuery()
		:AutoPauseDBQueryUpdates()
	assertEquals(db._queryUpdatesPaused, 1)
	db:InsertRow(0)
	assertEquals(numUpdateCallbacks, 0)
	assertEquals(query2:Count(), 1)
	assertEquals(db._queryUpdatesPaused, 0)
	assertEquals(numUpdateCallbacks, 1)
	numUpdateCallbacks = 0

	-- Pause query updates and add a row
	db:SetQueryUpdatesPaused(true)
	assertEquals(db._queryUpdatesPaused, 1)
	db:InsertRow(1)
	assertEquals(numUpdateCallbacks, 0)
	db:SetQueryUpdatesPaused(false)
	assertEquals(db._queryUpdatesPaused, 0)
	assertEquals(numUpdateCallbacks, 1)
	numUpdateCallbacks = 0

	-- Pause query updates with a context manager and add a row
	for _ in db:WithQueryUpdatesPaused() do
		assertEquals(db._queryUpdatesPaused, 1)
		db:InsertRow(2)
		assertEquals(numUpdateCallbacks, 0)
	end
	assertEquals(db._queryUpdatesPaused, 0)
	assertEquals(numUpdateCallbacks, 1)
	numUpdateCallbacks = 0

	-- Pause query updates with 1 of each type of pauses and add a row
	db:SetQueryUpdatesPaused(true)
	assertEquals(db._queryUpdatesPaused, 1)
	for _ in db:WithQueryUpdatesPaused() do
		assertEquals(db._queryUpdatesPaused, 2)
		db:InsertRow(3)
		assertEquals(numUpdateCallbacks, 0)
	end
	assertEquals(db._queryUpdatesPaused, 1)
	assertEquals(numUpdateCallbacks, 0)
	db:SetQueryUpdatesPaused(false)
	assertEquals(db._queryUpdatesPaused, 0)
	assertEquals(numUpdateCallbacks, 1)
	numUpdateCallbacks = 0

	-- Pause query updates with multiple of each type of pauses and add a row
	db:SetQueryUpdatesPaused(true)
	db:SetQueryUpdatesPaused(true)
	for _ in db:WithQueryUpdatesPaused() do
		for _ in db:WithQueryUpdatesPaused() do
			assertEquals(db._queryUpdatesPaused, 4)
			db:InsertRow(3)
			assertEquals(numUpdateCallbacks, 0)
		end
		assertEquals(db._queryUpdatesPaused, 3)
		assertEquals(numUpdateCallbacks, 0)
	end
	assertEquals(db._queryUpdatesPaused, 2)
	assertEquals(numUpdateCallbacks, 0)
	db:SetQueryUpdatesPaused(false)
	assertEquals(db._queryUpdatesPaused, 1)
	assertEquals(numUpdateCallbacks, 0)
	db:SetQueryUpdatesPaused(false)
	assertEquals(db._queryUpdatesPaused, 0)
	assertEquals(numUpdateCallbacks, 1)
	numUpdateCallbacks = 0

	query:Release()
end

function TestDatabase:TestBulkInsert()
	-- create the DB
	local db = Database.NewSchema("TEST")
		:AddNumberField("num1")
		:AddNumberField("num2")
		:AddIndex("num1")
		:Commit()

	db:BulkInsertStart()
	db:BulkInsertNewRow(7, 3)
	db:BulkInsertNewRow(8, 2)
	db:BulkInsertNewRow(9, 1)
	db:BulkInsertEnd()

	local query = db:NewOwnedQuery()
		:OrderBy("num1", false)
	local expected = { 1, 2, 3 }
	assertEquals(query:Count(), #expected)
	local expectedIndex = 0
	for _, num in query:Iterator("num2") do
		assertTrue(query._optimization.result == OPTIMIZAITON_RESULT.ORDER_BY)
		expectedIndex = expectedIndex + 1
		assertEquals(num, expected[expectedIndex])
	end
	assertEquals(expectedIndex, #expected)
	query:Release()

	local nextUUID = db._uuids[#db._uuids] - 1
	db:BulkInsertStart()
	db:BulkInsertNewRow(17, 13)
	db:BulkInsertNewRow(18, 12)
	db:BulkInsertNewRow(19, 11)
	for i = db._bulkInsertContext.firstUUIDIndex, #db._uuids do
		assertEquals(db._uuids[i], nextUUID)
		nextUUID = nextUUID - 1
	end
	db:BulkInsertAbort()

	local query2 = db:NewOwnedQuery()
		:OrderBy("num1", false)
	local expected2 = { 1, 2, 3 }
	assertEquals(query2:Count(), #expected2)
	local expectedIndex = 0
	for _, num in query2:Iterator("num2") do
		assertTrue(query2._optimization.result == OPTIMIZAITON_RESULT.ORDER_BY)
		expectedIndex = expectedIndex + 1
		assertEquals(num, expected2[expectedIndex])
	end
	assertEquals(expectedIndex, #expected2)
	query2:Release()
end

function TestDatabase:TestAggregate()
	-- create the DB
	local db = Database.NewSchema("TEST")
		:AddNumberField("num1")
		:AddNumberField("num2")
		:AddIndex("num1")
		:Commit()

	-- add some rows
	db:InsertRow(1, 10)
	db:InsertRow(3, 20)
	db:InsertRow(2, 20)
	db:InsertRow(3, 30)

	local query = db:NewOwnedQuery()
		:Equal("num1", 3)
	assertEquals(query:Count(), 2)
	assertTrue(query._resultState == RESULT_STATE.HAS_COUNT)
	assertEquals(query:Min("num1"), 3)
	assertTrue(query._resultState == RESULT_STATE.DONE)
	assertEquals(query:Count(), 2)
	assertEquals(query:Max("num1"), 3)
	assertEquals(query:Sum("num1"), 6)
	assertEquals(query:Avg("num1"), 3)
	assertEquals(query:Min("num2"), 20)
	assertEquals(query:Max("num2"), 30)
	assertEquals(query:Sum("num2"), 50)
	assertEquals(query:Avg("num2"), 25)
	-- make sure the results aren't hydrated
	assertEquals(type(query._result[1]), "number")
	assertEquals(type(query._result[2]), "number")
	query:Release()
end

function TestDatabase:TestVirtualField()
	-- create the DB
	local db = Database.NewSchema("TEST")
		:AddNumberField("num1")
		:AddNumberField("num2")
		:Commit()

	-- add some rows
	db:InsertRow(1, 5)
	db:InsertRow(3, 10)
	db:InsertRow(2, 1)
	db:InsertRow(10, 3)

	local function SumVirtualFieldFunc(num1, num2)
		return num1 + num2
	end

	-- test that we can order by, select, and make distinct the virtual field
	local query = db:NewOwnedQuery()
		:VirtualField("sum", "number", SumVirtualFieldFunc, {"num1", "num2"})
		:Distinct("sum")
		:OrderBy("sum", true)
	local expected = { 3, 6, 13 }
	assertEquals(query:Count(), #expected)
	local expectedIndex = 0
	for _, num in query:Iterator("sum") do
		expectedIndex = expectedIndex + 1
		assertEquals(num, expected[expectedIndex])
	end
	assertEquals(expectedIndex, #expected)
	query:Release()

	-- test that we can filter by the virtual field
	local query = db:NewOwnedQuery()
		:VirtualField("sum", "number", SumVirtualFieldFunc, {"num1", "num2"})
		:Equal("sum", 13)
		:OrderBy("num1", true)
	local expected = { 3, 10 }
	assertEquals(query:Count(), #expected)
	local expectedIndex = 0
	for _, num in query:Iterator("num1") do
		expectedIndex = expectedIndex + 1
		assertEquals(num, expected[expectedIndex])
	end
	assertEquals(expectedIndex, #expected)
	query:Release()

	-- test virtual hash fields
	local hashValues = {}
	db:NewAutoReleaseQuery()
		:VirtualHashField("hash", {"num1", "num2"})
		:AsTable(hashValues, "num1", "hash")
	local function GetExpectedHash(num1, num2)
		return Hash.Calculate(num2, Hash.Calculate(num1))
	end
	local expectedHashes = {
		[1] = GetExpectedHash(1, 5),
		[2] = GetExpectedHash(2, 1),
		[3] = GetExpectedHash(3, 10),
		[10] = GetExpectedHash(10, 3)
	}
	assertEquals(hashValues, expectedHashes)
end

function TestDatabase:TestSmartMapField()
	local valueLookupTable = {
		["i:1:-1"] = "i:1",
		["i:2:-2"] = "i:2",
		["i:3:-3"] = "i:3",
	}
	local map = SmartMap.New("string", "string", function(key)
		return valueLookupTable[key]
	end)
	local map2 = SmartMap.New("string", "string", function(key)
		return strmatch(key, "i:%d+")
	end)

	-- create the DB
	local db = Database.NewSchema("TEST")
		:AddStringField("itemString")
		:AddNumberField("num")
		:AddSmartMapField("baseItemString", map2, "itemString")
		:AddSmartMapField("autoBaseItemString", map, "itemString")
		:AddIndex("baseItemString")
		:AddIndex("autoBaseItemString")
		:Commit()

	-- add some rows
	db:BulkInsertStart()
	db:BulkInsertNewRow("i:1:-1", 1)
	db:BulkInsertNewRow("i:2:-2", 2)
	db:BulkInsertNewRow("i:3:-3", 3)
	db:BulkInsertEnd()

	-- select the smart map field in a query
	local query1 = db:NewOwnedQuery()
		:OrderBy("num", true)
	local expected = { "i:1", "i:2", "i:3" }
	assertEquals(query1:Count(), #expected)
	local expectedIndex = 0
	for _, num in query1:Iterator("autoBaseItemString") do
		expectedIndex = expectedIndex + 1
		assertEquals(num, expected[expectedIndex])
	end
	assertEquals(expectedIndex, #expected)
	query1:Release()

	-- filter on the smart map field
	local query2 = db:NewOwnedQuery()
		:Equal("autoBaseItemString", "i:2")
	local expected = { 2 }
	assertEquals(query2:Count(), #expected)
	assertTrue(query2._optimization.result == OPTIMIZAITON_RESULT.INDEX)
	assertEquals(query2._optimization.field, "autoBaseItemString")
	local expectedIndex = 0
	for _, num in query2:Iterator("num") do
		expectedIndex = expectedIndex + 1
		assertEquals(num, expected[expectedIndex])
	end
	assertEquals(expectedIndex, #expected)
	-- change some smart map values and confirm the query reflects this change
	valueLookupTable["i:2:-2"] = "i:2:-2"
	map:ValueChanged("i:2:-2")
	assertEquals(query2:Count(), 0)
	-- change the field we modified back
	valueLookupTable["i:2:-2"] = "i:2"
	map:ValueChanged("i:2:-2")
	query2:Release()

	-- order by the computed field
	local query3 = db:NewOwnedQuery()
		:OrderBy("autoBaseItemString", true)
	local expected = { 1, 2, 3 }
	assertEquals(query3:Count(), #expected)
	assertTrue(query3._optimization.result == OPTIMIZAITON_RESULT.ORDER_BY)
	assertEquals(query3._optimization.field, "autoBaseItemString")
	local expectedIndex = 0
	for _, num in query3:Iterator("num") do
		expectedIndex = expectedIndex + 1
		assertEquals(num, expected[expectedIndex])
	end
	assertEquals(expectedIndex, #expected)
	-- change some smart map values and confirm the query reflects this change
	valueLookupTable["i:2:-2"] = "i:9"
	map:ValueChanged("i:2:-2")
	local expected = { 1, 3, 2 }
	assertEquals(query3:Count(), #expected)
	assertTrue(query3._optimization.result == OPTIMIZAITON_RESULT.ORDER_BY)
	assertEquals(query3._optimization.field, "autoBaseItemString")
	local expectedIndex = 0
	for _, num in query3:Iterator("num") do
		expectedIndex = expectedIndex + 1
		assertEquals(num, expected[expectedIndex])
	end
	assertEquals(expectedIndex, #expected)
	-- change the field we modified back
	valueLookupTable["i:2:-2"] = "i:2"
	map:ValueChanged("i:2:-2")
	query3:Release()

	-- join on the smart map field
	local joinDB = Database.NewSchema("TEST_JOIN")
		:AddUniqueStringField("autoBaseItemString")
		:AddStringField("str")
		:Commit()
	joinDB:BulkInsertStart()
	joinDB:BulkInsertNewRow("i:1", "a")
	joinDB:BulkInsertNewRow("i:3", "c")
	joinDB:BulkInsertEnd()
	local query4 = db:NewOwnedQuery()
		:InnerJoin(joinDB, "autoBaseItemString")
		:OrderBy("autoBaseItemString", true)
	local expected = { "a", "c" }
	assertEquals(query4:Count(), #expected)
	assertTrue(query4._optimization.result == OPTIMIZAITON_RESULT.ORDER_BY)
	assertEquals(query4._optimization.field, "autoBaseItemString")
	local expectedIndex = 0
	for _, num in query4:Iterator("str") do
		expectedIndex = expectedIndex + 1
		assertEquals(num, expected[expectedIndex])
	end
	assertEquals(expectedIndex, #expected)
	query4:Release()
end

function TestDatabase:TestInTable()
	-- create the DB
	local db = Database.NewSchema("TEST")
		:AddStringField("str")
		:Commit()

	-- add some rows
	db:InsertRow("a")
	db:InsertRow("b")
	db:InsertRow("c")

	local query1 = db:NewOwnedQuery()
		:InTable("str", { a = true })
	assertEquals(query1:Count(), 1)
	for _, str in query1:Iterator("str") do
		assertEquals(str, "a")
	end
	query1:Release()

	local query2 = db:NewOwnedQuery()
		:InTable("str", { a = 2 })
	assertEquals(query2:Count(), 1)
	for _, str in query2:Iterator("str") do
		assertEquals(str, "a")
	end
	query2:Release()

	local query3 = db:NewOwnedQuery()
		:InTable("str", { a = false, b = "test" })
		:OrderBy("str", true)
	assertEquals(query3:Count(), 2)
	local isFirst = true
	for _, str in query3:Iterator("str") do
		if isFirst then
			isFirst = false
			assertEquals(str, "a")
		else
			assertEquals(str, "b")
		end
	end
	query3:Release()
end

function TestDatabase:TestTrigramIndex()
	-- create the DB
	local db = Database.NewSchema("TEST")
		:AddStringField("str")
		:AddNumberField("num")
		:AddTrigramIndex("str")
		:Commit()

	-- add some rows
	db:BulkInsertStart()
	db:BulkInsertNewRow("Ace of Spades", 1)
	db:BulkInsertNewRow("Ace of Clubs", 2)
	db:BulkInsertNewRow("Ace of Hearts", 4)
	db:BulkInsertNewRow("Two of Hearts", 8)
	db:BulkInsertNewRow("Three of Clubs", 16)
	db:BulkInsertEnd()

	local query1 = db:NewOwnedQuery()
		:Contains("str", "Ace of")
	assertEquals(query1:Count(), 3)
	assertEquals(query1:Sum("num"), 7)
	assertTrue(query1._optimization.result == OPTIMIZAITON_RESULT.TRIGRAM)
	assertEquals(query1._optimization.field, "str")
	query1:Release()

	local query2 = db:NewOwnedQuery()
		:Contains("str", "Ace of H")
	assertEquals(query2:Count(), 1)
	assertEquals(query2:Sum("num"), 4)
	assertTrue(query2._optimization.result == OPTIMIZAITON_RESULT.TRIGRAM)
	assertEquals(query2._optimization.field, "str")
	query2:Release()
end

function TestDatabase:TestList()
	local function ListFieldIterToTable(iter)
		local tbl = {}
		for _, v in iter do
			tinsert(tbl, v)
		end
		return tbl
	end

	-- create the DB
	local db = Database.NewSchema("TEST")
		:AddNumberField("id")
		:AddStringListField("strs")
		:AddNumberListField("nums")
		:Commit()

	-- add a row
	db:InsertRow(2, {"2a", "2b", "common"}, {})
	assertEquals(db:GetRowFields(db._uuids[1], "id"), 2)
	assertEquals(ListFieldIterToTable(db:GetRowFields(db._uuids[1], "strs")), {"2a", "2b", "common"})
	assertEquals(ListFieldIterToTable(db:GetRowFields(db._uuids[1], "nums")), {})
	assertEquals(#db._data / db._numStoredFields, 1)

	-- add a second row via bulk insert
	db:BulkInsertStart()
	db:BulkInsertNewRow(3, {"3a", "3b"}, {30, 31, 32})
	db:BulkInsertEnd()
	assertEquals(db:GetRowFields(db._uuids[2], "id"), 3)
	assertEquals(ListFieldIterToTable(db:GetRowFields(db._uuids[2], "strs")), {"3a", "3b"})
	assertEquals(ListFieldIterToTable(db:GetRowFields(db._uuids[2], "nums")), {30, 31, 32})
	assertEquals(#db._data / db._numStoredFields, 2)

	local uuid = db:NewAutoReleaseQuery()
		:Equal("id", 3)
		:GetFirstResultWithUUID()
	db:UpdateRow(uuid, "strs", {"3a", "common", "3b"})
	assertEquals(db:GetRowFields(db._uuids[2], "id"), 3)
	assertEquals(ListFieldIterToTable(db:GetRowFields(db._uuids[2], "strs")), {"3a", "common", "3b"})
	assertEquals(ListFieldIterToTable(db:GetRowFields(db._uuids[2], "nums")), {30, 31, 32})
	assertEquals(#db._data / db._numStoredFields, 2)

	local query1 = db:NewOwnedQuery()
		:ListContains("strs", "2b")
	assertEquals(query1:Count(), 1)
	local found = false
	for _, id in query1:Iterator("id") do
		assertTrue(query1._optimization.result == OPTIMIZAITON_RESULT.NONE)
		assertEquals(id, 2)
		assert(not found)
		found = true
	end
	query1:Release()

	local query2 = db:NewOwnedQuery()
		:ListContains("strs", "common")
		:OrderBy("id", true)
	assertEquals(query2:Count(), 2)
	local expected = { 2, 3 }
	local expectedIndex = 0
	for _, id in query2:Iterator("id") do
		assertTrue(query2._optimization.result == OPTIMIZAITON_RESULT.NONE)
		expectedIndex = expectedIndex + 1
		assertEquals(id, expected[expectedIndex])
	end
	assertEquals(expectedIndex, #expected)
	query2:Release()

	local query3 = db:NewOwnedQuery()
	local index3 = 0
	for _, strs in query3:Iterator("strs") do
		index3 = index3 + 1
		if index3 == 1 then
			assertEquals(ListFieldIterToTable(strs), {"2a", "2b", "common"})
		else
			assertEquals(ListFieldIterToTable(strs), {"3a", "common", "3b"})
		end
	end
	query3:Release()

	local query4 = db:NewOwnedQuery()
		:VirtualField("joinedStrs", "string", function(strsIter) return strsIter:ToJoinedValueString(",") end, "strs")
	assertEquals(query4:Count(), 2)
	local expected = { "2a,2b,common", "3a,common,3b" }
	local expectedIndex = 0
	for _, res in query4:Iterator("joinedStrs") do
		assertTrue(query4._optimization.result == OPTIMIZAITON_RESULT.NONE)
		expectedIndex = expectedIndex + 1
		assertEquals(res, expected[expectedIndex])
	end
	assertEquals(expectedIndex, #expected)

	-- Update the list field using :UpdateRow()
	assertEquals(ListFieldIterToTable(db:GetRowFields(db._uuids[1], "strs")), {"2a", "2b", "common"})
	db:UpdateRow(db._uuids[1], "strs", {"a", "b"})
	assertEquals(ListFieldIterToTable(db:GetRowFields(db._uuids[1], "strs")), {"a", "b"})

	-- Make sure all iterators were released
	assertNil(next(Locals["LibTSMUtil.BaseType.Iterator"].private.objectPool._state))
end

function TestDatabase:TestErrors()
	-- Create the DB
	local db = Database.NewSchema("TEST")
		:AddStringField("str")
		:AddNumberField("num")
		:Commit()

	db:BulkInsertStart()
	db:BulkInsertNewRow("a", 1)
	db:BulkInsertNewRow("b", 2)
	db:BulkInsertNewRow("c", 3)
	db:BulkInsertEnd()

	assertErrorMsgContains("Field 'str' is not unique", function() db:HasUniqueRow("str", "a") end)
	assertErrorMsgContains("Value of '2' for field 'str' is the wrong type (expected string)", function() db:HasUniqueRow("str", 2) end)
	assertErrorMsgContains("Field 'str2' doesn't exist", function() db:HasUniqueRow("str2", "a") end)
end

function TestDatabase:TestEnumField()
	local COLOR = EnumType.New("COLOR", {
		RED = EnumType.NewValue(),
		GREEN = EnumType.NewValue(),
		BLUE = EnumType.NewValue(),
	})
	local db = Database.NewSchema("TEST")
		:AddStringField("str")
		:AddEnumField("color", COLOR)
		:Commit()

	db:BulkInsertStart()
	db:BulkInsertNewRow("a", COLOR.RED)
	db:BulkInsertNewRow("b", COLOR.GREEN)
	db:BulkInsertNewRow("c", COLOR.RED)
	db:BulkInsertNewRow("d", COLOR.BLUE)
	db:BulkInsertEnd()

	local query = db:NewOwnedQuery()
		:Equal("color", COLOR.RED)
		:OrderBy("str", true)
	local expected = { "a", "c" }
	assertEquals(query:Count(), #expected)
	local expectedIndex = 0
	for _, num in query:Iterator("str") do
		expectedIndex = expectedIndex + 1
		assertEquals(num, expected[expectedIndex])
	end
	assertEquals(expectedIndex, #expected)
	query:Release()
end

function TestDatabase:TestQueryFunction()
	local db = Database.NewSchema("TEST")
		:AddStringField("str")
		:AddNumberField("value")
		:Commit()

	db:BulkInsertStart()
	db:BulkInsertNewRow("a", 2)
	db:BulkInsertNewRow("b", 3)
	db:BulkInsertNewRow("c", 4)
	db:BulkInsertNewRow("d", 5)
	db:BulkInsertEnd()

	local query = db:NewOwnedQuery()
		:Function("value", function(num) return num % 2 == 0 end)
		:OrderBy("str", true)
	local expected = { "a", "c" }
	assertEquals(query:Count(), #expected)
	local expectedIndex = 0
	for _, str in query:Iterator("str") do
		expectedIndex = expectedIndex + 1
		assertEquals(str, expected[expectedIndex])
	end
	assertEquals(expectedIndex, #expected)
	query:Release()
end

function TestDatabase:TestQueryIteratorObject()
	local db = Database.NewSchema("TEST")
		:AddStringField("str")
		:Commit()

	db:BulkInsertStart()
	db:BulkInsertNewRow("d")
	db:BulkInsertNewRow("a")
	db:BulkInsertNewRow("c")
	db:BulkInsertNewRow("b")
	db:BulkInsertEnd()

	local query1 = db:NewOwnedQuery()
		:OrderBy("str", true)
	assertEquals(query1:Count(), 4)
	query1:AutoRelease()
	local iter1 = query1:Iterator("str")
	assertEquals(select(2, iter1()), "a")
	assertEquals(select(2, iter1()), "b")
	assertEquals(select(2, iter1()), "c")
	assertEquals(select(2, iter1()), "d")
	assertNil(iter1())
	assertTrue(query1._db == nil)

	local query2 = db:NewOwnedQuery()
		:OrderBy("str", true)
	assertEquals(query2:Count(), 4)
	query2:AutoRelease()
	local iter2 = query2:Iterator("str")
	assertEquals({select(2, iter2())}, {"a"})
	iter2:Release()
	assertTrue(query2._db == nil)
end

function TestDatabase:TestQueryDelete()
	local db = Database.NewSchema("TEST")
		:AddStringField("str")
		:AddNumberField("value")
		:Commit()

	db:BulkInsertStart()
	db:BulkInsertNewRow("a", 2)
	db:BulkInsertNewRow("b", 2)
	db:BulkInsertNewRow("c", 3)
	db:BulkInsertNewRow("d", 4)
	db:BulkInsertEnd()

	local query = db:NewOwnedQuery()
		:Equal("value", 2)
		:OrderBy("str", true)

	local numUpdateCallbacks = 0
	query:SetUpdateCallback(function(self)
		assertTrue(self == query)
		numUpdateCallbacks = numUpdateCallbacks + 1
	end)

	assertEquals(query:Count(), 2)
	assertEquals(query:JoinedString("str", ","), "a,b")

	assertEquals(numUpdateCallbacks, 0)
	query:Delete()
	assertEquals(numUpdateCallbacks, 1)
	assertEquals(query:Count(), 0)

	query:Release()
end

function TestDatabase:TestIf()
	local db = Database.NewSchema("TEST")
		:AddStringField("str")
		:AddNumberField("value")
		:Commit()

	db:BulkInsertStart()
	db:BulkInsertNewRow("a", 2)
	db:BulkInsertNewRow("b", 2)
	db:BulkInsertNewRow("c", 3)
	db:BulkInsertNewRow("d", 4)
	db:BulkInsertEnd()

	local result1 = db:NewAutoReleaseQuery()
		:If(true)
			:Equal("value", 2)
		:ElseIf(false)
			:Equal("value", 3)
		:ElseIf(false)
			:Equal("value", 4)
		:Else()
			:Equal("value", 5)
		:End()
		:OrderBy("str", true)
		:JoinedString("str", ",")
	assertEquals(result1, "a,b")

	local result2 = db:NewAutoReleaseQuery()
		:If(false)
			:Equal("value", 2)
		:ElseIf(true)
			:Equal("value", 3)
		:ElseIf(false)
			:Equal("value", 4)
		:Else()
			:Equal("value", 5)
		:End()
		:OrderBy("str", true)
		:JoinedString("str", ",")
	assertEquals(result2, "c")

	local result3 = db:NewAutoReleaseQuery()
		:If(false)
			:Equal("value", 2)
		:ElseIf(false)
			:Equal("value", 3)
		:ElseIf(true)
			:Equal("value", 4)
		:Else()
			:Equal("value", 5)
		:End()
		:OrderBy("str", true)
		:JoinedString("str", ",")
	assertEquals(result3, "d")

	local result4 = db:NewAutoReleaseQuery()
		:If(false)
			:Equal("value", 2)
		:ElseIf(false)
			:Equal("value", 3)
		:ElseIf(false)
			:Equal("value", 4)
		:Else()
			:Equal("value", 5)
		:End()
		:OrderBy("str", true)
		:JoinedString("str", ",")
	assertEquals(result4, "")

	local result5 = db:NewAutoReleaseQuery()
		:If(true)
			:Equal("value", 2)
		:ElseIf(true)
			:Equal("value", 3)
		:ElseIf(true)
			:Equal("value", 4)
		:Else()
			:Equal("value", 5)
		:End()
		:OrderBy("str", true)
		:JoinedString("str", ",")
	assertEquals(result5, "a,b")

	local result6 = db:NewAutoReleaseQuery()
		:If(false)
			:Equal("value", 2)
		:ElseIf(true)
			:Equal("value", 3)
		:ElseIf(true)
			:Equal("value", 4)
		:Else()
			:Equal("value", 5)
		:End()
		:OrderBy("str", true)
		:JoinedString("str", ",")
	assertEquals(result6, "c")

	local result7 = db:NewAutoReleaseQuery()
		:If(false)
			:VirtualField("str2", "string", function(str) return str.."1" end, "str")
			:Equal("value", 2)
		:ElseIf(true)
			:VirtualField("str2", "string", function(str) return str.."2" end, "str")
			:Equal("value", 3)
		:ElseIf(true)
			:VirtualField("str2", "string", function(str) return str.."3" end, "str")
			:Equal("value", 4)
		:Else()
			:VirtualField("str2", "string", function(str) return str.."4" end, "str")
			:Equal("value", 5)
		:End()
		:OrderBy("str", true)
		:JoinedString("str2", ",")
	assertEquals(result7, "c2")
end
