-- ------------------------------------------------------------------------------ --
--                                   LibTSMUtil                                   --
--                 https://github.com/TradeSkillMaster/LibTSMUtil                 --
--         Licensed under the MIT license. See LICENSE.txt for more info.         --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local Util = LibTSMUtil:Init("Reactive.Type.Util")
local EnumType = LibTSMUtil:Include("BaseType.EnumType")
Util.INITIAL_IGNORE_VALUE = newproxy(false)
local STEP = EnumType.New("PUBLISHER_STEP", {
	MAP_WITH_FUNCTION = EnumType.NewValue(),
	MAP_WITH_FUNCTION_AND_KEYS = EnumType.NewValue(),
	MAP_WITH_METHOD = EnumType.NewValue(),
	MAP_WITH_KEY = EnumType.NewValue(),
	MAP_WITH_KEY_COALESCED = EnumType.NewValue(),
	MAP_WITH_LOOKUP_TABLE = EnumType.NewValue(),
	MAP_WITH_STATE_EXPRESSION = EnumType.NewValue(),
	MAP_BOOLEAN_WITH_VALUES = EnumType.NewValue(),
	MAP_BOOLEAN_EQUALS = EnumType.NewValue(),
	MAP_BOOLEAN_NOT_EQUALS = EnumType.NewValue(),
	MAP_BOOLEAN_GREATER_THAN_OR_EQUALS = EnumType.NewValue(),
	MAP_TO_BOOLEAN = EnumType.NewValue(),
	MAP_STRING_FORMAT = EnumType.NewValue(),
	MAP_STRING_ADD_SUFFIX = EnumType.NewValue(),
	MAP_STRING_ADD_PREFIX = EnumType.NewValue(),
	MAP_TO_VALUE = EnumType.NewValue(),
	MAP_NIL_TO_VALUE = EnumType.NewValue(),
	MAP_NON_NIL_WITH_FUNCTION = EnumType.NewValue(),
	MAP_NON_NIL_WITH_METHOD = EnumType.NewValue(),
	INVERT_BOOLEAN = EnumType.NewValue(),
	IGNORE_IF_KEY_EQUALS = EnumType.NewValue(),
	IGNORE_IF_KEY_NOT_EQUALS = EnumType.NewValue(),
	IGNORE_IF_EQUALS = EnumType.NewValue(),
	IGNORE_IF_NOT_EQUALS = EnumType.NewValue(),
	IGNORE_NIL = EnumType.NewValue(),
	IGNORE_DUPLICATES = EnumType.NewValue(),
	IGNORE_DUPLICATES_WITH_KEYS = EnumType.NewValue(),
	IGNORE_DUPLICATES_WITH_METHOD = EnumType.NewValue(),
	PRINT = EnumType.NewValue(),
	START_PROFILING = EnumType.NewValue(),
	SHARE = EnumType.NewValue(),
	CALL_METHOD = EnumType.NewValue(),
	CALL_FUNCTION = EnumType.NewValue(),
	ASSIGN_TO_TABLE_KEY = EnumType.NewValue(),
})
Util.PUBLISHER_STEP = STEP
local IS_TERMINAL_STEP = {
	[STEP.MAP_WITH_FUNCTION] = false,
	[STEP.MAP_WITH_FUNCTION_AND_KEYS] = false,
	[STEP.MAP_WITH_METHOD] = false,
	[STEP.MAP_WITH_KEY] = false,
	[STEP.MAP_WITH_KEY_COALESCED] = false,
	[STEP.MAP_WITH_LOOKUP_TABLE] = false,
	[STEP.MAP_WITH_STATE_EXPRESSION] = false,
	[STEP.MAP_BOOLEAN_WITH_VALUES] = false,
	[STEP.MAP_BOOLEAN_EQUALS] = false,
	[STEP.MAP_BOOLEAN_NOT_EQUALS] = false,
	[STEP.MAP_BOOLEAN_GREATER_THAN_OR_EQUALS] = false,
	[STEP.MAP_TO_BOOLEAN] = false,
	[STEP.MAP_STRING_FORMAT] = false,
	[STEP.MAP_STRING_ADD_SUFFIX] = false,
	[STEP.MAP_STRING_ADD_PREFIX] = false,
	[STEP.MAP_TO_VALUE] = false,
	[STEP.MAP_NIL_TO_VALUE] = false,
	[STEP.MAP_NON_NIL_WITH_FUNCTION] = false,
	[STEP.MAP_NON_NIL_WITH_METHOD] = false,
	[STEP.INVERT_BOOLEAN] = false,
	[STEP.IGNORE_IF_KEY_EQUALS] = false,
	[STEP.IGNORE_IF_KEY_NOT_EQUALS] = false,
	[STEP.IGNORE_IF_EQUALS] = false,
	[STEP.IGNORE_IF_NOT_EQUALS] = false,
	[STEP.IGNORE_NIL] = false,
	[STEP.IGNORE_DUPLICATES] = false,
	[STEP.IGNORE_DUPLICATES_WITH_KEYS] = false,
	[STEP.IGNORE_DUPLICATES_WITH_METHOD] = false,
	[STEP.PRINT] = false,
	[STEP.SHARE] = false,
	[STEP.CALL_METHOD] = true,
	[STEP.CALL_FUNCTION] = true,
	[STEP.ASSIGN_TO_TABLE_KEY] = true,
}

---@class ReactiveSubject
---@field _AddPublisher fun(self: ReactiveSubject, publisher: ReactivePublisher)
---@field _RemovePublisher fun(self: ReactiveSubject, publisher: ReactivePublisher)
---@field _SetPublisherDisabled fun(self: ReactiveSubject, publisher: ReactivePublisher, disabled: boolean)
---@field _GetInitialValue fun(self: ReactiveSubject): any
---@field _RequiresOptimized fun(): boolean



-- ============================================================================
-- Module Functions
-- ============================================================================

---Checks whether a step is a terminal step indicating the end of a publisher chain.
---@param stepType EnumValue The publisher step type
---@return boolean
function Util.IsTerminalStep(stepType)
	local result = IS_TERMINAL_STEP[stepType]
	assert(result ~= nil)
	return result
end
