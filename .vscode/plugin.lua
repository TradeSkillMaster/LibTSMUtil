---@diagnostic disable: param-type-mismatch

local client = require 'client'

local rootPath = nil
if client.info.rootPath then
	rootPath = client.info.rootPath
else
	rootPath = string.match(client.info.rootUri, "file://(.+)")
	rootPath = string.gsub(rootPath, "^/c%%3A", "C:")
end
if string.match(package.path, "\\%?") then
	rootPath = string.gsub(rootPath, "/", "\\")
	package.path = package.path .. ";" .. rootPath .. "\\..\\LibTSMClass\\LuaLSPlugin\\?.lua"
	package.path = package.path .. ";" .. rootPath .. "\\..\\LibTSMCore\\LuaLSPlugin\\?.lua"
else
	package.path = package.path .. ";" .. rootPath .. "/../LibTSMClass/LuaLSPlugin/?.lua"
	package.path = package.path .. ";" .. rootPath .. "/../LibTSMCore/LuaLSPlugin/?.lua"
end

local LibTSMCorePlugin = require("LibTSMCoreLuaLSPlugin")

---@param uri string
---@param text string
function OnSetText(uri, text)
	local context = LibTSMCorePlugin.GetContext(uri, text)
	if not context then
		return
	end
	LibTSMCorePlugin.ProcessContext(context)
	return context.diffs
end
