-- ------------------------------------------------------------------------------ --
--                                   LibTSMUtil                                   --
--                 https://github.com/TradeSkillMaster/LibTSMUtil                 --
--         Licensed under the MIT license. See LICENSE.txt for more info.         --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local Util = LibTSMUtil:Init("Database.Util")
local Math = LibTSMUtil:Include("Lua.Math")
Util.CONSTANTS = {
	OTHER_FIELD_QUERY_PARAM = newproxy(false) --[[@as DatabaseQueryParam]],
	BOUND_QUERY_PARAM = newproxy(false) --[[@as DatabaseQueryParam]],
}
---@class DatabaseQueryParam: userdata



-- ============================================================================
-- Module Functions
-- ============================================================================

---Converts a value to the equivalent value which should be used for an index.
---@param value any The value to convert
---@return any
function Util.ToIndexValue(value)
	if value == nil then
		return nil
	end
	local valueType = type(value)
	if valueType == "string" then
		return strlower(value)
	elseif valueType == "boolean" then
		return value and 1 or 0
	elseif valueType == "number" and Math.IsNan(value) then
		return nil
	else
		return value
	end
end
