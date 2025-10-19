local repo_root = io.popen("git rev-parse --show-superproject-working-tree --show-toplevel | head -1"):read('*l')
local opt = assert(loadfile(repo_root.."/LibTSMCore/.luacheckrc"))()

-- Add TSMDEV
table.insert(opt.globals, "TSMDEV")

return opt
