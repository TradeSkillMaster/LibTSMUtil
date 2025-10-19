-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local Range = LibTSMUtil:DefineClassType("Range")
local ObjectPool = LibTSMUtil:IncludeClassType("ObjectPool")
local private = {
	objectPool = ObjectPool.New("RANGE", Range),
}



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Acquires a static range object (can't be released or mutated) for a given start and end value.
---@param startValue number The start value of the range
---@param endValue number The end value of the range
---@return Range
function Range.__static.StaticStartEnd(startValue, endValue)
	return Range(true):SetStartEnd(startValue, endValue)
end

---Acquires a range object for a given start and end value.
---@param startValue number The start value of the range
---@param endValue number The end value of the range
---@return Range
function Range.__static.AcquireStartEnd(startValue, endValue)
	return private.objectPool:Get():SetStartEnd(startValue, endValue)
end

---Acquires a range object from a given start value and length.
---@param startValue number The start value of the range
---@param length number The length of the range
---@return Range
function Range.__static.AcquireStartLength(startValue, length)
	return private.objectPool:Get():SetStartLength(startValue, length)
end



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function Range.__private:__init(static)
	self._static = static or false
	self._startValue = nil
	self._endValue = nil
end

function Range:__tostring()
	return "Range:["..self._startValue..","..self._endValue.."]"
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Releases the range object.
function Range:Release()
	assert(not self._static)
	self._startValue = nil
	self._endValue = nil
	private.objectPool:Recycle(self)
end

---Sets the start value and end value of the range.
---@param startValue number The start value of the range
---@param endValue number The end value of the range
---@return Range
function Range:SetStartEnd(startValue, endValue)
	assert(not self._startValue or not self._static)
	assert(floor(startValue) == startValue and floor(endValue) == endValue and startValue <= endValue)
	self._startValue = startValue
	self._endValue = endValue
	return self
end

---Sets the start value and length of the range.
---@param startValue number The start value of the range
---@param length number The length of the range
---@return Range
function Range:SetStartLength(startValue, length)
	assert(length > 0)
	-- Make sure the start is not Inf/NaN
	assert(length == 1 or startValue + length ~= startValue)
	self:SetStartEnd(startValue, startValue + length - 1)
	return self
end

---Gets the start and end values of a range.
---@return number startValue
---@return number endValue
function Range:GetValues()
	assert(self._startValue)
	return self._startValue, self._endValue
end

---Gets the start value of the range.
---@return number
function Range:GetStart()
	assert(self._startValue)
	return self._startValue
end

---Gets the end value of the range.
---@return number
function Range:GetEnd()
	assert(self._startValue)
	return self._endValue
end

---Gets the length of the range.
---@return number
function Range:GetLength()
	assert(self._startValue)
	return self._endValue - self._startValue + 1
end

---Returns the length of the intersection with another range or 0 if they don't intersect.
---@param other Range The other range
---@return number
function Range:IntersectionLength(other)
	local intersectionStart = max(self:GetStart(), other:GetStart())
	local intersectionEnd = min(self:GetEnd(), other:GetEnd())
	if intersectionStart > intersectionEnd then
		return 0
	end
	return intersectionEnd - intersectionStart + 1
end

---Returns whether or not the range includes a value.
---@param value number The value to check
---@return boolean
function Range:Includes(value)
	return value >= self:GetStart() and value <= self:GetEnd()
end

---Returns whether or not the range completely contains another range.
---@param other Range The other range
---@return boolean
function Range:Contains(other)
	return self:GetStart() <= other:GetStart() and self:GetEnd() >= other:GetEnd()
end

---Returns whether or not the range starts before another range.
---@param other Range The other range
---@return boolean
function Range:StartsBefore(other)
	return self:GetStart() < other:GetStart()
end

---Iterates over the integer values in the range.
---@return fun(): number @Iterator with fields: `value`
---@return number
---@return number
function Range:Iterator()
	return private.IteratorHelper, self:GetEnd(), self:GetStart() - 1
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.IteratorHelper(endValue, value)
	value = value + 1
	if value > endValue then
		return
	end
	return value
end
