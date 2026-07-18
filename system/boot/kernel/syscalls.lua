local scheduler = ...

local vfs = include("vfs.lua")()

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
		end
	end,

	-- ["spawn"] = function(pcb, request) end -- spawn a new process executing a file

	------------------------------------------------------------------------------------
	------------------------------------- FILE I/O -------------------------------------
	------------------------------------------------------------------------------------
	["open"] = function(pcb, request)
		continue(pcb)
		local normalized_path, fs = vfs.resolvePathFs(request.path)
		pcb.to_return = fs.open(normalized_path, request.mode)
	end,

	["close"] = function(pcb, request)
		continue(pcb)
		local fd = vfs.fd_list[request.fd]
		fd.fs.open(fd)
	end,

	["read"] = function(pcb, request)
		continue(pcb)
		local fd = vfs.fd_list[request.fd]
		pcb.to_return = fd.fs.read(fd, request.buffer, request.count)
	end,

	["lseek"] = function(pcb, request)
		continue(pcb)
		local fd = vfs.fd_list[request.fd]
		fd.fs.lseek(fd, request.offset, request.whence)
	end,

	["write"] = function(pcb, request)
		continue(pcb)
		local fd = vfs.fd_list[request.fd]
		fd.fs.lseek(fd, request.buffer)
	end,

	["mkdir"] = function(pcb, request)
		continue(pcb)
		local normalized_path, fs = vfs.resolvePathFs(request.path)
		fs.mkdir(normalized_path)
	end,

	["unlink"] = function(pcb, request)
		continue(pcb)
		local normalized_path, fs = vfs.resolvePathFs(request.path)
		fs.unlink(normalized_path)
	end,

	["rename"] = function(pcb, request)
		continue(pcb)
		local oldpath, oldfs = vfs.resolvePathFs(request.oldpath)
		local newpath, newfs = vfs.resolvePathFs(request.newpath)
		if oldfs == newfs then
			fs.rename(oldpath, newpath)
		end
	end,

	["readdir"] = function(pcb, request)
		continue(pcb)
		local normalized_path, fs = vfs.resolvePathFs(request.path)
		pcb.to_return = fs.readdir(normalized_path, request.mode)
	end,
}
