local scheduler = ...

return {
	["getpid"] = function(pcb, _)
		pcb.state = "ready"
		scheduler.enqueue(pcb.pid)

		return pcb.pid
	end,
	["sleep"] = function(pcb, request)
		pcb.state = "sleeping"
		pcb.wake_at = chip.getTime() + request.seconds
	end,
	["wait"] = function(pcb, request)
		local target = scheduler.processes[request.pid]
		if not target or target.state == "zombie" then
			pcb.state = "ready"
			scheduler.enqueue(pcb.pid) -- resume immediately next tick with result ready
		else
			table.insert(target.waiters, pcb.pid)
			pcb.state = "blocked"
		end
	end,
}
