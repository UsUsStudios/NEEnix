local scheduler = {}

local syscalls = include("syscalls.lua")(scheduler)

scheduler.pid_counter = 0
scheduler.processes = {}

local run_queue = {}
function scheduler.enqueue(pid)
	table.insert(run_queue, pid)
end

function scheduler.new_process(fn, parent_pid)
	if fn == nil then
		error("cannot start process with function nil")
	end

	scheduler.pid_counter = scheduler.pid_counter + 1
	local pcb = {
		pid = scheduler.pid_counter,
		ppid = parent_pid,
		co = coroutine.create(fn),
		state = "ready", -- ready | running | sleeping | blocked | zombie | dead
		wake_at = nil, -- for sleeping
		exit_code = nil,
		waiters = {}, -- pids blocked in wait() on this pid
		children = {},
		fds = {}, -- your open file table
		sighandlers = {},
		to_return = nil, -- return to the coroutine on next resume
		error = nil, -- error message to return to coroutine on next resume
	}
	scheduler.processes[pcb.pid] = pcb
	if parent_pid and scheduler.processes[parent_pid] then
		table.insert(scheduler.processes[parent_pid].children, pcb.pid)
	end
	scheduler.enqueue(pcb.pid)
	return pcb
end

local function handle_syscall(pcb, req)
	if req == nil then
		pcb.state = "ready"
		scheduler.enqueue(pcb.pid)
	else
		for callName, call in pairs(syscalls) do
			if req.type == callName then
				pcb.to_return = call(pcb, req)
				return
			end
		end
		pcb.state = "ready"
		scheduler.enqueue(pcb.pid)
	end
end

function scheduler.tick()
	local now = chip.getTime()
	-- wake up sleeping processes
	for pid, pcb in pairs(scheduler.processes) do
		if pcb.state == "sleeping" and pcb.wake_at <= now then
			pcb.state = "ready"
			scheduler.enqueue(pid)
		end
	end

	local queue = run_queue
	run_queue = {}

	for _, pid in ipairs(queue) do
		local pcb = scheduler.processes[pid]
		if pcb and pcb.state == "ready" then
			pcb.state = "running"
			local ok, req
			if pcb.error ~= nil then
				ok, req = coroutine.resume(pcb.co, nil, pcb.error)
			else
				ok, req = coroutine.resume(pcb.co, pcb.to_return)
			end
			pcb.to_return = nil

			if coroutine.status(pcb.co) == "dead" then
				pcb.state = "zombie"
				pcb.exit_code = ok and (req or 0) or -1
				for _, wpid in ipairs(pcb.waiters) do
					scheduler.processes[wpid].state = "ready"
					scheduler.enqueue(wpid)
				end
			elseif not ok then
				-- uncaught error
				pcb.state = "zombie"
				pcb.exit_code = -1
			else
				local syscall_ok, error = pcall(handle_syscall, pcb, req)
				if not syscall_ok then
					pcb.error = error
				end
			end
		end
	end
end

function scheduler.printProcesses()
	print("PID", "state", "wake_at", "exit_code")
	for _, pcb in pairs(scheduler.processes) do
		print(pcb.pid, pcb.state, pcb.wake_at, pcb.exit_code)
	end
end

return scheduler
