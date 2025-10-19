-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local Signal = LibTSMUtil:DefineClassType("Signal")



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Create a new signal.
---@param name string The name of the signal for debugging purposes
---@return Signal
function Signal.__static.New(name)
	return Signal(name)
end



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function Signal.__private:__init(name)
	self._name = name
	self._value = false
	self._handler = nil
	self._setCallback = function()
		self:Set()
	end
end

function Signal:__tostring()
	return "Signal:"..self._name
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Gets the name for debugging purposes.
---@return string
function Signal:GetName()
	return self._name
end

---Sets the signal
function Signal:Set()
	if self._value then
		return
	end
	self._value = true
	if self._handler then
		self:_handler()
	end
end

---Clears the signal.
function Signal:Clear()
	self._value = false
end

---Clears the signal.
function Signal:IsSet()
	return self._value
end

---Returns a callback function which sets the signal when called.
---@return fun()
function Signal:CallbackToSet()
	return self._setCallback
end

---Sets the handler for when the signal is set
---@param handler? fun(input: Signal) The handler or nil to clear the handler
function Signal:SetHandler(handler)
	if handler then
		assert(type(handler) == "function")
		assert(not self._handler)
		self._handler = handler
	else
		self._handler = nil
	end
end
