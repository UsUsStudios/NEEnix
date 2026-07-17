local scheduler = {}
local syscalls = include("syscalls.lua")

scheduler.pid_counter = 0
scheduler.processes = {}

local run_queue = {}
local function enqueue(pid)
	table.insert(run_queue, pid)
end

function scheduler.new_process(fn, parent_pid)
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
		signals = {}, -- pending signal queue
		to_return = nil, -- return to the coroutine on next resume
	}
	scheduler.processes[pcb.pid] = pcb
	if parent_pid and scheduler.processes[parent_pid] then
		table.insert(scheduler.processes[parent_pid].children, pcb.pid)
	end
	enqueue(pcb.pid)
	return pcb
end

local function handle_syscall(pcb, req)
	for callName, call in pairs(syscalls) do
		if req.type == callName then
			pcb.to_return = call(req)
		end
	end
	if req == nil then
		pcb.state = "ready"
		enqueue(pcb.pid)
	else
		pcb.state = "ready"
		enqueue(pcb.pid)
	end
end

function scheduler.scheduler_tick()
	local now = chip.getTime()
	-- wake up sleeping processes
	for pid, pcb in pairs(scheduler.processes) do
		if pcb.state == "sleeping" and pcb.wake_at <= now then
			pcb.state = "ready"
			enqueue(pid)
		end
	end

	local queue = run_queue
	run_queue = {}

	for _, pid in ipairs(queue) do
		local pcb = scheduler.processes[pid]
		if pcb and pcb.state == "ready" then
			pcb.state = "running"
			local ok, req = coroutine.resume(pcb.co, pcb.to_return)

			if coroutine.status(pcb.co) == "dead" then
				pcb.state = "zombie"
				pcb.exit_code = ok and (req or 0) or -1
				for _, wpid in ipairs(pcb.waiters) do
					enqueue(wpid)
				end
			elseif not ok then
				-- uncaught error
				pcb.state = "zombie"
				pcb.exit_code = -1
			else
				handle_syscall()
			end
		end
	end
end

return scheduler
