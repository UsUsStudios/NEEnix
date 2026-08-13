function _G.include(path, env)
	local handle = files.open("system:/boot/kernel/" .. path)
	local data = handle.read("a")
	handle.close()
	local f, err = load(data, "/boot/kernel/" .. path, nil, env or _G)
	if err then
		error(err)
	end
	return f
end

_G.NEENIXVERSION = "v0.0.1"
_G.cwd = "/"

include("scheduler.lua")()
include("vfs.lua")()

local function pid1()
	local function mount(mountpoint, fsname)
		local _, err =
			coroutine.yield({ type = "mount", mountpoint = mountpoint, fspath = "system:/boot/kernel/fs/" .. fsname })
		if err then
			error(err)
		end
	end
	mount("/", "rootfs")
	mount("/proc", "procfs")
	mount("/dev/popen", "pipefs")
	mount("/dev/screen", "screenfs")

	coroutine.yield({ type = "setenv", name = "hi", value = "hello", exported = true })

	coroutine.yield({ type = "exec", path = "/etc/init.d/init.lua" })
end

scheduler.new_process(pid1)

while true do
	scheduler.tick()
	coroutine.yield()
end
