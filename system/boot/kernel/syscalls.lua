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
}
