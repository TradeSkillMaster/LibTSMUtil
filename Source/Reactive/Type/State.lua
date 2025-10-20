-- ------------------------------------------------------------------------------ --
--                                   LibTSMUtil                                   --
--                 https://github.com/TradeSkillMaster/LibTSMUtil                 --
--         Licensed under the MIT license. See LICENSE.txt for more info.         --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local State = LibTSMUtil:Init("Reactive.Type.State")
local Expression = LibTSMUtil:IncludeClassType("ReactiveStateExpression")
local ReactivePublisherSchema = LibTSMUtil:IncludeClassType("ReactivePublisherSchema")
local Table = LibTSMUtil:Include("Lua.Table")
local Vararg = LibTSMUtil:Include("Lua.Vararg")
local private = {
	nextPublisherId = 1,
	stateContext = {}, ---@type table<ReactiveState,StateContext>
	debugLinesTemp = {},
	keysTemp = {},
}

---@class StateContext
---@field schema ReactiveStateSchema
---@field data table<string,any>
---@field publishers table<ReactivePublisher,number>|ReactivePublisher[]
---@field deferredPublishers ReactivePublisher[]
---@field disabled table<ReactivePublisher,boolean|nil>
---@field autoDeferred boolean
---@field autoStore table?
---@field autoStorePaused boolean
---@field autoDisable boolean
---@field handlingDataChange boolean
---@field dataChangeQueue string[]
---@field dataChangeTemp ReactivePublisher[]



-- ============================================================================
-- State Methods
-- ============================================================================

local STATE_METHODS = {} ---@class ReactiveState: ReactiveSubject

---Creates a new publisher for a specific key of the state.
---@param key string The key to create a publisher for (ignoring duplicate values)
---@return ReactivePublisherSchema
function STATE_METHODS:PublisherForKeyChange(key)
	local context = private.stateContext[self]
	if not context.schema:_HasKey(key) then ---@diagnostic disable-line: invisible
		error("Unknown state key: "..tostring(key), 2)
	end
	return self:_GetPublisher()
		:MapWithKey(key)
		:IgnoreDuplicates()
end

---Creates a new publisher which publishes the state when any of the specified keys change.
---@param ... string The key to ignore duplicates for
---@return ReactivePublisherSchema
function STATE_METHODS:PublisherForKeys(...)
	local context = private.stateContext[self]
	for _, key in Vararg.Iterator(...) do
		if not context.schema:_HasKey(key) then ---@diagnostic disable-line: invisible
			error("Unknown state key: "..tostring(key), 2)
		end
	end
	return self:_GetPublisher()
		:IgnoreDuplicatesWithKeys(...)
end

---Creates a new publisher which publishes the state when the result of a function which gets passed the specified keys changes.
---
---NOTE: The function must be constant and strictly depend on its inputs only.
---@param ... string The key to ignore duplicates for
---@return ReactivePublisherSchema
function STATE_METHODS:PublisherForFunctionWithKeys(func, ...)
	local context = private.stateContext[self]
	local numArgs = 0
	for _, key in Vararg.Iterator(...) do
		if not context.schema:_HasKey(key) then ---@diagnostic disable-line: invisible
			error("Unknown state key: "..tostring(key), 2)
		end
		numArgs = numArgs + 1
	end
	if numArgs == 1 then
		return self:_GetPublisher()
			:MapWithKey(...)
			:IgnoreDuplicates()
			:MapWithFunction(func)
			:IgnoreDuplicates()
	else
		assert(numArgs > 1)
		return self:_GetPublisher()
			:IgnoreDuplicatesWithKeys(...)
			:MapWithFunctionAndKeys(func, ...)
			:IgnoreDuplicates()
	end
end

---Creates a publisher for an expression which operates on state fields.
---@param expressionStr string A valid lua expression which can only access fields of the state (as globals)
---@return ReactivePublisherSchema
function STATE_METHODS:PublisherForExpression(expressionStr)
	local context = private.stateContext[self]
	local expression = Expression.Get(expressionStr, context.schema)
	local singleKey = expression:GetSingleKey()
	local publisher = self:_GetPublisher()
	if singleKey then
		if not context.schema:_HasKey(singleKey) then ---@diagnostic disable-line: invisible
			error("Unknown state key: "..tostring(singleKey), 2)
		end
		publisher:MapWithKey(singleKey)
		publisher:IgnoreDuplicates()
	else
		assert(not next(private.keysTemp))
		for key in expression:KeyIterator() do
			if not context.schema:_HasKey(key) then ---@diagnostic disable-line: invisible
				error("Unknown state key: "..tostring(key), 2)
			end
			tinsert(private.keysTemp, key)
		end
		publisher:IgnoreDuplicatesWithKeys(Table.UnpackAndWipe(private.keysTemp))
	end
	return publisher
		:MapWithStateExpression(expression)
		:IgnoreDuplicates()
end

---Sets whether or not new publishers which are added should be deferred and handled as late as possible.
---@param deferred boolean Whether or not to defer publishers
function STATE_METHODS:SetAutoDeferred(deferred)
	local context = private.stateContext[self]
	assert(type(deferred) == "boolean" and deferred ~= context.autoDeferred)
	context.autoDeferred = deferred
end

---Gets the default value of a state field.
---@param key string The key to get the default value of
---@return any
function STATE_METHODS:GetDefaultValue(key)
	return private.stateContext[self].schema:_GetDefaultValue(key) ---@diagnostic disable-line: invisible
end

---Resets the state to its default value.
function STATE_METHODS:ResetToDefault()
	local context = private.stateContext[self]
	wipe(context.data)
	context.schema:_ApplyDefaults(context.data) ---@diagnostic disable-line: invisible
	self:_HandleDataChanged()
end

---Automatically stores any new publishers in the specified table.
---@param tbl table The table to store new publishers in
---@return ReactiveState
function STATE_METHODS:SetAutoStore(tbl)
	local context = private.stateContext[self]
	context.autoStore = tbl
	return self
end

---Sets whether automatic storing of new publisher is paused.
---@param paused boolean Pause or unpause automatic storing of publishers
function STATE_METHODS:SetAutoStorePaused(paused)
	local context = private.stateContext[self]
	assert(type(paused) == "boolean" and paused ~= context.autoStorePaused)
	context.autoStorePaused = paused
end

---Sets whether or not new publishers are automatically disabled when stored.
---@param disable boolean Disable publishers when stored
---@return ReactiveState
function STATE_METHODS:SetAutoDisable(disable)
	local context = private.stateContext[self]
	context.autoDisable = disable
	return self
end

---@private
---@return ReactivePublisherSchema
function STATE_METHODS:_GetPublisher()
	local context = private.stateContext[self]
	local schema = ReactivePublisherSchema.Get(self)
	if context.autoStore and not context.autoStorePaused then
		schema:AutoStore(context.autoStore)
	end
	if context.autoDisable then
		schema:AutoDisable()
	end
	return schema
end

---@private
function STATE_METHODS:_GetData()
	return private.stateContext[self].data
end

---@private
---@param publisher ReactivePublisher
function STATE_METHODS:_AddPublisher(publisher)
	local context = private.stateContext[self]
	assert(not context.publishers[publisher])
	context.publishers[publisher] = private.nextPublisherId
	private.nextPublisherId = private.nextPublisherId + 1
	if context.autoDeferred then
		tinsert(context.deferredPublishers, publisher)
	else
		tinsert(context.publishers, publisher)
	end
end

---@private
---@param publisher ReactivePublisher
function STATE_METHODS:_RemovePublisher(publisher)
	local context = private.stateContext[self]
	assert(context.publishers[publisher])
	context.publishers[publisher] = nil
	context.disabled[publisher] = nil
	assert(Table.RemoveByValue(context.publishers, publisher) + Table.RemoveByValue(context.deferredPublishers, publisher) == 1)
end

---@private
---@param publisher ReactivePublisher
---@param disabled boolean
function STATE_METHODS:_SetPublisherDisabled(publisher, disabled)
	local context = private.stateContext[self]
	context.disabled[publisher] = disabled
end

---@private
---@return any
function STATE_METHODS:_GetInitialValue()
	return private.stateContext[self].data
end

---@private
---@return boolean
function STATE_METHODS:_RequiresOptimized()
	return true
end

---@private
function STATE_METHODS:_HandleDataChanged(key)
	local context = private.stateContext[self]
	if context.handlingDataChange then
		-- We are already in the middle of processing another event, so queue this one up
		tinsert(context.dataChangeQueue, key)
		assert(#context.dataChangeQueue < 50)
		return
	end
	context.handlingDataChange = true
	self:_CallPublishersHandleData(key)
	-- Process queued keys
	while #context.dataChangeQueue > 0 do
		local queuedKey = tremove(context.dataChangeQueue, 1)
		self:_CallPublishersHandleData(queuedKey)
	end
	context.handlingDataChange = false
end

---@private
function STATE_METHODS:_CallPublishersHandleData(key)
	local context = private.stateContext[self]
	-- The list of publishers can change as a result of calling _HandleData() so copy them to a
	-- temp table and verify they are still subscribed before calling them.
	if #context.dataChangeTemp ~= 0 then
		error("Temp table is not empty")
	end
	local maxId = 0
	for i = 1, #context.publishers do
		local publisher = context.publishers[i]
		context.dataChangeTemp[i] = publisher
		local id = context.publishers[publisher]
		maxId = id > maxId and id or maxId
	end
	local insertOffset = #context.dataChangeTemp
	for i = 1, #context.deferredPublishers do
		local publisher = context.deferredPublishers[i]
		context.dataChangeTemp[i + insertOffset] = publisher
		local id = context.publishers[publisher]
		maxId = id > maxId and id or maxId
	end
	local data = context.data
	for i = 1, #context.dataChangeTemp do
		local publisher = context.dataChangeTemp[i]
		local id = context.publishers[publisher]
		if id and id <= maxId and not context.disabled[publisher] then
			publisher:_HandleData(data, key) ---@diagnostic disable-line: invisible
		end
	end
	wipe(context.dataChangeTemp)
end



-- ============================================================================
-- State Metatable
-- ============================================================================

local STATE_MT = {
	__index = function(self, key)
		if STATE_METHODS[key] then
			return STATE_METHODS[key]
		end
		local context = private.stateContext[self]
		if not context.schema:_HasKey(key) then ---@diagnostic disable-line: invisible
			error("Invalid key: "..tostring(key))
		end
		return context.data[key]
	end,
	__newindex = function(self, key, value)
		local context = private.stateContext[self]
		local data = context.data
		if data[key] == value then
			return
		end
		context.schema:_ValidateValueForKey(key, value) ---@diagnostic disable-line: invisible
		data[key] = value
		self:_HandleDataChanged(key)
	end,
	__tostring = function(self)
		local context = private.stateContext[self]
		local schemaName = strmatch(tostring(context.schema), "ReactiveStateSchema:(.+)") or "???"
		return schemaName..":"..strsub(strmatch(tostring(context), "table:[^1-9a-fA-F]*([0-9a-fA-F]+)"), -8)
	end,
	__metatable = false,
}



-- ============================================================================
-- Module Functions
-- ============================================================================

---Creates a new state object.
---@return ReactiveState
function State.Create(schema)
	local state = setmetatable({}, STATE_MT)
	local data = {}
	schema:_ApplyDefaults(data)
	private.stateContext[state] = {
		schema = schema,
		data = data,
		publishers = {},
		deferredPublishers = {},
		disabled = {},
		autoDeferred = false,
		autoStore = nil,
		autoStorePaused = false,
		autoDisable = false,
		handlingDataChange = false,
		dataChangeQueue = {},
		dataChangeTemp = {},
	}
	return state
end

---Gets a debug representation of the state object.
---@param state ReactiveState
---@return string?
function State.GetDebugInfo(state)
	local context = private.stateContext[state]
	if not context then
		return nil
	end
	assert(not next(private.debugLinesTemp))
	for key, fieldType in context.schema:_FieldIterator() do ---@diagnostic disable-line: invisible
		local value = context.data[key]
		if value ~= nil then
			if fieldType == "string" then
				tinsert(private.debugLinesTemp, format("%s = \"%s\"", key, value))
			else
				tinsert(private.debugLinesTemp, format("%s = %s", key, tostring(value)))
			end
		end
	end
	local result = table.concat(private.debugLinesTemp, "\n")
	wipe(private.debugLinesTemp)
	return result
end

---Gets state debug data.
---@return table<string,table>
function State.GetDebugData()
	local result = {}
	for state, context in pairs(private.stateContext) do
		result[tostring(state)] = context.data
	end
	return result
end
