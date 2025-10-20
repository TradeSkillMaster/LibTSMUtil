-- ------------------------------------------------------------------------------ --
--                                   LibTSMUtil                                   --
--                 https://github.com/TradeSkillMaster/LibTSMUtil                 --
--         Licensed under the MIT license. See LICENSE.txt for more info.         --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local DatabaseQuery = LibTSMUtil:DefineClassType("DatabaseQuery")
local Util = LibTSMUtil:Include("Database.Util")
local QueryClause = LibTSMUtil:IncludeClassType("DatabaseQueryClause")
local ObjectPool = LibTSMUtil:IncludeClassType("ObjectPool")
local Reactive = LibTSMUtil:Include("Reactive")
local EnumType = LibTSMUtil:Include("BaseType.EnumType")
local Iterator = LibTSMUtil:Include("BaseType.Iterator")
local Table = LibTSMUtil:Include("Lua.Table")
local Vararg = LibTSMUtil:Include("Lua.Vararg")
local Hash = LibTSMUtil:Include("Util.Hash")
local private = {
	objectPool = ObjectPool.New("DATABASE_QUERIES", DatabaseQuery, 1),
	smartMapReaderContext = {},
	uuidDiffContext = {
		inUse = false,
		insert = {},
		remove = {},
		result = {},
		uuids = {},
	},
	resultTemp = {},
	sortTemp = {},
}
local HASH_VIRTUAL_FIELD_FUNC = newproxy(true)
local ITERATOR_STATE = EnumType.New("DB_QUERY_ITER_STATE", {
	IDLE = EnumType.NewValue(),
	IN_PROGRESS = EnumType.NewValue(),
	IN_PROGRESS_CAN_ABORT = EnumType.NewValue(),
	PENDING_ABORT = EnumType.NewValue(),
	ABORTED = EnumType.NewValue(),
})
local JOIN_TYPE = EnumType.New("DB_QUERY_JOIN_TYPE", {
	INNER = EnumType.NewValue(),
	LEFT = EnumType.NewValue(),
	AGGREGATE_SUM = EnumType.NewValue(),
})
local OPTIMIZAITON_RESULT = EnumType.New("DB_QUERY_OPTIMIZATION_RESULT", {
	NONE = EnumType.NewValue(),
	EMPTY = EnumType.NewValue(),
	UNIQUE = EnumType.NewValue(),
	INDEX = EnumType.NewValue(),
	TRIGRAM = EnumType.NewValue(),
	ORDER_BY = EnumType.NewValue(),
	INDEX_AND_ORDER_BY = EnumType.NewValue(),
})
local RESULT_STATE = EnumType.New("DB_QUERY_RESULT_STATE", {
	WIPED = EnumType.NewValue(),
	STALE = EnumType.NewValue(),
	HAS_COUNT = EnumType.NewValue(),
	POPULATED = EnumType.NewValue(),
	DONE = EnumType.NewValue(),
})
local EXECUTE_TYPE = EnumType.New("DB_QUERY_EXECUTE_TYPE", {
	COMPLETE = EnumType.NewValue(),
	UNORDERED = EnumType.NewValue(),
	COUNT_ONLY = EnumType.NewValue(),
})
local ITERATOR_TYPE = EnumType.New("DB_QUERY_ITERATOR_TYPE", {
	UNOPTIMIZED = EnumType.NewValue(),
	NO_FIELDS = EnumType.NewValue(),
	LOCAL_SIMPLE_FIELDS = EnumType.NewValue(),
	LOCAL_FIELDS = EnumType.NewValue(),
})

---@diagnostic disable: invisible



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Gets a query object.
---@param db DatabaseTable The database table to query
---@return DatabaseQuery
function DatabaseQuery.__static.Get(db)
	local clause = private.objectPool:Get() ---@type DatabaseQuery
	clause:_Acquire(db)
	return clause
end



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function DatabaseQuery.__private:__init()
	self._db = nil ---@type DatabaseTable
	self._rootClause = nil
	self._currentClause = nil
	self._orderBy = {}
	self._orderByAscending = {}
	self._distinct = nil
	self._updateCallback = nil
	self._updateCallbackContext = nil
	self._updatesPaused = 0
	self._queuedUpdate = false
	self._inUpdateCallback = false
	self._iteratorState = ITERATOR_STATE.IDLE
	self._iteratorType = ITERATOR_TYPE.UNOPTIMIZED
	self._iteratorIndex = nil
	self._optimization = {
		result = nil,
		field = nil,
		value1 = nil,
		value2 = nil,
		strict = nil,
	}
	self._result = {
		count = 0,
	}
	self._iterDistinctUsed = {}
	self._autoRelease = false
	self._autoPause = false
	self._resultState = RESULT_STATE.WIPED
	self._joinTypes = {}
	self._joinDBs = {}
	self._joinFields = {}
	self._joinForeignFields = {}
	self._aggregateJoinQueries = {} ---@type DatabaseQuery[]
	self._virtualFieldFunc = {}
	self._virtualFieldArgField = {}
	self._virtualFieldType = {}
	self._virtualFieldDefault = {}
	self._genericSortWrapper = function(a, b)
		return private.DatabaseQuerySortGeneric(self, a, b)
	end
	self._singleSortWrapper = function(a, b)
		return private.DatabaseQuerySortSingle(self, a, b, self._orderByAscending[1])
	end
	self._secondarySortWrapper = function(a, b)
		return private.DatabaseQuerySortSingle(self, a, b, self._orderByAscending[2])
	end
	self._sortValueCache = {}
	self._resultDependencies = {}
	self._stream = Reactive.GetStream(function() return nil end)
end

function DatabaseQuery.__private:_Acquire(db)
	self._db = db
	self._db:_RegisterQuery(self)
	-- Implicit root AND clause
	self._rootClause = QueryClause.Get(self, nil, QueryClause.OPERATION.AND)
	self._currentClause = self._rootClause
	assert(self._resultState == RESULT_STATE.WIPED)
end

function DatabaseQuery.__private:_Release()
	assert(not self._autoRelease and not self._autoPause)
	assert(self._iteratorState == ITERATOR_STATE.IDLE and self._iteratorType == ITERATOR_TYPE.UNOPTIMIZED and self._iteratorIndex == nil)
	assert(self._stream:GetNumPublishers() == 0)
	self:_ResetDistinct()
	self:_ResetJoinsAndVirtualFields()
	self:ResetOrderBy()
	-- Remove from the database
	self._db:_RemoveQuery(self)
	self._db = nil
	self._rootClause:_Release()
	self._rootClause = nil
	self._currentClause = nil
	self._updateCallback = nil
	self._updateCallbackContext = nil
	self._updatesPaused = 0
	self._queuedUpdate = false
	self._inUpdateCallback = false
	wipe(self._iterDistinctUsed)
	self._autoRelease = false
	self._autoPause = false
	self:_WipeResults()
	self._resultState = RESULT_STATE.WIPED
	wipe(self._resultDependencies)
	private.objectPool:Recycle(self)
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Releases the database query.
---
---The database query object will be recycled and must not be accessed after calling this method.
---@param abortIterator? boolean Abort any in-progress iterator
function DatabaseQuery:Release(abortIterator)
	assert(not self._autoRelease)
	if abortIterator then
		self._iteratorState = ITERATOR_STATE.IDLE
		self._iteratorType = ITERATOR_TYPE.UNOPTIMIZED
		self._iteratorIndex = nil
	end
	local dbToUnpause = nil
	if self._autoPause then
		self._autoPause = false
		dbToUnpause = self._db
	end
	self:_Release()
	if dbToUnpause then
		dbToUnpause:SetQueryUpdatesPaused(false)
	end
end

---Adds a virtual field to the query.
---@param field string The name of the new virtual field
---@param fieldType string The type of the virtual field
---@param func fun(...: any) A function which takes the arg field(s) and returns the value of the virtual field
---@param argField string|string[] The field (or list of fields) to pass into the function
---@param defaultValue? any The default value to use if the function returns nil
---@return DatabaseQuery
function DatabaseQuery:VirtualField(field, fieldType, func, argField, defaultValue)
	if self._currentClause:_IgnoringSubClauses() then
		return self
	end
	if self:_HasField(field) or self._virtualFieldFunc[field] then
		error("Field already exists: "..tostring(field))
	elseif type(func) ~= "function" then
		error("Invalid func: "..tostring(func))
	elseif fieldType ~= "number" and fieldType ~= "string" and fieldType ~= "boolean" then
		error("Field type must be string, number, or boolean")
	elseif defaultValue ~= nil and type(defaultValue) ~= fieldType then
		error("Invalid defaultValue type: "..tostring(defaultValue))
	end
	if type(argField) == "table" then
		for i = 1, #argField do
			if not self:_HasField(argField[i]) then
				error("Arg field doesn't exist: "..tostring(argField[i]))
			end
		end
	else
		if not argField or not self:_HasField(argField) then
			error("Arg field doesn't exist: "..tostring(argField))
		end
	end
	self:_NewVirtualField(field, func, argField, fieldType, defaultValue)
	return self
end

---Adds a virtual field with a smart map.
---@param field string The name of the new virtual field
---@param map SmartMap The smart map
---@param inputFieldName string The field to use as the input to the smart map
---@return DatabaseQuery
function DatabaseQuery:VirtualSmartMapField(field, map, inputFieldName)
	if self._currentClause:_IgnoringSubClauses() then
		return self
	end
	if self:_HasField(field) or self._virtualFieldFunc[field] then
		error("Field already exists: "..tostring(field))
	elseif self:_GetFieldType(inputFieldName) ~= map:GetKeyType() then
		error("Invalid input field type or input field doesn't exist: "..tostring(inputFieldName))
	elseif self:_GetListFieldType(inputFieldName) then
		error("Cannot use list fields as input")
	end
	self:_NewVirtualField(field, self:_GetSmartMapReader(map), inputFieldName, map:GetValueType(), nil)
	return self
end

---Adds a virtual field which is the hash of a list of other fields.
---@param field string The name of the new virtual field
---@param hashFields string[] The list of fields to calculate the hash of (NOTE: this reference must remain valid and constant for the lifecycle of the query)
---@return DatabaseQuery
function DatabaseQuery:VirtualHashField(field, hashFields)
	if self._currentClause:_IgnoringSubClauses() then
		return self
	end
	if self:_HasField(field) or self._virtualFieldFunc[field] then
		error("Field already exists: "..tostring(field))
	elseif #hashFields == 0 then
		error("List of hash fields is empty")
	end
	for _, hashField in ipairs(hashFields) do
		if not self:_HasField(hashField) then
			error("Field does not exist: "..tostring(hashField))
		elseif self:_GetListFieldType(hashField) then
			error("Cannot use list fields for hashing: "..tostring(hashFields))
		end
	end
	self:_NewVirtualField(field, HASH_VIRTUAL_FIELD_FUNC, hashFields, "number", nil)
	return self
end

---Where a field equals a value.
---@param field string The name of the field
---@param value any The value to compare to
---@param otherField? string The name of the other field to compare with
---@return DatabaseQuery
function DatabaseQuery:Equal(field, value, otherField)
	if self._currentClause:_IgnoringSubClauses() then
		return self
	end
	self:_ValidateEqualityValue(field, value, otherField)
	self:_NewClause(QueryClause.OPERATION.EQUAL, field, value, otherField)
	return self
end

---Where a field does not equals a value.
---@param field string The name of the field
---@param value any The value to compare to
---@param otherField? string The name of the other field to compare with
---@return DatabaseQuery
function DatabaseQuery:NotEqual(field, value, otherField)
	if self._currentClause:_IgnoringSubClauses() then
		return self
	end
	self:_ValidateEqualityValue(field, value, otherField)
	self:_NewClause(QueryClause.OPERATION.NOT_EQUAL, field, value, otherField)
	return self
end

---Where a field is less than a value.
---@param field string The name of the field
---@param value any The value to compare to
---@param otherField? string The name of the other field to compare with
---@return DatabaseQuery
function DatabaseQuery:LessThan(field, value, otherField)
	if self._currentClause:_IgnoringSubClauses() then
		return self
	end
	self:_ValidateComparisonValue(field, value, otherField)
	self:_NewClause(QueryClause.OPERATION.LESS, field, value, otherField)
	return self
end

---Where a field is less than or equal to a value.
---@param field string The name of the field
---@param value any The value to compare to
---@param otherField? string The name of the other field to compare with
---@return DatabaseQuery
function DatabaseQuery:LessThanOrEqual(field, value, otherField)
	if self._currentClause:_IgnoringSubClauses() then
		return self
	end
	self:_ValidateComparisonValue(field, value, otherField)
	self:_NewClause(QueryClause.OPERATION.LESS_OR_EQUAL, field, value, otherField)
	return self
end

---Where a field is greater than a value.
---@param field string The name of the field
---@param value any The value to compare to
---@param otherField? string The name of the other field to compare with
---@return DatabaseQuery
function DatabaseQuery:GreaterThan(field, value, otherField)
	if self._currentClause:_IgnoringSubClauses() then
		return self
	end
	self:_ValidateComparisonValue(field, value, otherField)
	self:_NewClause(QueryClause.OPERATION.GREATER, field, value, otherField)
	return self
end

---Where a field is greater than or equal to a value.
---@param field string The name of the field
---@param value any The value to compare to
---@param otherField? string The name of the other field to compare with
---@return DatabaseQuery
function DatabaseQuery:GreaterThanOrEqual(field, value, otherField)
	if self._currentClause:_IgnoringSubClauses() then
		return self
	end
	self:_ValidateComparisonValue(field, value, otherField)
	self:_NewClause(QueryClause.OPERATION.GREATER_OR_EQUAL, field, value, otherField)
	return self
end

---Where a string field matches a pattern.
---@param field string The name of the field
---@param value string The pattern to match
---@return DatabaseQuery
function DatabaseQuery:Matches(field, value)
	if self._currentClause:_IgnoringSubClauses() then
		return self
	end
	assert(value ~= Util.CONSTANTS.BOUND_QUERY_PARAM, "This method does not support bound values")
	assert(self:_GetFieldType(field) == "string" and type(value) == "string")
	self:_NewClause(QueryClause.OPERATION.MATCHES, field, strlower(value))
	return self
end

---Where a string field contains a substring.
---@param field string The name of the field
---@param value string The substring to match
---@return DatabaseQuery
function DatabaseQuery:Contains(field, value)
	if self._currentClause:_IgnoringSubClauses() then
		return self
	end
	assert(value ~= Util.CONSTANTS.BOUND_QUERY_PARAM, "This method does not support bound values")
	assert(self:_GetFieldType(field) == "string" and type(value) == "string")
	self:_NewClause(QueryClause.OPERATION.CONTAINS, field, strlower(value))
	return self
end

---Where a string field starts with a substring.
---@param field string The name of the field
---@param value string The substring to match
---@return DatabaseQuery
function DatabaseQuery:StartsWith(field, value)
	if self._currentClause:_IgnoringSubClauses() then
		return self
	end
	assert(value ~= Util.CONSTANTS.BOUND_QUERY_PARAM, "This method does not support bound values")
	assert(self:_GetFieldType(field) == "string" and type(value) == "string")
	self:_NewClause(QueryClause.OPERATION.STARTS_WITH, field, strlower(value))
	return self
end

---Where a foreign field (obtained via a left join) is nil.
---@param field string The name of the field
---@return DatabaseQuery
function DatabaseQuery:IsNil(field)
	if self._currentClause:_IgnoringSubClauses() then
		return self
	end
	assert(not self:_GetListFieldType(field), "Cannot use this method on list fields")
	assert(self:_GetJoinType(field) == JOIN_TYPE.LEFT, "Must be a left join")
	self:_NewClause(QueryClause.OPERATION.IS_NIL, field)
	return self
end

---Where a foreign field (obtained via a left join) is not nil.
---@param field string The name of the field
---@return DatabaseQuery
function DatabaseQuery:IsNotNil(field)
	if self._currentClause:_IgnoringSubClauses() then
		return self
	end
	assert(not self:_GetListFieldType(field), "Cannot use this method on list fields")
	assert(self:_GetJoinType(field) == JOIN_TYPE.LEFT, "Must be a left join")
	self:_NewClause(QueryClause.OPERATION.IS_NOT_NIL, field)
	return self
end

---A query clause which uses a function.
---@param field string The name of the field
---@param func fun(value: any, arg?: any): boolean The function which gets passed the field value and returns whether or not the query results should include it
---@param arg? any An extra argument to pass to the function
---@return DatabaseQuery
function DatabaseQuery:Function(field, func, arg)
	if self._currentClause:_IgnoringSubClauses() then
		return self
	end
	assert(type(func) == "function")
	self:_NewClause(QueryClause.OPERATION.FUNCTION, field, func, arg)
	return self
end

---Where a field exists as a key within a table.
---@param field string The name of the field
---@param value table<string,any> The table to check against
---@return DatabaseQuery
function DatabaseQuery:InTable(field, value)
	if self._currentClause:_IgnoringSubClauses() then
		return self
	end
	assert(value ~= Util.CONSTANTS.BOUND_QUERY_PARAM and value ~= Util.CONSTANTS.OTHER_FIELD_QUERY_PARAM, "This method does not support indirect values")
	assert(not self:_GetListFieldType(field), "Cannot use this method on list fields")
	assert(type(value) == "table")
	self:_NewClause(QueryClause.OPERATION.IN_TABLE, field, value)
	return self
end

---Where a field does not exists as a key within a table.
---@param field string The name of the field
---@param value table The table to check against
---@return DatabaseQuery
function DatabaseQuery:NotInTable(field, value)
	if self._currentClause:_IgnoringSubClauses() then
		return self
	end
	assert(value ~= Util.CONSTANTS.BOUND_QUERY_PARAM and value ~= Util.CONSTANTS.OTHER_FIELD_QUERY_PARAM, "This method does not support indirect values")
	assert(not self:_GetListFieldType(field), "Cannot use this method on list fields")
	assert(type(value) == "table")
	self:_NewClause(QueryClause.OPERATION.NOT_IN_TABLE, field, value)
	return self
end

---Where a list field contains a value.
---@param field string The name of the list field
---@param value string The value to check against
---@return DatabaseQuery
function DatabaseQuery:ListContains(field, value)
	if self._currentClause:_IgnoringSubClauses() then
		return self
	end
	assert(value ~= Util.CONSTANTS.BOUND_QUERY_PARAM and value ~= Util.CONSTANTS.OTHER_FIELD_QUERY_PARAM, "This method does not support indirect values")
	assert(type(value) == self:_GetListFieldType(field))
	self:_NewClause(QueryClause.OPERATION.LIST_CONTAINS, field, value)
	return self
end

---Starts a nested AND clause.
---
---All of the clauses following this (until the matching `:End()`) must be true for the AND clause to be true.
---@return DatabaseQuery
function DatabaseQuery:And()
	if self._currentClause:_IsConditinal() then
		error("Can't have nested clauses inside of a conditional")
	end
	self._currentClause = self:_NewClause(QueryClause.OPERATION.AND)
	return self
end

---Starts a nested OR clause.
---
---At least one of the clauses following this (until the matching `:End()`) must be true for the OR clause to be true.
---@return DatabaseQuery
function DatabaseQuery:Or()
	if self._currentClause:_IsConditinal() then
		error("Can't have nested clauses inside of a conditional")
	end
	self._currentClause = self:_NewClause(QueryClause.OPERATION.OR)
	return self
end

---Starts a nested IF clause.
---
---Any clauses following this (until the matching `:ElseIf()` / `:Else()` / `:End()`) are only added to the query as part of the outer clause if the condition is true.
---@param condition boolean The condition
---@return DatabaseQuery
function DatabaseQuery:If(condition)
	if self._currentClause:_IsConditinal() then
		error("Can't have nested clauses inside of a conditional")
	end
	self._currentClause = self:_NewClause(QueryClause.OPERATION.IF, condition)
	return self
end

---Starts an ELSEIF clause.
---
---Any clauses following this (until the matching `:ElseIf()` / `:Else()` / `:End()`) are only added to the query as part of the outer clause if the condition is true.
---@param condition boolean The condition
---@return DatabaseQuery
function DatabaseQuery:ElseIf(condition)
	self:_NewClause(QueryClause.OPERATION.ELSEIF, condition)
	return self
end

---Starts an ELSE clause.
---
---Any clauses following this (until the matching `:End()`) are only added to the query (asart of the outer clause) if the prior IF condition is false.
---@return DatabaseQuery
function DatabaseQuery:Else()
	self:_NewClause(QueryClause.OPERATION.ELSE)
	return self
end

---Ends a nested AND/OR/IF clause.
---@return DatabaseQuery
function DatabaseQuery:End()
	assert(self._currentClause ~= self._rootClause, "No current clause to end")
	self._currentClause = self._currentClause:_EndSubClause()
	assert(self._currentClause)
	return self
end

---Performs a left join with another table.
---@param db DatabaseTable The database table to join with
---@param field string The field to join on
---@param foreignField? string The foreign field to join on (defaults to `field`)
---@return DatabaseQuery
function DatabaseQuery:LeftJoin(db, field, foreignField)
	if self._currentClause:_IsConditinal() then
		error("Can't have joins inside of conditionals")
	end
	self:_JoinHelper(JOIN_TYPE.LEFT, db, field, foreignField or field)
	return self
end

---Performs an inner join with another table.
---@param db DatabaseTable The database table to join with
---@param field string The field to join on
---@param foreignField? string The foreign field to join on (defaults to `field`)
---@return DatabaseQuery
function DatabaseQuery:InnerJoin(db, field, foreignField)
	if self._currentClause:_IsConditinal() then
		error("Can't have joins inside of conditionals")
	end
	self:_JoinHelper(JOIN_TYPE.INNER, db, field, foreignField or field)
	return self
end

---Performs an aggregate join with another table with a summed field.
---@param db DatabaseTable The database to join with
---@param field string The name of the field in the other table to join on
---@param sumField string The name of the field in the other table to sum
---@return DatabaseQuery
function DatabaseQuery:AggregateJoinSummed(db, field, sumField)
	if self._currentClause:_IsConditinal() then
		error("Can't have joins inside of conditionals")
	end
	local query = db:NewOwnedQuery()
		:Equal(field, Util.CONSTANTS.BOUND_QUERY_PARAM)
	self:_JoinHelper(JOIN_TYPE.AGGREGATE_SUM, db, field, sumField, query)
	return self
end

---Order the results by a field.
---
---This may be called multiple times to provide additional ordering constraints. The priority of the ordering will be
---descending as this method is called additional times (meaning the first OrderBy will have highest priority).
---@param field string The name of the field to order by
---@param ascending boolean Whether to order in ascending order (descending otherwise)
---@return DatabaseQuery
function DatabaseQuery:OrderBy(field, ascending)
	if self._currentClause:_IgnoringSubClauses() then
		return self
	end
	assert(ascending == true or ascending == false)
	local fieldType = self:_GetFieldType(field)
	if not fieldType then
		error(format("Field %s doesn't exist", tostring(field)))
	elseif fieldType ~= "number" and fieldType ~= "string" and fieldType ~= "boolean" then
		error(format("Cannot order by field of type %s", tostring(fieldType)))
	end
	tinsert(self._orderBy, field)
	tinsert(self._orderByAscending, ascending)
	self._resultState = RESULT_STATE.STALE
	return self
end

---Only return distinct results based on a field.
---
---This method can be used to ensure that only the first row for each distinct value of the field is returned.
---@param field string The field to ensure is distinct in the results
---@return DatabaseQuery
function DatabaseQuery:Distinct(field)
	if self._currentClause:_IgnoringSubClauses() then
		return self
	end
	assert(self:_HasField(field), format("Field %s doesn't exist within local DB", tostring(field)))
	assert(not self:_GetListFieldType(field), "Cannot use this method on list fields")
	self._distinct = field
	self._resultState = RESULT_STATE.STALE
	return self
end

---Binds parameters to a prepared query.
---
---The number of arguments should match the number of Util.CONSTANTS.BOUND_QUERY_PARAM values in the query's clauses.
---@param ... any The bound parameter values
---@return DatabaseQuery
function DatabaseQuery:BindParams(...)
	if self._currentClause:_IgnoringSubClauses() then
		return self
	end
	local numFields = select("#", ...)
	assert(self._rootClause:_BindParams(...) == numFields, "Invalid number of bound parameters")
	self._resultState = RESULT_STATE.STALE
	return self
end

---Set an update callback.
---
---This callback gets called whenever any rows in the underlying database change.
---@param func fun(db: DatabaseQuery, changedUUID: number|nil, context: any) The callback function
---@param context? any A context argument which is passed as the third argument to the callback function
---@return DatabaseQuery
function DatabaseQuery:SetUpdateCallback(func, context)
	assert(self._db)
	self._updateCallback = func
	self._updateCallbackContext = context
	return self
end

---Pauses or unpauses callbacks for query updates.
---@param paused boolean Whether or not updates should be paused
---@return DatabaseQuery
function DatabaseQuery:SetUpdatesPaused(paused)
	assert(self._db)
	self._updatesPaused = self._updatesPaused + (paused and 1 or -1)
	assert(self._updatesPaused >= 0)
	if self._updatesPaused == 0 and self._queuedUpdate then
		self:_DoUpdateCallback()
	end
	return self
end

---Marks the query to be automatically released upon completion of the next results method.
---@return DatabaseQuery
function DatabaseQuery:AutoRelease()
	assert(self._db and not self._autoRelease)
	self._autoRelease = true
	return self
end

---Automatically pauses query updates on the DB for the lifecycle of this query.
function DatabaseQuery:AutoPauseDBQueryUpdates()
	assert(self._db and not self._autoPause)
	self._autoPause = true
	self._db:SetQueryUpdatesPaused(true)
	return self
end

---Iterate over the result rows, extracting the specified fields.
---@param ... string Fields to get
---@return IteratorObject|fun(): number, ... @Iterator with fields: `uuid`, ...
function DatabaseQuery:Iterator(...)
	assert(self._iteratorIndex == nil)
	self:_Execute()
	self._iteratorState = ITERATOR_STATE.IN_PROGRESS
	self:_SetIteratorType(...)
	assert(self._iteratorIndex == nil)
	self._iteratorIndex = 0
	return Iterator.Acquire(private.QueryResultIterator, self, nil, ...)
		:SetCleanupFunc(self:__closure("_ResultIteratorCleanup"))
end

---Iterator which can be aborted if the underlying data is updated.
---
---Abortion must be handled by the caller by calling `IsIteratorAborted()` at the end of each iteration loop
---@param ... string Fields to get
---@return IteratorObject|fun(): number, ... @Iterator with fields: `uuid`, ...
function DatabaseQuery:AbortableIterator(...)
	assert(self._iteratorIndex == nil)
	self:_Execute()
	assert(not self._updateCallback and self._stream:GetNumPublishers() == 0)
	self._iteratorState = ITERATOR_STATE.IN_PROGRESS_CAN_ABORT
	self:_SetIteratorType(...)
	assert(self._iteratorIndex == nil)
	self._iteratorIndex = 0
	return Iterator.Acquire(private.QueryResultIterator, self, nil, ...)
		:SetCleanupFunc(self:__closure("_ResultIteratorCleanup"))
end

---Check if the abortable iterator has been aborted.
---@return boolean
function DatabaseQuery:IsIteratorAborted()
	if self._iteratorState == ITERATOR_STATE.IN_PROGRESS_CAN_ABORT then
		return false
	elseif self._iteratorState == ITERATOR_STATE.PENDING_ABORT then
		self._iteratorState = ITERATOR_STATE.ABORTED
		return true
	else
		error("Invalid iterator state: "..tostring(self._iteratorState))
	end
end

---Prepares a UUID diff against a previous list of UUIDs.
---
---If this function returns true, `DatabaseQuery:UUIDDiffIterator()` must be called and run to completion.
---@param oldUUIDs number[] The list of old UUIDs
---@return boolean
function DatabaseQuery:UUIDDiffPrepare(oldUUIDs)
	self:_Execute()
	local context = private.uuidDiffContext
	assert(not context.inUse)
	context.inUse = true
	if not Table.GetDiffOrdered(oldUUIDs, self._result, context.insert, context.remove) then
		context.inUse = false
		return false
	end
	-- Add the remove actions in reverse order
	while #context.remove > 0 do
		local endIndex = tremove(context.remove)
		local startIndex = endIndex
		while #context.remove > 0 and context.remove[#context.remove] == startIndex - 1 do
			startIndex = tremove(context.remove)
		end
		Table.InsertMultiple(context.result, "REMOVE", startIndex, endIndex - startIndex + 1)
		Table.InsertFrom(context.result, oldUUIDs, startIndex, endIndex)
	end

	-- Add the insert actions
	local i = 1
	while i <= #context.insert do
		local startIndex = context.insert[i]
		local endIndex = startIndex
		for j = i + 1, #context.insert do
			if context.insert[j] == endIndex + 1 then
				endIndex = endIndex + 1
			else
				break
			end
		end
		Table.InsertMultiple(context.result, "INSERT", startIndex, endIndex - startIndex + 1)
		Table.InsertFrom(context.result, self._result, startIndex, endIndex)
		i = i + endIndex - startIndex + 1
	end
	wipe(context.insert)
	return true
end

---Iterate over the diff prepared with `DatabaseQuery:UUIDDiffPrepare()`.
---@return IteratorObject|fun(): number, "REMOVE"|"INSERT", number, number[] @Iterator with fields: `index`, `action`, `startIndex`, `uuids`
function DatabaseQuery:UUIDDiffIterator()
	local context = private.uuidDiffContext
	assert(context.inUse)
	return Iterator.Acquire(private.UUIDDiffIterator, context, 1)
		:SetCleanupFunc(private.UUIDDiffIteratorCleanup)
end

---Populates a table with the results.
---@param tbl table The table to store the result in
---@param field1 string The first field to select (either the key if `field2` is provided or the value for the list)
---@param field2? string If provided, the field to use as the value with `field1` being used as the key
---@return DatabaseQuery
function DatabaseQuery:AsTable(tbl, field1, field2)
	assert(field1)
	-- Don't care about the results being sorted if we are creating a key/value table
	self:_Execute(field2 and EXECUTE_TYPE.UNORDERED or EXECUTE_TYPE.COMPLETE)
	if field2 then
		for _, uuid in ipairs(self._result) do
			local key = self:_GetResultRowData(uuid, field1)
			if key == nil or tbl[key] then
				error("Key is nil or not distinct")
			end
			tbl[key] = self:_GetResultRowData(uuid, field2)
		end
	else
		for _, uuid in ipairs(self._result) do
			tinsert(tbl, self:_GetResultRowData(uuid, field1))
		end
	end
	return self
end

---Get the number of resulting rows.
---@return number
function DatabaseQuery:Count()
	self:_Execute(EXECUTE_TYPE.COUNT_ONLY)
	local result = self._result.count
	self:_DoAutoRelease()
	return result
end

---Get if the result is not empty.
---@return boolean
function DatabaseQuery:IsNotEmpty()
	return self:Count() > 0
end

---Assert that there's a single result row and get the selected fields from it.
---@param ... string Fields to get
---@return any ...
function DatabaseQuery:GetSingleResult(...)
	self:_Execute()
	assert(self._result.count == 1)
	return self:GetNthResult(1, ...)
end

---Assert that there's a single result row and get the UUID and the selected fields from it.
---@param ... string Fields to get
---@return any ...
function DatabaseQuery:GetSingleResultWithUUID(...)
	self:_Execute()
	assert(self._result.count == 1)
	return self:GetNthResultWithUUID(1, ...)
end

---Get the selected fields from the first result row.
---@param ... string Fields to get
---@return any? ...
function DatabaseQuery:GetFirstResult(...)
	return self:GetNthResult(1, ...)
end

---Get the UUID and the selected fields from the first result row.
---@param ... string Fields to get
---@return number? uuid
---@return any? ...
function DatabaseQuery:GetFirstResultWithUUID(...)
	return self:GetNthResultWithUUID(1, ...)
end

---Get the selected fields from the n-th result row.
---@param n number The index of the result row to get
---@param ... string Fields to get
---@return any? ...
function DatabaseQuery:GetNthResult(n, ...)
	self:_Execute()
	assert(self._iteratorState == ITERATOR_STATE.IDLE)
	if self._result.count < n then
		self:_DoAutoRelease()
		return
	end
	local uuid = self._result[n]
	if not uuid or select("#", ...) == 0 then
		self:_DoAutoRelease()
		return
	else
		return self:_PassThroughAndAutoRelease(self:_GetResultRowDataFields(uuid, ...))
	end
end

---Get the UUID and the selected fields from the n-th result row.
---@param n number The index of the result row to get
---@param ... string Fields to get
---@return number? uuid
---@return any? ...
function DatabaseQuery:GetNthResultWithUUID(n, ...)
	self:_Execute()
	assert(self._iteratorState == ITERATOR_STATE.IDLE)
	if self._result.count < n then
		self:_DoAutoRelease()
		return nil
	end
	local uuid = self._result[n]
	if not uuid or select("#", ...) == 0 then
		self:_DoAutoRelease()
		return uuid
	else
		return uuid, self:_PassThroughAndAutoRelease(self:_GetResultRowDataFields(uuid, ...))
	end
end

---Get the specified fields by UUID.
---@param uuid number The UUID of the row to get
---@param ... string Fields to get
---@return ...
function DatabaseQuery:GetResultByUUID(uuid, ...)
	assert(self._resultState == RESULT_STATE.DONE)
	assert(not self._autoRelease)
	assert(self._iteratorState == ITERATOR_STATE.IDLE)
	return self:_GetResultRowDataFields(uuid, ...)
end

---Gets the minimum value of a specific field within the query results (or nil if there are no results).
---@param field string The field within the results
---@return number|nil
function DatabaseQuery:Min(field)
	self:_Execute(EXECUTE_TYPE.UNORDERED)
	local result = nil
	for _, uuid in ipairs(self._result) do
		local value = self:_GetResultRowData(uuid, field)
		result = min(result or math.huge, value)
	end
	self:_DoAutoRelease()
	return result
end

---Gets the maximum value of a specific field within the query results (or nil if there are no results).
---@param field string The field within the results
---@return number|nil
function DatabaseQuery:Max(field)
	self:_Execute(EXECUTE_TYPE.UNORDERED)
	local result = nil
	for _, uuid in ipairs(self._result) do
		local value = self:_GetResultRowData(uuid, field)
		result = max(result or -math.huge, value)
	end
	self:_DoAutoRelease()
	return result
end

---Gets the summed value of a specific field within the query results.
---@param field string The field within the results
---@return number
function DatabaseQuery:Sum(field)
	self:_Execute(EXECUTE_TYPE.UNORDERED)
	local result = 0
	for _, uuid in ipairs(self._result) do
		result = result + self:_GetResultRowData(uuid, field)
	end
	self:_DoAutoRelease()
	return result
end

---Gets the summed value of a specific field for each group within the query results.
---@param groupField string The field to group by
---@param sumField string The field to sum
---@param result table The results table
function DatabaseQuery:GroupedSum(groupField, sumField, result)
	self:_Execute(EXECUTE_TYPE.UNORDERED)
	for _, uuid in ipairs(self._result) do
		local group = self:_GetResultRowData(uuid, groupField)
		local value = self:_GetResultRowData(uuid, sumField)
		result[group] = (result[group] or 0) + value
	end
	self:_DoAutoRelease()
end

---Gets the average value of a specific field within the query results (or nil if there are no results).
---@param field string The field within the results
---@return number|nil
function DatabaseQuery:Avg(field)
	self:_Execute(EXECUTE_TYPE.UNORDERED)
	local sum = 0
	local num = self._result.count
	for _, uuid in ipairs(self._result) do
		sum = sum + self:_GetResultRowData(uuid, field)
	end
	self:_DoAutoRelease()
	return num > 0 and (sum / num) or nil
end

---Gets the sum of the products of two fields within the query results.
---@param field1 string The first field within the results
---@param field2 string The second field within the results
---@return number
function DatabaseQuery:SumOfProduct(field1, field2)
	self:_Execute(EXECUTE_TYPE.UNORDERED)
	local result = 0
	for _, uuid in ipairs(self._result) do
		local value1 = self:_GetResultRowData(uuid, field1)
		local value2 = self:_GetResultRowData(uuid, field2)
		result = result + value1 * value2
	end
	self:_DoAutoRelease()
	return result
end

---Joins the string values of a field with a given separator.
---@param field string The field within the results
---@param sep string The separator (can be any number of characters, including an empty string)
---@return string
function DatabaseQuery:JoinedString(field, sep)
	self:_Execute()
	assert(not next(private.resultTemp))
	for _, uuid in ipairs(self._result) do
		tinsert(private.resultTemp, self:_GetResultRowData(uuid, field))
	end
	local result = table.concat(private.resultTemp, sep)
	Table.WipeAndDeallocate(private.resultTemp)
	self:_DoAutoRelease()
	return result
end

---Calculates the hash of the query results (or nil if there are no results).
---@param ... string The fields from each row to hash
---@return number|nil
function DatabaseQuery:Hash(...)
	self:_Execute()
	local result = nil
	for _, uuid in ipairs(self._result) do
		for _, field in Vararg.Iterator(...) do
			result = Hash.Calculate(self:_GetResultRowData(uuid, field), result)
		end
	end
	self:_DoAutoRelease()
	return result
end

---Deletes all the result rows from the database and returns the number of rows deleted.
---@return number
function DatabaseQuery:Delete()
	local count = nil
	for _ in self._db:WithQueryUpdatesPaused() do
		self:_Execute(EXECUTE_TYPE.UNORDERED)
		count = self._result.count
		self._db:DeleteRow(self._result)
		self._resultState = RESULT_STATE.STALE
		self:_DoAutoRelease()
	end
	return count
end

---Resets the database query.
---@return DatabaseQuery
function DatabaseQuery:Reset()
	assert(self._db)
	self:_ResetDistinct()
	self:_ResetJoinsAndVirtualFields()
	self:ResetOrderBy()
	self:ResetFilters()
	self:_WipeResults()
	self._resultState = RESULT_STATE.WIPED
	return self
end

---Resets any virtual fields added to the database query.
---@return DatabaseQuery
function DatabaseQuery:ResetVirtualFields()
	assert(self._db)
	for _, func in pairs(self._virtualFieldFunc) do
		if private.smartMapReaderContext[func] then
			private.smartMapReaderContext[func].query = nil
		end
	end
	wipe(self._virtualFieldFunc)
	wipe(self._virtualFieldArgField)
	wipe(self._virtualFieldType)
	wipe(self._virtualFieldDefault)
	self._resultState = RESULT_STATE.STALE
	return self
end

---Resets any filtering clauses of the database query.
---@return DatabaseQuery
function DatabaseQuery:ResetFilters()
	self._rootClause:_Release()
	self._rootClause = QueryClause.Get(self, nil, QueryClause.OPERATION.AND)
	self._currentClause = self._rootClause
	self._resultState = RESULT_STATE.STALE
	return self
end

---Resets any ordering clauses of the database query.
---@return DatabaseQuery
function DatabaseQuery:ResetOrderBy()
	assert(self._db)
	wipe(self._orderBy)
	wipe(self._orderByAscending)
	self._resultState = RESULT_STATE.STALE
	return self
end

---Gets info on a specific order by clause.
---@param index number The index of the order by clause
---@return string? field
---@return boolean? ascending
function DatabaseQuery:GetOrderBy(index)
	assert(self._orderBy[index])
	return self._orderBy[index], self._orderByAscending[index]
end

---Gets info on the last order by clause.
---@return string? field
---@return boolean? ascending
function DatabaseQuery:GetLastOrderBy()
	assert(self._db)
	return self._orderBy[#self._orderBy], self._orderByAscending[#self._orderByAscending]
end

---Updates the last order by clause.
---@param field string The name of the field to order by
---@param ascending boolean Whether to order in ascending order (descending otherwise)
---@return DatabaseQuery
function DatabaseQuery:UpdateLastOrderBy(field, ascending)
	assert(#self._orderBy > 0)
	tremove(self._orderBy)
	tremove(self._orderByAscending)
	self:OrderBy(field, ascending)
	return self
end

---Gets a publisher for query result changes.
---@return ReactivePublisherSchema
function DatabaseQuery:Publisher()
	assert(self._db)
	return self._stream:Publisher()
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function DatabaseQuery.__private:_ValidateEqualityValue(field, value, otherField)
	local fieldType, enumFieldType = self:_GetFieldType(field)
	assert(fieldType, "Field does not exist")
	assert(not self:_GetListFieldType(field), "Cannot use this method on list fields")
	if value == Util.CONSTANTS.OTHER_FIELD_QUERY_PARAM then
		local otherFieldType, otherEnumFieldType = self:_GetFieldType(otherField)
		assert(fieldType == otherFieldType and enumFieldType == otherEnumFieldType)
	elseif value ~= Util.CONSTANTS.BOUND_QUERY_PARAM then
		if enumFieldType then
			assert(enumFieldType:HasValue(value))
		else
			assert(fieldType == type(value))
		end
	end
end

function DatabaseQuery.__private:_ValidateComparisonValue(field, value, otherField)
	local fieldType, enumFieldType = self:_GetFieldType(field)
	assert(fieldType, "Field does not exist")
	assert(not self:_GetListFieldType(field), "Cannot use this method on list fields")
	assert(not enumFieldType, "Cannot use this method on enum fields")
	if value == Util.CONSTANTS.OTHER_FIELD_QUERY_PARAM then
		assert(fieldType == self:_GetFieldType(otherField))
	elseif value ~= Util.CONSTANTS.BOUND_QUERY_PARAM then
		assert(fieldType == type(value))
	end
end

function DatabaseQuery.__private:_GetJoinType(field)
	for i, db in ipairs(self._joinDBs) do
		if db:_HasField(field) then
			return self._joinTypes[i]
		end
	end
end

function DatabaseQuery.__private:_HasField(field)
	if self._virtualFieldType[field] or self._db:_HasField(field) then
		return true
	end
	for i, db in ipairs(self._joinDBs) do
		if field == self._joinForeignFields[i] and self._joinTypes[i] == JOIN_TYPE.AGGREGATE_SUM then
			return true
		elseif db:_HasField(field) then
			return true
		end
	end
end

function DatabaseQuery.__private:_GetFieldType(field)
	local virtualFieldType = self._virtualFieldType[field]
	if virtualFieldType then
		return virtualFieldType, nil
	end
	local fieldType, enumFieldType = self._db:_GetFieldType(field)
	if fieldType then
		return fieldType, enumFieldType
	end
	for i, db in ipairs(self._joinDBs) do
		if field == self._joinForeignFields[i] and self._joinTypes[i] == JOIN_TYPE.AGGREGATE_SUM then
			return "number", nil
		else
			fieldType, enumFieldType = db:_GetFieldType(field)
			if fieldType then
				return fieldType, enumFieldType
			end
		end
	end
end

function DatabaseQuery.__private:_GetListFieldType(field)
	if self._virtualFieldType[field] then
		return nil
	end
	if self._db:_HasField(field) then
		return self._db:_GetListFieldType(field)
	end
	for _, db in ipairs(self._joinDBs) do
		if db:_HasField(field) then
			return db:_GetListFieldType(field)
		end
	end
end

---@private
function DatabaseQuery:_GetListFields(result)
	self._db:_GetListFields(result)
	for _, db in ipairs(self._joinDBs) do
		db:_GetListFields(result)
	end
end

---@private
function DatabaseQuery:_MarkResultStale(changes)
	assert(self._iteratorState == ITERATOR_STATE.IDLE or self._iteratorState == ITERATOR_STATE.IN_PROGRESS_CAN_ABORT or self._iteratorState == ITERATOR_STATE.PENDING_ABORT)
	if self._resultState == RESULT_STATE.STALE then
		-- Already marked stale
		return
	end

	if self._resultDependencies._all or not changes then
		-- Either the result depends on all fields or we weren't given a table of changed fields
		self._resultState = RESULT_STATE.STALE
	else
		-- Check if any of the fields our result is based on changed
		local singledChangedField = type(changes) == "string" and changes or nil
		if singledChangedField then
			-- Single field changed
			if self._resultDependencies[singledChangedField] then
				self._resultState = RESULT_STATE.STALE
			end
		else
			for field in pairs(changes) do
				if self._resultDependencies[field] then
					self._resultState = RESULT_STATE.STALE
					break
				end
			end
		end
	end

	if self._iteratorState == ITERATOR_STATE.IN_PROGRESS_CAN_ABORT then
		self._iteratorState = ITERATOR_STATE.PENDING_ABORT
	end
end

---@private
function DatabaseQuery:_DoUpdateCallback(uuid)
	if not self._updateCallback and self._stream:GetNumPublishers() == 0 then
		assert(self._iteratorState == ITERATOR_STATE.IDLE or self._iteratorState == ITERATOR_STATE.PENDING_ABORT)
		return
	end
	-- can't have an update callback on an abortable iterator
	assert(self._iteratorState == ITERATOR_STATE.IDLE)
	if self._updatesPaused > 0 then
		self._queuedUpdate = true
	else
		self._queuedUpdate = false
		-- Pause query updates while processing this one so we don't end up recursing
		self:SetUpdatesPaused(true)
		local updatedUUID = nil
		if self._resultState ~= RESULT_STATE.DONE or not uuid then
			updatedUUID = nil
		elseif self._db:_ContainsUUID(uuid) then
			updatedUUID = uuid
		else
			-- the UUID is from a joined DB, so see if we can easily translate it to a local UUID
			local localUUID = nil
			for i = 1, #self._joinDBs do
				local joinDB = self._joinDBs[i]
				if not self._aggregateJoinQueries[i] and joinDB:_ContainsUUID(uuid) then
					if localUUID then
						-- found more than once, so bail
						localUUID = nil
						break
					end
					local joinField = self._joinFields[i]
					local joinForeignField = self._joinForeignFields[i]
					local joinValue = joinDB:GetRowFields(uuid, joinForeignField)
					if self._db:_IsUnique(joinField) then
						localUUID = self._db:_GetUniqueRow(joinField, joinValue)
					elseif self._db:_IsIndex(joinField) then
						local lowIndex, highIndex = self._db:_GetIndexListMatchingIndexRange(joinField, Util.ToIndexValue(joinValue))
						if not lowIndex or not highIndex or lowIndex ~= highIndex then
							-- can't use this index to find a single local UUID
							break
						end
						localUUID = self._db:_GetAllRowsByIndex(joinField)[lowIndex]
					end
				end
			end
			updatedUUID = localUUID
		end
		self._inUpdateCallback = true
		self._stream:Send(updatedUUID)
		if self._updateCallback then
			self:_updateCallback(updatedUUID, self._updateCallbackContext)
		end
		self._inUpdateCallback = false
		self:SetUpdatesPaused(false)
	end
end

function DatabaseQuery.__private:_NewClause(operation, ...)
	assert(self._iteratorState == ITERATOR_STATE.IDLE)
	local newClause = QueryClause.Get(self, self._currentClause, operation, ...)
	self._currentClause:_InsertSubClause(newClause)
	self._resultState = RESULT_STATE.STALE
	return newClause
end

function DatabaseQuery.__private:_NewVirtualField(field, func, argField, fieldType, defaultValue)
	assert(self._iteratorState == ITERATOR_STATE.IDLE)
	self._virtualFieldFunc[field] = func
	self._virtualFieldArgField[field] = argField
	self._virtualFieldType[field] = fieldType
	self._virtualFieldDefault[field] = defaultValue
	self._resultState = RESULT_STATE.STALE
end

function DatabaseQuery.__private:_WipeResults()
	wipe(self._optimization)
	wipe(self._result)
	self._result.count = 0
	if self._updatesPaused > 0 and not self._inUpdateCallback then
		self._queuedUpdate = true
	end
end

function DatabaseQuery.__private:_Execute(executeType)
	executeType = executeType or EXECUTE_TYPE.COMPLETE
	assert(self._db)
	if self:_IsExecuteTypeSatisfied(executeType) then
		return
	end
	assert(self._rootClause and self._currentClause == self._rootClause, "Did not end sub-clause")
	assert(self._iteratorState == ITERATOR_STATE.IDLE)

	-- Clear the current results if needed
	if self._resultState == RESULT_STATE.STALE then
		self:_WipeResults()
		self._resultState = RESULT_STATE.WIPED
	end

	-- Run the optimization if needed
	if self._resultState == RESULT_STATE.WIPED then
		self:_Optimize()
		if self._optimization.result == OPTIMIZAITON_RESULT.INDEX and self._optimization.strict and #self._joinDBs == 0 and not self._distinct then
			self._resultState = RESULT_STATE.HAS_COUNT
			self._result.count = self._optimization.value2 - self._optimization.value1 + 1
		elseif self._optimization.result == OPTIMIZAITON_RESULT.EMPTY then
			self._resultState = RESULT_STATE.HAS_COUNT
			self._result.count = 0
		end
		if self:_IsExecuteTypeSatisfied(executeType) then
			return
		end
	end

	-- Populate the results if needed
	if self._resultState == RESULT_STATE.WIPED or self._resultState == RESULT_STATE.HAS_COUNT then
		local sortNeeded = self:_PopulateResults()
		self._resultState = RESULT_STATE.POPULATED
		if not sortNeeded then
			self:_FinalizeResults()
			self._resultState = RESULT_STATE.DONE
		end
		if self:_IsExecuteTypeSatisfied(executeType) then
			return
		end
	end

	-- Sort the results if needed
	if self._resultState == RESULT_STATE.POPULATED then
		self:_SortResults()
		self:_FinalizeResults()
		self._resultState = RESULT_STATE.DONE
	end

	assert(self:_IsExecuteTypeSatisfied(executeType))
end

function DatabaseQuery.__private:_IsExecuteTypeSatisfied(executeType)
	if executeType == EXECUTE_TYPE.COMPLETE then
		return self._resultState == RESULT_STATE.DONE
	elseif executeType == EXECUTE_TYPE.UNORDERED then
		return self._resultState == RESULT_STATE.POPULATED or self._resultState == RESULT_STATE.DONE
	elseif executeType == EXECUTE_TYPE.COUNT_ONLY then
		return self._resultState == RESULT_STATE.HAS_COUNT or self._resultState == RESULT_STATE.POPULATED or self._resultState == RESULT_STATE.DONE
	else
		error("Unexpected execute type: "..tostring(executeType))
	end
end

function DatabaseQuery.__private:_Optimize()
	wipe(self._optimization)
	-- Try to find the index with the least result rows
	local indexField, indexFirstIndex, indexLastIndex, indexIsStrict = nil, nil, nil, false
	local bestIndexDiff = math.huge
	for _, field in self._db:_IndexOrUniqueFieldIterator() do
		local valueMin, valueMax = self._rootClause:_GetIndexValue(field)
		if valueMin == nil and valueMax == nil then
			-- Continue
		elseif self._db:_IsUnique(field) and valueMin == valueMax then
			-- Unique indexes result in a single row, at which point the benefit of trying to find something better (EMPTY) is negligible
			self._optimization.result = OPTIMIZAITON_RESULT.UNIQUE
			self._optimization.field = field
			self._optimization.value1 = valueMin
			return
		elseif self._db:_IsIndex(field) then
			-- Check how many rows this index results in
			local indexList = self._db:_GetAllRowsByIndex(field)
			local firstIndex, lastIndex = nil, nil
			if valueMin and valueMax and valueMin == valueMax then
				firstIndex, lastIndex = self._db:_GetIndexListMatchingIndexRange(field, valueMin)
				if not firstIndex then
					-- There are no results within this index, so this is as good as it gets
					self._optimization.result = OPTIMIZAITON_RESULT.EMPTY
					self._optimization.field = field
					return
				end
			else
				firstIndex = valueMin and self._db:_IndexListBinarySearch(field, valueMin, true) or min(1, #indexList)
				lastIndex = valueMax and self._db:_IndexListBinarySearch(field, valueMax, false) or #indexList
			end
			local indexDiff = lastIndex - firstIndex
			if indexDiff < 0 then
				-- There are no results within this index, so this is as good as it gets
				self._optimization.result = OPTIMIZAITON_RESULT.EMPTY
				self._optimization.field = field
				return
			else
				-- NOTE: String indexes can't be strict since they are case-insensitive
				local isStrict = type(valueMin) ~= "string" and type(valueMax) ~= "string" and self._rootClause:_IsStrictIndex(field, valueMin, valueMax)
				if isStrict then
					-- Rough estimate that being able to skip the query makes each row cost 1/4 as much
					indexDiff = floor(indexDiff / 4)
				end
				if indexDiff < bestIndexDiff then
					-- This is our new best index
					indexField = field
					indexFirstIndex = firstIndex
					indexLastIndex = lastIndex
					indexIsStrict = isStrict
					bestIndexDiff = indexDiff
				end
			end
		end
	end
	if indexField then
		self._optimization.result = OPTIMIZAITON_RESULT.INDEX
		self._optimization.field = indexField
		self._optimization.value1 = indexFirstIndex
		self._optimization.value2 = indexLastIndex
		self._optimization.strict = indexIsStrict
		return
	end
	-- Try the trigram index
	local trigramIndexField = self._db:_GetTrigramIndexField()
	if trigramIndexField then
		local trigramIndexValue = self._rootClause:_GetTrigramIndexValue(trigramIndexField)
		if trigramIndexValue then
			self._optimization.result = OPTIMIZAITON_RESULT.TRIGRAM
			self._optimization.field = trigramIndexField
			self._optimization.value1 = trigramIndexValue
			return
		end
	end
	self._optimization.result = OPTIMIZAITON_RESULT.NONE
end

function DatabaseQuery.__private:_PopulateResults()
	assert(not next(self._iterDistinctUsed))

	local firstOrderBy = self._orderBy[1]
	local sortNeeded = firstOrderBy and true or false
	if self._optimization.result == OPTIMIZAITON_RESULT.EMPTY then
		sortNeeded = false
	elseif self._optimization.result == OPTIMIZAITON_RESULT.UNIQUE then
		-- We are looking for a unique row
		local uuid = self._db:_GetUniqueRow(self._optimization.field, self._optimization.value1)
		if uuid and self:_ResultShouldIncludeRow(uuid, false, #self._joinDBs, self._distinct) then
			tinsert(self._result, uuid)
			self._result.count = 1
		end
		sortNeeded = false
	elseif self._optimization.result == OPTIMIZAITON_RESULT.INDEX then
		-- We're querying on an index, so use that index to populate the result
		local isAscending = true
		if firstOrderBy and self._optimization.field == firstOrderBy then
			-- We're also ordering by this field so can skip the first OrderBy field
			self._optimization.result = OPTIMIZAITON_RESULT.INDEX_AND_ORDER_BY
			sortNeeded = #self._orderBy > 1
			isAscending = self._orderByAscending[1]
		end
		local indexList = self._db:_GetAllRowsByIndex(self._optimization.field)
		self:_AddResultRowsFromIndex(indexList, self._optimization.strict, self._optimization.value1, self._optimization.value2, isAscending, self._optimization.field)
	elseif self._optimization.result == OPTIMIZAITON_RESULT.NONE then
		if firstOrderBy and self._db:_IsIndex(firstOrderBy) then
			-- We're ordering on an index, so use that index to iterate through all the rows in order to skip the first OrderBy field
			self._optimization.result = OPTIMIZAITON_RESULT.ORDER_BY
			self._optimization.field = firstOrderBy
			sortNeeded = #self._orderBy > 1
			local isAscending = self._orderByAscending[1]
			local indexList = self._db:_GetAllRowsByIndex(firstOrderBy)
			self:_AddResultRowsFromIndex(indexList, false, 1, #indexList, isAscending)
		else
			-- No optimizations
			self:_AddResultRowsCheckAll()
		end
	elseif self._optimization.result == OPTIMIZAITON_RESULT.TRIGRAM then
		assert(not next(private.resultTemp))
		self._db:_GetTrigramIndexMatchingRows(self._optimization.value1, private.resultTemp)
		self:_AddResultRowsFromIndex(private.resultTemp, false, 1, #private.resultTemp, true)
		Table.WipeAndDeallocate(private.resultTemp)
	else
		error("Invalid optimization result: "..tostring(self._optimization.result))
	end

	wipe(self._iterDistinctUsed)
	if self._result.count ~= 0 then
		assert(self._result.count == #self._result)
	end
	self._result.count = #self._result
	return sortNeeded
end

function DatabaseQuery.__private:_SortResults()
	local skipFirstOrderBy = self._optimization.result == OPTIMIZAITON_RESULT.INDEX_AND_ORDER_BY or self._optimization.result == OPTIMIZAITON_RESULT.ORDER_BY
	if #self._orderBy == 1 then
		assert(not skipFirstOrderBy)
		assert(not next(self._sortValueCache))
		for _, uuid in ipairs(self._result) do
			self._sortValueCache[uuid] = Util.ToIndexValue(self:_GetResultRowData(uuid, self._orderBy[1]))
		end
		Table.Sort(self._result, self._singleSortWrapper)
		wipe(self._sortValueCache)
	elseif skipFirstOrderBy and #self._orderBy == 2 then
		-- The result is already ordered by the first orderBy field, so iterate through it
		-- and sort each group of results where the first orderBy field is the same
		assert(not next(self._sortValueCache) and not next(private.sortTemp))
		local subsetLen = 0
		local currentSortValue = nil
		for i = 1, #self._result do
			local uuid = self._result[i]
			local sortValue = Util.ToIndexValue(self:_GetResultRowData(uuid, self._orderBy[1]))
			self._sortValueCache[uuid] = Util.ToIndexValue(self:_GetResultRowData(uuid, self._orderBy[2]))
			if sortValue ~= currentSortValue then
				-- The first sort value changed, so we're now in a new group
				if subsetLen > 1 then
					-- Sort the previous group
					Table.Sort(private.sortTemp, self._secondarySortWrapper)
					-- Update the corresponding results
					local offset = i - subsetLen - 1
					for j = 1, subsetLen do
						self._result[offset + j] = private.sortTemp[j]
					end
				end
				subsetLen = 0
				wipe(private.sortTemp)
				currentSortValue = sortValue
			end
			subsetLen = subsetLen + 1
			private.sortTemp[subsetLen] = uuid
		end
		if subsetLen > 1 then
			-- Sort the previous group
			Table.Sort(private.sortTemp, self._secondarySortWrapper)
			-- Update the corresponding results
			local offset = #self._result - subsetLen
			for i = 1, subsetLen do
				self._result[offset + i] = private.sortTemp[i]
			end
		end
		Table.WipeAndDeallocate(private.sortTemp)
		wipe(self._sortValueCache)
	else
		Table.Sort(self._result, self._genericSortWrapper)
	end
end

function DatabaseQuery.__private:_FinalizeResults()
	-- Update the dependencies
	wipe(self._resultDependencies)
	if next(self._virtualFieldFunc) then
		self._resultDependencies._all = true
	else
		for i = 1, #self._joinFields do
			self._resultDependencies[self._joinFields[i]] = true
		end
		for i = 1, #self._orderBy do
			self._resultDependencies[self._orderBy[i]] = true
		end
		if self._distinct then
			self._resultDependencies[self._distinct] = true
		end
		for field in self._db:_FieldIterator() do
			if self._rootClause:_UsesField(field) then
				self._resultDependencies[field] = true
			end
		end
	end
end

function DatabaseQuery.__private:_AddResultRowsFromIndex(indexList, skipQuery, firstIndex, lastIndex, isAscending, indexField)
	local numJoinDBs = #self._joinDBs
	local distinct = self._distinct
	local result = self._result
	local resultIndex = #self._result + 1
	local includeAllRows = skipQuery and numJoinDBs == 0 and not distinct
	local iterIncrement = 1
	if not isAscending then
		-- Swap the first / last index since we're iterating in descending order
		firstIndex, lastIndex = lastIndex, firstIndex
		iterIncrement = -1
	end
	for i = firstIndex, lastIndex, iterIncrement do
		local uuid = indexList[i]
		if includeAllRows or self:_ResultShouldIncludeRow(uuid, skipQuery, numJoinDBs, distinct, indexField) then
			result[resultIndex] = uuid
			resultIndex = resultIndex + 1
		end
	end
end

function DatabaseQuery.__private:_AddResultRowsCheckAll()
	local numJoinDBs = #self._joinDBs
	local distinct = self._distinct
	local result = self._result
	local resultIndex = #self._result + 1
	for _, uuid in self._db:_UUIDIterator() do
		if self:_ResultShouldIncludeRow(uuid, false, numJoinDBs, distinct) then
			result[resultIndex] = uuid
			resultIndex = resultIndex + 1
		end
	end
end

function DatabaseQuery.__private:_ResultShouldIncludeRow(uuid, skipQuery, numJoinDBs, distinct, ignoreField)
	for i = 1, numJoinDBs do
		if self._joinTypes[i] == JOIN_TYPE.INNER then
			local joinField = self._joinFields[i]
			local joinForeignField = self._joinForeignFields[i]
			if not self._joinDBs[i]:_GetUniqueRow(joinForeignField, self:_GetResultRowData(uuid, joinField)) then
				return false
			end
		end
	end
	if not skipQuery then
		if not self._rootClause:_IsTrue(uuid, ignoreField) then
			return false
		end
	end
	if distinct then
		local distinctValue = self:_GetResultRowData(uuid, distinct)
		if self._iterDistinctUsed[distinctValue] then
			return false
		end
		self._iterDistinctUsed[distinctValue] = true
	end
	return true
end

---@private
function DatabaseQuery:_GetResultRowData(uuid, field)
	if self._virtualFieldFunc[field] == HASH_VIRTUAL_FIELD_FUNC then
		local hashFields = self._virtualFieldArgField[field]
		local result = nil
		for i = 1, #hashFields do
			result = Hash.Calculate(self:_GetResultRowData(uuid, hashFields[i]), result)
		end
		return result
	elseif self._virtualFieldFunc[field] then
		local argField = self._virtualFieldArgField[field]
		local value = nil
		if type(argField) == "table" then
			value = self._virtualFieldFunc[field](self:_GetResultRowDataFields(uuid, unpack(argField)))
		else
			value = self._virtualFieldFunc[field](self:_GetResultRowData(uuid, argField))
		end
		if value == nil then
			value = self._virtualFieldDefault[field]
		end
		if type(value) ~= self._virtualFieldType[field] then
			error(format("Virtual field value not the correct type (%s, %s)", tostring(value), field))
		end
		return value
	elseif #self._joinDBs == 0 or self._db:_HasField(field) then
		-- This is a local field
		return self._db:GetRowFields(uuid, field)
	else
		-- This is a foreign field
		local joinDB, joinField, joinForeignField, joinType, aggregateJoinField, aggregateJoinQuery = nil, nil, nil, nil, nil, nil
		for i = 1, #self._joinDBs do
			local testDB = self._joinDBs[i]
			local testAggregateJoinField = self._aggregateJoinQueries[i] and self._joinForeignFields[i] or nil
			if field == testAggregateJoinField or (not testAggregateJoinField and testDB:_HasField(field)) then
				if joinDB then
					error("Multiple joined DBs have this field", 2)
				end
				joinDB = testDB
				joinField = self._joinFields[i]
				joinForeignField = self._joinForeignFields[i]
				joinType = self._joinTypes[i]
				aggregateJoinField = testAggregateJoinField
				aggregateJoinQuery = self._aggregateJoinQueries[i]
			end
		end
		if not joinDB then
			error("Invalid field: "..tostring(field), 2)
		end
		if joinType == JOIN_TYPE.AGGREGATE_SUM then
			if not aggregateJoinField or not aggregateJoinQuery then
				error("Missing aggregate join context: " + tostring(aggregateJoinField) + ", " + tostring(aggregateJoinQuery))
			end
			aggregateJoinQuery:BindParams(self:_GetResultRowData(uuid, joinField))
			return aggregateJoinQuery:Sum(aggregateJoinField)
		elseif joinType == JOIN_TYPE.INNER or joinType == JOIN_TYPE.LEFT then
			if aggregateJoinField or aggregateJoinQuery then
				error("Unexpected aggregate join context: " + tostring(aggregateJoinField) + ", " + tostring(aggregateJoinQuery))
			end
			local foreignUUID = joinDB:_GetUniqueRow(joinForeignField, self:_GetResultRowData(uuid, joinField))
			if foreignUUID then
				return joinDB:GetRowFields(foreignUUID, field)
			end
		else
			error("Unknown join type: "..tostring(joinType))
		end
	end
end

---@private
function DatabaseQuery:_GetResultRowDataFields(uuid, ...)
	-- Get up to 4 simple (non-list, non-SmartMap) fields at a time - recursing as needed for more
	local numFields = select("#", ...)
	local field1, field2, field3, field4 = ...
	if numFields == 1 then
		return self:_GetResultRowData(uuid, field1)
	elseif numFields == 2 then
		return self:_GetResultRowData(uuid, field1), self:_GetResultRowData(uuid, field2)
	elseif numFields == 3 then
		return self:_GetResultRowData(uuid, field1), self:_GetResultRowData(uuid, field2), self:_GetResultRowData(uuid, field3)
	elseif numFields == 4 then
		return self:_GetResultRowData(uuid, field1), self:_GetResultRowData(uuid, field2), self:_GetResultRowData(uuid, field3), self:_GetResultRowData(uuid, field4)
	elseif numFields > 4 then
		return self:_GetResultRowData(uuid, field1), self:_GetResultRowData(uuid, field2), self:_GetResultRowData(uuid, field3), self:_GetResultRowData(uuid, field4), self:_GetResultRowDataFields(uuid, select(5, ...))
	else
		error("Invalid numFields: "..tostring(numFields))
	end
end

function DatabaseQuery.__private:_JoinHelper(joinType, db, field, foreignField, aggregateQuery)
	assert(type(field) == "string" and type(foreignField) == "string")
	local localFieldType = nil
	if self._virtualFieldType[field] then
		localFieldType = self._virtualFieldType[field]
	elseif self._db:_HasField(field) then
		assert(not self._db:_IsListField(field), "Can't join on list fields")
		local fieldType, enumFieldType = self._db:_GetFieldType(field)
		assert(not enumFieldType, "Can't join on enum fields")
		localFieldType = fieldType
	else
		error("Local field doesn't exist: "..field)
	end
	local foreignFieldType = nil
	if db:_HasField(foreignField) then
		assert(not db:_IsListField(foreignField), "Can't join on list fields")
		local fieldType, enumFieldType = db:_GetFieldType(foreignField)
		assert(not enumFieldType, "Can't join on enum fields")
		foreignFieldType = fieldType
	else
		error("Foreign field doesn't exist: "..foreignField)
	end
	assert(not Table.KeyByValue(self._joinDBs, db), "Already joining with this DB")
	assert(self._iteratorState == ITERATOR_STATE.IDLE)
	if aggregateQuery then
		assert(aggregateQuery:__isa(DatabaseQuery))
		assert(joinType == JOIN_TYPE.AGGREGATE_SUM)
		assert(not self._db:_HasField(foreignField), "Local DB contains aggregate field: "..tostring(foreignField))
		assert(db:_HasField(foreignField), "Foreign DB does not contains aggregate field: "..tostring(foreignField))
	else
		assert(localFieldType == foreignFieldType, format("Field types don't match (%s, %s, %s, %s)", field, tostring(localFieldType), foreignField, tostring(foreignFieldType)))
		assert(db:_IsUnique(foreignField), "Field must be unique in foreign DB")
		assert(joinType ~= JOIN_TYPE.AGGREGATE_SUM)
		assert(not aggregateQuery)
		for dbField in db:_FieldIterator() do
			if dbField ~= field and dbField ~= foreignField then
				assert(not self._db:_HasField(dbField), "Foreign field conflicts with local DB: "..tostring(dbField))
			end
		end
		for virtualField in pairs(self._virtualFieldFunc) do
			if virtualField ~= field then
				assert(not db:_HasField(virtualField), "Virtual field conflicts with foreign DB: "..tostring(virtualField))
			end
		end
	end
	db:_RegisterQuery(self)
	tinsert(self._joinTypes, joinType)
	tinsert(self._joinDBs, db)
	tinsert(self._joinFields, field)
	tinsert(self._joinForeignFields, foreignField)
	tinsert(self._aggregateJoinQueries, aggregateQuery or false)
	self._resultState = RESULT_STATE.STALE
end

function DatabaseQuery.__private:_GetSmartMapReader(map)
	for reader, context in pairs(private.smartMapReaderContext) do
		if context.map == map and context.query == nil then
			context.query = self
			return reader
		end
	end
	local reader = map:CreateReader(private.HandleSmartMapUpdate)
	private.smartMapReaderContext[reader] = {
		map = map,
		query = self,
	}
	return reader
end

function DatabaseQuery.__private:_DoAutoRelease()
	if self._autoRelease then
		self._autoRelease = false
		self:Release()
	end
end

function DatabaseQuery.__private:_ResultIteratorCleanup()
	assert(self._iteratorState == ITERATOR_STATE.IN_PROGRESS or self._iteratorState == ITERATOR_STATE.IN_PROGRESS_CAN_ABORT or self._iteratorState == ITERATOR_STATE.ABORTED)
	self._iteratorState = ITERATOR_STATE.IDLE
	self._iteratorType = ITERATOR_TYPE.UNOPTIMIZED
	self._iteratorIndex = nil
	self:_DoAutoRelease()
end

function DatabaseQuery.__private:_PassThroughAndAutoRelease(...)
	self:_DoAutoRelease()
	return ...
end

function DatabaseQuery.__private:_ResetDistinct()
	self._distinct = nil
end

function DatabaseQuery.__private:_ResetJoinsAndVirtualFields()
	for _, db in ipairs(self._joinDBs) do
		db:_RemoveQuery(self)
	end
	wipe(self._joinTypes)
	wipe(self._joinDBs)
	wipe(self._joinFields)
	wipe(self._joinForeignFields)
	for _, query in ipairs(self._aggregateJoinQueries) do
		if query then
			query:Release()
		end
	end
	wipe(self._aggregateJoinQueries)
	for _, func in pairs(self._virtualFieldFunc) do
		if private.smartMapReaderContext[func] then
			private.smartMapReaderContext[func].query = nil
		end
	end
	wipe(self._virtualFieldFunc)
	wipe(self._virtualFieldArgField)
	wipe(self._virtualFieldType)
	wipe(self._virtualFieldDefault)
end

function DatabaseQuery.__private:_SetIteratorType(...)
	if select("#", ...) == 0 then
		self._iteratorType = ITERATOR_TYPE.NO_FIELDS
		return
	end
	local hasSmartMapOrListFields, hasForeignOrVirtualFields = false, false
	for _, field in Vararg.Iterator(...) do
		if self._virtualFieldFunc[field] or not self._db:_HasField(field) then
			hasForeignOrVirtualFields = true
		elseif self._db:_IsListField(field) or self._db:_IsSmartMapField(field) then
			hasSmartMapOrListFields = true
		end
	end
	if hasForeignOrVirtualFields then
		-- Can't optimize at all
		self._iteratorType = ITERATOR_TYPE.UNOPTIMIZED
	elseif hasSmartMapOrListFields then
		-- Have some smart map or list fields, so can only optimize as local DB fields only
		self._iteratorType = ITERATOR_TYPE.LOCAL_FIELDS
	else
		-- Have only simple local DB fields, so can optimize accordingly
		self._iteratorType = ITERATOR_TYPE.LOCAL_SIMPLE_FIELDS
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.DatabaseQuerySortSingle(self, aUUID, bUUID, isAscending)
	local aValue = self._sortValueCache[aUUID]
	local bValue = self._sortValueCache[bUUID]
	if aValue == bValue then
		-- make the sort stable
		return aUUID > bUUID
	elseif aValue == nil then
		-- sort nil to the end
		return false
	elseif bValue == nil then
		-- sort nil to the end
		return true
	elseif isAscending then
		return aValue < bValue
	else
		return aValue > bValue
	end
end

function private.DatabaseQuerySortGeneric(self, aUUID, bUUID)
	for i = 1, #self._orderBy do
		local orderByField = self._orderBy[i]
		local aValue = Util.ToIndexValue(self:_GetResultRowData(aUUID, orderByField))
		local bValue = Util.ToIndexValue(self:_GetResultRowData(bUUID, orderByField))
		if aValue == bValue then
			-- continue looping
		elseif aValue == nil then
			-- sort nil to the end
			return false
		elseif bValue == nil then
			-- sort nil to the end
			return true
		elseif self._orderByAscending[i] then
			return aValue < bValue
		else
			return aValue > bValue
		end
	end
	-- make the sort stable
	return aUUID > bUUID
end

---@param self DatabaseQuery
function private.QueryResultIterator(self, _, ...)
	self._iteratorIndex = self._iteratorIndex + 1
	local uuid = self._result[self._iteratorIndex]
	if not uuid or self._iteratorState == ITERATOR_STATE.ABORTED then
		return
	elseif self._iteratorState ~= ITERATOR_STATE.IN_PROGRESS and self._iteratorState ~= ITERATOR_STATE.IN_PROGRESS_CAN_ABORT then
		error("Invalid iteratorState: "..tostring(self._iteratorState))
	end
	if self._iteratorType == ITERATOR_TYPE.NO_FIELDS then
		return uuid
	elseif self._iteratorType == ITERATOR_TYPE.LOCAL_SIMPLE_FIELDS then
		-- Optimized path for local simple fields
		return uuid, self._db:_GetRowSimpleFields(uuid, ...)
	elseif self._iteratorType == ITERATOR_TYPE.LOCAL_FIELDS then
		-- Optimized path for local fields
		return uuid, self._db:GetRowFields(uuid, ...)
	else
		-- Unoptimized path
		return uuid, self:_GetResultRowDataFields(uuid, ...)
	end
end

function private.HandleSmartMapUpdate(reader, pendingChanges)
	local self = private.smartMapReaderContext[reader].query
	if not self then
		return
	end

	local changedField = nil
	for field, func in pairs(self._virtualFieldFunc) do
		if func == reader then
			changedField = field
			break
		end
	end
	assert(changedField)
	self:_MarkResultStale(changedField)

	self:_DoUpdateCallback()
end

function private.UUIDDiffIterator(context, index)
	assert(context.inUse)
	wipe(context.uuids)
	if index > #context.result then
		return
	end
	local action = context.result[index]
	local startIndex = context.result[index + 1]
	local num = context.result[index + 2]
	index = index + 3
	assert(action == "INSERT" or action == "REMOVE")
	assert(startIndex > 0 and num > 0 and num <= #context.result - index + 1)
	Table.InsertFrom(context.uuids, context.result, index, index + num - 1)
	return index + num, action, startIndex, context.uuids
end

function private.UUIDDiffIteratorCleanup(context)
	wipe(context.result)
	context.inUse = false
end
