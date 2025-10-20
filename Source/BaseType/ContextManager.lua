-- ------------------------------------------------------------------------------ --
--                                   LibTSMUtil                                   --
--                 https://github.com/TradeSkillMaster/LibTSMUtil                 --
--         Licensed under the MIT license. See LICENSE.txt for more info.         --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local ContextManager = LibTSMUtil:Init("BaseType.ContextManager")
local private = {
	enterFunc = {},
	exitFunc = {},
	iterContext = {},
}
local ITER_CONTEXT_POOL_SIZE = 10
local PLACEHOLDER_ENTER_VALUE = newproxy(false)



-- ============================================================================
-- Metatable
-- ============================================================================

---@class ContextManagerObject
local CONTEXT_MANAGER_METHODS = {}

local CONTEXT_MANAGER_MT = {
	__newindex = function()
		error("ContextManager is read-only")
	end,
	__index = CONTEXT_MANAGER_METHODS,
	__metatable = false,
}



-- ============================================================================
-- Module Loading
-- ============================================================================

ContextManager:OnModuleLoad(function()
	for _ = 1, ITER_CONTEXT_POOL_SIZE do
		tinsert(private.iterContext, {})
	end
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Creates a context manager.
---@generic A, E
---@param enterFunc fun(arg: A): E The enter function which is called when the managed code block starts
---@param exitFunc fun(arg: A, enterValue: E) The exit function which is called when the managed code block completes
---@return ContextManagerObject
function ContextManager.Create(enterFunc, exitFunc)
	local obj = setmetatable({}, CONTEXT_MANAGER_MT)
	private.enterFunc[obj] = enterFunc
	private.exitFunc[obj] = exitFunc
	return obj
end



-- ============================================================================
-- Context Manager Class
-- ============================================================================

---Returns an iterator which executes to completion with the context manager.
---
---**NOTE:** The iterator must not be interrupted (i.e. with a `break` or `return`).
---@param arg any A value to pass as the first argument to the enter and exit functions (must be non-nil)
---@param func? fun(obj: any, key?: any): ... The iterator function or nil to iterate exactly once
---@param obj? any The object to pass to the iterator function
---@param key? any The initial key to pass to the iterator function
---@return function
---@return any
---@return any
function CONTEXT_MANAGER_METHODS:With(arg, func, obj, key)
	if func == nil then
		if not arg or obj ~= nil or key ~= nil then
			error("Invalid args", 2)
		end
		func = private.IterateOnce
		obj = arg
	end
	local iterContext = tremove(private.iterContext, 1)
	if not iterContext then
		error("No available iter context")
	end
	iterContext.arg = arg
	iterContext.func = func
	iterContext.obj = obj
	iterContext.key = key
	private.iterContext[iterContext] = true
	return self --[[@as function]], iterContext, key
end



-- ============================================================================
-- Context Manager __call Metamethod
-- ============================================================================

function CONTEXT_MANAGER_MT:__call(iterContext)
	if not private.iterContext[iterContext] then
		error("Using non-acquired iter context")
	end
	if iterContext.enterValue == nil then
		-- This is the first iteration - call the enter function and start the iterator
		iterContext.enterValue = private.enterFunc[self](iterContext.arg)
		if iterContext.enterValue == nil then
			iterContext.enterValue = PLACEHOLDER_ENTER_VALUE
		end
	end
	return private.CheckIteratorValues(self, iterContext, iterContext.func(iterContext.obj, iterContext.key))
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.IterateOnce(arg, key)
	if key == nil then
		-- This is the 1st loop, so return the arg
		return arg
	elseif key == arg then
		-- This is the 2nd loop, so finish the iteration
		return
	else
		error("Unexpected key: "..tostring(key))
	end
end

function private.CheckIteratorValues(obj, iterContext, key, ...)
	if key == nil then
		-- This is the end of the iteration, so call the exit function
		if iterContext.enterValue == PLACEHOLDER_ENTER_VALUE then
			iterContext.enterValue = nil
		end
		private.exitFunc[obj](iterContext.arg, iterContext.enterValue)
		wipe(iterContext)
		private.iterContext[iterContext] = nil
		tinsert(private.iterContext, iterContext)
		return
	else
		iterContext.key = key
		return key, ...
	end
end
