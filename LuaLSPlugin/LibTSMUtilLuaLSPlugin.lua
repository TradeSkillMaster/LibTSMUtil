local Plugin = {}

local function ProcessSmartMapNew(context, line)
	-- Quick plain-text check as an optimization
	if not line:find("SmartMap.New(", nil, true) then
		return
	end
	-- Already annotated inline
	if line:find("---@type SmartMap", nil, true) then
		return
	end
	local keyType, valueType = line:match('SmartMap%.New%("(%w+)", "(%w+)"')
	if not keyType or not valueType then
		return
	end
	-- Check for annotation on preceding line
	local prevIndex = context.currentLine.index - 1
	if prevIndex >= 1 and context.lines[prevIndex]:find("---@type SmartMap", nil, true) then
		return
	end
	context:AddPrefixDiff("---@type SmartMap<"..keyType..", "..valueType..">\n")
end

local function ProcessObjectPoolNew(context, line)
	-- Quick plain-text check as an optimization
	if not line:find("ObjectPool.New(", nil, true) then
		return
	end
	-- Already annotated inline
	if line:find("---@type ObjectPool", nil, true) then
		return
	end
	local className = line:match('ObjectPool%.New%("[^"]+", ([A-Z][A-Za-z0-9_]+)')
	if not className then
		return
	end
	-- Check for annotation on preceding line
	local prevIndex = context.currentLine.index - 1
	if prevIndex >= 1 and context.lines[prevIndex]:find("---@type ObjectPool", nil, true) then
		return
	end
	context:AddPrefixDiff("---@type ObjectPool<"..className..">\n")
end

function Plugin.ProcessContext(context)
	for _, line in context:LineIterator() do
		ProcessSmartMapNew(context, line)
		ProcessObjectPoolNew(context, line)
	end
end

return Plugin
