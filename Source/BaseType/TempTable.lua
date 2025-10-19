-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local TempTable = LibTSMUtil:Init("BaseType.TempTable")
local DebugStack = LibTSMUtil:Include("Lua.DebugStack")
local Table = LibTSMUtil:Include("Lua.Table")
local Vararg = LibTSMUtil:Include("Lua.Vararg")
local private = {
	debugLeaks = LibTSMUtil.IsTestVersion(),
	free = {},
	state = {},
	iterNumFields = {},
	owner = {},
	numTables = 0,
}
local MAX_NUM_TABLES = 100
local RELEASED_TEMP_TABLE_MT = {
	__newindex = function()
		error("Attempt to access temp table after release", 2)
	end,
	__index = function()
		error("Attempt to access temp table after release", 2)
	end,
}



-- ============================================================================
-- Module Loading
-- ============================================================================

TempTable:OnModuleLoad(function()
	-- Mark the keys of our free table as weak to allow the GC to recycle temp tables
	setmetatable(private.free, { __mode = "k" })
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Acquires a temporary table.
---
---Temporary tables are recycled tables which can be used instead of creating a new table every time one is needed for a
---defined lifecycle. This avoids relying on the garbage collector and improves overall performance.
---@param ... any Any number of values to insert into the table initially
---@return table
function TempTable.Acquire(...)
	if private.numTables >= MAX_NUM_TABLES then
		error("Could not acquire temp table")
	end
	private.numTables = private.numTables + 1
	local tbl = next(private.free)
	if tbl then
		private.free[tbl] = nil
		setmetatable(tbl, nil)
		Vararg.IntoTable(tbl, ...)
	else
		tbl = {...}
	end
	if private.debugLeaks then
		private.state[tbl] = (DebugStack.GetLocation(3) or "?").." -> "..(DebugStack.GetLocation(4) or "?")
	else
		private.state[tbl] = true
	end
	return tbl
end

---Acquires a temporary table and takes ownership.
---@param owner table The owner
---@param ... any Any number of values to insert into the table initially
---@return table
function TempTable.AcquireWithOwner(owner, ...)
	local tbl = TempTable.Acquire(...)
	TempTable.TakeOwnership(tbl, owner)
	return tbl
end

---Iterators over a temporary table, releasing it when done.
---
---**NOTE:** This iterator must be run to completion and not be interrupted (i.e. with a `break` or `return`).
---@param tbl table The temporary table to iterator over
---@param numFields? number The number of fields to unpack with each iteration (defaults to 1)
---@return fun(): number, ... @Iterator with fields: `index`, `{numFields...}`
---@return table
---@return number
function TempTable.Iterator(tbl, numFields)
	numFields = numFields or 1
	assert(numFields >= 1 and #tbl % numFields == 0)
	assert(private.state[tbl])
	assert(not private.iterNumFields[tbl])
	private.iterNumFields[tbl] = numFields
	return private.Iterator, tbl, 1 - numFields
end

---Iterators over the keys of a temporary table, releasing it when done.
---
---**NOTE:** This iterator must be run to completion and not be interrupted (i.e. with a `break` or `return`).
---@param tbl table The temporary table to iterator over
---@return fun(): number, ... @Iterator with fields: `key`
---@return table
function TempTable.KeyIterator(tbl)
	assert(private.state[tbl])
	return private.KeyIterator, tbl
end

---Releases a temporary table.
---
---The temporary table will be returned to the pool and must not be accessed after being released.
---@param tbl table The temporary table to release
function TempTable.Release(tbl)
	private.ReleaseHelper(tbl)
end

---Releases the temporary table and returns its unpacked values.
---@generic T
---@param tbl T[] The temporary table to release and unpack
---@return T ...
function TempTable.UnpackAndRelease(tbl)
	return private.ReleaseHelper(tbl, unpack(tbl))
end

---Concatenates the temporary table and releases it.
---@param tbl string[] The temporary table
---@param sep string The separator
---@param startIndex? number The first index to concat
---@param endIndex? number The last index to concat
---@return string
function TempTable.ConcatAndRelease(tbl, sep, startIndex, endIndex)
	local result = table.concat(tbl, sep, startIndex, endIndex)
	private.ReleaseHelper(tbl)
	return result
end

---Assigns ownership of a temp table.
---@param tbl table The temp table
---@param owner table The owner
function TempTable.TakeOwnership(tbl, owner)
	assert(type(owner) == "table")
	assert(private.state[tbl] and not private.owner[tbl])
	private.owner[tbl] = owner
end

---Releases all owned temp tables.
---@param owner table The owner
function TempTable.ReleaseAllOwned(owner)
	assert(type(owner) == "table")
	for tbl, tblOwner in pairs(private.owner) do
		if tblOwner == owner then
			private.ReleaseHelper(tbl)
		end
	end
end

---Enables tracking of where temp tables are created from in order to debug leaks.
function TempTable.EnableLeakDebug()
	private.debugLeaks = true
end

---Gets debug information describing allocated and free temp tables.
---@return string[]
function TempTable.GetDebugInfo()
	local debugInfo = {}
	local counts = {}
	for _, info in pairs(private.state) do
		counts[info] = (counts[info] or 0) + 1
	end
	for info, count in pairs(counts) do
		tinsert(debugInfo, format("[%d] %s", count, type(info) == "string" and info or "?"))
	end
	if #debugInfo == 0 then
		tinsert(debugInfo, "<none>")
	end
	return debugInfo
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.Iterator(tbl, index)
	local numFields = private.iterNumFields[tbl]
	index = index + numFields
	if index > #tbl then
		private.iterNumFields[tbl] = nil
		TempTable.Release(tbl)
		return
	end
	if numFields == 1 then
		return index, tbl[index]
	else
		return index, unpack(tbl, index, index + numFields - 1)
	end
end

function private.KeyIterator(tbl, key)
	key = next(tbl, key)
	if key == nil then
		TempTable.Release(tbl)
		return
	end
	return key
end

function private.ReleaseHelper(tbl, ...)
	if not private.state[tbl] then
		error("Invalid table")
	end
	Table.WipeAndDeallocate(tbl)
	private.free[tbl] = true
	private.state[tbl] = nil
	private.owner[tbl] = nil
	private.numTables = private.numTables - 1
	setmetatable(tbl, RELEASED_TEMP_TABLE_MT)
	return ...
end
