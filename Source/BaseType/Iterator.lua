-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local Iterator = LibTSMUtil:Init("BaseType.Iterator")
local TempTable = LibTSMUtil:Include("BaseType.TempTable")
local Vararg = LibTSMUtil:Include("Lua.Vararg")
local ObjectPool = LibTSMUtil:IncludeClassType("ObjectPool")
local private = {
	objectPool = nil,
	context = {}, ---@type table<IteratorObject,IteratorContext>
}

---@alias IteratorFunc fun(obj?: any, key: any, ...: any): ...
---@alias IteratorFilterFunc fun(key: any, ...): boolean
---@alias IteratorMapFunc fun(key: any, ...): ...
---@alias IteratorCleanupFunc fun(key: any)

---@class IteratorContext
---@field filterFuncs IteratorFilterFunc[]
---@field mapFunc IteratorMapFunc?
---@field cleanupFunc IteratorCleanupFunc?
---@field func IteratorFunc?
---@field obj any?
---@field key any?
---@field extraArgs any[]
---@field releaseNext boolean?



-- ============================================================================
-- Iterator Metatable
-- ============================================================================

---@class IteratorObject
---@overload fun(): ...
local ITERATOR_METHODS = {}

local ITERATOR_MT = {
	__index = ITERATOR_METHODS,
	__newindex = function() error("Iterator cannot be written to", 2) end,
	__tostring = function(self)
		return "Iterator:"..strmatch(tostring(private.context[self]), "table:[^1-9a-fA-F]*([0-9a-fA-F]+)")
	end,
	__metatable = false,
}



-- ============================================================================
-- Module Loading
-- ============================================================================

Iterator:OnModuleLoad(function()
	private.objectPool = ObjectPool.New("ITERATOR", function()
		local iter = setmetatable({}, ITERATOR_MT)
		private.context[iter] = {
			filterFuncs = {},
			extraArgs = {},
		}
		return iter
	end)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Acquires an Iterator object which wraps the passed iterator function.
---@generic T, K
---@param func fun(obj?: T, key: K, ...: any): ... The iterator function
---@param obj? T The object being iterated over
---@param key? K The initial key for the iterator function
---@param ... any Additional arguments to pass to the iterator function
---@return IteratorObject
function Iterator.Acquire(func, obj, key, ...)
	assert(type(func) == "function")
	local iter = private.objectPool:Get() ---@type IteratorObject
	local context = private.context[iter]
	assert(context and not context.func)
	context.func = func
	context.obj = obj
	context.key = key
	Vararg.IntoTable(context.extraArgs, ...)
	return iter
end

---Acquires an Iterator object which does not produce any values.
---@return IteratorObject|fun()
function Iterator.AcquireEmpty()
	return Iterator.Acquire(private.EmptyIterator)
end



-- ============================================================================
-- Iterator Class
-- ============================================================================

---Sets a function to filter iterator values (happens before mapping).
---@param func IteratorFilterFunc Function which returns if a value should be provided by the iterator
---@return IteratorObject
function ITERATOR_METHODS:Filter(func)
	local context = private.context[self]
	assert(type(func) == "function")
	tinsert(context.filterFuncs, func)
	return self
end

---Sets a function to map iterator values (happens after filtering).
---@param func IteratorMapFunc Function used to map iterator values (the key cannot be mapped and shouldn't be returned)
---@return IteratorObject
function ITERATOR_METHODS:SetMapFunc(func)
	local context = private.context[self]
	assert(type(func) == "function" and not context.mapFunc)
	context.mapFunc = func
	return self
end

---Sets a function called when the iterator is released to clean up any associated context.
---@param func fun(obj: any) The cleanup function which is passed the original iterator object
---@return IteratorObject
function ITERATOR_METHODS:SetCleanupFunc(func)
	local context = private.context[self]
	assert(type(func) == "function" and not context.cleanupFunc)
	context.cleanupFunc = func
	return self
end

---Get the next value and release the iterator.
---@return any ...
function ITERATOR_METHODS:GetValueAndRelease()
	local context = private.context[self]
	assert(context.func)
	context.releaseNext = true
	return self()
end

---Evaluates the iterator and returns the result as a joined string of all the values.
---@param sep string The separator
---@param sorted? boolean Whether or not to sort the values before concatenating it
---@return string
function ITERATOR_METHODS:ToJoinedValueString(sep, sorted)
	local parts = TempTable.Acquire()
	for _, value in self do
		tinsert(parts, value)
	end
	if sorted then
		sort(parts)
	end
	return TempTable.ConcatAndRelease(parts, sep)
end

---Releases the iterator.
function ITERATOR_METHODS:Release()
	local context = private.context[self]
	local cleanupFunc = context.cleanupFunc
	local obj = context.obj
	assert(context.func)
	wipe(context.filterFuncs)
	context.mapFunc = nil
	context.cleanupFunc = nil
	context.func = nil
	context.obj = nil
	context.key = nil
	context.releaseNext = nil
	wipe(context.extraArgs)
	private.objectPool:Recycle(self)
	if cleanupFunc then
		cleanupFunc(obj)
	end
end



-- ============================================================================
-- Iterator __call Metamethod
-- ============================================================================

---@param self IteratorObject
function ITERATOR_MT:__call()
	local context = private.context[self]
	return private.IterateHelper(self, context, context.func(context.obj, context.key, unpack(context.extraArgs)))
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

---@param iter IteratorObject
---@param context IteratorContext
function private.IterateHelper(iter, context, key, ...)
	if key == nil then
		return iter:Release()
	end
	context.key = key
	for i = 1, #context.filterFuncs do
		if not context.filterFuncs[i](key, ...) then
			return iter()
		end
	end
	local mapFunc = context.mapFunc
	if context.releaseNext then
		iter:Release()
	end
	if mapFunc then
		return key, mapFunc(key, ...)
	else
		return key, ...
	end
end

function private.EmptyIterator()
	-- Don't return anything
end
