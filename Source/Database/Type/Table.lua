-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local DatabaseTable = LibTSMUtil:DefineClassType("DatabaseTable")
local Util = LibTSMUtil:Include("Database.Util")
local DatabaseQuery = LibTSMUtil:IncludeClassType("DatabaseQuery")
local ContextManager = LibTSMUtil:Include("BaseType.ContextManager")
local Iterator = LibTSMUtil:Include("BaseType.Iterator")
local Table = LibTSMUtil:Include("Lua.Table")
local String = LibTSMUtil:Include("Lua.String")
local Vararg = LibTSMUtil:Include("Lua.Vararg")
local BinarySearch = LibTSMUtil:Include("Util.BinarySearch")
local private = {
	createCallback = nil,
	-- Make the initial UUID a very big negative number so it doesn't conflict with other numbers
	lastUUID = -1000000,
	bulkInsertTemp = {},
	smartMapReaderFieldLookup = {},
	usedTrigramSubStrTemp = {},
	contextManager = ContextManager.Create(function(db) db:SetQueryUpdatesPaused(true) return db end, function(db) db:SetQueryUpdatesPaused(false) end),
	bulkDeleteTemp = {},
	indexTemp = {},
	uniqueTemp = {},
	indexMergeTemp1 = {},
	indexMergeTemp2 = {},
}
local LIST_FIELD_ENTRY_TYPE_LOOKUP = {
	STRING_LIST = "string",
	NUMBER_LIST = "number",
}



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Sets the callback to be called when a table is created.
---@param func fun(DatabaseTable, DatabaseSchema)
function DatabaseTable.__static.SetCreateCallback(func)
	private.createCallback = func
end

---Creates a table.
---@param schema DatabaseSchema
---@return DatabaseTable
function DatabaseTable.__static.Create(schema)
	return DatabaseTable(schema)
end



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

---@param schema DatabaseSchema
function DatabaseTable.__private:__init(schema)
	self._name = schema:_GetName() ---@diagnostic disable-line: invisible
	self._queries = {}
	self._indexLists = {}
	self._uniques = {}
	self._trigramIndexField = nil
	self._trigramIndexLists = {}
	self._indexOrUniqueFields = {}
	self._queryUpdatesPaused = 0
	self._queuedQueryUpdate = false
	self._bulkInsertContext = {
		inUse = nil,
		firstDataIndex = nil,
		firstUUIDIndex = nil,
		partitionUUIDIndex = nil,
		fastNum = nil,
		fastUnique = nil,
	}
	self._fieldOffsetLookup = {}
	self._fieldTypeLookup = {}
	self._fieldTypeEnumType = {} ---@type table<string,EnumObject>
	self._storedFieldList = {}
	self._numStoredFields = 0
	self._data = {}
	self._uuids = {}
	self._uuidToDataOffsetLookup = {}
	self._smartMapInputLookup = {}
	self._smartMapInputFields = {}
	self._smartMapReaderLookup = {}
	self._listData = nil

	-- Process all the fields and grab the indexFields for further processing
	assert(not next(private.indexTemp))
	for _, fieldName, fieldType, isIndex, isUnique, isTrigram, smartMap, smartMapInput, fieldTypeEnumType in schema:_FieldIterator() do ---@diagnostic disable-line: invisible
		if smartMap then
			-- Smart map fields aren't actually stored in the DB
			assert(self._fieldOffsetLookup[smartMapInput], "SmartMap field must be based on a stored field")
			local reader = smartMap:CreateReader(self:__closure("_HandleSmartMapReaderUpdate"))
			private.smartMapReaderFieldLookup[reader] = fieldName
			self._smartMapInputLookup[fieldName] = smartMapInput
			self._smartMapInputFields[smartMapInput] = self._smartMapInputFields[smartMapInput] or {}
			tinsert(self._smartMapInputFields[smartMapInput], fieldName)
			self._smartMapReaderLookup[fieldName] = reader
		else
			self._numStoredFields = self._numStoredFields + 1
			self._fieldOffsetLookup[fieldName] = self._numStoredFields
			tinsert(self._storedFieldList, fieldName)
		end
		self._fieldTypeLookup[fieldName] = fieldType
		self._fieldTypeEnumType[fieldName] = fieldTypeEnumType
		if not self._listData and LIST_FIELD_ENTRY_TYPE_LOOKUP[fieldType] then
			self._listData = { nextIndex = 1 }
		end
		if isIndex then
			self._indexLists[fieldName] = {}
			tinsert(private.indexTemp, fieldName)
		end
		if isUnique then
			self._uniques[fieldName] = {}
			tinsert(self._indexOrUniqueFields, fieldName)
		end
		if isTrigram then
			assert(not self._trigramIndexField and self._fieldOffsetLookup[fieldName] and fieldType == "string")
			self._trigramIndexField = fieldName
		end
	end

	-- Process the index fields
	for _, field in ipairs(private.indexTemp) do
		if not self._uniques[field] then
			tinsert(self._indexOrUniqueFields, field)
		end
	end
	wipe(private.indexTemp)

	if private.createCallback then
		private.createCallback(self, schema)
	end
end

function DatabaseTable:__tostring()
	return "DatabaseTable:"..self._name
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Inserts a new row into the database.
---@param ... any The values of all the DB fields
function DatabaseTable:InsertRow(...)
	local uuid = private.GetNextUUID()
	local rowIndex = #self._data + 1
	local uuidIndex = #self._uuids + 1
	local numFields = select("#", ...)
	if numFields ~= self._numStoredFields then
		error(format("Invalid number of values (%d, %s)", numFields, tostring(self._numStoredFields)))
	end
	self._uuidToDataOffsetLookup[uuid] = rowIndex
	self._uuids[uuidIndex] = uuid

	for i, value in Vararg.Iterator(...) do
		local field = self._storedFieldList[i]
		local fieldType = self._fieldTypeLookup[field]
		local listFieldType = LIST_FIELD_ENTRY_TYPE_LOOKUP[fieldType]
		local fieldTypeEnumType = self._fieldTypeEnumType[field]
		if listFieldType then
			if type(value) ~= "table" then
				error(format("Expected list value, got %s", type(value)), 2)
			end
			local len = #value
			for j, v in pairs(value) do
				if type(i) ~= "number" or j < 1 or j > len then
					error("Invalid table index: "..tostring(j), 2)
				elseif type(v) ~= listFieldType then
					error(format("List (%s) entries should be of type %s, got %s", tostring(field), listFieldType, tostring(v)), 2)
				end
			end
		elseif fieldTypeEnumType then
			if not fieldTypeEnumType:HasValue(value) then
				error(format("Expected enum value (%s), got '%s'", tostring(fieldTypeEnumType), tostring(value)), 2)
			end
		elseif type(value) ~= fieldType then
			error(format("Field %s should be a %s, got %s", tostring(field), tostring(fieldType), type(value)), 2)
		end
		if listFieldType then
			self._data[rowIndex + i - 1] = self:_InsertListData(value)
		else
			self._data[rowIndex + i - 1] = value
		end
		local uniqueValues = self._uniques[field]
		if uniqueValues then
			if uniqueValues[value] ~= nil then
				error(format("A row with this unique value (%s) already exists", tostring(value)), 2)
			end
			uniqueValues[value] = uuid
		end
	end

	for field in pairs(self._indexLists) do
		self:_IndexListInsert(field, uuid)
	end
	if self._trigramIndexField then
		self:_TrigramIndexInsert(uuid)
	end
	self:_UpdateQueries()
end

---Updates an existing row in the DB.
---@param uuid number The UUID of the row
---@param updates string|table<string,any> The updates to make to the row (either the name of the field followed by the value or a table with names and values)
---@param value? any
function DatabaseTable:UpdateRow(uuid, updates, value)
	local dataOffset = self._uuidToDataOffsetLookup[uuid]
	if not dataOffset then
		error("Invalid UUID: "..tostring(uuid))
	end
	if type(updates) == "table" then
		for field, newValue in pairs(updates) do
			self:_ValidateFieldValue(field, newValue)
			if self:_IsUnique(field) then
				error("Cannot set unique field using this method", 3)
			end
			local fieldOffset = self._fieldOffsetLookup[field]
			if not fieldOffset then
				error("Invalid field: "..tostring(field))
			end
			local prevValue = self._data[dataOffset + fieldOffset - 1]
			if prevValue == newValue then
				updates[field] = nil
			end
		end
		if next(updates) then
			self:_UpdateFields(uuid, updates)
		end
	else
		self:_ValidateFieldValue(updates, value)
		if self:_IsUnique(updates) then
			error("Cannot set unique field using this method", 3)
		end
		local fieldOffset = self._fieldOffsetLookup[updates]
		if not fieldOffset then
			error("Invalid field: "..tostring(updates))
		end
		local prevValue = self._data[dataOffset + fieldOffset - 1]
		if prevValue == value then
			-- The value didn't change
			return
		end
		local isIndex = self:_IsIndex(updates)
		if isIndex then
			-- Remove the old value from the index first
			self:_IndexListRemove(updates, uuid)
		end
		if self._trigramIndexField == updates then
			self:_TrigramIndexRemove(uuid, prevValue)
		end
		if self:_IsListField(updates) then
			self._data[dataOffset + fieldOffset - 1] = self:_InsertListData(value)
		else
			self._data[dataOffset + fieldOffset - 1] = value
		end
		if isIndex then
			-- Insert the new value into the index
			self:_IndexListInsert(updates, uuid)
		end
		if self._trigramIndexField == updates then
			self:_TrigramIndexInsert(uuid)
		end
		self:_UpdateQueries()
	end
end

---Gets fields from a row in the DB.
---@param uuid number The UUID
---@param ... string The fields to get the values of
---@return ...
function DatabaseTable:GetRowFields(uuid, ...)
	-- Get up to 4 fields at a time - recursing as needed for more
	local numFields = select("#", ...)
	local field1, field2, field3, field4 = ...
	local value1 = numFields >= 1 and self:_GetRowField(uuid, field1)
	local value2 = numFields >= 2 and self:_GetRowField(uuid, field2)
	local value3 = numFields >= 3 and self:_GetRowField(uuid, field3)
	local value4 = numFields >= 4 and self:_GetRowField(uuid, field4)
	if numFields == 1 then
		return value1
	elseif numFields == 2 then
		return value1, value2
	elseif numFields == 3 then
		return value1, value2, value3
	elseif numFields == 4 then
		return value1, value2, value3, value4
	elseif numFields > 4 then
		return value1, value2, value3, value4, self:GetRowFields(uuid, select(5, ...))
	else
		error("Invalid number of fields")
	end
end

---Delete a row rom the DB.
---@param uuids number|number[] The UUID or a list of UUIDs of the row(s) to delete
function DatabaseTable:DeleteRow(uuids)
	assert(not self._bulkInsertContext.inUse)
	if type(uuids) == "number" then
		assert(not self._bulkInsertContext.inUse)
		assert(self._uuidToDataOffsetLookup[uuids])
		for indexField in pairs(self._indexLists) do
			self:_IndexListRemove(indexField, uuids)
		end
		if self._trigramIndexField then
			local prevTrigramValue = private.TrigramValueFunc(uuids, self, self._trigramIndexField)
			self:_TrigramIndexRemove(uuids, prevTrigramValue)
		end
		for field, uniqueValues in pairs(self._uniques) do
			uniqueValues[self:_GetRowField(uuids, field)] = nil
		end
		self:_DeleteRowHelper(uuids)
	else
		assert(not self._trigramIndexField, "Cannot bulk delete on tables with trigram indexes")
		assert(not next(private.bulkDeleteTemp))
		for _, uuid in ipairs(uuids) do
			private.bulkDeleteTemp[uuid] = true
			for field, uniqueValues in pairs(self._uniques) do
				uniqueValues[self:_GetRowField(uuid, field)] = nil
			end
			self:_DeleteRowHelper(uuid)
		end

		-- Re-build the indexes
		for _, indexList in pairs(self._indexLists) do
			assert(not next(private.indexTemp))
			for i = 1, #indexList do
				private.indexTemp[i] = indexList[i]
			end
			wipe(indexList)
			local insertIndex = 1
			for i = 1, #private.indexTemp do
				local uuid = private.indexTemp[i]
				if not private.bulkDeleteTemp[uuid] then
					indexList[insertIndex] = uuid
					insertIndex = insertIndex + 1
				end
			end
			Table.WipeAndDeallocate(private.indexTemp)
		end

		Table.WipeAndDeallocate(private.bulkDeleteTemp)
	end
	self:_UpdateQueries()
end

---Check whether or not a row with a unique value exists.
---@param uniqueField string The unique field
---@param uniqueValue any The value of the unique field
---@return boolean
function DatabaseTable:HasUniqueRow(uniqueField, uniqueValue)
	self:_ValidateFieldValue(uniqueField, uniqueValue)
	self:_ValidateUnique(uniqueField)
	return self:_GetUniqueRow(uniqueField, uniqueValue) and true or false
end

---Gets the UUID of the unique row.
---@param uniqueField string The unique field
---@param uniqueValue any The value of the unique field
---@return number
function DatabaseTable:GetUniqueRow(uniqueField, uniqueValue)
	self:_ValidateFieldValue(uniqueField, uniqueValue)
	self:_ValidateUnique(uniqueField)
	local uuid = self:_GetUniqueRow(uniqueField, uniqueValue)
	assert(uuid)
	return uuid
end

---Gets fields from a unique row in the DB.
---@param uniqueField string The unique field
---@param uniqueValue any The value of the unique field
---@param ... string The fields to get the values of
---@return ...
function DatabaseTable:GetUniqueRowFields(uniqueField, uniqueValue, ...)
	return self:GetRowFields(self:GetUniqueRow(uniqueField, uniqueValue), ...)
end

---Gets a new query which is automatically released after execution.
---@return DatabaseQuery
function DatabaseTable:NewAutoReleaseQuery()
	assert(not self._bulkInsertContext.inUse)
	return DatabaseQuery.Get(self)
		:AutoRelease()
end

---Gets a new query which is owned by the caller (the caller is responsible for calling `:Release()`).
---@return DatabaseQuery
function DatabaseTable:NewOwnedQuery()
	assert(not self._bulkInsertContext.inUse)
	return DatabaseQuery.Get(self)
end

---Pauses or unpauses query updates.
---
---Query updates should be paused while performing batch row updates to improve performance and avoid spamming callbacks.
---@param paused boolean Whether or not query updates should be paused
function DatabaseTable:SetQueryUpdatesPaused(paused)
	self._queryUpdatesPaused = self._queryUpdatesPaused + (paused and 1 or -1)
	assert(self._queryUpdatesPaused >= 0)
	if self._queryUpdatesPaused == 0 and self._queuedQueryUpdate then
		self:_UpdateQueries()
	end
end

---Returns an iterator which executes to completion with query updates paused.
---@param func? fun(obj: any, key?: any): ... The iterator function or nil to iterate exactly once
---@param obj? any The object to pass to the iterator function
---@param key? any The initial key to pass to the iterator function
---@return function
---@return any
---@return any
function DatabaseTable:WithQueryUpdatesPaused(func, obj, key)
	return private.contextManager:With(self, func, obj, key)
end

---Remove all rows.
function DatabaseTable:Truncate()
	wipe(self._uuids)
	wipe(self._uuidToDataOffsetLookup)
	wipe(self._data)
	if self._listData then
		wipe(self._listData)
		self._listData.nextIndex = 1
	end
	for _, indexList in pairs(self._indexLists) do
		wipe(indexList)
	end
	wipe(self._trigramIndexLists)
	for _, uniqueValues in pairs(self._uniques) do
		wipe(uniqueValues)
	end
	self:_UpdateQueries()
end

---Starts a bulk insert into the database.
function DatabaseTable:BulkInsertStart()
	assert(not self._bulkInsertContext.inUse)
	self._bulkInsertContext.inUse = true
	self._bulkInsertContext.firstDataIndex = nil
	self._bulkInsertContext.firstUUIDIndex = nil
	self._bulkInsertContext.partitionUUIDIndex = nil
	self._bulkInsertContext.fastNum = not self._listData and self._numStoredFields or nil -- TODO: Support this?
	if Table.Count(self._uniques) == 1 then
		local uniqueField = next(self._uniques)
		self._bulkInsertContext.fastUnique = Table.GetDistinctKey(self._storedFieldList, uniqueField)
	end
	self:SetQueryUpdatesPaused(true)
end

---Truncates and then starts a bulk insert into the database.
function DatabaseTable:TruncateAndBulkInsertStart()
	for _ in self:WithQueryUpdatesPaused() do
		self:Truncate()
		self:BulkInsertStart()
		-- Calling :BulkInsertStart() pauses query updates, so we can safely undo our pausing
	end
end

---Inserts a new row as part of the on-going bulk insert.
---@param ... any The values which make up this new row (in `schema.fieldOrder` order)
function DatabaseTable:BulkInsertNewRow(...)
	local v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13, v14, v15, v16, v17, v18, v19, v20, v21, v22, v23, extraValue = ...
	local uuid = private.GetNextUUID()
	local rowIndex = #self._data + 1
	local uuidIndex = #self._uuids + 1
	if not self._bulkInsertContext.inUse then
		error("Bulk insert hasn't been started")
	elseif extraValue ~= nil then
		error("Too many values")
	elseif not self._bulkInsertContext.firstDataIndex then
		self._bulkInsertContext.firstDataIndex = rowIndex
		self._bulkInsertContext.firstUUIDIndex = uuidIndex
	end

	local tempTbl = private.bulkInsertTemp
	tempTbl[1] = v1
	tempTbl[2] = v2
	tempTbl[3] = v3
	tempTbl[4] = v4
	tempTbl[5] = v5
	tempTbl[6] = v6
	tempTbl[7] = v7
	tempTbl[8] = v8
	tempTbl[9] = v9
	tempTbl[10] = v10
	tempTbl[11] = v11
	tempTbl[12] = v12
	tempTbl[13] = v13
	tempTbl[14] = v14
	tempTbl[15] = v15
	tempTbl[16] = v16
	tempTbl[17] = v17
	tempTbl[18] = v18
	tempTbl[19] = v19
	tempTbl[20] = v20
	tempTbl[21] = v21
	tempTbl[22] = v22
	tempTbl[23] = v23
	local numFields = #tempTbl
	if numFields ~= self._numStoredFields then
		error(format("Invalid number of values (%d, %s)", numFields, tostring(self._numStoredFields)))
	end
	self._uuidToDataOffsetLookup[uuid] = rowIndex
	self._uuids[uuidIndex] = uuid

	for i = 1, numFields do
		local field = self._storedFieldList[i]
		local value = tempTbl[i]
		local fieldType = self._fieldTypeLookup[field]
		local listFieldType = LIST_FIELD_ENTRY_TYPE_LOOKUP[fieldType]
		local fieldTypeEnumType = self._fieldTypeEnumType[field]
		if listFieldType then
			if type(value) ~= "table" then
				error(format("Expected list value, got %s", type(value)), 2)
			end
			local len = #value
			for j, v in pairs(value) do
				if type(i) ~= "number" or j < 1 or j > len then
					error("Invalid table index: "..tostring(j), 2)
				elseif type(v) ~= listFieldType then
					error(format("List (%s) entries should be of type %s, got %s", tostring(field), listFieldType, tostring(v)), 2)
				end
			end
		elseif fieldTypeEnumType then
			if not fieldTypeEnumType:HasValue(value) then
				error(format("Expected enum value (%s), got '%s'", tostring(fieldTypeEnumType), tostring(value)), 2)
			end
		elseif type(value) ~= fieldType then
			error(format("Field %s should be a %s, got %s", tostring(field), tostring(fieldType), type(value)), 2)
		end
		if listFieldType then
			self._data[rowIndex + i - 1] = self:_InsertListData(value)
		else
			self._data[rowIndex + i - 1] = value
		end
		local uniqueValues = self._uniques[field]
		if uniqueValues then
			if uniqueValues[value] ~= nil then
				error(format("A row with this unique value (%s) already exists", tostring(value)), 2)
			end
			uniqueValues[value] = uuid
		end
	end
end

---An optimized version of BulkInsertNewRow() for 7 fields with minimal error checking.
function DatabaseTable:BulkInsertNewRowFast7(v1, v2, v3, v4, v5, v6, v7, extraValue)
	local uuid = private.GetNextUUID()
	local rowIndex = #self._data + 1
	local uuidIndex = #self._uuids + 1
	if not self._bulkInsertContext.inUse then
		error("Bulk insert hasn't been started")
	elseif self._bulkInsertContext.fastNum ~= 7 then
		error("Invalid usage of fast insert")
	elseif v6 == nil or extraValue ~= nil then
		error("Wrong number of values")
	elseif not self._bulkInsertContext.firstDataIndex then
		self._bulkInsertContext.firstDataIndex = rowIndex
		self._bulkInsertContext.firstUUIDIndex = uuidIndex
	end

	self._uuidToDataOffsetLookup[uuid] = rowIndex
	self._uuids[uuidIndex] = uuid

	self._data[rowIndex] = v1
	self._data[rowIndex + 1] = v2
	self._data[rowIndex + 2] = v3
	self._data[rowIndex + 3] = v4
	self._data[rowIndex + 4] = v5
	self._data[rowIndex + 5] = v6
	self._data[rowIndex + 6] = v7

	if self._bulkInsertContext.fastUnique == 1 then
		-- the first field is always a unique (and the only unique)
		local uniqueValues = self._uniques[self._storedFieldList[1]]
		if uniqueValues[v1] ~= nil then
			error(format("A row with this unique value (%s) already exists", tostring(v1)), 2)
		end
		uniqueValues[v1] = uuid
	elseif self._bulkInsertContext.fastUnique then
		error("Invalid unique field num")
	end
end

---An optimized version of BulkInsertNewRow() for 9 fields with minimal error checking.
function DatabaseTable:BulkInsertNewRowFast9(v1, v2, v3, v4, v5, v6, v7, v8, v9, extraValue)
	local uuid = private.GetNextUUID()
	local rowIndex = #self._data + 1
	local uuidIndex = #self._uuids + 1
	if not self._bulkInsertContext.inUse then
		error("Bulk insert hasn't been started")
	elseif self._bulkInsertContext.fastNum ~= 9 then
		error("Invalid usage of fast insert")
	elseif v8 == nil or extraValue ~= nil then
		error("Wrong number of values")
	elseif not self._bulkInsertContext.firstDataIndex then
		self._bulkInsertContext.firstDataIndex = rowIndex
		self._bulkInsertContext.firstUUIDIndex = uuidIndex
	end

	self._uuidToDataOffsetLookup[uuid] = rowIndex
	self._uuids[uuidIndex] = uuid

	self._data[rowIndex] = v1
	self._data[rowIndex + 1] = v2
	self._data[rowIndex + 2] = v3
	self._data[rowIndex + 3] = v4
	self._data[rowIndex + 4] = v5
	self._data[rowIndex + 5] = v6
	self._data[rowIndex + 6] = v7
	self._data[rowIndex + 7] = v8
	self._data[rowIndex + 8] = v9

	if self._bulkInsertContext.fastUnique == 1 then
		-- the first field is always a unique (and the only unique)
		local uniqueValues = self._uniques[self._storedFieldList[1]]
		if uniqueValues[v1] ~= nil then
			error(format("A row with this unique value (%s) already exists", tostring(v1)), 2)
		end
		uniqueValues[v1] = uuid
	elseif self._bulkInsertContext.fastUnique then
		error("Invalid unique field num")
	end
end

---An optimized version of BulkInsertNewRow() for 13 fields with minimal error checking.
function DatabaseTable:BulkInsertNewRowFast13(v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13, extraValue)
	local uuid = private.GetNextUUID()
	local rowIndex = #self._data + 1
	local uuidIndex = #self._uuids + 1
	if not self._bulkInsertContext.inUse then
		error("Bulk insert hasn't been started")
	elseif self._bulkInsertContext.fastNum ~= 13 then
		error("Invalid usage of fast insert")
	elseif v12 == nil or extraValue ~= nil then
		error("Wrong number of values")
	elseif not self._bulkInsertContext.firstDataIndex then
		self._bulkInsertContext.firstDataIndex = rowIndex
		self._bulkInsertContext.firstUUIDIndex = uuidIndex
	end

	self._uuidToDataOffsetLookup[uuid] = rowIndex
	self._uuids[uuidIndex] = uuid

	self._data[rowIndex] = v1
	self._data[rowIndex + 1] = v2
	self._data[rowIndex + 2] = v3
	self._data[rowIndex + 3] = v4
	self._data[rowIndex + 4] = v5
	self._data[rowIndex + 5] = v6
	self._data[rowIndex + 6] = v7
	self._data[rowIndex + 7] = v8
	self._data[rowIndex + 8] = v9
	self._data[rowIndex + 9] = v10
	self._data[rowIndex + 10] = v11
	self._data[rowIndex + 11] = v12
	self._data[rowIndex + 12] = v13

	if self._bulkInsertContext.fastUnique == 1 then
		-- the first field is always a unique (and the only unique)
		local uniqueValues = self._uniques[self._storedFieldList[1]]
		if uniqueValues[v1] ~= nil then
			error(format("A row with this unique value (%s) already exists", tostring(v1)), 2)
		end
		uniqueValues[v1] = uuid
	elseif self._bulkInsertContext.fastUnique then
		error("Invalid unique field num")
	end
end

---An optimized version of BulkInsertNewRow() for 15 fields with minimal error checking.
function DatabaseTable:BulkInsertNewRowFast15(v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13, v14, v15, extraValue)
	local uuid = private.GetNextUUID()
	local rowIndex = #self._data + 1
	local uuidIndex = #self._uuids + 1
	if not self._bulkInsertContext.inUse then
		error("Bulk insert hasn't been started")
	elseif self._bulkInsertContext.fastNum ~= 15 then
		error("Invalid usage of fast insert")
	elseif v15 == nil or extraValue ~= nil then
		error("Wrong number of values")
	elseif not self._bulkInsertContext.firstDataIndex then
		self._bulkInsertContext.firstDataIndex = rowIndex
		self._bulkInsertContext.firstUUIDIndex = uuidIndex
	end

	self._uuidToDataOffsetLookup[uuid] = rowIndex
	self._uuids[uuidIndex] = uuid

	self._data[rowIndex] = v1
	self._data[rowIndex + 1] = v2
	self._data[rowIndex + 2] = v3
	self._data[rowIndex + 3] = v4
	self._data[rowIndex + 4] = v5
	self._data[rowIndex + 5] = v6
	self._data[rowIndex + 6] = v7
	self._data[rowIndex + 7] = v8
	self._data[rowIndex + 8] = v9
	self._data[rowIndex + 9] = v10
	self._data[rowIndex + 10] = v11
	self._data[rowIndex + 11] = v12
	self._data[rowIndex + 12] = v13
	self._data[rowIndex + 13] = v14
	self._data[rowIndex + 14] = v15

	if self._bulkInsertContext.fastUnique == 1 then
		-- the first field is always a unique (and the only unique)
		local uniqueValues = self._uniques[self._storedFieldList[1]]
		if uniqueValues[v1] ~= nil then
			error(format("A row with this unique value (%s) already exists", tostring(v1)), 2)
		end
		uniqueValues[v1] = uuid
	elseif self._bulkInsertContext.fastUnique then
		error("Invalid unique field num")
	end
	return uuid
end

---Indicates that a partition should be stored at the current number of rows in the table for optimizations.
function DatabaseTable:BulkInsertPartition()
	assert(self._bulkInsertContext.inUse, "Bulk insert hasn't been started")
	assert(not self._bulkInsertContext.partitionUUIDIndex)
	self._bulkInsertContext.partitionUUIDIndex = #self._uuids
end

---Ends a bulk insert into the database.
function DatabaseTable:BulkInsertEnd()
	assert(self._bulkInsertContext.inUse)
	if self._bulkInsertContext.firstDataIndex then
		local numNewRows = #self._uuids - self._bulkInsertContext.firstUUIDIndex + 1
		local newRowRatio = numNewRows / #self._uuids
		local partitionUUIDIndex = self._bulkInsertContext.partitionUUIDIndex
		for field, indexList in pairs(self._indexLists) do
			local isSimpleIndex = partitionUUIDIndex and not self._smartMapReaderLookup[field]
			local fieldOffset = self._fieldOffsetLookup[field]
			if newRowRatio < 0.01 then
				-- We inserted less than 1% of the rows, so just insert the new index values 1 by 1
				for i = self._bulkInsertContext.firstUUIDIndex, #self._uuids do
					local uuid = self._uuids[i]
					self:_IndexListInsert(field, uuid)
				end
			else
				-- Insert the new index values
				assert(not next(private.indexTemp))
				for i = 1, #self._uuids do
					local uuid = self._uuids[i]
					if isSimpleIndex then
						private.indexTemp[uuid] = Util.ToIndexValue(self._data[self._uuidToDataOffsetLookup[uuid] + fieldOffset - 1])
					else
						private.indexTemp[uuid] = self:_GetRowIndexValue(uuid, field)
					end
					if i >= self._bulkInsertContext.firstUUIDIndex then
						indexList[i] = uuid
					end
				end
				if partitionUUIDIndex and Table.IsSortedWithValueLookup(indexList, private.indexTemp, nil, partitionUUIDIndex) then
					-- Values up to the partition are already sorted, so just sort the new values and then merge the two portions instead of sorting the entire list
					assert(not next(private.indexMergeTemp1) and not next(private.indexMergeTemp2))
					local part1 = private.indexMergeTemp1
					local part2 = private.indexMergeTemp2
					for i = 1, #indexList do
						if i <= partitionUUIDIndex then
							tinsert(part1, indexList[i])
						else
							tinsert(part2, indexList[i])
						end
					end
					Table.SortWithValueLookup(part2, private.indexTemp)
					wipe(indexList)
					Table.MergeSortedWithValueLookup(part1, part2, indexList, private.indexTemp)
					Table.WipeAndDeallocate(part1)
					Table.WipeAndDeallocate(part2)
					assert(Table.IsSortedWithValueLookup(indexList, private.indexTemp))
				else
					Table.SortWithValueLookup(indexList, private.indexTemp)
				end
				Table.WipeAndDeallocate(private.indexTemp)
			end
		end
		if self._trigramIndexField then
			if newRowRatio < 0.01 then
				-- We inserted less than 1% of the rows, so just insert the new index values 1 by 1
				for i = self._bulkInsertContext.firstUUIDIndex, #self._uuids do
					self:_TrigramIndexInsert(self._uuids[i])
				end
			else
				local trigramIndexLists = self._trigramIndexLists
				wipe(trigramIndexLists)
				assert(not next(private.indexTemp))
				assert(not next(private.usedTrigramSubStrTemp))
				for i = 1, #self._uuids do
					local uuid = self._uuids[i]
					local value = private.TrigramValueFunc(uuid, self, self._trigramIndexField)
					private.indexTemp[uuid] = value
					for word in String.SplitIterator(value, " ") do
						for j = 1, #word - 2 do
							local subStr = strsub(word, j, j + 2)
							if private.usedTrigramSubStrTemp[subStr] ~= uuid then
								private.usedTrigramSubStrTemp[subStr] = uuid
								local list = trigramIndexLists[subStr]
								if not list then
									trigramIndexLists[subStr] = { uuid }
								else
									list[#list + 1] = uuid
								end
							end
						end
					end
				end
				Table.WipeAndDeallocate(private.usedTrigramSubStrTemp)
				Table.WipeAndDeallocate(private.indexTemp)
				-- Sort all the trigram index lists
				for _, list in pairs(trigramIndexLists) do
					Table.Sort(list)
				end
			end
		end
		self:_UpdateQueries()
	end
	wipe(self._bulkInsertContext)
	self:SetQueryUpdatesPaused(false)
end

---Aborts a bulk insert into the database without adding any of the rows.
function DatabaseTable:BulkInsertAbort()
	assert(self._bulkInsertContext.inUse)
	if self._bulkInsertContext.firstDataIndex then
		-- remove all the unique values
		for i = #self._uuids, self._bulkInsertContext.firstUUIDIndex, -1 do
			local uuid = self._uuids[i]
			for field, values in pairs(self._uniques) do
				local value = self:GetRowFields(uuid, field)
				if values[value] == nil then
					error("Could not find unique values")
				end
				values[value] = nil
			end
		end

		-- remove all the UUIDs
		for i = #self._uuids, self._bulkInsertContext.firstUUIDIndex, -1 do
			local uuid = self._uuids[i]
			self._uuidToDataOffsetLookup[uuid] = nil
			self._uuids[i] = nil
		end

		-- remove all the data we inserted
		table.removemulti(self._data, self._bulkInsertContext.firstDataIndex, #self._data - self._bulkInsertContext.firstDataIndex + 1)
	end
	wipe(self._bulkInsertContext)
	self:SetQueryUpdatesPaused(false)
end

---Returns a raw iterator over all rows in the database.
---@return fun(): number, ... @Iterator with fields (index, <DB_FIELDS...>)
---@return table
---@return number
function DatabaseTable:RawIterator()
	assert(not self._listData)
	return private.RawIterator, self, 1 - self._numStoredFields
end

---Gets the number of rows in the database.
---@return number
function DatabaseTable:GetNumRows()
	return #self._data / self._numStoredFields
end

---Gets the raw database data table for highly-optimized low-level operations.
---@return table
function DatabaseTable:GetRawData()
	assert(not self._listData)
	return self._data
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@private
function DatabaseTable:_FieldIterator()
	return Table.KeyIterator(self._fieldOffsetLookup)
end

---@private
function DatabaseTable:_UUIDIterator()
	return ipairs(self._uuids)
end

---@private
function DatabaseTable:_ValidateFieldValue(field, value)
	local fieldType = self._fieldTypeLookup[field]
	if not fieldType then
		error(format("Field '%s' doesn't exist", tostring(field)), 5)
	end
	local listFieldType = LIST_FIELD_ENTRY_TYPE_LOOKUP[fieldType]
	local fieldTypeEnumType = self._fieldTypeEnumType[field]
	if listFieldType then
		local len = #value
		if type(value) ~= "table" then
			error(format("Expected list value, got %s", type(value)), 5)
		end
		for i, v in pairs(value) do
			if type(i) ~= "number" or i < 1 or i > len then
				error("Invalid table index: "..tostring(i), 5)
			elseif type(v) ~= listFieldType then
				error(format("List (%s) entries should be of type %s, got %s", tostring(field), listFieldType, tostring(v)), 5)
			end
		end
	elseif fieldTypeEnumType then
		if not fieldTypeEnumType:HasValue(value) then
			error(format("Expected enum value (%s), got '%s'", tostring(fieldTypeEnumType), tostring(value)), 2)
		end
	elseif fieldType ~= type(value) then
		error(format("Value of '%s' for field '%s' is the wrong type (expected %s)", tostring(value), tostring(field), tostring(fieldType)), 5)
	end
end

function DatabaseTable:_HasField(field)
	return self._fieldTypeLookup[field] and true or false
end

function DatabaseTable:_IsListField(field)
	return self._listData and self:_GetListFieldType(field) and true or false
end

---@private
function DatabaseTable:_GetFieldType(field)
	return self._fieldTypeLookup[field], self._fieldTypeEnumType[field]
end

---@private
function DatabaseTable:_GetListFieldType(field)
	local fieldType = self._fieldTypeLookup[field]
	if not fieldType then
		error("Invalid field: "..tostring(field))
	end
	return LIST_FIELD_ENTRY_TYPE_LOOKUP[fieldType]
end

---@private
function DatabaseTable:_IsIndex(field)
	return self._indexLists[field] and true or false
end

---@private
function DatabaseTable:_GetTrigramIndexField()
	return self._trigramIndexField
end

---@private
function DatabaseTable:_IsUnique(field)
	return self._uniques[field] and true or false
end

---@private
function DatabaseTable:_ValidateUnique(field)
	if not self._uniques[field] then
		error(format("Field '%s' is not unique", tostring(field)), 5)
	end
end

---@private
function DatabaseTable:_IndexOrUniqueFieldIterator()
	return ipairs(self._indexOrUniqueFields)
end

---@private
function DatabaseTable:_GetAllRowsByIndex(indexField)
	return self._indexLists[indexField]
end

---@private
function DatabaseTable:_IsSmartMapField(field)
	return self._smartMapReaderLookup[field] and true or false
end

---@private
function DatabaseTable:_ContainsUUID(uuid)
	return self._uuidToDataOffsetLookup[uuid] and true or false
end

---@private
function DatabaseTable:_GetListFields(result)
	if not self._listData then
		return
	end
	for field in pairs(self._fieldTypeLookup) do
		local listFieldType = self:_GetListFieldType(field)
		if listFieldType then
			result[field] = listFieldType
		end
	end
end

---@private
function DatabaseTable:_IndexListBinarySearch(indexField, indexValue, matchLowest, low, high)
	-- Optimize index value code path for simple indexes
	local indexFieldOffset = not self._smartMapReaderLookup[indexField] and self._fieldOffsetLookup[indexField] or nil
	local indexList = self._indexLists[indexField]
	low = low or 1
	high = high or #indexList
	local firstMatchLow, firstMatchHigh = nil, nil
	while low <= high do
		local mid = floor((low + high) / 2)
		local rowValue = nil
		if indexFieldOffset then
			rowValue = Util.ToIndexValue(self._data[self._uuidToDataOffsetLookup[indexList[mid]] + indexFieldOffset - 1])
		else
			rowValue = self:_GetRowIndexValue(indexList[mid], indexField)
		end
		if rowValue == indexValue then
			-- cache the first low and high values which contain a match to make future searches faster
			firstMatchLow = firstMatchLow or low
			firstMatchHigh = firstMatchHigh or high
			if matchLowest then
				-- treat this as too high as there may be lower indexes with the same value
				high = mid - 1
			else
				-- treat this as too low as there may be lower indexes with the same value
				low = mid + 1
			end
		elseif rowValue < indexValue then
			-- we're too low
			low = mid + 1
		else
			-- we're too high
			high = mid - 1
		end
	end
	return matchLowest and low or high, firstMatchLow, firstMatchHigh
end

---@private
function DatabaseTable:_GetIndexListMatchingIndexRange(indexField, indexValue)
	local lowerBound, firstMatchLow, firstMatchHigh = self:_IndexListBinarySearch(indexField, indexValue, true)
	if not firstMatchLow then
		-- we didn't find an exact match
		return
	end
	local upperBound = self:_IndexListBinarySearch(indexField, indexValue, false, firstMatchLow, firstMatchHigh)
	assert(upperBound)
	return lowerBound, upperBound
end

---@private
function DatabaseTable:_GetUniqueRow(field, value)
	return self._uniques[field][value]
end

---@private
function DatabaseTable:_RegisterQuery(query)
	tinsert(self._queries, query)
end

---@private
function DatabaseTable:_RemoveQuery(query)
	assert(Table.RemoveByValue(self._queries, query) == 1)
end

function DatabaseTable.__private:_UpdateQueries(uuid, changeContext)
	if self._queryUpdatesPaused > 0 then
		self._queuedQueryUpdate = true
	else
		self._queuedQueryUpdate = false
		-- Pause query updates while processing this one so we don't end up recursing
		for _ in self:WithQueryUpdatesPaused() do
			-- We need to mark all the queries stale first as an update callback may cause another of the queries to run which may not have yet been marked stale
			for _, query in ipairs(self._queries) do
				query:_MarkResultStale(changeContext)
			end
			for _, query in ipairs(self._queries) do
				query:_DoUpdateCallback(uuid)
			end
		end
	end
end

function DatabaseTable.__private:_IndexListInsert(field, uuid)
	local list = self._indexLists[field]
	local _, insertIndex = BinarySearch.Raw(#list, self:_GetRowIndexValue(uuid, field), private.IndexValueFunc, self, field)
	tinsert(list, insertIndex, uuid)
end

function DatabaseTable.__private:_IndexListRemove(field, uuid)
	local indexList = self._indexLists[field]
	local indexValue = self:_GetRowIndexValue(uuid, field)
	local deleteIndex = nil
	local lowIndex, highIndex = self:_GetIndexListMatchingIndexRange(field, indexValue)
	for i = lowIndex, highIndex do
		if indexList[i] == uuid then
			deleteIndex = i
			break
		end
	end
	assert(deleteIndex)
	tremove(indexList, deleteIndex)
end

function DatabaseTable.__private:_TrigramIndexInsert(uuid)
	local field = self._trigramIndexField
	local indexValue = private.TrigramValueFunc(uuid, self, field)
	assert(not next(private.usedTrigramSubStrTemp))
	for word in String.SplitIterator(indexValue, " ") do
		for i = 1, #word - 2 do
			local subStr = strsub(word, i, i + 2)
			if not private.usedTrigramSubStrTemp[subStr] then
				private.usedTrigramSubStrTemp[subStr] = true
				local list = self._trigramIndexLists[subStr]
				if not list then
					self._trigramIndexLists[subStr] = { uuid }
				else
					local _, insertIndex = BinarySearch.Table(list, uuid)
					tinsert(list, insertIndex, uuid)
				end
			end
		end
	end
	Table.WipeAndDeallocate(private.usedTrigramSubStrTemp)
end

function DatabaseTable.__private:_TrigramIndexRemove(uuid, prevValue)
	if #prevValue <= 3 then
		return
	end
	-- Get all the previous sub-strings to remove from
	assert(not next(private.usedTrigramSubStrTemp))
	for word in String.SplitIterator(prevValue, " ") do
		for i = 1, #word - 2 do
			local subStr = strsub(word, i, i + 2)
			private.usedTrigramSubStrTemp[subStr] = true
		end
	end
	for subStr in pairs(private.usedTrigramSubStrTemp) do
		Table.RemoveByValue(self._trigramIndexLists[subStr], uuid)
	end
	Table.WipeAndDeallocate(private.usedTrigramSubStrTemp)
end

function DatabaseTable.__private:_UpdateFields(uuid, changeContext)
	-- Cache the min index within the index lists for the old values to make removing from the index faster
	assert(not next(private.indexTemp))
	local oldIndexMinIndex = private.indexTemp
	for indexField in pairs(self._indexLists) do
		if changeContext[indexField] ~= nil then
			local prevValue = self:_GetRowField(uuid, indexField)
			oldIndexMinIndex[indexField] = self:_IndexListBinarySearch(indexField, Util.ToIndexValue(prevValue), true)
		end
	end
	-- Cache the previous value for unique fields
	assert(not next(private.uniqueTemp))
	local prevUniqueValue = private.uniqueTemp
	for field in pairs(self._uniques) do
		if changeContext[field] ~= nil then
			prevUniqueValue[field] = self:_GetRowField(uuid, field)
		end
	end
	local prevTrigramValue = self._trigramIndexField and changeContext[self._trigramIndexField] and private.TrigramValueFunc(uuid, self, self._trigramIndexField)
	local index = self._uuidToDataOffsetLookup[uuid]
	for i = 1, self._numStoredFields do
		local field = self._storedFieldList[i]
		if changeContext[field] ~= nil then
			if self:_IsListField(field) then
				self._data[index + i - 1] = self:_InsertListData(changeContext[field])
			else
				self._data[index + i - 1] = changeContext[field]
			end
		end
	end
	local changedIndexUnique = false
	for indexField, indexList in pairs(self._indexLists) do
		if changeContext[indexField] ~= nil or (self:_IsSmartMapField(indexField) and changeContext[self._smartMapInputLookup[indexField]] ~= nil) then
			-- remove and re-add row to the index list since the index value changed
			if oldIndexMinIndex[indexField] then
				local deleteIndex = nil
				for i = oldIndexMinIndex[indexField], #indexList do
					if indexList[i] == uuid then
						deleteIndex = i
						break
					end
				end
				assert(deleteIndex)
				tremove(indexList, deleteIndex)
			else
				Table.RemoveByValue(indexList, uuid)
			end
			self:_IndexListInsert(indexField, uuid)
			changedIndexUnique = true
		end
	end
	Table.WipeAndDeallocate(oldIndexMinIndex)
	if self._trigramIndexField and changeContext[self._trigramIndexField] ~= nil then
		self:_TrigramIndexRemove(uuid, prevTrigramValue)
		self:_TrigramIndexInsert(uuid)
	end
	for field, uniqueValues in pairs(self._uniques) do
		if changeContext[field] ~= nil then
			local prevValue = prevUniqueValue[field]
			assert(uniqueValues[prevValue] == uuid)
			uniqueValues[prevValue] = nil
			uniqueValues[self:_GetRowField(uuid, field)] = uuid
			changedIndexUnique = true
		end
	end
	Table.WipeAndDeallocate(prevUniqueValue)
	if not changedIndexUnique then
		self:_UpdateQueries(uuid, changeContext)
	else
		self:_UpdateQueries()
	end
end

function DatabaseTable.__private:_GetRowIndexValue(uuid, field)
	return Util.ToIndexValue(self:_GetRowField(uuid, field))
end

---@private
function DatabaseTable:_GetTrigramIndexMatchingRows(value, result)
	value = strlower(value)
	assert(not next(private.usedTrigramSubStrTemp) and not next(private.indexTemp))
	local matchingLists = private.indexTemp
	for word in String.SplitIterator(value, " ") do
		for i = 1, #word - 2 do
			local subStr = strsub(word, i, i + 2)
			if not self._trigramIndexLists[subStr] then
				-- this value doesn't match anything
				Table.WipeAndDeallocate(matchingLists)
				Table.WipeAndDeallocate(private.usedTrigramSubStrTemp)
				return
			end
			if not private.usedTrigramSubStrTemp[subStr] then
				private.usedTrigramSubStrTemp[subStr] = true
				tinsert(matchingLists, self._trigramIndexLists[subStr])
			end
		end
	end
	Table.WipeAndDeallocate(private.usedTrigramSubStrTemp)
	Table.GetCommonValuesSorted(matchingLists, result)
	Table.WipeAndDeallocate(matchingLists)
end

function DatabaseTable.__private:_HandleSmartMapReaderUpdate(reader, changes)
	local fieldName = private.smartMapReaderFieldLookup[reader]
	if fieldName == self._trigramIndexField then
		error("Smart map field cannot be part of a trigram index")
	elseif reader ~= self._smartMapReaderLookup[fieldName] then
		error("Invalid smart map context")
	end

	local indexList = self._indexLists[fieldName]
	if indexList then
		-- Re-build the index
		wipe(indexList)
		assert(not next(private.indexTemp))
		for i, uuid in ipairs(self._uuids) do
			indexList[i] = uuid
			private.indexTemp[uuid] = self:_GetRowIndexValue(uuid, fieldName)
		end
		Table.SortWithValueLookup(indexList, private.indexTemp)
		Table.WipeAndDeallocate(private.indexTemp)
	end

	local uniqueValues = self._uniques[fieldName]
	if uniqueValues then
		for key, prevValue in pairs(changes) do
			local uuid = uniqueValues[prevValue]
			assert(uuid)
			uniqueValues[prevValue] = nil
			uniqueValues[reader[key]] = uuid
		end
	end

	self:_UpdateQueries()
end

function DatabaseTable.__private:_InsertListData(value)
	local dataIndex = self._listData.nextIndex
	self._listData[self._listData.nextIndex] = #value
	for j = 1, #value do
		self._listData[self._listData.nextIndex + j] = value[j]
	end
	self._listData.nextIndex = self._listData.nextIndex + #value + 1
	return dataIndex
end

function DatabaseTable.__private:_DeleteRowHelper(uuid)
	-- Lookup the index of the row being deleted
	local uuidIndex = ((self._uuidToDataOffsetLookup[uuid] - 1) / self._numStoredFields) + 1
	local rowIndex = self._uuidToDataOffsetLookup[uuid]
	assert(rowIndex)

	-- Get the index of the last row
	local lastUUIDIndex = #self._data / self._numStoredFields
	local lastRowIndex = #self._data - self._numStoredFields + 1
	assert(lastRowIndex > 0 and lastUUIDIndex > 0)

	-- Remove this row from both lookups
	self._uuidToDataOffsetLookup[uuid] = nil

	if self._listData then
		-- Remove any list field data for this row
		for field in pairs(self._fieldTypeLookup) do
			if self:_GetListFieldType(field) then
				local fieldOffset = self._fieldOffsetLookup[field]
				local dataIndex = self._data[rowIndex + fieldOffset - 1]
				local len = self._listData[dataIndex]
				for i = 0, len do
					self._listData[dataIndex + i] = nil
				end
			end
		end
	end

	if rowIndex == lastRowIndex then
		-- This is the last row so just remove it
		table.removemulti(self._data, #self._data - self._numStoredFields + 1, self._numStoredFields)
		assert(uuidIndex == #self._uuids)
		self._uuids[#self._uuids] = nil
	else
		-- This row is in the middle, so move the last row into this slot
		local moveRowUUID = tremove(self._uuids)
		self._uuids[uuidIndex] = moveRowUUID
		self._uuidToDataOffsetLookup[moveRowUUID] = rowIndex
		for i = self._numStoredFields, 1, -1 do
			local moveDataIndex = lastRowIndex + i - 1
			assert(moveDataIndex == #self._data)
			self._data[rowIndex + i - 1] = self._data[moveDataIndex]
			tremove(self._data)
		end
	end
end

function DatabaseTable:_GetRowField(uuid, field)
	local smartMapReader = self._smartMapReaderLookup[field]
	if smartMapReader then
		return smartMapReader[self:_GetRowField(uuid, self._smartMapInputLookup[field])]
	end
	local dataOffset = self._uuidToDataOffsetLookup[uuid]
	local fieldOffset = self._fieldOffsetLookup[field]
	if not dataOffset then
		error("Invalid UUID: "..tostring(uuid))
	elseif not fieldOffset then
		error("Invalid field: "..tostring(field))
	end
	local result = self._data[dataOffset + fieldOffset - 1]
	if result == nil then
		error("Failed to get row data")
	end
	if self:_IsListField(field) then
		local len = self._listData[result]
		return Iterator.Acquire(private.ListDataIterator, self._listData, result, result + len)
	else
		return result
	end
end

function DatabaseTable:_GetRowSimpleFields(uuid, ...)
	local dataOffset = self._uuidToDataOffsetLookup[uuid]
	if not dataOffset then
		error("Invalid UUID: "..tostring(uuid))
	end
	dataOffset = dataOffset - 1
	-- Get up to 4 simple (non-list, non-SmartMap) fields at a time - recursing as needed for more
	local numFields = select("#", ...)
	local field1, field2, field3, field4 = ...
	local value1 = numFields >= 1 and self._data[dataOffset + self._fieldOffsetLookup[field1]]
	local value2 = numFields >= 2 and self._data[dataOffset + self._fieldOffsetLookup[field2]]
	local value3 = numFields >= 3 and self._data[dataOffset + self._fieldOffsetLookup[field3]]
	local value4 = numFields >= 4 and self._data[dataOffset + self._fieldOffsetLookup[field4]]
	if numFields == 1 then
		if value1 == nil then
			error("Failed to get row data")
		end
		return value1
	elseif numFields == 2 then
		if value1 == nil or value2 == nil then
			error("Failed to get row data")
		end
		return value1, value2
	elseif numFields == 3 then
		if value1 == nil or value2 == nil or value3 == nil then
			error("Failed to get row data")
		end
		return value1, value2, value3
	elseif numFields >= 4 then
		if value1 == nil or value2 == nil or value3 == nil or value4 == nil then
			error("Failed to get row data")
		end
		if numFields > 4 then
			return value1, value2, value3, value4, self:_GetRowSimpleFields(uuid, select(5, ...))
		else
			return value1, value2, value3, value4
		end
	else
		error("Invalid number of fields")
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.RawIterator(db, index)
	index = index + db._numStoredFields
	if index > #db._data then
		return
	end
	return index, unpack(db._data, index, index + db._numStoredFields - 1)
end

function private.GetNextUUID()
	private.lastUUID = private.lastUUID - 1
	return private.lastUUID
end

function private.IndexValueFunc(index, db, field)
	local uuid = db._indexLists[field][index]
	return db:_GetRowIndexValue(uuid, field)
end

function private.TrigramValueFunc(uuid, db, field)
	return strlower(db:_GetRowField(uuid, field))
end

function private.ListDataIterator(tbl, index, maxIndex)
	index = index + 1
	if index > maxIndex then
		return
	end
	return index, tbl[index]
end
