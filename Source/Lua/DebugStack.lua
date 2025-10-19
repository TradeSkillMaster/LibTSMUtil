-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local DebugStack = LibTSMUtil:Init("Lua.DebugStack")
local private = {
	shortenPatterns = {},
}
local IGNORED_STACK_LEVEL_MATCHERS = {
	-- Ignore wrapper code from LibTSMClass
	"LibTSMClass%.lua:",
}



-- ============================================================================
-- Module Functions
-- ============================================================================

---Adds a pattern and replacement string for shortening the names of addons stack frames.
---@param pattern string The search pattern
---@param replacement string The replacement string
function DebugStack.AddShortenPattern(pattern, replacement)
	private.shortenPatterns[pattern] = replacement
end

---Gets the location string for the specified stack level.
---@param targetLevel number The stack level to get the location for
---@param thread? thread The thread to get the location for
---@return string?
function DebugStack.GetLocation(targetLevel, thread)
	targetLevel = targetLevel + 1
	assert(targetLevel > 0)
	local level = 1
	while true do
		local stackLine = nil
		if thread then
			stackLine = debugstack(thread, level, 1, 0)
		else
			stackLine = debugstack(level, 1, 0)
		end
		if not stackLine or stackLine == "" then
			return nil
		end
		local parsedStackLine, numSubs = gsub(stackLine, "^%s*%[string \"@*([^%.]+%.lua)\"%](:%d+).*$", "%1%2")
		if numSubs == 0 then
			parsedStackLine, numSubs = gsub(stackLine, "^%s*%[(Interface[^%.]+%.lua)%](:%d+).*$", "%1%2")
		end
		stackLine = numSubs > 0 and parsedStackLine or nil
		if stackLine then
			local ignored = false
			for _, matchStr in ipairs(IGNORED_STACK_LEVEL_MATCHERS) do
				if strmatch(stackLine, matchStr) then
					ignored = true
					break
				end
			end
			if not ignored then
				targetLevel = targetLevel - 1
				if targetLevel == 0 then
					stackLine = gsub(stackLine, "/", "\\")
					for matchStr, replaceStr in pairs(private.shortenPatterns) do
						stackLine = gsub(stackLine, matchStr, replaceStr)
					end
					return stackLine
				end
			end
		end
		level = level + 1
	end
end
