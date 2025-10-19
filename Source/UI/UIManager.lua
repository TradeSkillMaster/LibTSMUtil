-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local UIManager = LibTSMUtil:DefineClassType("UIManager")
local Log = LibTSMUtil:Include("Util.Log")

---@alias UIManagerActionHandler fun(manager: UIManager, state: ReactiveState, action: string, ...: any)



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Creates a new UI manager object.
---@param name string The name for debugging purposes
---@param state ReactiveState The state
---@param actionHandler UIManagerActionHandler The action handler
---@return UIManager
function UIManager.__static.Create(name, state, actionHandler)
	return UIManager(name, state, actionHandler)
end



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function UIManager.__private:__init(name, state, actionHandler)
	self._name = name
	self._state = state ---@type ReactiveState
	self._actionHandler = actionHandler ---@type UIManagerActionHandler
	self._cancellables = {}
	self._futureStateKey = {}
	self._futureAction = {}
	self._callbackFuncs = {}
	self._suppressedLogs = {}
	self._suppressAllLogs = false
	self._frameBuilder = nil
end

function UIManager:__tostring()
	return "UIManager:"..self._name
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Sets up a publisher to assign any published values to the state.
---@param key string The key to set in the state
---@param publisher ReactivePublisherSchema The publisher
function UIManager:SetStateFromPublisher(key, publisher)
	publisher:AssignToTableKey(self._state, key)
		:StoreIn(self._cancellables)
end

---Sets a state field based on the result of an expression on the state
---@param key string The key to set in the state
---@param expression string The expression to apply to the state
function UIManager:SetStateFromExpression(key, expression)
	self._state:PublisherForExpression(expression)
		:AssignToTableKey(self._state, key)
		:StoreIn(self._cancellables)
end

---Adds a cancellable to be owned by the manager.
---@param publisher ReactivePublisher
function UIManager:AddCancellable(publisher)
	publisher:StoreIn(self._cancellables)
end

---Processes an action whenever a value is published.
---@param action string The action to be processed
---@param publisher ReactivePublisherSchema The publisher
function UIManager:ProcessActionFromPublisher(action, publisher)
	publisher
		:MapToValue(action)
		:CallMethod(self, "ProcessAction")
		:StoreIn(self._cancellables)
end

---Mirrors a state key with a given table.
---@param key string The state key
---@param tbl table The table to assign to
---@param tblKey string The key within the table to assign to
function UIManager:MirrorStateWithTable(key, tbl, tblKey)
	self._state[key] = tbl[tblKey]
	self._state:PublisherForKeyChange(key)
		:AssignToTableKey(tbl, tblKey)
		:StoreIn(self._cancellables)
end

---Returns a function which can be used as a callback to process the specified action.
---@param action string The action to be processed
---@return fun(...)
function UIManager:CallbackToProcessAction(action)
	if not self._callbackFuncs[action] then
		self._callbackFuncs[action] = function(...)
			return self:ProcessAction(action, ...)
		end
	end
	return self._callbackFuncs[action]
end

---Processes an action.
---@param action string The action
---@param ... any Arguments for the action
function UIManager:ProcessAction(action, ...)
	assert(action)
	if not self._suppressAllLogs and not self._suppressedLogs[action] then
		Log.Custom("INFO", tostring(self), "Handling action %s (%s)", action, strjoin(",", tostringall(...)))
	end
	self:_actionHandler(self._state, action, ...)
end

---Sends an action when a future is done (passing through the value).
---@param stateKey string The state key to store the future at
---@param future Future The future
---@param action? string The action to send
function UIManager:ManageFuture(stateKey, future, action)
	assert(stateKey and future)
	assert(not self._futureStateKey[future])
	assert(not self._state[stateKey])
	future:SetScript("OnDone", self:__closure("_HandleFutureDone"))
	self._futureStateKey[future] = stateKey
	self._futureAction[future] = action
	self._state[stateKey] = future
end

---Cancels a future previously added via `:ManageFuture()`.
---@param stateKey string The state key to use to store the future
function UIManager:CancelFuture(stateKey)
	local future = self._state[stateKey]
	assert(future and self._futureStateKey[future] == stateKey)
	self._futureStateKey[future] = nil
	self._futureAction[future] = nil
	future:Cancel()
	self._state[stateKey] = nil
end

---Suppresses logs for a given action
---@param action string|boolean The action or true to suppress all actions
---@return UIManager
function UIManager:SuppressActionLog(action)
	if action == true then
		self._suppressAllLogs = true
	else
		assert(type(action) == "string")
		self._suppressedLogs[action] = true
	end
	return self
end

---Adds a UI frame building function.
---@param func fun(state: ReactiveState, ...: unknown): unknown The function which builds the UI
---@return UIManager
function UIManager:AddFrameBuilder(func)
	assert(type(func) == "function" and not self._frameBuilder)
	self._frameBuilder = func
	return self
end

---Builds a frame using a previously-registered builder.
---@param ... unknown Additional arguments to pass to the frame builder
---@return unknown
function UIManager:BuildFrame(...)
	return self._frameBuilder(self._state, ...)
end

---Gets a publisher for a state key.
---@param key string The state key to get a publisher for.
function UIManager:StatePublisherForKey(key)
	return self._state:PublisherForKeyChange(key)
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param future Future
function UIManager.__private:_HandleFutureDone(future)
	local stateKey = self._futureStateKey[future]
	local action = self._futureAction[future]
	assert(stateKey)
	self._futureStateKey[future] = nil
	self._futureAction[future] = nil
	local value = future:GetValue()
	if action then
		self:ProcessAction(action, value)
	end
	self._state[stateKey] = nil
end
