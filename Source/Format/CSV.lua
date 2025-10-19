-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local CSV = LibTSMUtil:Init("Format.CSV")
local String = LibTSMUtil:Include("Lua.String")
local TempTable = LibTSMUtil:Include("BaseType.TempTable")
local private = {
	linePartsTemp = {},
}



-- ============================================================================
-- Module Functions
-- ============================================================================

---Creates a CSV encoding context for the specified keys.
---@param keys string[] The keys which are being encoded
---@return table
function CSV.EncodeStart(keys)
	local context = TempTable.Acquire()
	context.keys = keys
	tinsert(context, table.concat(keys, ","))
	return context
end

---Adds a row to the CSV encoding context.
---@param context table The CSV encoding context
---@param data table The data for the row
function CSV.EncodeAddRowData(context, data)
	for i = 1, #context.keys do
		private.linePartsTemp[i] = data[context.keys[i]] or ""
	end
	tinsert(context, table.concat(private.linePartsTemp, ","))
	wipe(private.linePartsTemp)
end

---Adds a raw row to the CSV encoding context.
---@param context table The CSV encoding context
---@param ... string The raw data for the row
function CSV.EncodeAddRowDataRaw(context, ...)
	tinsert(context, strjoin(",", ...))
end

---Ends a CSV encoding context and returns the resulting CSV string.
---@param context table The CSV encoding context
---@return string
function CSV.EncodeEnd(context)
	return TempTable.ConcatAndRelease(context, "\n")
end

---Encodes the specified data to a CSV string.
---@param keys string[] The list of keys to encode
---@param data table The data to encode
---@return string
function CSV.Encode(keys, data)
	local context = CSV.EncodeStart(keys)
	for _, row in ipairs(data) do
		CSV.EncodeAddRowData(context, row)
	end
	return CSV.EncodeEnd(context)
end

---Creates a CSV decoding context for the specified fields.
---@param str string The CSV encoded data
---@param fields string[] The fields which are being decoded
---@return table? context
function CSV.DecodeStart(str, fields)
	local context = TempTable.Acquire()
	context.numFields = #fields
	context.result = true
	context.index = 1
	String.SafeSplit(str, "\n", context)
	if context[1] ~= table.concat(fields, ",") then
		CSV.DecodeEnd(context)
		return nil
	end
	return context
end

---Iterates over the CSV encoded data.
---@param context table The CSV decoding context
---@return fun(): ... @Iterator with fields matching the decoded values
---@return table
function CSV.DecodeIterator(context)
	return private.DecodeIteratorHelper, context
end

---Ends a CSV decoding context and returns whether or not the data was fully decoded successfully.
---@param context table The CSV decoding context
---@return boolean
function CSV.DecodeEnd(context)
	local result = context.result
	TempTable.Release(context)
	return result
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.DecodeIteratorHelper(context)
	context.index = context.index + 1
	if context.index > #context then
		return
	end
	return private.DecodeIteratorHelper2(context, strsplit(",", context[context.index]))
end

function private.DecodeIteratorHelper2(context, ...)
	if select("#", ...) ~= context.numFields then
		context.result = false
		return
	end
	return ...
end
