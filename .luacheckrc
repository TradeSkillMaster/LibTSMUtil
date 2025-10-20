local repo_root = io.popen("git rev-parse --show-toplevel"):read('*l')
local f = loadfile(repo_root.."/LibTSMCore/.luacheckrc")
if not f then
	f = assert(loadfile(repo_root.."/../LibTSMCore/.luacheckrc"))
end
local opt = f()

-- Add TSMDEV
table.insert(opt.globals, "TSMDEV")

return opt
