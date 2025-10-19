local TSM = ... ---@type TSM
local LibTSMUtil = TSM.LibTSMUtil
local MoneyFormatter = LibTSMUtil:IncludeClassType("MoneyFormatter")



-- ============================================================================
-- Tests
-- ============================================================================

TestMoneyFormatter = {}

function TestMoneyFormatter:TestDefaultConfig()
	local formatter = MoneyFormatter.New()
	assertEquals(formatter:ToString(20), "20|cffeda55fc|r")
	assertEquals(formatter:ToString(2000), "20|cffc7c7cfs|r 00|cffeda55fc|r")
	assertEquals(formatter:ToString(5005005), "500|cffffd70ag|r 50|cffc7c7cfs|r 05|cffeda55fc|r")
	assertEquals(formatter:ToString(500000000000), "50,000,000|cffffd70ag|r 00|cffc7c7cfs|r 00|cffeda55fc|r")
end

function TestMoneyFormatter:TestColor()
	local formatter = MoneyFormatter.New()
		:SetColor("|cff000000")
	assertEquals(formatter:ToString(5005005, "|cff000000"), "|cff000000500|r|cffffd70ag|r |cff00000050|r|cffc7c7cfs|r |cff00000005|r|cffeda55fc|r")
	assertEquals(formatter:ToString(50000002121, "|cff000000"), "|cff0000005,000,000|r|cffffd70ag|r |cff00000021|r|cffc7c7cfs|r |cff00000021|r|cffeda55fc|r")
end

function TestMoneyFormatter:TestRemoveCopper()
	local formatter = MoneyFormatter.New()
		:SetCopperHandling(MoneyFormatter.COPPER_HANDLING.REMOVE)
	assertEquals(formatter:ToString(0), "0|cffc7c7cfs|r")
	assertEquals(formatter:ToString(2000), "20|cffc7c7cfs|r")
	assertEquals(formatter:ToString(5005000), "500|cffffd70ag|r 50|cffc7c7cfs|r")
	assertEquals(formatter:ToString(500000000000), "50,000,000|cffffd70ag|r 00|cffc7c7cfs|r")
end

function TestMoneyFormatter:TestRoundCopper()
	local formatter = MoneyFormatter.New()
		:SetCopperHandling(MoneyFormatter.COPPER_HANDLING.ROUND_OVER_1G)
	assertEquals(formatter:ToString(2), "2|cffeda55fc|r")
	assertEquals(formatter:ToString(50), "50|cffeda55fc|r")
	assertEquals(formatter:ToString(2050), "20|cffc7c7cfs|r 50|cffeda55fc|r")
	assertEquals(formatter:ToString(12050), "1|cffffd70ag|r 21|cffc7c7cfs|r")
end

function TestMoneyFormatter:TestTrim()
	local formatter = MoneyFormatter.New()
		:SetTrimEnabled(true)
	assertEquals(formatter:ToString(2), "2|cffeda55fc|r")
	assertEquals(formatter:ToString(2000), "20|cffc7c7cfs|r")
	assertEquals(formatter:ToString(5005000), "500|cffffd70ag|r 50|cffc7c7cfs|r")
	assertEquals(formatter:ToString(5005005), "500|cffffd70ag|r 50|cffc7c7cfs|r 05|cffeda55fc|r")
	assertEquals(formatter:ToString(500000000000), "50,000,000|cffffd70ag|r")
end

function TestMoneyFormatter:TestFromString()
	assertEquals(MoneyFormatter.FromString("20c"), 20)
	assertEquals(MoneyFormatter.FromString("20s 0c"), 2000)
	assertEquals(MoneyFormatter.FromString("500g 50s 5c"), 5005005)
	assertEquals(MoneyFormatter.FromString("50000000g 0s 0c"), 500000000000)
	assertEquals(MoneyFormatter.FromString("|cff0000005,000,000|r|cffffd70ag|r |cff00000021|r|cffc7c7cfs|r |cff00000021|r|cffeda55fc|r"), 50000002121)
end
