local repo_root = io.popen("git rev-parse --show-toplevel"):read('*l')
local opt = assert(loadfile(repo_root.."/LibTSMCore/.luacheckrc"))()

-- Add TSMDEV
table.insert(opt.globals, "TSMDEV")

return opt
