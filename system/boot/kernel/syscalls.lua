local scheduler = ...

local SIGTERM = 1
local SIGKILL = 2

local function continue(pcb)
	pcb.state = "ready"
	scheduler.enqueue(pcb.pid)
end

return {
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
}
