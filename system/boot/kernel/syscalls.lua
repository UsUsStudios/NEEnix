-- fetch the signal list from signal.lua
-- calling a library directly from the kernel like this is a little sketchy ngl

local signal
do
	local handle = files.open("system:/lib/signal.lua")
	local data = handle.read("a")
	handle.close()
	local f, err = load(data, "/lib/signal.lua")
	if err or not f then
		error(err)
	end
	signal = f()
end

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

function calls.getenv(pcb, request) -- return the value and exported of environment variable request.name
	continueproc(pcb)
	return pcb.env[request.name]
end

function calls.environ(pcb, _) -- return the environment list
	continueproc(pcb)
	return pcb.env
end

function calls.setenv(pcb, request) -- sets the value and exported state of an environment variable, or unsets the variable if request.value is nil
	continueproc(pcb)
	if request.value == nil then
		pcb.env[request.name] = nil
	else
		if not pcb.env[request.name] then
			pcb.env[request.name] = {}
		end
		pcb.env[request.name][1] = request.value
		pcb.env[request.name][2] = request.exported or false
	end
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
	scheduler.dead(pcb)
end

function calls.kill(pcb, request) -- send a signal to the process
	continueproc(pcb)

	local proc = scheduler.processes[request.pid]
	if request.sig == signal.SIGKILL then
		proc.state = "dead"
		pcb.exit_code = 0
		scheduler.dead(pcb)
		return
	end
	table.insert(proc.sigs, request.sig)
end

function calls.signal(pcb, request) -- set a signal handler to this process
	continueproc(pcb)

	if request.sig ~= signal.SIGKILL then
		pcb.sighandlers[request.sig] = request.handler
	else
		error("cannot set a signal handler for SIGKILL")
	end
end

function calls.spawn(pcb, request) -- spawn a new process executing a function
	continueproc(pcb)

	-- inherit STDIN, STDOUT and STDERR
	local fds = {
		[0] = pcb.fds[request.stdin] or pcb.fds[0],
		[1] = pcb.fds[request.stdout] or pcb.fds[1],
		[2] = pcb.fds[request.stderr] or pcb.fds[2],
	}

	if request.args then
		return scheduler.new_process(function()
			request.fn(table.unpack(request.args))
		end, pcb.pid, fds).pid -- return pid
	end
	return scheduler.new_process(request.fn, pcb.pid, fds).pid -- return pid
end

function calls.exec(pcb, request) -- spawn a new process executing a file
	continueproc(pcb)

	local env = request.env or scheduler.create_env()
	env.cwd = request.cwd or cwd

	local normalized_path, fs = vfs.resolvePathFs(request.path)
	local fd = fs.open(pcb, normalized_path, "r")
	local fn = load(fs.read(pcb, fd, "a"), request.path, nil, env)
	if fn == nil then
		error("function loaded from file invalid")
	end

	fs.close(pcb, fd)

	request.fn = fn -- to pass onto calls.spawn
	return calls.spawn(pcb, request)
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
	if request.fd == 0 then
		error("cannot close STDIN")
	elseif request.fd == 1 then
		error("cannot close STDOUT")
	elseif request.fd == 2 then
		error("cannot close STDERR")
	end
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
	return fd.fs.write(pcb, request.fd, request.buffer)
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

function calls.isfile(pcb, request)
	continueproc(pcb)
	local normalized_path, fs = vfs.resolvePathFs(request.path)
	return fs.isFile(pcb, normalized_path)
end

function calls.mount(pcb, request)
	continueproc(pcb)
	vfs.mountFromFile(pcb, request.mountpoint, request.fspath)
end

return calls
