-- ------------------------------------------------------------------------------ --
--                                   LibTSMUtil                                   --
--                 https://github.com/TradeSkillMaster/LibTSMUtil                 --
--         Licensed under the MIT license. See LICENSE.txt for more info.         --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local FSM = LibTSMUtil:Init("FSM")
local Object = LibTSMUtil:IncludeClassType("FSMObject")
local State = LibTSMUtil:IncludeClassType("FSMState")



-- ============================================================================
-- Module Functions
-- ============================================================================

---Create a new FSM.
---@param name string The name of the FSM (for debugging purposes)
---@return FSMObject
function FSM.New(name)
	return Object.New(name)
end

---Create a new FSM state.
---@param state string The name of the state
---@return FSMState
function FSM.NewState(state)
	return State.New(state)
end
