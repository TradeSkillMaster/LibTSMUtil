-- ------------------------------------------------------------------------------ --
--                                   LibTSMUtil                                   --
--                 https://github.com/TradeSkillMaster/LibTSMUtil                 --
--         Licensed under the MIT license. See LICENSE.txt for more info.         --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local ExecutionTime = LibTSMUtil:Init("Util.ExecutionTime")
local ContextManager = LibTSMUtil:Include("BaseType.ContextManager")
local TempTable = LibTSMUtil:Include("BaseType.TempTable")
local Vararg = LibTSMUtil:Include("Lua.Vararg")
local Log = LibTSMUtil:Include("Util.Log")
local private = {
	labelTemp = {},
	contextManager = nil,
}
local WARNING_THRESHOLD = LibTSMUtil.IsDevVersion() and 0.02 or 0.05



-- ============================================================================
-- Module Loading
-- ============================================================================

ExecutionTime:OnModuleLoad(function()
	private.contextManager = ContextManager.Create(private.EnterFunc, private.ExitFunc)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Checks the elapsed time and warns if it's too long.
---@param elapsedTime number The elapsed time
---@param labelFormatString string The label format string to use for logging any warnings
---@param ... any Additional arguments for the label format string
function ExecutionTime.CheckElapsed(elapsedTime, labelFormatString, ...)
	if elapsedTime < WARNING_THRESHOLD then
		return
	end
	wipe(private.labelTemp)
	Vararg.IntoTable(private.labelTemp, Log.PrepareFormatArgs(...))
	tinsert(private.labelTemp, elapsedTime)
	Log.RaiseStackLevel()
	Log.Warn(labelFormatString.." took %0.5fs", unpack(private.labelTemp))
	Log.LowerStackLevel()
	wipe(private.labelTemp)
end

---Returns an iterator which executes exactly once and measures the time taken within the loop body, warning if it's too long.
---@param labelFormatString string The label format string to use for logging any warnings
---@param ... any Additional arguments for the label format string
---@return function
---@return table
---@return any
function ExecutionTime.WithMeasurement(labelFormatString, ...)
	return ExecutionTime.WithMeasurementAndRaisedLogStackLevel(0, labelFormatString, ...)
end

---Returns an iterator which executes exactly once and measures the time taken within the loop body, warning if it's too long.
---@param raiseStackLevel number The amount to raise the stack level before logging
---@param labelFormatString string The label format string to use for logging any warnings
---@param ... any Additional arguments for the label format string
---@return function
---@return table
---@return any
function ExecutionTime.WithMeasurementAndRaisedLogStackLevel(raiseStackLevel, labelFormatString, ...)
	assert(type(labelFormatString) == "string")
	local labelContext = TempTable.Acquire(...)
	labelContext.formatString = labelFormatString
	labelContext.raiseStackLevel = raiseStackLevel
	return private.contextManager:With(labelContext)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.EnterFunc()
	return LibTSMUtil.GetTime()
end

function private.ExitFunc(labelContext, startTime)
	local elapsedTime = LibTSMUtil.GetTime() - startTime
	if elapsedTime > WARNING_THRESHOLD then
		tinsert(labelContext, elapsedTime)
		local raiseStackLevel = labelContext.raiseStackLevel
		Log.RaiseStackLevel(2 + raiseStackLevel)
		Log.Warn(labelContext.formatString.." took %0.5fs", unpack(labelContext))
		Log.LowerStackLevel(2 + raiseStackLevel)
	end
	TempTable.Release(labelContext)
end
