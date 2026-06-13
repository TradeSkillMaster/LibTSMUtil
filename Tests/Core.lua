local Env = require("LibTSMCore.Tests.Env.Core")
Env.Init("TradeSkillMaster", "RETAIL")
C_EncodingUtil = {
	CompressString = function(str) return str end,
	DecompressString = function(str) return str end,
	EncodeBase64 = function(str) return str end,
	DecodeBase64 = function(str) return str end,
}
Env.LoadAddonFiles({
	"LibTSMClass/LibStub/LibStub.lua",
	"LibTSMClass/LibTSMClass.lua",
	"LibTSMCore/LibTSMCore.xml",
	"LibTSMUtil/LibTSMUtil.xml",
})
Env.LoadTestCaseFiles({
	"LibTSMUtil/Tests/ContextManagerTest.lua",
	"LibTSMUtil/Tests/EncoderTest.lua",
	"LibTSMUtil/Tests/EnumTypeTest.lua",
	"LibTSMUtil/Tests/FSMTest.lua",
	"LibTSMUtil/Tests/HashTest.lua",
	"LibTSMUtil/Tests/IteratorTest.lua",
	"LibTSMUtil/Tests/MathTest.lua",
	"LibTSMUtil/Tests/MoneyFormatterTest.lua",
	"LibTSMUtil/Tests/MoneyTest.lua",
	"LibTSMUtil/Tests/NamedTupleListTest.lua",
	"LibTSMUtil/Tests/RangeTest.lua",
	"LibTSMUtil/Tests/SmartMapTest.lua",
	"LibTSMUtil/Tests/StringBuilderTest.lua",
	"LibTSMUtil/Tests/StringTest.lua",
	"LibTSMUtil/Tests/TableTest.lua",
	"LibTSMUtil/Tests/TempTableTest.lua",
	"LibTSMUtil/Tests/TreeTest.lua",
	"LibTSMUtil/Tests/VarargTest.lua",
})
Env.Run()
