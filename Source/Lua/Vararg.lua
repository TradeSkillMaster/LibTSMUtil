-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local Vararg = LibTSMUtil:Init("Lua.Vararg")
local private = {
	iterTemp = {},
}
local PLACEHOLDER_VALUE = newproxy(false)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Stores a varag into a table.
---@param tbl table The table to store the values in
---@param ... any Zero or more values to store in the table
function Vararg.IntoTable(tbl, ...)
	local numValues = select("#", ...)
	if numValues == 0 then
		return
	end
	-- Populate with placeholder values so the table acts as a list even if there are nil values in the middle
	for i = 1, numValues do
		tbl[i] = PLACEHOLDER_VALUE
	end
	-- Insert up to 4 values at a time as an optimization
	local index = 1
	while numValues > 0 do
		local arg1, arg2, arg3, arg4 = nil, nil, nil, nil
		if index == 1 then
			arg1, arg2, arg3, arg4 = ...
		else
			arg1, arg2, arg3, arg4 = select(index, ...)
		end
		if numValues == 1 then
			tbl[index] = arg1
		elseif numValues == 2 then
			tbl[index] = arg1
			tbl[index + 1] = arg2
		elseif numValues == 3 then
			tbl[index] = arg1
			tbl[index + 1] = arg2
			tbl[index + 2] = arg3
		else
			tbl[index] = arg1
			tbl[index + 1] = arg2
			tbl[index + 2] = arg3
			tbl[index + 3] = arg4
		end
		index = index + 4
		numValues = numValues - 4
	end
end

---Creates an iterator from a vararg.
---
---**NOTE:** This iterator must be run to completion and not be interrupted (i.e. with a `break` or `return`).
---@param ... any The values to iterate over
---@return fun(): number, any @Iterator with fields: `index`, `value`
---@return table
---@return number
function Vararg.Iterator(...)
	local tbl = private.iterTemp
	assert(not tbl.inUse)
	tbl.inUse = true
	tbl.length = select("#", ...)
	Vararg.IntoTable(tbl, ...)
	return private.IteratorHelper, tbl, 0
end

---Returns whether not the value exists within the vararg.
---@param value any The value to search for
---@param ... any Any number of values to search in
---@return boolean
function Vararg.In(value, ...)
	local numValues = select("#", ...)
	-- Check up to 4 values at a time as an optimization
	local index = 1
	while numValues > 0 do
		local arg1, arg2, arg3, arg4 = nil, nil, nil, nil
		if index == 1 then
			arg1, arg2, arg3, arg4 = ...
		else
			arg1, arg2, arg3, arg4 = select(index, ...)
		end
		if numValues >= 1 and arg1 == value then
			return true
		elseif numValues >= 2 and arg2 == value then
			return true
		elseif numValues >= 3 and arg3 == value then
			return true
		elseif numValues >= 4 and arg4 == value then
			return true
		end
		index = index + 4
		numValues = numValues - 4
	end
	return false
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.IteratorHelper(tbl, index)
	index = index + 1
	if index > tbl.length then
		wipe(tbl)
		return
	end
	return index, tbl[index]
end
