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

	local pipefds, err = coroutine.yield({ type = "open", path = "/dev/popen" })
	if err then
		error(err)
	end
	local stdout_in, stdout_out = table.unpack(pipefds)
	pipefds, err = coroutine.yield({ type = "open", path = "/dev/popen" })
	if err then
		error(err)
	end
	local stderr_in, stderr_out = table.unpack(pipefds)

	coroutine.yield({
		type = "exec",
		path = "/bin/nterm/init.lua",
		args = { "/etc/init.d/init.lua" },
		cwd = "/bin/nterm/",
		stdout = stdout_in,
		stderr = stderr_in,
	})

	while true do
		local stdout_data, err1 = coroutine.yield({ type = "read", fd = stdout_out })
		local stderr_data, err2 = coroutine.yield({ type = "read", fd = stderr_out })
		if err1 then
			error(err1)
		end
		if err2 then
			error(err2)
		end
		if stdout_data ~= "\0" then
			print(stdout_data)
		end
		if stderr_data ~= "\0" then
			print(stderr_data)
		end
	end
end

print("\n")
print("##############################################################################")
print("##############################################################################")
print("######################                                  ######################")
print("######################    NEW NEENIX SESSION STARTED    ######################")
print("######################                                  ######################")
print("##############################################################################")
print("##############################################################################")
scheduler.new_process(pid1)

while true do
	scheduler.tick()
	coroutine.yield()

	if scheduler.processes[1].state ~= "ready" and scheduler.processes[1].state ~= "running" then
		print("#############################################################")
		print("##############   KERNEL PANIC: PID 1 IS DEAD   ##############")
		print("#############################################################")
		break
	end
end

while true do
end
