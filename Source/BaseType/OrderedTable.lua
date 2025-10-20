-- ------------------------------------------------------------------------------ --
--                                   LibTSMUtil                                   --
--                 https://github.com/TradeSkillMaster/LibTSMUtil                 --
--         Licensed under the MIT license. See LICENSE.txt for more info.         --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local OrderedTable = LibTSMUtil:Init("BaseType.OrderedTable")
local Table = LibTSMUtil:Include("Lua.Table")
local private = {}

---@class OrderedTable.Table<K,V>: { [integer]: V, [K]: V }



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets a value from an ordered table by index.
---@generic K, V
---@param tbl OrderedTable.Table<K,V>
---@param index number
---@return K
---@return V
function OrderedTable.GetByIndex(tbl, index)
	local key = tbl[index]
	if key == nil then
		error("Invalid index: "..tostring(index))
	end
	local value = tbl[key]
	return key, value
end

---Inserts into an ordered table.
---@generic K, V
---@param tbl OrderedTable.Table<K,V> The ordered table
---@param key K The key to insert
---@param value V The value to insert
function OrderedTable.Insert(tbl, key, value)
	tinsert(tbl, key)
	tbl[key] = value
end

---Inserts into an ordered table if the key wasn't previously set.
---@generic K, V
---@param tbl OrderedTable.Table<K,V> The ordered table
---@param key K The key to insert
---@param value V The value to insert
function OrderedTable.InsertIfNotSet(tbl, key, value)
	if tbl[key] ~= nil then
		return
	end
	return OrderedTable.Insert(tbl, key, value)
end

---Removes from an ordered table.
---@generic K, V
---@param tbl OrderedTable.Table<K,V> The ordered table
---@param key K The key to remove
function OrderedTable.Remove(tbl, key)
	tbl[key] = nil
	assert(Table.RemoveByValue(tbl, key) == 1)
end

---Sorts the ordered table by its keys
---@generic K, V
---@param tbl OrderedTable.Table<K,V> The ordered table
function OrderedTable.SortByKeys(tbl)
	Table.Sort(tbl)
end

---Sorts the ordered table by its values
---@generic K, V
---@param tbl OrderedTable.Table<K,V> The ordered table
function OrderedTable.SortByValues(tbl)
	Table.SortWithValueLookup(tbl, tbl)
end

---Iterates over an ordered table.
---@generic K, V
---@param tbl OrderedTable.Table<K,V> The ordered table
---@return fun(): number, K, V @Iterator with fields: `index`, `key`, `value`
---@return OrderedTable.Table<K,V>
function OrderedTable.Iterator(tbl)
	return private.IteratorHelper, tbl
end

---Iterates over the keys of an ordered table.
---@generic K, V
---@param tbl OrderedTable.Table<K,V> The ordered table
---@return fun(): number, K @Iterator with fields: `key`
---@return OrderedTable.Table<K,V>
function OrderedTable.KeyIterator(tbl)
	return private.KeyIteratorHelper, tbl
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.IteratorHelper(tbl, index)
	index = (index or 0) + 1
	if index > #tbl then
		return
	end
	local key = tbl[index]
	return index, key, tbl[key]
end

function private.KeyIteratorHelper(tbl, index)
	index = (index or 0) + 1
	if index > #tbl then
		return
	end
	local key = tbl[index]
	return index, key
end
