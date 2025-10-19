-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local StringBuilder = LibTSMUtil:DefineClassType("StringBuilder")
local private = {
	paramsTemp = {},
	usedParamsTemp = {},
}



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Creates a new string builder object.
---@return StringBuilder
function StringBuilder.__static.Create()
	return StringBuilder()
end



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function StringBuilder.__private:__init()
	self._template = nil
	self._params = {}
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Sets the template.
---@param template string The template string to format
---@return StringBuilder
function StringBuilder:SetTemplate(template)
	assert(type(template) == "string")
	assert(not self._template and not next(self._params))
	self._template = template
	return self
end

---Sets the value of a named parameter.
---@param name string The parameter name
---@param value any The parameter value
---@return StringBuilder
function StringBuilder:SetParam(name, value)
	assert(self._template)
	assert(type(name) == "string" and value ~= nil and not self._params[name])
	self._params[name] = value
	return self
end

---Gets the number of occurences of a parameter in the template.
---@param name string The parameter name
---@return number
function StringBuilder:GetParamCount(name)
	local _, num = gsub(self._template, "%%%("..name.."%)([-0-9%.]*[cdeEfgGiouxXsq])", "")
	return num
end

---Commits the string builder and returns the generated string.
---@return string
function StringBuilder:Commit()
	assert(self._template)
	assert(not next(private.paramsTemp) and not next(private.usedParamsTemp))
	-- This is inspired by http://lua-users.org/wiki/StringInterpolation
	local result = gsub(self._template, "%%%((%a%w*)%)([-0-9%.]*[cdeEfgGiouxXsq])", private.FormatHelper)
	for _, name in ipairs(private.usedParamsTemp) do
		local value = self._params[name]
		if value == nil then
			error(format("Named parameter '%s' not provided", tostring(name)))
		end
		tinsert(private.paramsTemp, value)
	end
	result = format(result, unpack(private.paramsTemp))
	wipe(private.paramsTemp)
	wipe(private.usedParamsTemp)
	self._template = nil
	wipe(self._params)
	return result
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.FormatHelper(name, fmtStr)
	tinsert(private.usedParamsTemp, name)
	return "%"..fmtStr
end
