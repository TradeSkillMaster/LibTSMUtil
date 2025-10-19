-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local ReactivePublisher = LibTSMUtil:DefineClassType("ReactivePublisher")
local EnumType = LibTSMUtil:Include("BaseType.EnumType")
local ObjectPool = LibTSMUtil:IncludeClassType("ObjectPool")
local private = {
	objectPool = ObjectPool.New("PUBLISHER", ReactivePublisher, 2),
}
local STATE = EnumType.New("PUBLISHER_STATE", {
	INIT = EnumType.NewValue(),
	ACQUIRED = EnumType.NewValue(),
	STORED = EnumType.NewValue(),
})



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Gets a publisher object.
---@param codeGen ReactivePublisherCodeGen The code gen object
---@param subject ReactiveSubject The subject
---@return ReactivePublisher
function ReactivePublisher.__static.Get(codeGen, subject)
	local publisher = private.objectPool:Get()
	publisher:_Acquire(codeGen, subject)
	return publisher
end



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function ReactivePublisher.__private:__init()
	self._state = STATE.INIT
	self._subject = nil
	self._compiled = nil
	self._context = {}
	self._optimizeResult = nil
	self._optimizeKeys = {}
	self._disabled = false
end

---@param codeGen ReactivePublisherCodeGen
---@param subject ReactiveSubject
function ReactivePublisher.__private:_Acquire(codeGen, subject)
	assert(self._state == STATE.INIT)
	self._state = STATE.ACQUIRED
	self._subject = subject
	self._compiled, self._optimizeResult = codeGen:Commit(self._context, self._optimizeKeys)
	assert(not self._subject:_RequiresOptimized() or self._optimizeResult)
	self._subject:_AddPublisher(self)
end

function ReactivePublisher.__private:_Release()
	assert(self._compiled and self._state == STATE.STORED)
	self._subject = nil
	self._compiled = nil
	wipe(self._context)
	self._optimizeResult = nil
	wipe(self._optimizeKeys)
	self._state = STATE.INIT
	self._disabled = false
	private.objectPool:Recycle(self)
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Stores the publisher within the provided table and marks it as stored and active.
---@param tbl ReactivePublisher[] The table to add the publisher to
function ReactivePublisher:StoreIn(tbl)
	tinsert(tbl, self:Stored())
end

---Marks the publisher as stored and active.
---@return ReactivePublisher
function ReactivePublisher:Stored()
	assert(self._state == STATE.ACQUIRED)
	self._state = STATE.STORED
	if not self._disabled then
		self:_ResetAndSendInitialValue()
	end
	return self
end

---Cancels and releases the publisher.
function ReactivePublisher:Cancel()
	assert(self._state == STATE.STORED)
	self._subject:_RemovePublisher(self)
	self:_Release()
end

---Marks the publisher as disabled so it'll ignore any new values.
function ReactivePublisher:Disable()
	assert(self._state ~= STATE.INIT and not self._disabled)
	self._disabled = true
	self._subject:_SetPublisherDisabled(self, true)
end

---Marks the publisher as enabled and reset it to its initial state (sends the initial value again).
function ReactivePublisher:EnableAndReset()
	assert(self._state ~= STATE.INIT and self._disabled)
	self._disabled = false
	self._subject:_SetPublisherDisabled(self, false)
	self:_ResetAndSendInitialValue()
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@private
function ReactivePublisher:_HandleData(data, optimizeKey)
	if not self._compiled then
		error("Not compiled")
	end
	if optimizeKey and self._optimizeResult and not self._optimizeKeys[optimizeKey] then
		return
	end
	self._compiled:HandleData(data, self._context)
end

function ReactivePublisher.__private:_ResetAndSendInitialValue()
	self._compiled:Reset(self._context)
	self:_HandleData(self._subject:_GetInitialValue())
end
