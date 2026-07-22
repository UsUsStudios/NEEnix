function _G.include(path)
	local handle = files.open("system:/boot/kernel/" .. path)
	local data = handle.read("a")
	handle.close()
	return load(data, "system:/boot/kernel/" .. path, nil, _G)
end

_G.NEENIXVERSION = "v0.0.1"

include("scheduler.lua")()
include("vfs.lua")()

scheduler.new_process(function()
	coroutine.yield({ type = "mount", mountpoint = "/", fspath = "system:/boot/kernel/fs/rootfs" })
	coroutine.yield({ type = "spawn", path = "/etc/initd/init.lua" })
end)

while true do
	scheduler.tick()
	coroutine.yield()
end
