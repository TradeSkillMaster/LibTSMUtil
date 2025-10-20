-- ------------------------------------------------------------------------------ --
--                                   LibTSMUtil                                   --
--                 https://github.com/TradeSkillMaster/LibTSMUtil                 --
--         Licensed under the MIT license. See LICENSE.txt for more info.         --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local CompiledPublisher = LibTSMUtil:Init("Reactive.Type.CompiledPublisher")
local Util = LibTSMUtil:Include("Reactive.Type.Util")
local private = {
	context = {} ---@type table<CompiledPublisherObject,CompiledPublisherContext>
}

---@alias CompiledPublisherResetFunction fun(contextTbl: table, initialIgnoreValue: userdata)
---@alias CompiledPublisherDataFunction fun(data: any, contextTbl: table)

---@class CompiledPublisherContext
---@field resetFunc CompiledPublisherResetFunction
---@field dataFunc CompiledPublisherDataFunction



-- ============================================================================
-- Metatable
-- ============================================================================


---@class CompiledPublisherObject
local COMPILED_PUBLISHER_METHODS = {}

local COMPILED_PUBLISHER_MT = {
	__index = COMPILED_PUBLISHER_METHODS,
	__newindex = function() error("Compiled publisher cannot be written to", 2) end,
	__metatable = false,
}

---Resets the context table.
---@param contextTbl table The context table
function COMPILED_PUBLISHER_METHODS:Reset(contextTbl)
	local context = private.context[self]
	context.resetFunc(contextTbl, Util.INITIAL_IGNORE_VALUE)
end

---Executed the data function.
---@param data any The data
---@param contextTbl table The context table
function COMPILED_PUBLISHER_METHODS:HandleData(data, contextTbl)
	local context = private.context[self]
	context.dataFunc(data, contextTbl)
end



-- ============================================================================
-- Module Functions
-- ============================================================================

---Creates a compiled publisher object.
---@param resetFunc CompiledPublisherResetFunction
---@param dataFunc CompiledPublisherDataFunction
function CompiledPublisher.Create(resetFunc, dataFunc)
	local compiled = setmetatable({}, COMPILED_PUBLISHER_MT)
	private.context[compiled] = {
		resetFunc = resetFunc,
		dataFunc = dataFunc,
	}
	return compiled
end
