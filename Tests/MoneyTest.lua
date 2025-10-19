local TSM = ... ---@type TSM
local LibTSMUtil = TSM.LibTSMUtil
local Money = LibTSMUtil:Include("UI.Money")



-- ============================================================================
-- Tests
-- ============================================================================

TestMoney = {}

function TestMoney:TestToString()
	assertEquals(Money.ToStringExact(20), "20|cffeda55fc|r")
	assertEquals(Money.ToStringExact(2000), "20|cffc7c7cfs|r 00|cffeda55fc|r")
	assertEquals(Money.ToStringExact(5005005), "500|cffffd70ag|r 50|cffc7c7cfs|r 05|cffeda55fc|r")
	assertEquals(Money.ToStringExact(500000000000), "50,000,000|cffffd70ag|r 00|cffc7c7cfs|r 00|cffeda55fc|r")
end

function TestMoney:TestToStringColor()
	assertEquals(Money.ToStringExact(5005005, "|cff000000"), "|cff000000500|r|cffffd70ag|r |cff00000050|r|cffc7c7cfs|r |cff00000005|r|cffeda55fc|r")
	assertEquals(Money.ToStringExact(50000002121, "|cff000000"), "|cff0000005,000,000|r|cffffd70ag|r |cff00000021|r|cffc7c7cfs|r |cff00000021|r|cffeda55fc|r")
end

function TestMoney:TestToStringNoCopper()
	assertEquals(Money.ToStringForAH(0), "0|cffc7c7cfs|r")
	assertEquals(Money.ToStringForAH(2000), "20|cffc7c7cfs|r")
	assertEquals(Money.ToStringForAH(5005000), "500|cffffd70ag|r 50|cffc7c7cfs|r")
	assertEquals(Money.ToStringForAH(500000000000), "50,000,000|cffffd70ag|r 00|cffc7c7cfs|r")
end

function TestMoney:TestFromString()
	assertEquals(Money.FromString("20c"), 20)
	assertEquals(Money.FromString("20s 0c"), 2000)
	assertEquals(Money.FromString("500g 50s 5c"), 5005005)
	assertEquals(Money.FromString("50000000g 0s 0c"), 500000000000)
	assertEquals(Money.FromString("|cff0000005,000,000|r|cffffd70ag|r |cff00000021|r|cffc7c7cfs|r |cff00000021|r|cffeda55fc|r"), 50000002121)
end
