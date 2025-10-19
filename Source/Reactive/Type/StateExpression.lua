-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local ReactiveStateExpression = LibTSMUtil:DefineClassType("ReactiveStateExpression")
local EnumType = LibTSMUtil:Include("BaseType.EnumType")
local String = LibTSMUtil:Include("Lua.String")
local Table = LibTSMUtil:Include("Lua.Table")
local private = {
	cache = {}, ---@type table<ReactiveStateSchema,table<string,ReactiveStateExpression>>
}
local VALID_OPERATORS = {
	["or"] = true,
	["and"] = true,
	["not"] = true,
	["false"] = true,
	["true"] = true,
	["nil"] = true,
	["#"] = true,
	[".."] = true,
}
local VALID_FUNCTIONS = {
	min = true,
	max = true,
}



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets an expression object.
---@param expressionStr string A valid lua expression which can only access fields of the state (as globals)
---@param schema ReactiveStateSchema The state schema
---@return ReactiveStateExpression
function ReactiveStateExpression.__static.Get(expressionStr, schema)
	private.cache[schema] = private.cache[schema] or {}
	local obj = private.cache[schema][expressionStr]
	if not obj then
		obj = ReactiveStateExpression(expressionStr, schema)
		private.cache[schema][expressionStr] = obj
	end
	return obj
end



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function ReactiveStateExpression.__private:__init(expressionStr, schema)
	self._schema = schema
	self._context = {}
	self._keys = {}
	self._stringId = 1
	self:_Compile(expressionStr)
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Returns the single key or nil if there are multiple keys.
---@return string|nil
function ReactiveStateExpression:GetSingleKey()
	local key = next(self._keys)
	assert(key ~= nil)
	return next(self._keys, key) == nil and key or nil
end

---Iterates over the keys.
---@return fun(): string @Iterator with fields: `key`
---@return table
function ReactiveStateExpression:KeyIterator()
	return Table.KeyIterator(self._keys)
end

---Gets the code.
---@return string
function ReactiveStateExpression:GetCode()
	return self._code
end

---Gets the context table.
---@return table
function ReactiveStateExpression:GetContext()
	return self._context
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function ReactiveStateExpression.__private:_Compile(expression)
	assert(not strmatch(expression, "__context"))

	-- Replace EnumEquals() function calls and string literals
	expression = gsub(expression, "EnumEquals%((.-),(.-)%)", self:__closure("_EnumEqualsSub"))
	expression = gsub(expression, "(\"(.-)\")", self:__closure("_StringLiteralSub"))

	-- Process all the tokens
	expression = gsub(expression, "\"?[a-zA-Z0-9_%.#`]+\"?", self:__closure("_HandleToken"))

	assert(next(self._keys) ~= nil)
	local singleKey = self:GetSingleKey()
	if singleKey then
		expression = gsub(expression, "data%."..String.Escape(singleKey), "data")
	end
	expression = "local __context = context[%(contextArgIndex)d]\ndata = "..expression
	self._code = expression
end

function ReactiveStateExpression.__private:_HandleToken(key)
	if (strsub(key, 1, 1) == "\"" and strsub(key, -1) == "\"") or tonumber(key) then
		-- String or number literal
		return key
	elseif VALID_OPERATORS[key] or VALID_FUNCTIONS[key] then
		-- Valid operator or function
		return key
	else
		local contextKey = strmatch(key, "^[^%.]+")
		if self._context[contextKey] then
			-- Context key
			assert(not self._schema:_HasKey(contextKey)) ---@diagnostic disable-line: invisible
			return "__context."..key
		else
			-- State key
			assert(key ~= "data", "Illegal key: "..tostring(key))
			self._keys[key] = true
			return "data."..key
		end
	end
end

function ReactiveStateExpression.__private:_EnumEqualsSub(stateKey, valueKey)
	stateKey = strtrim(stateKey)
	valueKey = strtrim(valueKey)
	local enumType = self._schema:_GetEnumFieldType(stateKey) ---@diagnostic disable-line: invisible
	assert(enumType and EnumType.IsType(enumType))
	local enumValue = nil
	if strmatch(valueKey, "%.") then
		enumValue = enumType
		for valueKeyPart in gmatch(valueKey, "[^%.]+") do
			enumValue = enumValue[valueKeyPart]
		end
	else
		enumValue = enumType[valueKey]
	end
	assert(enumValue)
	local enumName = tostring(enumType)
	assert(not self._context[enumName] or self._context[enumName] == enumType)
	self._context[enumName] = enumType
	return format("(%s == %s.%s)", stateKey, enumName, valueKey)
end

function ReactiveStateExpression.__private:_StringLiteralSub(origToken, str)
	if strmatch(str, "^[A-Za-z_0-9]*$") then
		-- Don't need to replace this
		return origToken
	end
	self._stringId = self._stringId + 1
	local contextKey = "__string_"..(self._stringId)
	assert(not self._context[contextKey])
	self._context[contextKey] = str
	return contextKey
end
