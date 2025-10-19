local TSM, Locals = ... ---@type TSM, table<string,table<string,any>>
local LibTSMUtil = TSM.LibTSMUtil
local Reactive = LibTSMUtil:Include("Reactive")
local EnumType = LibTSMUtil:Include("BaseType.EnumType")
local private = {
	cancellables = {},
}



-- ============================================================================
-- Tests
-- ============================================================================

TestState = {}

function TestState:setUp()
end

function TestState:tearDown()
	for _, cancellable in ipairs(private.cancellables) do
		cancellable:Cancel()
	end
	wipe(private.cancellables)
	local objectPool = Locals["LibTSMUtil.Reactive.Type.PublisherSchema"].private.objectPool
	assertEquals(objectPool._state, {})
end

function TestState:TestSetGetValues()
	local state = Reactive.CreateStateSchema("TEST_SET_GET")
		:AddNumberField("num1", 0)
		:AddStringField("str1", "")
		:Commit()
		:CreateState()

	assertEquals(state.num1, 0)
	assertEquals(state.str1, "")

	state.num1 = 1
	assertEquals(state.num1, 1)
	assertEquals(state.str1, "")

	state:ResetToDefault()
	assertEquals(state.num1, 0)
	assertEquals(state.str1, "")

	assertError(function() return state.str2 end)
	assertError(function() state.str2 = "" end)
	assertError(function() state.str1 = 0 end)
end

function TestState:TestPublisher()
	local state = Reactive.CreateStateSchema("TEST_PUBLISHER")
		:AddNumberField("num1", 0)
		:AddStringField("str1", "")
		:Commit()
		:CreateState()
		:SetAutoStore(private.cancellables)

	local publishedValues1 = {}
	state:PublisherForKeyChange("num1")
		:CallFunction(function(value) tinsert(publishedValues1, value) end)

	local publishedValues2, publishedValues3 = {}, {}
	state:PublisherForKeyChange("str1")
		:IgnoreIfEquals("ignore1")
		:IgnoreIfEquals("ignore2")
		:CallFunction(function(value) tinsert(publishedValues2, value) end)
	state:PublisherForKeyChange("str1")
		:IgnoreIfEquals("ignore1")
		:IgnoreIfEquals("ignore3")
		:CallFunction(function(value) tinsert(publishedValues3, value) end)

	assertEquals(publishedValues1, {0})
	assertEquals(publishedValues2, {""})
	assertEquals(publishedValues3, {""})

	state.num1 = 1
	assertEquals(publishedValues1, {0, 1})
	assertEquals(publishedValues2, {""})
	assertEquals(publishedValues3, {""})

	state.str1 = "a"
	assertEquals(publishedValues1, {0, 1})
	assertEquals(publishedValues2, {"", "a"})
	assertEquals(publishedValues3, {"", "a"})

	state.str1 = "ignore1"
	assertEquals(publishedValues1, {0, 1})
	assertEquals(publishedValues2, {"", "a"})
	assertEquals(publishedValues3, {"", "a"})

	state.str1 = "ignore2"
	assertEquals(publishedValues1, {0, 1})
	assertEquals(publishedValues2, {"", "a"})
	assertEquals(publishedValues3, {"", "a", "ignore2"})

	state.str1 = "ignore3"
	assertEquals(publishedValues1, {0, 1})
	assertEquals(publishedValues2, {"", "a", "ignore3"})
	assertEquals(publishedValues3, {"", "a", "ignore2"})

	local publishedValues4 = {}
	state:PublisherForKeyChange("num1")
		:MapToValue({val = 2, GetValue = function(self, extra) return self.val + extra end})
		:MapWithMethod("GetValue", 1)
		:CallFunction(function(value) tinsert(publishedValues4, value) end)
	assertEquals(publishedValues4, {3})
end

function TestState:TestNilDuplicates()
	local state = Reactive.CreateStateSchema("TEST_PUBLISHER")
		:AddOptionalNumberField("num")
		:Commit()
		:CreateState()
		:SetAutoStore(private.cancellables)

	local publishedValues = {}
	state:PublisherForKeyChange("num")
		:MapNilToValue(-1)
		:CallFunction(function(value) tinsert(publishedValues, value) end)

	assertEquals(publishedValues, {-1})

	state.num = 1
	assertEquals(publishedValues, {-1, 1})

	state.num = -1
	assertEquals(publishedValues, {-1, 1, -1})

	state.num = nil
	assertEquals(publishedValues, {-1, 1, -1, -1})

	state.num = -1
	assertEquals(publishedValues, {-1, 1, -1, -1, -1})
end

function TestState:TestFunctionWithKeys()
	local state = Reactive.CreateStateSchema("TEST_FUNCTION_WITH_KEYS")
		:AddNumberField("num", 0)
		:AddOptionalStringField("str")
		:Commit()
		:CreateState()
		:SetAutoStore(private.cancellables)

	local function MapFunc(num, str)
		return num == 0 and "" or str or "nil"
	end
	local function MapFunc2(num)
		return num % 2 == 0 and "EVEN" or "ODD"
	end
	local publishedValues1 = {}
	local publishedValues2 = {}
	state:PublisherForFunctionWithKeys(MapFunc, "num", "str")
		:CallFunction(function(value) tinsert(publishedValues1, value) end)
	state:PublisherForFunctionWithKeys(MapFunc2, "num")
		:CallFunction(function(value) tinsert(publishedValues2, value) end)

	assertEquals(publishedValues1, {""})
	assertEquals(publishedValues2, {"EVEN"})

	state.num = 1
	assertEquals(publishedValues1, {"", "nil"})
	assertEquals(publishedValues2, {"EVEN", "ODD"})

	state.num = 2
	assertEquals(publishedValues1, {"", "nil"})
	assertEquals(publishedValues2, {"EVEN", "ODD", "EVEN"})

	state.num = 0
	assertEquals(publishedValues1, {"", "nil", ""})
	assertEquals(publishedValues2, {"EVEN", "ODD", "EVEN"})

	state.str = "a"
	assertEquals(publishedValues1, {"", "nil", ""})
	assertEquals(publishedValues2, {"EVEN", "ODD", "EVEN"})

	state.num = 1
	assertEquals(publishedValues1, {"", "nil", "", "a"})
	assertEquals(publishedValues2, {"EVEN", "ODD", "EVEN", "ODD"})

	state.str = "b"
	assertEquals(publishedValues1, {"", "nil", "", "a", "b"})
	assertEquals(publishedValues2, {"EVEN", "ODD", "EVEN", "ODD"})

	state.num = 3
	assertEquals(publishedValues1, {"", "nil", "", "a", "b"})
	assertEquals(publishedValues2, {"EVEN", "ODD", "EVEN", "ODD"})

	state.num = 0
	assertEquals(publishedValues1, {"", "nil", "", "a", "b", ""})
	assertEquals(publishedValues2, {"EVEN", "ODD", "EVEN", "ODD", "EVEN"})
end

function TestState:TestShare()
	local state = Reactive.CreateStateSchema("TEST_SHARE")
		:AddNumberField("num", 0)
		:Commit()
		:CreateState()
		:SetAutoStore(private.cancellables)

	local publishedValues1 = {}
	local publishedValues2 = {}
	state:PublisherForKeyChange("num")
		:IgnoreIfEquals(0)
		:Share()
		:MapWithFunction(function(value) return floor(value / 2) end)
		:IgnoreDuplicates()
		:CallFunctionAndContinueShare(function(value) tinsert(publishedValues1, value) end)
		:CallFunctionAndContinueShare(function(value) tinsert(publishedValues2, value) end)
		:EndShare()

	state.num = 1
	assertEquals(publishedValues1, {0})
	assertEquals(publishedValues2, {1})

	state.num = 2
	assertEquals(publishedValues1, {0, 1})
	assertEquals(publishedValues2, {1, 2})

	state.num = 3
	assertEquals(publishedValues1, {0, 1})
	assertEquals(publishedValues2, {1, 2, 3})

	state.num = 0
	assertEquals(publishedValues1, {0, 1})
	assertEquals(publishedValues2, {1, 2, 3})
end

function TestState:TestStateExpression()
	local COLOR = EnumType.New("COLOR", {
		RED = EnumType.NewValue(),
		BLUE = EnumType.NewValue(),
	})
	local state = Reactive.CreateStateSchema("TEST_STATE_EXPRESSION")
		:AddEnumField("color", COLOR, COLOR.RED)
		:AddNumberField("num1", 10)
		:AddNumberField("num2", 20)
		:AddStringField("str", "1+2")
		:Commit()
		:CreateState()
		:SetAutoStore(private.cancellables)

	local publishedValues1 = {}
	local publishedValues2 = {}
	local publishedValues3 = {}
	state:PublisherForExpression([[num1 + num2]])
		:CallFunction(function(value) tinsert(publishedValues1, value) end)
	state:PublisherForExpression([[-1 * (EnumEquals(color, RED) and -num1 or -num2)]])
		:CallFunction(function(value) tinsert(publishedValues2, value) end)
	state:PublisherForExpression([[EnumEquals(color, RED) and "String 1" or "String 2"]])
		:CallFunction(function(value) tinsert(publishedValues3, value) end)

	assertEquals(publishedValues1, {30})
	assertEquals(publishedValues2, {10})
	assertEquals(publishedValues3, {"String 1"})

	state.color = COLOR.BLUE
	assertEquals(publishedValues1, {30})
	assertEquals(publishedValues2, {10, 20})
	assertEquals(publishedValues3, {"String 1", "String 2"})

	state.num1 = 11
	assertEquals(publishedValues1, {30, 31})
	assertEquals(publishedValues2, {10, 20})
	assertEquals(publishedValues3, {"String 1", "String 2"})

	state.num2 = 21
	assertEquals(publishedValues1, {30, 31, 32})
	assertEquals(publishedValues2, {10, 20, 21})
	assertEquals(publishedValues3, {"String 1", "String 2"})

	local publishedValues4 = {}
	state:PublisherForExpression([[str == "1+2" and "orig" or "changed"]])
		:CallFunction(function(value) tinsert(publishedValues4, value) end)
	assertEquals(publishedValues4, {"orig"})
	state.str = "2+3"
	assertEquals(publishedValues4, {"orig", "changed"})
end

function TestState:TestDeferred()
	local state = Reactive.CreateStateSchema("TEST_DEFER")
		:AddStringField("str", "A")
		:Commit()
		:CreateState()
		:SetAutoStore(private.cancellables)

	local publishedValues = {}
	state:SetAutoDeferred(true)
	state:PublisherForKeyChange("str")
		:CallFunction(function(value) tinsert(publishedValues, "1_"..value) end)
	state:SetAutoDeferred(false)
	state:PublisherForKeyChange("str")
		:CallFunction(function(value) tinsert(publishedValues, "2_"..value) end)
	assertEquals(publishedValues, {"1_A", "2_A"})

	state.str = "B"
	assertEquals(publishedValues, {"1_A", "2_A", "2_B", "1_B"})
end

function TestState:TestDisable()
	local state = Reactive.CreateStateSchema("TEST_DIABLE")
		:AddStringField("str", "A")
		:Commit()
		:CreateState()
		:SetAutoStore(private.cancellables)
		:SetAutoDisable(true)

	local publishedValues = {}
	local publisher = state:PublisherForKeyChange("str")
		:CallFunction(function(value) tinsert(publishedValues, value) end)
	assertEquals(publishedValues, {})

	state.str = "B"
	assertEquals(publishedValues, {})

	publisher:EnableAndReset()
	assertEquals(publishedValues, {"B"})

	publisher:Disable()
	publisher:EnableAndReset()
	assertEquals(publishedValues, {"B", "B"})

	state.str = "C"
	assertEquals(publishedValues, {"B", "B", "C"})

	publisher:Disable()
	state.str = "D"
	assertEquals(publishedValues, {"B", "B", "C"})
end
