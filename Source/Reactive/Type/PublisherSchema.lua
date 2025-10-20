-- ------------------------------------------------------------------------------ --
--                                   LibTSMUtil                                   --
--                 https://github.com/TradeSkillMaster/LibTSMUtil                 --
--         Licensed under the MIT license. See LICENSE.txt for more info.         --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local ReactivePublisherSchema = LibTSMUtil:DefineClassType("ReactivePublisherSchema")
local ReactivePublisher = LibTSMUtil:IncludeClassType("ReactivePublisher")
local ReactivePublisherCodeGen = LibTSMUtil:IncludeClassType("ReactivePublisherCodeGen")
local Util = LibTSMUtil:Include("Reactive.Type.Util")
local ObjectPool = LibTSMUtil:IncludeClassType("ObjectPool")
local private = {
	objectPool = ObjectPool.New("PUBLISHER_SCHEMA", ReactivePublisherSchema, 2),
}
local STEP = Util.PUBLISHER_STEP



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Gets a publisher object.
---@param subject ReactiveSubject The subject which is publishing values
---@return ReactivePublisherSchema
function ReactivePublisherSchema.__static.Get(subject)
	local publisher = private.objectPool:Get()
	publisher:_Acquire(subject)
	return publisher
end



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function ReactivePublisherSchema.__private:__init()
	self._subject = nil
	self._codeGen = nil
	self._autoStore = nil
	self._autoDisable = false
	self._hasShare = false
end

---@param subject ReactiveSubject
function ReactivePublisherSchema.__private:_Acquire(subject)
	self._subject = subject
end

---@private
function ReactivePublisherSchema.__private:_Release()
	assert(not self._codeGen)
	self._subject = nil
	self._autoStore = nil
	self._autoDisable = false
	self._hasShare = false
	private.objectPool:Recycle(self)
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Automatically stores the publisher in the provided table when it's handled.
---@param tbl ReactivePublisherSchema[] The table to store the publisher in
---@return ReactivePublisherSchema
function ReactivePublisherSchema:AutoStore(tbl)
	assert(type(tbl) == "table" and not self._autoStore)
	assert(self._subject and not self._codeGen)
	self._autoStore = tbl
	return self
end

---Automatically disables the publisher when it's handled.
---@return ReactivePublisherSchema
function ReactivePublisherSchema:AutoDisable()
	self._autoDisable = true
	return self
end

---Map published values to another value using a function.
---@param func fun(value: any, arg: any): any The mapping function which takes the published values and returns the results
---@param arg any An additional argument to pass to the function
---@return ReactivePublisherSchema
function ReactivePublisherSchema:MapWithFunction(func, arg)
	return self:_AddStepHelper(STEP.MAP_WITH_FUNCTION, func, arg)
end

---Map published values to another value using a function and passing in the specified keys of the value.
---@param func fun(...: any): any The mapping function which takes the specified keys of the published values and returns the results
---@return ReactivePublisherSchema
function ReactivePublisherSchema:MapWithFunctionAndKeys(func, ...)
	return self:_AddStepHelper(STEP.MAP_WITH_FUNCTION_AND_KEYS, func, ...)
end

---Maps published values by calling a method on it.
---@param method string The name of the method to call on the published values
---@param arg any An additional argument to pass to the method
---@return ReactivePublisherSchema
function ReactivePublisherSchema:MapWithMethod(method, arg)
	return self:_AddStepHelper(STEP.MAP_WITH_METHOD, method, arg)
end

---Maps published values by indexing it with the specified key.
---@param key string|number The key to index the published values with
---@return ReactivePublisherSchema
function ReactivePublisherSchema:MapWithKey(key)
	return self:_AddStepHelper(STEP.MAP_WITH_KEY, key)
end

---Map published values by indexing it with two keys, keeping the first value one which is non-nil.
---@param key1 string The first key to index the published values with
---@param key2 string The second key to index the published values with
---@return ReactivePublisherSchema
function ReactivePublisherSchema:MapWithKeyCoalesced(key1, key2)
	return self:_AddStepHelper(STEP.MAP_WITH_KEY_COALESCED, key1, key2)
end

---Maps published values by using them as a key to a lookup table.
---@param tbl table The lookup table
---@return ReactivePublisherSchema
function ReactivePublisherSchema:MapWithLookupTable(tbl)
	return self:_AddStepHelper(STEP.MAP_WITH_LOOKUP_TABLE, tbl)
end

---Maps published values by using a compiled expression.
---@param expression ReactiveStateExpression The state expression object
---@return ReactivePublisherSchema
function ReactivePublisherSchema:MapWithStateExpression(expression)
	return self:_AddStepHelper(STEP.MAP_WITH_STATE_EXPRESSION, expression)
end

---Map published boolean values to the specified true / false values.
---@param trueValue any The value to map to if true
---@param falseValue any The value to map to if false
---@return ReactivePublisherSchema
function ReactivePublisherSchema:MapBooleanWithValues(trueValue, falseValue)
	return self:_AddStepHelper(STEP.MAP_BOOLEAN_WITH_VALUES, trueValue, falseValue)
end

---Map published values to a boolean based on whether or not it equals the specified value.
---@param value any The value to compare with
---@return ReactivePublisherSchema
function ReactivePublisherSchema:MapBooleanEquals(value)
	return self:_AddStepHelper(STEP.MAP_BOOLEAN_EQUALS, value)
end

---Map published values to a boolean based on whether or not it equals the specified value.
---@param value any The value to compare with
---@return ReactivePublisherSchema
function ReactivePublisherSchema:MapBooleanNotEquals(value)
	return self:_AddStepHelper(STEP.MAP_BOOLEAN_NOT_EQUALS, value)
end

---Map published values to a boolean based on whether or not it is greater than or equal to the specified value.
---@param value any The value to compare with
---@return ReactivePublisherSchema
function ReactivePublisherSchema:MapBooleanGreaterThanOrEquals(value)
	return self:_AddStepHelper(STEP.MAP_BOOLEAN_GREATER_THAN_OR_EQUALS, value)
end

---Map published values as arguments to a format string.
---@param formatStr string The string to format with the published values
---@return ReactivePublisherSchema
function ReactivePublisherSchema:MapToStringFormat(formatStr)
	return self:_AddStepHelper(STEP.MAP_STRING_FORMAT, formatStr)
end

---Map published values to a string with the specified suffix appended.
---@param suffix string The string to append to the published values
---@return ReactivePublisherSchema
function ReactivePublisherSchema:MapToStringAddSuffix(suffix)
	return self:_AddStepHelper(STEP.MAP_STRING_ADD_SUFFIX, suffix)
end

---Map published values to a string with the specified prefix prepended.
---@param prefix string The string to prepend to the published values
---@return ReactivePublisherSchema
function ReactivePublisherSchema:MapToStringAddPrefix(prefix)
	return self:_AddStepHelper(STEP.MAP_STRING_ADD_PREFIX, prefix)
end

---Map published values to a specific value.
---@param value any The value to map to
---@return ReactivePublisherSchema
function ReactivePublisherSchema:MapToValue(value)
	return self:_AddStepHelper(STEP.MAP_TO_VALUE, value)
end

---Map nil published values to a specific value.
---@param value any The value to map to
---@return ReactivePublisherSchema
function ReactivePublisherSchema:MapNilToValue(value)
	return self:_AddStepHelper(STEP.MAP_NIL_TO_VALUE, value)
end

---Map non-nil published values to another value using a function and passes nil values straight through.
---@param func fun(value: any): any The mapping function which takes the published values and returns the results
---@param arg any An additional argument to pass to the method
---@return ReactivePublisherSchema
function ReactivePublisherSchema:MapNonNilWithFunction(func, arg)
	return self:_AddStepHelper(STEP.MAP_NON_NIL_WITH_FUNCTION, func, arg)
end

---Map non-nil published values to another value by calling a method on them and passes nil values straight through.
---@param method string The name of the method to call on the published values
---@param arg any An additional argument to pass to the method
---@return ReactivePublisherSchema
function ReactivePublisherSchema:MapNonNilWithMethod(method, arg)
	return self:_AddStepHelper(STEP.MAP_NON_NIL_WITH_METHOD, method, arg)
end

---Invert published boolean values.
---@return ReactivePublisherSchema
function ReactivePublisherSchema:InvertBoolean()
	return self:_AddStepHelper(STEP.INVERT_BOOLEAN)
end

---Ignores published values where a specified key equals the specified value.
---@param key string|number The key to compare at
---@param value any The value to compare with
---@return ReactivePublisherSchema
function ReactivePublisherSchema:IgnoreIfKeyEquals(key, value)
	return self:_AddStepHelper(STEP.IGNORE_IF_KEY_EQUALS, key, value)
end

---Ignores published values where a specified key does not equal the specified value.
---@param key string|number The key to compare at
---@param value any The value to compare with
---@return ReactivePublisherSchema
function ReactivePublisherSchema:IgnoreIfKeyNotEquals(key, value)
	return self:_AddStepHelper(STEP.IGNORE_IF_KEY_NOT_EQUALS, key, value)
end

---Ignores published values which equal the specified value.
---@param value any The value to compare against
---@return ReactivePublisherSchema
function ReactivePublisherSchema:IgnoreIfEquals(value)
	return self:_AddStepHelper(STEP.IGNORE_IF_EQUALS, value)
end

---Ignores published values which don't equal the specified value.
---@param value any The value to compare against
---@return ReactivePublisherSchema
function ReactivePublisherSchema:IgnoreIfNotEquals(value)
	return self:_AddStepHelper(STEP.IGNORE_IF_NOT_EQUALS, value)
end

---Ignores published values if it's nil.
---@return ReactivePublisherSchema
function ReactivePublisherSchema:IgnoreNil()
	return self:_AddStepHelper(STEP.IGNORE_NIL)
end

---Ignores duplicate published values.
---@return ReactivePublisherSchema
function ReactivePublisherSchema:IgnoreDuplicates()
	return self:_AddStepHelper(STEP.IGNORE_DUPLICATES)
end

---Ignores duplicate published values by checking the specified keys.
---@param ... string Keys to compare to detect duplicate published values
---@return ReactivePublisherSchema
function ReactivePublisherSchema:IgnoreDuplicatesWithKeys(...)
	return self:_AddStepHelper(STEP.IGNORE_DUPLICATES_WITH_KEYS, ...)
end

---Ignores duplicate published values by calling the specified method.
---@param method string The method to call on the published values
---@return ReactivePublisherSchema
function ReactivePublisherSchema:IgnoreDuplicatesWithMethod(method)
	return self:_AddStepHelper(STEP.IGNORE_DUPLICATES_WITH_METHOD, method)
end

---Prints published values and passes them through for debugging purposes.
---@param tag? string An optional tag to add to the prints
---@return ReactivePublisherSchema
function ReactivePublisherSchema:Print(tag)
	return self:_AddStepHelper(STEP.PRINT, tag)
end

---Shares the result of the publisher at the current point in the chain.
---@return ReactivePublisherSchema
function ReactivePublisherSchema:Share()
	assert(not self._hasShare)
	self._hasShare = true
	return self:_AddStepHelper(STEP.SHARE)
end

---Calls a method with the published values and continue the publisher chain.
---@param obj table The object to call the method on
---@param method string The name of the method to call with the published values
---@return ReactivePublisherSchema
function ReactivePublisherSchema:CallMethodAndContinueShare(obj, method)
	return self:_AddContinueShareStepHelper(STEP.CALL_METHOD, obj, method)
end

---Calls a function with the published values and continue the publisher chain.
---@param func fun(value: any) The function to call with the published values
---@return ReactivePublisherSchema
function ReactivePublisherSchema:CallFunctionAndContinueShare(func)
	return self:_AddContinueShareStepHelper(STEP.CALL_FUNCTION, func)
end

---Assigns published values to the specified key in the table and continue the publisher chain.
---@param tbl table The table to assign the published values into
---@param key string The key to assign the published values at
---@return ReactivePublisherSchema
function ReactivePublisherSchema:AssignToTableKeyAndContinueShare(tbl, key)
	return self:_AddContinueShareStepHelper(STEP.ASSIGN_TO_TABLE_KEY, tbl, key)
end

---Calls a method with the published values.
---@param obj table The object to call the method on
---@param method string The name of the method to call with the published values
---@return ReactivePublisher
function ReactivePublisherSchema:CallMethod(obj, method)
	self:_AddStepHelper(STEP.CALL_METHOD, obj, method)
	return self:_Commit()
end

---Calls a function with the published values.
---@param func fun(value: any) The function to call with the published values
---@return ReactivePublisher
function ReactivePublisherSchema:CallFunction(func)
	self:_AddStepHelper(STEP.CALL_FUNCTION, func)
	return self:_Commit()
end

---Assigns published values to the specified key in the table.
---@param tbl table The table to assign the published values into
---@param key string The key to assign the published values at
---@return ReactivePublisher
function ReactivePublisherSchema:AssignToTableKey(tbl, key)
	self:_AddStepHelper(STEP.ASSIGN_TO_TABLE_KEY, tbl, key)
	return self:_Commit()
end

---Ends a share which was previously-continued without needing to add another step.
---@return ReactivePublisher
function ReactivePublisherSchema:EndShare()
	assert(self._hasShare)
	return self:_Commit()
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function ReactivePublisherSchema.__private:_AddStepHelper(stepType, ...)
	assert(self._subject)
	self._codeGen = self._codeGen or ReactivePublisherCodeGen.Get()
	self._codeGen:AddStep(stepType, ...)
	return self
end

function ReactivePublisherSchema.__private:_AddContinueShareStepHelper(stepType, ...)
	assert(self._hasShare)
	return self:_AddStepHelper(stepType, ...)
end

function ReactivePublisherSchema.__private:_Commit()
	-- Commit the generated code to a publisher
	local publisher = ReactivePublisher.Get(self._codeGen, self._subject)
	self._codeGen = nil

	-- Disable the publisher if applicable
	if self._autoDisable then
		publisher:Disable()
	end

	-- Auto-store the publisher if applicable
	if self._autoStore then
		publisher:StoreIn(self._autoStore)
	end

	-- Release this schema object
	self:_Release()

	return publisher
end
