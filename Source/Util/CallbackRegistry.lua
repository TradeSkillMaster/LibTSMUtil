-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local CallbackRegistry = LibTSMUtil:DefineClassType("CallbackRegistry")
local Table = LibTSMUtil:Include("Lua.Table")
local ExecutionTime = LibTSMUtil:Include("Util.ExecutionTime")



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Creates a new callback registry which maintains a list of callbacks.
---@param executionTimeLabel? string
---@return CallbackRegistry
function CallbackRegistry.__static.NewList(executionTimeLabel)
	return CallbackRegistry(false, executionTimeLabel)
end

---Creates a new callback registry which maintains a keyed table of callbacks.
---@param executionTimeLabel? string
---@return CallbackRegistry
function CallbackRegistry.__static.NewWithKeys(executionTimeLabel)
	return CallbackRegistry(true, executionTimeLabel)
end



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function CallbackRegistry.__private:__init(hasKeys, executionTimeLabel)
	self._hasKeys = hasKeys
	self._executionTimeLabel = executionTimeLabel
	self._funcs = {}
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Adds a callback into the registry.
---@param func function The callback function
---@param key? string The key (required if and only if the registry was created via `NewWithKeys()`)
function CallbackRegistry:Add(func, key)
	assert(type(func) == "function")
	if self._hasKeys then
		assert(key)
		assert(not self:HasCallback(key))
		self._funcs[key] = func
	else
		assert(not key)
		assert(not self:HasCallback(func))
		tinsert(self._funcs, func)
	end
end

---Removes a callback from the registry.
---@param funcOrKey function|string The callback function for registries created via `NewList()` or the key if created via `NewWithkeys()`
function CallbackRegistry:Remove(funcOrKey)
	if self._hasKeys then
		assert(self._funcs[funcOrKey])
		self._funcs[funcOrKey] = nil
	else
		assert(type(funcOrKey) == "function")
		assert(Table.RemoveByValue(self._funcs, funcOrKey) == 1)
	end
end

---Checks if a callback is already within the registry.
---@param funcOrKey function|string The callback function for registries created via `NewList()` or the key if created via `NewWithkeys()`
function CallbackRegistry:HasCallback(funcOrKey)
	if self._hasKeys then
		return self._funcs[funcOrKey] and true or false
	else
		return Table.KeyByValue(self._funcs, funcOrKey) and true or false
	end
end

---Returns whether or not the registry is empty.
---@return boolean
function CallbackRegistry:IsEmpty()
	return not next(self._funcs)
end

---Removes all callbacks from the registry.
function CallbackRegistry:Wipe()
	wipe(self._funcs)
end

---Calls a specific registered callback by its key and passes through its returns.
---
---**NOTE:** This registry must have been created via `NewWithKeys()` and without an execution time label
---@param key string The key
---@param ... any Arguments to pass to the callbacks
---@return ...
function CallbackRegistry:Call(key, ...)
	assert(self._hasKeys and not self._executionTimeLabel)
	local func = self._funcs[key]
	assert(func)
	return func(...)
end

---Calls all registered callbacks.
---@param ... any Arguments to pass to the callbacks
function CallbackRegistry:CallAll(...)
	if self._hasKeys then
		for key, func in pairs(self._funcs) do
			self:_DoCallback(key, func, ...)
		end
	else
		for _, func in pairs(self._funcs) do
			self:_DoCallback(nil, func, ...)
		end
	end
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function CallbackRegistry:_DoCallback(key, func, ...)
	if self._executionTimeLabel then
		for _ in ExecutionTime.WithMeasurementAndRaisedLogStackLevel(2, self._executionTimeLabel, key) do
			func(...)
		end
	else
		func(...)
	end
end
