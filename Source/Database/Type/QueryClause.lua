-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local DatabaseQueryClause = LibTSMUtil:DefineClassType("DatabaseQueryClause")
local Util = LibTSMUtil:Include("Database.Util")
local ObjectPool = LibTSMUtil:IncludeClassType("ObjectPool")
local EnumType = LibTSMUtil:Include("BaseType.EnumType")
local Table = LibTSMUtil:Include("Lua.Table")
local private = {
	objectPool = ObjectPool.New("DATABASE_QUERY_CLAUSES", DatabaseQueryClause, 2),
}
-- NOTE: We don't use a nested enum for performance reasons
local OPERATION_TYPE = EnumType.New("DB_QUERY_OPERATION_TYPE", {
	COMPARISON = EnumType.NewValue(),
	SUB_CLAUSE = EnumType.NewValue(),
	CONDITIONAL = EnumType.NewValue(),
})
local OPERATION = EnumType.New("DB_QUERY_OPERATION", {
	-- Comparison operations
	EQUAL = EnumType.NewValue(),
	NOT_EQUAL = EnumType.NewValue(),
	LESS = EnumType.NewValue(),
	LESS_OR_EQUAL = EnumType.NewValue(),
	GREATER = EnumType.NewValue(),
	GREATER_OR_EQUAL = EnumType.NewValue(),
	MATCHES = EnumType.NewValue(),
	CONTAINS = EnumType.NewValue(),
	STARTS_WITH = EnumType.NewValue(),
	IS_NIL = EnumType.NewValue(),
	IS_NOT_NIL = EnumType.NewValue(),
	FUNCTION = EnumType.NewValue(),
	IN_TABLE = EnumType.NewValue(),
	NOT_IN_TABLE = EnumType.NewValue(),
	LIST_CONTAINS = EnumType.NewValue(),
	-- Sub-clause operations
	OR = EnumType.NewValue(),
	AND = EnumType.NewValue(),
	-- Conditional operations
	IF = EnumType.NewValue(),
	ELSEIF = EnumType.NewValue(),
	ELSE = EnumType.NewValue(),
})
DatabaseQueryClause.OPERATION = OPERATION
local OPERATION_TYPE_LOOKUP = {
	[OPERATION.EQUAL] = OPERATION_TYPE.COMPARISON,
	[OPERATION.NOT_EQUAL] = OPERATION_TYPE.COMPARISON,
	[OPERATION.LESS] = OPERATION_TYPE.COMPARISON,
	[OPERATION.LESS_OR_EQUAL] = OPERATION_TYPE.COMPARISON,
	[OPERATION.GREATER] = OPERATION_TYPE.COMPARISON,
	[OPERATION.GREATER_OR_EQUAL] = OPERATION_TYPE.COMPARISON,
	[OPERATION.MATCHES] = OPERATION_TYPE.COMPARISON,
	[OPERATION.CONTAINS] = OPERATION_TYPE.COMPARISON,
	[OPERATION.STARTS_WITH] = OPERATION_TYPE.COMPARISON,
	[OPERATION.IS_NIL] = OPERATION_TYPE.COMPARISON,
	[OPERATION.IS_NOT_NIL] = OPERATION_TYPE.COMPARISON,
	[OPERATION.FUNCTION] = OPERATION_TYPE.COMPARISON,
	[OPERATION.IN_TABLE] = OPERATION_TYPE.COMPARISON,
	[OPERATION.NOT_IN_TABLE] = OPERATION_TYPE.COMPARISON,
	[OPERATION.LIST_CONTAINS] = OPERATION_TYPE.COMPARISON,
	[OPERATION.OR] = OPERATION_TYPE.SUB_CLAUSE,
	[OPERATION.AND] = OPERATION_TYPE.SUB_CLAUSE,
	[OPERATION.IF] = OPERATION_TYPE.CONDITIONAL,
	[OPERATION.ELSEIF] = OPERATION_TYPE.CONDITIONAL,
	[OPERATION.ELSE] = OPERATION_TYPE.CONDITIONAL,
}



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Gets a new query clause.
---@param query DatabaseQuery The owning query
---@param parent? DatabaseQueryClause The parent query clause
---@param operation EnumValue The operation type
---@param ... any Additional arguments to the operation
---@return DatabaseQueryClause
function DatabaseQueryClause.__static.Get(query, parent, operation, ...)
	local clause = private.objectPool:Get() ---@type DatabaseQueryClause
	clause:_Acquire(query, parent, operation, ...)
	return clause
end



-- ============================================================================
-- Class Method Methods
-- ============================================================================

function DatabaseQueryClause.__private:__init()
	self._query = nil ---@type DatabaseQuery
	self._parent = nil ---@type DatabaseQueryClause?
	self._operation = nil
	-- Comparison
	self._field = nil
	self._value = nil
	self._boundValue = nil
	self._extraArg = nil
	-- Or / And
	self._subClauses = {}
end

function DatabaseQueryClause.__private:_Acquire(query, parent, operation, ...)
	self._query = query
	self._parent = parent
	self:_SetOperation(operation, ...)
end

---@private
function DatabaseQueryClause:_Release()
	self._query = nil
	self._parent = nil
	self._operation = nil
	self._field = nil
	self._value = nil
	self._boundValue = nil
	self._extraArg = nil
	for _, clause in ipairs(self._subClauses) do
		clause:_Release()
	end
	wipe(self._subClauses)
	private.objectPool:Recycle(self)
end



-- ============================================================================
-- Private Class Method
-- ============================================================================

function DatabaseQueryClause.__private:_SetOperation(operation, ...)
	assert(not self._operation)
	self._operation = operation
	local operationType = OPERATION_TYPE_LOOKUP[operation]
	if operationType == OPERATION_TYPE.COMPARISON then
		local field, value, extraArg = ...
		assert(value == Util.CONSTANTS.OTHER_FIELD_QUERY_PARAM or operation == OPERATION.FUNCTION or not extraArg)
		self._field = field
		self._value = value
		self._extraArg = extraArg
	elseif operationType == OPERATION_TYPE.SUB_CLAUSE then
		assert(#self._subClauses == 0)
	elseif operationType == OPERATION_TYPE.CONDITIONAL then
		local condition = ...
		if operation == OPERATION.IF then
			assert(#self._subClauses == 0)
			self._value = condition and true or false
		elseif operation == OPERATION.ELSEIF then
			assert(self._parent._operation == OPERATION.IF)
			for _, subClause in ipairs(self._subClauses) do
				if subClause._operation == OPERATION.ELSE then
					error("ELSEIF clause follows ELSE clause")
				end
			end
			self._value = condition and true or false
		elseif operation == OPERATION.ELSE then
			assert(condition == nil)
			assert(self._parent._operation == OPERATION.IF)
			for _, subClause in ipairs(self._subClauses) do
				if subClause._operation == OPERATION.ELSE then
					error("Multiple ELSE clauses")
				end
			end
			self._value = true
		else
			error("Invalid operation: "..tostring(operation))
		end
	else
		error(format("Unknown operation type (%s, %s)", operation, operationType))
	end
end

function DatabaseQueryClause:_EndSubClause()
	local parent = self._parent
	if self._operation == OPERATION.IF then
		-- Collapse all the sub clauses into the parent (we know they were part of the true block at this point)
		-- and remove any residual elseif / else clauses
		for _, subClause in ipairs(self._subClauses) do
			if subClause._operation == OPERATION.ELSEIF or subClause._operation == OPERATION.ELSE then
				subClause:_Release()
			else
				subClause._parent = self._parent
				self._parent:_InsertSubClause(subClause)
			end
		end
		wipe(self._subClauses)
		-- Remove this clause from the parent and release it
		assert(Table.RemoveByValue(self._parent._subClauses, self) == 1)
		self:_Release()
	end
	return parent
end

function DatabaseQueryClause:_IsTrue(uuid, ignoreField)
	if ignoreField and self._field == ignoreField then
		return true
	end
	local value = self._value
	if value == Util.CONSTANTS.BOUND_QUERY_PARAM then
		value = self._boundValue
	elseif value == Util.CONSTANTS.OTHER_FIELD_QUERY_PARAM then
		value = self._query:_GetResultRowData(uuid, self._extraArg) ---@diagnostic disable-line: invisible
	end
	local operation = self._operation
	if operation == OPERATION.OR then
		for i = 1, #self._subClauses do
			if self._subClauses[i]:_IsTrue(uuid, ignoreField) then
				return true
			end
		end
		return false
	elseif operation == OPERATION.AND then
		for i = 1, #self._subClauses do
			if not self._subClauses[i]:_IsTrue(uuid, ignoreField) then
				return false
			end
		end
		return true
	end
	local rowValue = self._query:_GetResultRowData(uuid, self._field) ---@diagnostic disable-line: invisible
	if operation == OPERATION.EQUAL then
		return rowValue == value
	elseif operation == OPERATION.NOT_EQUAL then
		return rowValue ~= value
	elseif operation == OPERATION.LESS then
		return rowValue < value
	elseif operation == OPERATION.LESS_OR_EQUAL then
		return rowValue <= value
	elseif operation == OPERATION.GREATER then
		return rowValue > value
	elseif operation == OPERATION.GREATER_OR_EQUAL then
		return rowValue >= value
	elseif operation == OPERATION.MATCHES then
		return strfind(strlower(rowValue), value --[[@as string]]) and true or false
	elseif operation == OPERATION.CONTAINS then
		return strfind(strlower(rowValue), value --[[@as string]], 1, true) and true or false
	elseif operation == OPERATION.STARTS_WITH then
		return strsub(strlower(rowValue), 1, #value) == value
	elseif operation == OPERATION.IS_NIL then
		return rowValue == nil
	elseif operation == OPERATION.IS_NOT_NIL then
		return rowValue ~= nil
	elseif operation == OPERATION.FUNCTION then
		return self._value(rowValue, self._extraArg) and true or false
	elseif operation == OPERATION.IN_TABLE then
		return value[rowValue] ~= nil
	elseif operation == OPERATION.NOT_IN_TABLE then
		return value[rowValue] == nil
	elseif operation == OPERATION.LIST_CONTAINS then
		for _, listValue in rowValue do
			if listValue == value then
				rowValue:Release()
				return true
			end
		end
		return false
	else
		error("Invalid operation: " .. tostring(operation))
	end
end

function DatabaseQueryClause:_GetIndexValue(indexField)
	if self._operation == OPERATION.EQUAL then
		if self._field ~= indexField then
			return
		end
		if self._value == Util.CONSTANTS.OTHER_FIELD_QUERY_PARAM then
			return
		elseif self._value == Util.CONSTANTS.BOUND_QUERY_PARAM then
			local result = Util.ToIndexValue(self._boundValue)
			return result, result
		else
			local result = Util.ToIndexValue(self._value)
			return result, result
		end
	elseif self._operation == OPERATION.LESS_OR_EQUAL then
		if self._field ~= indexField then
			return
		end
		if self._value == Util.CONSTANTS.OTHER_FIELD_QUERY_PARAM then
			return
		elseif self._value == Util.CONSTANTS.BOUND_QUERY_PARAM then
			return nil, Util.ToIndexValue(self._boundValue)
		else
			return nil, Util.ToIndexValue(self._value)
		end
	elseif self._operation == OPERATION.GREATER_OR_EQUAL then
		if self._field ~= indexField then
			return
		end
		if self._value == Util.CONSTANTS.OTHER_FIELD_QUERY_PARAM then
			return
		elseif self._value == Util.CONSTANTS.BOUND_QUERY_PARAM then
			return Util.ToIndexValue(self._boundValue), nil
		else
			return Util.ToIndexValue(self._value), nil
		end
	elseif self._operation == OPERATION.STARTS_WITH then
		if self._field ~= indexField then
			return
		end
		local minValue = nil
		if self._value == Util.CONSTANTS.OTHER_FIELD_QUERY_PARAM then
			return
		elseif self._value == Util.CONSTANTS.BOUND_QUERY_PARAM then
			minValue = Util.ToIndexValue(self._boundValue)
		else
			minValue = Util.ToIndexValue(self._value)
		end
		-- calculate the max value
		assert(gsub(minValue, "\255", "") ~= "")
		local maxValue = nil
		for i = #minValue, 1, -1 do
			if strsub(minValue, i, i) ~= "\255" then
				maxValue = strsub(minValue, 1, i - 1)..strrep("\255", #minValue - i + 1)
				break
			end
		end
		return minValue, maxValue
	elseif self._operation == OPERATION.OR then
		local numSubClauses = #self._subClauses
		if numSubClauses == 0 then
			return
		end
		-- all of the subclauses need to support the same index
		local valueMin, valueMax = self._subClauses[1]:_GetIndexValue(indexField)
		for i = 2, numSubClauses do
			local subClauseValueMin, subClauseValueMax = self._subClauses[i]:_GetIndexValue(indexField)
			if subClauseValueMin ~= valueMin or subClauseValueMax ~= valueMax then
				return
			end
		end
		return valueMin, valueMax
	elseif self._operation == OPERATION.AND then
		-- get the most constrained range of index values from the subclauses
		local valueMin, valueMax = nil, nil
		for _, subClause in ipairs(self._subClauses) do
			local subClauseValueMin, subClauseValueMax = subClause:_GetIndexValue(indexField)
			if subClauseValueMin ~= nil and (valueMin == nil or subClauseValueMin > valueMin) then
				valueMin = subClauseValueMin
			end
			if subClauseValueMax ~= nil and (valueMax == nil or subClauseValueMax < valueMax) then
				valueMax = subClauseValueMax
			end
		end
		return valueMin, valueMax
	end
end

function DatabaseQueryClause:_GetTrigramIndexValue(indexField)
	if self._operation == OPERATION.EQUAL then
		if self._field ~= indexField then
			return
		end
		if self._value == Util.CONSTANTS.OTHER_FIELD_QUERY_PARAM then
			return
		elseif self._value == Util.CONSTANTS.BOUND_QUERY_PARAM then
			return self._boundValue
		else
			return self._value
		end
	elseif self._operation == OPERATION.CONTAINS then
		if self._field ~= indexField then
			return
		end
		if self._value == Util.CONSTANTS.OTHER_FIELD_QUERY_PARAM then
			return
		elseif self._value == Util.CONSTANTS.BOUND_QUERY_PARAM then
			return self._boundValue
		else
			return self._value
		end
	elseif self._operation == OPERATION.OR then
		-- All of the subclauses need to support the same trigram value
		local value = nil
		for i = 1, #self._subClauses do
			local subClause = self._subClauses[i]
			local subClauseValue = subClause:_GetTrigramIndexValue(indexField)
			if not subClauseValue then
				return
			end
			if i == 1 then
				value = subClauseValue
			elseif subClauseValue ~= value then
				return
			end
		end
		return value
	elseif self._operation == OPERATION.AND then
		-- At least one of the subclauses need to support the trigram
		for _, subClause in ipairs(self._subClauses) do
			local value = subClause:_GetTrigramIndexValue(indexField)
			if value then
				return value
			end
		end
	end
end

function DatabaseQueryClause:_IsStrictIndex(indexField, indexValueMin, indexValueMax)
	if self._value == Util.CONSTANTS.OTHER_FIELD_QUERY_PARAM then
		return false
	end
	if self._operation == OPERATION.EQUAL and self._field == indexField and indexValueMin == indexValueMax then
		if self._value == Util.CONSTANTS.BOUND_QUERY_PARAM then
			return Util.ToIndexValue(self._boundValue) == indexValueMin
		else
			return Util.ToIndexValue(self._value) == indexValueMin
		end
	elseif self._operation == OPERATION.GREATER_OR_EQUAL and self._field == indexField then
		if self._value == Util.CONSTANTS.BOUND_QUERY_PARAM then
			return Util.ToIndexValue(self._boundValue) == indexValueMin
		else
			return Util.ToIndexValue(self._value) == indexValueMin
		end
	elseif self._operation == OPERATION.LESS_OR_EQUAL and self._field == indexField then
		if self._value == Util.CONSTANTS.BOUND_QUERY_PARAM then
			return Util.ToIndexValue(self._boundValue) == indexValueMax
		else
			return Util.ToIndexValue(self._value) == indexValueMax
		end
	elseif self._operation == OPERATION.OR and #self._subClauses == 1 then
		return self._subClauses[1]:_IsStrictIndex(indexField, indexValueMin, indexValueMax)
	elseif self._operation == OPERATION.AND then
		-- Must be strict for all subclauses
		for _, subClause in ipairs(self._subClauses) do
			if not subClause:_IsStrictIndex(indexField, indexValueMin, indexValueMax) then
				return false
			end
		end
		return true
	else
		return false
	end
end

function DatabaseQueryClause:_UsesField(field)
	if field == self._field then
		return true
	end
	if OPERATION_TYPE_LOOKUP[self._operation] == OPERATION_TYPE.SUB_CLAUSE then
		for i = 1, #self._subClauses do
			if self._subClauses[i]:_UsesField(field) then
				return true
			end
		end
	end
	return false
end

function DatabaseQueryClause:_InsertSubClause(subClause)
	assert(OPERATION_TYPE_LOOKUP[self._operation] == OPERATION_TYPE.SUB_CLAUSE or self._operation == OPERATION.IF)
	tinsert(self._subClauses, subClause)
	return self
end

function DatabaseQueryClause:_BindParams(...)
	if self._value == Util.CONSTANTS.BOUND_QUERY_PARAM then
		self._boundValue = ...
		return 1
	end
	local valuesUsed = 0
	for _, clause in ipairs(self._subClauses) do
		valuesUsed = valuesUsed + clause:_BindParams(select(valuesUsed + 1, ...))
	end
	return valuesUsed
end

function DatabaseQueryClause:_IgnoringSubClauses()
	if self._operation ~= OPERATION.IF then
		return false
	end
	local condition = self._value
	local foundTrueBlock = condition
	for _, subClause in ipairs(self._subClauses) do
		if subClause._operation == OPERATION.ELSEIF or subClause._operation == OPERATION.ELSE then
			if foundTrueBlock then
				condition = false
			else
				condition = subClause._value
				foundTrueBlock = condition
			end
		end
	end
	return not condition
end

function DatabaseQueryClause:_IsConditinal()
	return self._operation == OPERATION.IF
end
