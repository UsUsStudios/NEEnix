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

	local pipefds, err = coroutine.yield({ type = "open", path = "/dev/popen" })
	if err then
		print(err)
	end
	local stdout_in, stdout_out = table.unpack(pipefds)
	pipefds, err = coroutine.yield({ type = "open", path = "/dev/popen" })
	if err then
		print(err)
	end
	local stderr_in, stderr_out = table.unpack(pipefds)

	coroutine.yield({ type = "exec", path = "/etc/initd/init.lua", stdout = stdout_in, stderr = stderr_in })

	while true do
		local stdout_data, err1 = coroutine.yield({ type = "read", fd = stdout_out })
		if err1 then
			print(err1)
		end
		local stderr_data, err2 = coroutine.yield({ type = "read", fd = stderr_out })
		if err2 then
			print(err2)
		end
		if stdout_data ~= "\0" then
			print(stdout_data:sub(1, #stdout_data - 1))
		end
		if stderr_data ~= "\0" then
			print(stderr_data:sub(1, #stderr_data - 1))
		end
	end
end

do
	scheduler.new_process(pid1)
end

while true do
	scheduler.tick()
	coroutine.yield()
end
