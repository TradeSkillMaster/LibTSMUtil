local TSM = ... ---@type TSM
local LibTSMUtil = TSM.LibTSMUtil
local ContextManager = LibTSMUtil:Include("BaseType.ContextManager")



-- ============================================================================
-- Tests
-- ============================================================================

TestContextManager = {}

function TestContextManager:TestEnterExit()
	local ARG_VALUE = 1
	local ENTER_VALUE = "a"
	local events = {}
	local function EnterFunc(arg)
		assertEquals(arg, ARG_VALUE)
		tinsert(events, "ENTER")
		return ENTER_VALUE
	end
	local function ExitFunc(arg, enterValue)
		assertEquals(arg, ARG_VALUE)
		assertEquals(enterValue, ENTER_VALUE)
		tinsert(events, "EXIT")
	end
	local obj = ContextManager.Create(EnterFunc, ExitFunc)
	for _ in obj:With(ARG_VALUE) do
		tinsert(events, "BODY")
	end
	assertEquals(events, {"ENTER", "BODY", "EXIT"})
end

function TestContextManager:TestIterator()
	local ARG_VALUE = 1
	local ENTER_VALUE = "a"
	local events = {}
	local function EnterFunc(arg)
		assertEquals(arg, ARG_VALUE)
		tinsert(events, "ENTER")
		return ENTER_VALUE
	end
	local function ExitFunc(arg, enterValue)
		assertEquals(arg, ARG_VALUE)
		assertEquals(enterValue, ENTER_VALUE)
		tinsert(events, "EXIT")
	end
	local obj = ContextManager.Create(EnterFunc, ExitFunc)
	local tbl = {"A", "B", "C"}
	for i, v in obj:With(ARG_VALUE, ipairs(tbl)) do
		assertEquals(tbl[i], v)
		tinsert(events, "BODY_"..i)
	end
	assertEquals(events, {"ENTER", "BODY_1", "BODY_2", "BODY_3", "EXIT"})
end

function TestContextManager:TestNested()
	local ARG_VALUE = 1
	local ENTER_VALUE = "a"
	local events = {}
	local function EnterFunc(arg)
		assertEquals(arg, ARG_VALUE)
		tinsert(events, "ENTER")
		return ENTER_VALUE
	end
	local function ExitFunc(arg, enterValue)
		assertEquals(arg, ARG_VALUE)
		assertEquals(enterValue, ENTER_VALUE)
		tinsert(events, "EXIT")
	end
	local obj = ContextManager.Create(EnterFunc, ExitFunc)
	for _ in obj:With(ARG_VALUE) do
		tinsert(events, "BODY_OUTER")
		for _ in obj:With(ARG_VALUE) do
			tinsert(events, "BODY_INNER")
		end
	end
	assertEquals(events, {"ENTER", "BODY_OUTER", "ENTER", "BODY_INNER", "EXIT", "EXIT"})
end
