local SIGTERM = 1
local SIGKILL = 2

local function continueproc(pcb)
	pcb.state = "ready"
	scheduler.enqueue(pcb.pid)
end

local calls = {}

------------------------------------------------------------------------------------
--------------------------------- PROCESS HANDLING ---------------------------------
------------------------------------------------------------------------------------

function calls.getpid(pcb, _) -- return the PID of the process that called
	continueproc(pcb)
	return pcb.pid
end

function calls.sleep(pcb, request) -- wait a given number of seconds
	pcb.state = "sleeping"
	pcb.wake_at = chip.getTime() + request.seconds
end

function calls.wait(pcb, request) -- wait until another process finishes executing
	local target = scheduler.processes[request.pid]
	if not target or target.state == "zombie" then
		continueproc(pcb)
	else
		table.insert(target.waiters, pcb.pid)
		pcb.state = "blocked"
	end
end

function calls.exit(pcb, request) -- end the execution of this process
	pcb.state = "zombie"
	pcb.exit_code = request.code
	print("Process with PID " .. pcb.pid .. " ended with exit code " .. pcb.exit_code)
end

function calls.kill(pcb, request) -- send a signal to the process
	continueproc(pcb)
	local proc = scheduler.processes[request.pid]
	if proc.sighandlers[request.sig] ~= nil then
		proc.sighandlers[request.sig](request.sig)
	else
		if request.sig == SIGTERM or request.sig == SIGKILL then
			proc.state = "dead"
			pcb.exit_code = 0
		end
	end
end

function calls.signal(pcb, request) -- set a signal handler to this process
	continueproc(pcb)

	if request.sig ~= SIGKILL then
		pcb.sighandlers[request.sig] = request.handler
	else
		error("cannot set a signal handler for SIGKILL")
	end
end

function calls.spawn(pcb, request) -- spawn a new process executing a function
	continueproc(pcb)

	if request.args then
		scheduler.new_process(function()
			request.fn(table.unpack(request.args))
		end, pcb.pid)
	else
		scheduler.new_process(request.fn, pcb.pid)
	end
end

function calls.exec(pcb, request) -- spawn a new process executing a file
	continueproc(pcb)
	local env = request.env or scheduler.create_env()
	env.cwd = request.cwd or _G.cwd
	local normalized_path, fs = vfs.resolvePathFs(request.path)
	local fd = fs.open(normalized_path, "r")
	local fn = load(fs.read(fd, "a"), request.path, nil, env)
	if fn == nil then
		error("function loaded from file invalid")
	end

	fs.close(fd)

	if request.args then
		scheduler.new_process(function()
			fn(table.unpack(request.args))
		end, pcb.pid)
	else
		scheduler.new_process(fn, pcb.pid)
	end
end

------------------------------------------------------------------------------------
------------------------------------- FILE I/O -------------------------------------
------------------------------------------------------------------------------------

function calls.open(pcb, request)
	continueproc(pcb)
	local normalized_path, fs = vfs.resolvePathFs(request.path)
	return fs.open(pcb, normalized_path, request.mode)
end

function calls.close(pcb, request)
	continueproc(pcb)
	local fd = pcb.fds[request.fd]
	fd.fs.close(pcb, request.fd)
end

function calls.read(pcb, request)
	continueproc(pcb)
	local fd = pcb.fds[request.fd]
	return fd.fs.read(pcb, request.fd, request.count)
end

function calls.lseek(pcb, request)
	continueproc(pcb)
	local fd = pcb.fds[request.fd]
	return fd.fs.lseek(pcb, request.fd, request.offset, request.whence)
end

function calls.write(pcb, request)
	continueproc(pcb)
	local fd = pcb.fds[request.fd]
	fd.fs.write(pcb, request.fd, request.buffer)
end

function calls.fsync(pcb, request)
	continueproc(pcb)
	local fd = pcb.fds[request.fd]
	fd.fs.fsync(pcb, request.fd, request.buffer)
end

function calls.mkdir(pcb, request)
	continueproc(pcb)
	local normalized_path, fs = vfs.resolvePathFs(request.path)
	return fs.mkdir(pcb, normalized_path)
end

function calls.unlink(pcb, request)
	continueproc(pcb)
	local normalized_path, fs = vfs.resolvePathFs(request.path)
	return fs.unlink(pcb, normalized_path)
end

function calls.readdir(pcb, request)
	continueproc(pcb)
	local normalized_path, fs = vfs.resolvePathFs(request.path)
	return fs.readdir(pcb, normalized_path)
end

function calls.mount(pcb, request)
	continueproc(pcb)
	vfs.mountFromFile(pcb, request.mountpoint, request.fspath)
end

return calls
