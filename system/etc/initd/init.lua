coroutine.yield({ type = "mount", mountpoint = "/proc", fspath = "system:/boot/kernel/fs/procfs" })

local function inspectProcess(pid)
	print("Inspecting proccess " .. pid)
	for _, file in ipairs(coroutine.yield({ type = "readdir", path = "/proc/" .. pid })) do
		print("    " .. file)
	end

	local function read(path)
		local fd, err = coroutine.yield({ type = "open", path = path, mode = "r" })
		if err then
			print(fd, err)
		end
		print(path .. ": " .. coroutine.yield({ type = "read", fd = fd, count = "a" }))
		coroutine.yield({ type = "close", fd = fd })
	end

	read("/proc/" .. pid .. "/status")
	read("/proc/" .. pid .. "/pid")
	read("/proc/" .. pid .. "/ppid")
	read("/proc/" .. pid .. "/state")
	read("/proc/" .. pid .. "/costatus")
	read("/proc/" .. pid .. "/wake_at")
	read("/proc/" .. pid .. "/exit_code")
	read("/proc/" .. pid .. "/waiters")
	read("/proc/" .. pid .. "/fds")
	read("/proc/" .. pid .. "/children")
	read("/proc/" .. pid .. "/sighandlers")
end

--inspectProcess(1)
--inspectProcess(2)
