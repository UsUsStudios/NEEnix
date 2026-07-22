local SIGTERM = 1
local SIGKILL = 2

local function continue(pcb)
	pcb.state = "ready"
	scheduler.enqueue(pcb.pid)
end

return {
	------------------------------------------------------------------------------------
	--------------------------------- PROCESS HANDLING ---------------------------------
	------------------------------------------------------------------------------------

	["getpid"] = function(pcb, _) -- return the PID of the process that called
		continue(pcb)
		return pcb.pid
	end,

	["sleep"] = function(pcb, request) -- wait a given number of seconds
		pcb.state = "sleeping"
		pcb.wake_at = chip.getTime() + request.seconds
	end,

	["wait"] = function(pcb, request) -- wait until another process finishes executing
		local target = scheduler.processes[request.pid]
		if not target or target.state == "zombie" then
			continue(pcb)
		else
			table.insert(target.waiters, pcb.pid)
			pcb.state = "blocked"
		end
	end,

	["exit"] = function(pcb, request) -- end the execution of this process
		pcb.state = "dead"
		pcb.exit_code = request.code
	end,

	["kill"] = function(pcb, request) -- send a signal to the process
		continue(pcb)
		local proc = scheduler.processes[request.pid]
		if proc.sighandlers[request.sig] ~= nil then
			proc.sighandlers[request.sig](request.sig)
		else
			if request.sig == SIGTERM or request.sig == SIGKILL then
				proc.state = "dead"
				pcb.exit_code = 0
			end
		end
	end,

	["signal"] = function(pcb, request) -- set a signal handler to this process
		continue(pcb)

		if request.sig ~= SIGKILL then
			pcb.sighandlers[request.sig] = request.handler
		else
			error("cannot set a signal handler for SIGKILL")
		end
	end,

	["spawn"] = function(pcb, request) -- spawn a new process executing a file
		continue(pcb)
		local env = request.env or scheduler.create_env()
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
	end,

	------------------------------------------------------------------------------------
	------------------------------------- FILE I/O -------------------------------------
	------------------------------------------------------------------------------------

	["open"] = function(pcb, request)
		continue(pcb)
		local normalized_path, fs = vfs.resolvePathFs(request.path)
		local fd = fs.open(normalized_path, request.mode)
		pcb.fds[fd] = request.path
		return fd
	end,

	["close"] = function(pcb, request)
		continue(pcb)
		local fd = vfs.fd_list[request.fd]
		pcb.fds[request.fd] = nil
		fd.fs.close(request.fd)
	end,

	["read"] = function(pcb, request)
		continue(pcb)
		local fd = vfs.fd_list[request.fd]
		return fd.fs.read(request.fd, request.count)
	end,

	["lseek"] = function(pcb, request)
		continue(pcb)
		local fd = vfs.fd_list[request.fd]
		return fd.fs.lseek(request.fd, request.offset, request.whence)
	end,

	["write"] = function(pcb, request)
		continue(pcb)
		local fd = vfs.fd_list[request.fd]
		fd.fs.write(request.fd, request.buffer)
	end,

	["mkdir"] = function(pcb, request)
		continue(pcb)
		local normalized_path, fs = vfs.resolvePathFs(request.path)
		return fs.mkdir(normalized_path)
	end,

	["unlink"] = function(pcb, request)
		continue(pcb)
		local normalized_path, fs = vfs.resolvePathFs(request.path)
		return fs.unlink(normalized_path)
	end,

	["readdir"] = function(pcb, request)
		continue(pcb)
		local normalized_path, fs = vfs.resolvePathFs(request.path)
		return fs.readdir(normalized_path)
	end,

	["mount"] = function(pcb, request)
		continue(pcb)
		vfs.mountFromFile(request.mountpoint, request.fspath)
	end,
}
