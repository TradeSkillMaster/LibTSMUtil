-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local Memory = LibTSMUtil:Init("Lua.Memory")



-- ============================================================================
-- Module Functions
-- ============================================================================

---Forces a garbage collection.
function Memory.CollectGarbage()
	collectgarbage("collect")
	collectgarbage("collect")
end
