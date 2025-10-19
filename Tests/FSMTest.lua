local TSM = ... ---@type TSM
local LibTSMUtil = TSM.LibTSMUtil
local FSM = LibTSMUtil:Include("FSM")



-- ============================================================================
-- Tests
-- ============================================================================

TestFSM = {}

function TestFSM:TestEnterExit()
	local events = {}
	local fsmContext = {}
	local fsm = FSM.New("TEST")
		:AddState(FSM.NewState("ST_ONE")
			:SetOnEnter(function(context, arg)
				assertEquals(arg, 1)
				assertIs(context, fsmContext)
				tinsert(events, "ONE_ENTER")
			end)
			:SetOnExit(function(context)
				assertIs(context, fsmContext)
				tinsert(events, "ONE_EXIT")
			end)
			:AddTransition("ST_ONE")
			:AddTransition("ST_TWO")
			:AddEventTransition("EV_NEXT", "ST_TWO")
			:AddEventTransition("EV_REPEAT", "ST_ONE")
		)
		:AddState(FSM.NewState("ST_TWO")
			:SetOnEnter(function(context, arg)
				assertEquals(arg, 2)
				assertIs(context, fsmContext)
				tinsert(events, "TWO_ENTER")
			end)
			:SetOnExit(function(context)
				assertIs(context, fsmContext)
				tinsert(events, "TWO_EXIT")
			end)
			:AddTransition("ST_ONE")
			:AddTransition("ST_TWO")
			:AddEventTransition("EV_NEXT", "ST_ONE")
		)
		:Init("ST_ONE", fsmContext)
		:SetLoggingEnabled(false)

	assertEquals(fsm._currentState, "ST_ONE")
	assertEquals(events, {})
	wipe(events)

	fsm:ProcessEvent("EV_REPEAT", 1)
	assertEquals(fsm._currentState, "ST_ONE")
	assertEquals(events, { "ONE_EXIT", "ONE_ENTER" })
	wipe(events)

	fsm:ProcessEvent("EV_NEXT", 2)
	assertEquals(fsm._currentState, "ST_TWO")
	assertEquals(events, { "ONE_EXIT", "TWO_ENTER" })
	wipe(events)

	fsm:ProcessEvent("EV_NEXT", 1)
	assertEquals(fsm._currentState, "ST_ONE")
	assertEquals(events, { "TWO_EXIT", "ONE_ENTER" })
	wipe(events)
end

function TestFSM:TestDefaultEventHandler()
	local value = 0
	local fsm = FSM.New("TEST")
		:AddState(FSM.NewState("ST_ONE")
			:AddTransition("ST_TWO")
		)
		:AddState(FSM.NewState("ST_TWO")
			:AddTransition("ST_ONE")
			:AddEvent("EV_SET_VALUE", function()
				value = 2
			end)
		)
		:AddDefaultEvent("EV_TO_ONE", function()
			return "ST_ONE"
		end)
		:AddDefaultEvent("EV_TO_TWO", function()
			return "ST_TWO"
		end)
		:AddDefaultEvent("EV_SET_VALUE", function()
			value = 1
		end)
		:Init("ST_ONE")
		:SetLoggingEnabled(false)

	assertEquals(fsm._currentState, "ST_ONE")

	fsm:ProcessEvent("EV_SET_VALUE")
	assertEquals(value, 1)
	value = 0

	fsm:ProcessEvent("EV_TO_TWO")
	assertEquals(fsm._currentState, "ST_TWO")

	fsm:ProcessEvent("EV_SET_VALUE")
	assertEquals(value, 2)
	value = 0

	fsm:ProcessEvent("EV_TO_ONE")
	assertEquals(fsm._currentState, "ST_ONE")

	assertError(function() fsm:ProcessEvent("EV_TO_ONE") end)
end

function TestFSM:TestEventHandler()
	local fsm = FSM.New("TEST")
		:AddState(FSM.NewState("ST_ONE")
			:AddTransition("ST_ONE")
			:AddTransition("ST_TWO")
			:AddEvent("EV_GO", function(context, goForward)
				if goForward then
					return "ST_TWO"
				end
			end)
			:AddEvent("EV_RESET", function(context)
				return "ST_ONE"
			end)
		)
		:AddState(FSM.NewState("ST_TWO")
			:AddTransition("ST_ONE")
			:AddTransition("ST_THREE")
			:AddEvent("EV_GO", function(context, goForward)
				if goForward then
					return "ST_THREE"
				else
					return "ST_ONE"
				end
			end)
			:AddEvent("EV_RESET", function(context)
				return "ST_ONE"
			end)
		)
		:AddState(FSM.NewState("ST_THREE")
			:AddTransition("ST_ONE")
			:AddTransition("ST_TWO")
			:AddEvent("EV_GO", function(context, goForward)
				if not goForward then
					return "ST_TWO"
				end
			end)
			:AddEvent("EV_RESET", function(context)
				return "ST_ONE"
			end)
		)
		:Init("ST_ONE")
		:SetLoggingEnabled(false)

	assertEquals(fsm._currentState, "ST_ONE")

	fsm:ProcessEvent("EV_GO", false)
	assertEquals(fsm._currentState, "ST_ONE")

	fsm:ProcessEvent("EV_RESET")
	assertEquals(fsm._currentState, "ST_ONE")

	fsm:ProcessEvent("EV_GO", true):ProcessEvent("EV_GO", true)
	assertEquals(fsm._currentState, "ST_THREE")

	fsm:ProcessEvent("EV_GO", true)
	assertEquals(fsm._currentState, "ST_THREE")

	fsm:ProcessEvent("EV_GO", false)
	assertEquals(fsm._currentState, "ST_TWO")

	fsm:ProcessEvent("EV_RESET")
	assertEquals(fsm._currentState, "ST_ONE")
end

function TestFSM:TestIgnoredEvent()
	local fsm = FSM.New("TEST")
		:AddState(FSM.NewState("ST_ONE")
			:AddTransition("ST_TWO")
			:AddEventTransition("EV_TO_TWO", "ST_TWO")
		)
		:AddState(FSM.NewState("ST_TWO")
			:AddTransition("ST_THREE")
			:AddEventTransition("EV_TO_THREE", "ST_THREE")
		)
		:AddState(FSM.NewState("ST_THREE")
			:AddTransition("ST_ONE")
			:AddEventTransition("EV_RESET", "ST_ONE")
		)
		:Init("ST_ONE")
		:SetLoggingEnabled(false)

	assertEquals(fsm._currentState, "ST_ONE")

	fsm:ProcessEvent("EV_TO_THREE")
	assertEquals(fsm._currentState, "ST_ONE")
	fsm:ProcessEvent("EV_RESET")
	assertEquals(fsm._currentState, "ST_ONE")

	fsm:ProcessEvent("EV_TO_TWO")
	assertEquals(fsm._currentState, "ST_TWO")
	fsm:ProcessEvent("EV_RESET")
	assertEquals(fsm._currentState, "ST_TWO")

	fsm:ProcessEvent("EV_TO_THREE")
	assertEquals(fsm._currentState, "ST_THREE")
	fsm:ProcessEvent("EV_TO_TWO")
	assertEquals(fsm._currentState, "ST_THREE")

	fsm:ProcessEvent("EV_RESET")
	assertEquals(fsm._currentState, "ST_ONE")
end

function TestFSM:TestOnEnterTransition()
	local fsm = FSM.New("TEST")
		:AddState(FSM.NewState("ST_INITIAL")
			:AddTransition("ST_ONE")
			:AddEventTransition("EV_START", "ST_ONE")
		)
		:AddState(FSM.NewState("ST_ONE")
			:SetOnEnter(function(context, arg)
				assertEquals(arg, 1)
				return "ST_TWO", 2
			end)
			:AddTransition("ST_TWO")
		)
		:AddState(FSM.NewState("ST_TWO")
			:SetOnEnter(function(context, arg)
				assertEquals(arg, 2)
				return "ST_THREE", 3
			end)
			:AddTransition("ST_THREE")
		)
		:AddState(FSM.NewState("ST_THREE")
			:SetOnEnter(function(context, arg)
				assertEquals(arg, 3)
			end)
		)
		:Init("ST_INITIAL")
		:SetLoggingEnabled(false)

	assertEquals(fsm._currentState, "ST_INITIAL")
	fsm:ProcessEvent("EV_START", 1)
	assertEquals(fsm._currentState, "ST_THREE")
end
