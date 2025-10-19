-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local Reactive = LibTSMUtil:Init("Reactive")
local ReactiveStateSchema = LibTSMUtil:IncludeClassType("ReactiveStateSchema")
local ReactiveStream = LibTSMUtil:IncludeClassType("ReactiveStream")



-- ============================================================================
-- Module Functions
-- ============================================================================

---Creates a new state schema object.
---@param name string The name for debugging purposes
---@return ReactiveStateSchema
function Reactive.CreateStateSchema(name)
	return ReactiveStateSchema.Create(name)
end

---Gets a stream object.
---@param initialValueFunc fun(): any A function to get the initial value to send to new publishers
---@return ReactiveStream
function Reactive.GetStream(initialValueFunc)
	return ReactiveStream.Get(initialValueFunc)
end
