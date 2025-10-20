-- ------------------------------------------------------------------------------ --
--                                   LibTSMUtil                                   --
--                 https://github.com/TradeSkillMaster/LibTSMUtil                 --
--         Licensed under the MIT license. See LICENSE.txt for more info.         --
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
