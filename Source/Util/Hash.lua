-- ------------------------------------------------------------------------------ --
--                                   LibTSMUtil                                   --
--                 https://github.com/TradeSkillMaster/LibTSMUtil                 --
--         Licensed under the MIT license. See LICENSE.txt for more info.         --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local Hash = LibTSMUtil:Init("Util.Hash")
local Table = LibTSMUtil:Include("Lua.Table")
local private = {
	queueTemp = {},
}
local MAX_VALUE = 2 ^ 24



-- ============================================================================
-- Module Functions
-- ============================================================================

---Calculates the hash of the specified data.
---
-- This can handle data of type string or number. It can also handle a table being passed as the data assuming all
-- keys and values of the table are also hashable (strings, numbers, or tables with the same restriction). This
-- function uses the [djb2 algorithm](http://www.cse.yorku.ca/~oz/hash.html).
---@param data any The data to be hased
---@param hash? number The initial value of the hash
---@return number
function Hash.Calculate(data, hash)
	hash = hash or 5381
	local dataType = type(data)
	if dataType ~= "table" then
		return private.CalculateForSimpleDataType(dataType, data, hash)
	end

	-- This queue is used to make allow for iteratively supporting nested tables - it stores its entries as negative
	-- indexes so the table can also be used as a temporary list of keys that can be sorted
	local queue = private.queueTemp
	queue[-1] = data
	local queueIndex = -1
	local queueLen = 1
	while -queueIndex <= queueLen do
		data = queue[queueIndex]
		dataType = type(data)
		queueIndex = queueIndex - 1
		if dataType == "table" then
			Table.GetKeys(data, queue)
			sort(queue)
			for _, key in ipairs(queue) do
				queue[-queueLen - 1] = key
				queue[-queueLen - 2] = data[key]
				queueLen = queueLen + 2
			end
			for i = #queue, 1, -1 do
				queue[i] = nil
			end
		else
			hash = private.CalculateForSimpleDataType(dataType, data, hash)
		end
	end
	Table.WipeAndDeallocate(private.queueTemp)
	return hash
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.CalculateForSimpleDataType(dataType, value, hash)
	if dataType == "string" then
		-- Iterate through 8 bytes at a time
		for i = 1, ceil(strlenutf8(value) / 8) do
			local b1, b2, b3, b4, b5, b6, b7, b8 = strbyte(value, (i - 1) * 8 + 1, i * 8)
			hash = (hash * 33 + b1) % MAX_VALUE
			if not b2 then break end
			hash = (hash * 33 + b2) % MAX_VALUE
			if not b3 then break end
			hash = (hash * 33 + b3) % MAX_VALUE
			if not b4 then break end
			hash = (hash * 33 + b4) % MAX_VALUE
			if not b5 then break end
			hash = (hash * 33 + b5) % MAX_VALUE
			if not b6 then break end
			hash = (hash * 33 + b6) % MAX_VALUE
			if not b7 then break end
			hash = (hash * 33 + b7) % MAX_VALUE
			if not b8 then break end
			hash = (hash * 33 + b8) % MAX_VALUE
		end
	elseif dataType == "number" then
		if value == floor(value) then
			if value < 0 then
				value = value * -1
				hash = (hash * 33 + 59) % MAX_VALUE
			end
			while value > 0 do
				hash = (hash * 33 + value % 256) % MAX_VALUE
				value = floor(value / 256)
			end
		else
			-- Hash 6 digits of the mantissa plus the exponent
			local mantissa, exponent = frexp(value)
			hash = private.CalculateForSimpleDataType("number", floor(mantissa * 1000000 + 0.5), hash)
			hash = private.CalculateForSimpleDataType("number", exponent, hash)
		end
	elseif dataType == "boolean" then
		hash = (hash * 33 + (value and 1 or 0)) % MAX_VALUE
	elseif dataType == "nil" then
		hash = (hash * 33 + 17) % MAX_VALUE
	else
		error("Invalid data type: "..tostring(dataType))
	end
	return hash
end
