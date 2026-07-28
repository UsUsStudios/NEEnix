coroutine.yield({ type = "mount", mountpoint = "/", fspath = "system:/boot/kernel/fs/rootfs" })
coroutine.yield({ type = "mount", mountpoint = "/proc", fspath = "/boot/kernel/fs/procfs" })
coroutine.yield({ type = "mount", mountpoint = "/dev/popen", fspath = "/boot/kernel/fs/pipefs" })

local unistd = require("unistd")
for _, v in ipairs(coroutine.yield({ type = "readdir", path = "/proc" })) do
	print(v)
end
