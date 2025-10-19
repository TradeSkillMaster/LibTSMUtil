-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local ReactiveStream = LibTSMUtil:DefineClassType("ReactiveStream")
local ReactivePublisherSchema = LibTSMUtil:IncludeClassType("ReactivePublisherSchema")
local OrderedTable = LibTSMUtil:Include("BaseType.OrderedTable")
local ObjectPool = LibTSMUtil:IncludeClassType("ObjectPool")
local private = {
	objectPool = ObjectPool.New("STREAM", ReactiveStream, 0),
}

---@class ReactiveStream: ReactiveSubject



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Gets a stream object.
---@param initialValueFunc fun(): any A function to get the initial value to send to new publishers
---@return ReactiveStream
function ReactiveStream.__static.Get(initialValueFunc)
	local stream = private.objectPool:Get()
	stream:_Acquire(initialValueFunc)
	return stream
end



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function ReactiveStream.__private:__init()
	self._initalValueFunc = nil
	self._publishers = {}
	self._disabled = {}
	self._noPublishersCallback = nil
	self._sending = false
	self._sendQueue = {}
end

---@param initialValueFunc fun(): any
function ReactiveStream.__private:_Acquire(initialValueFunc)
	assert(initialValueFunc)
	self._initalValueFunc = initialValueFunc
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Releases the stream.
function ReactiveStream:Release()
	assert(not self._sending and not next(self._sendQueue))
	assert(self:GetNumPublishers() == 0)
	self._noPublishersCallback = nil
	self._initalValueFunc = nil
	private.objectPool:Recycle(self)
end

---Creates a new publisher for the stream.
---@return ReactivePublisherSchema
function ReactiveStream:Publisher()
	return ReactivePublisherSchema.Get(self)
end

---Sends a new data value the stream's publishers.
---@param data any The data to send
function ReactiveStream:Send(data)
	local sendQueue = self._sendQueue
	assert(not self._sending and #sendQueue == 0)
	self._sending = true
	local publishers = self._publishers
	for i = 1, #publishers do
		sendQueue[i] = publishers[i]
	end
	for i = 1, #sendQueue do
		local publisher = sendQueue[i]
		if self._publishers[publisher] and not self._disabled[publisher] then
			publisher:_HandleData(data)
		end
	end
	wipe(sendQueue)
	self._sending = false
end

---Sets a callback for when there are no remaining publishers.
---@param handler fun(stream: ReactiveStream) The handler function
---@return ReactiveStream
function ReactiveStream:SetNoPublishersCallback(handler)
	assert(handler and not self._noPublishersCallback)
	self._noPublishersCallback = handler
	return self
end

---Gets the number of publishers on the stream.
---@return number
function ReactiveStream:GetNumPublishers()
	return #self._publishers
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@private
---@param publisher ReactivePublisher
function ReactiveStream:_AddPublisher(publisher)
	OrderedTable.Insert(self._publishers, publisher, true)
end

---@private
---@param publisher ReactivePublisher
function ReactiveStream:_RemovePublisher(publisher)
	OrderedTable.Remove(self._publishers, publisher)
	self._disabled[publisher] = nil
	if self:GetNumPublishers() == 0 and self._noPublishersCallback then
		self:_noPublishersCallback()
	end
end

---@private
---@param publisher ReactivePublisher
---@param disabled boolean
function ReactiveStream:_SetPublisherDisabled(publisher, disabled)
	self._disabled[publisher] = disabled
end

---@private
---@return any
function ReactiveStream:_GetInitialValue()
	return self._initalValueFunc()
end

---@private
---@return boolean
function ReactiveStream:_RequiresOptimized()
	return false
end
