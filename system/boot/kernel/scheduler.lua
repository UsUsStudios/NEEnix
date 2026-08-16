_G.scheduler = {}

local DEBUG_PRINT = false

local syscalls = _G.include("syscalls.lua")()
local wrap_process = _G.include("errors.lua")()

local signal
do
	local handle = _G.files.open("system:/lib/signal.lua")
	local data = handle.read("a")
	handle.close()
	local f, err = _G.load(data, "/lib/signal.lua")
	if err or not f then
		error(err)
	end
	signal = f()
end

_G.scheduler.pid_counter = 0
_G.scheduler.processes = {}
_G.scheduler.ticks = 0
_G.scheduler.yields = 0
_G.scheduler.load = 0
_G.scheduler.ticktime = 0

local run_queue = {}

local function get_sighandlers()
	local function die(sig)
		coroutine.yield({ type = "exit", code = sig })
	end
	local function ignore() end
	return {
		[signal.SIGKILL] = die,
		[signal.SIGTERM] = die,
		[signal.SIGINT] = die,
		[signal.SIGHUP] = die,
		[signal.SIGCHILD] = ignore,
		[signal.SIGUSR1] = ignore,
		[signal.SIGUSR2] = ignore,
		[signal.SIGWINCH] = ignore,
	}
end

function _G.scheduler.enqueue(pid)
	table.insert(run_queue, pid)
end

local function deep_copy(obj, seen)
	if type(obj) ~= "table" then
		return obj
	end

	seen = seen or {}

	if seen[obj] then
		return seen[obj]
	end

	local copy = {}
	seen[obj] = copy

	for k, v in pairs(obj) do
		copy[deep_copy(k, seen)] = deep_copy(v, seen)
	end
	return copy
end

function _G.scheduler.create_env()
	local env = deep_copy(_G)
	env.chip = nil
	env.headsup = nil
	env.event = nil
	env.io = nil
	env.internet = nil
	env.crypto = nil
	env.debug = nil
	env.scheduler = nil
	env.vfs = nil
	env.NEENIXVERSION = nil
	env.files = nil
	env.screen = nil
	env.include = nil
	env._VERSION = nil

	if not DEBUG_PRINT then
		function env.print(...)
			local strbuf = {}
			for _, v in ipairs({ ... }) do
				strbuf[#strbuf + 1] = tostring(v)
				strbuf[#strbuf + 1] = "    "
			end
			strbuf[#strbuf + 1] = "\n"
			local _, err = coroutine.yield({ type = "write", fd = 1, buffer = table.concat(strbuf) }) -- write to the fd of STDOUT
			if err then
				error(err)
			end
		end
	end

	env.package, env.require, env.loadfile = _G.include("loadfile-require.lua", env)()

	return env
end

function _G.scheduler.new_process(fn, parent_pid, fds)
	if fn == nil then
		error("cannot start process with function nil")
	end

	local env = {}
	if parent_pid then
		for name, value in pairs(_G.scheduler.processes[parent_pid].env) do
			if value[2] then -- if it is exported
				env[name] = { value[1], value[2] }
			end
		end
	else
		-- get default environment variables from /etc/environment
		local environment = "system:/etc/environment/"
		for _, child in ipairs(_G.files.getChildren(environment, 0)) do
			if _G.files.isFile(environment .. child) then
				local handle = _G.files.open(environment .. child, "r")
				local data = handle.read("a")
				env[child] = { data:sub(1, #data - 1), true }
				handle.close()
			end
		end
	end

	_G.scheduler.pid_counter = _G.scheduler.pid_counter + 1
	local pcb = {
		pid = _G.scheduler.pid_counter,
		ppid = parent_pid,
		state = "ready", -- ready | running | sleeping | blocked | zombie | dead
		wake_at = nil, -- for sleeping
		exit_code = nil,
		waiters = {}, -- pids blocked in wait() on this pid
		children = {},
		-- fds: open file table - key: fd, value: table
		--                     - must contain key "fs" with value of fs instance that owns fd
		--                     - rest of table is up to fs to define
		fds = fds or {},
		sighandlers = get_sighandlers(),
		sigs = {}, -- recieved signals, besides SIGKILL because it kills instantly
		to_return = nil, -- return to the coroutine on next resume
		error = nil, -- error message to return to coroutine on next resume
		yields = 0, -- how many yields have been processed by the scheduler
		env = env, -- environment variables - key: name, value: {value, exported (bool)}
	}
	pcb.co = coroutine.create(function()
		wrap_process(fn, pcb)
	end)

	_G.debug.sethook(pcb.co, function()
		for i, sig in ipairs(pcb.sigs) do
			if pcb.sighandlers[sig] then
				pcb.sighandlers[sig](sig) -- run the sighandler
			end
			table.remove(pcb.sigs, i)
		end
		-- TODO: readd preemeption?
		-- coroutine.yield()
	end, "", 1500)

	_G.scheduler.processes[pcb.pid] = pcb
	if parent_pid and _G.scheduler.processes[parent_pid] then
		table.insert(_G.scheduler.processes[parent_pid].children, pcb.pid)
	end
	_G.scheduler.enqueue(pcb.pid)

	return pcb
end

local function handle_syscall(pcb, req)
	if req == nil then
		pcb.state = "ready"
		_G.scheduler.enqueue(pcb.pid)
	else
		for callName, call in pairs(syscalls) do
			if req.type == callName then
				pcb.to_return = call(pcb, req)
				return
			end
		end
		pcb.state = "ready"
		_G.scheduler.enqueue(pcb.pid)
	end
end

function _G.scheduler.dead(pcb, req)
	print("Process with PID " .. pcb.pid .. " ended with exit code " .. pcb.exit_code)
	if type(req) ~= "table" and req then
		print("    error of exit: " .. req)
	end

	-- wake up waiting processors and return the exit code to them
	for _, wpid in ipairs(pcb.waiters) do
		_G.scheduler.processes[wpid].state = "ready"
		_G.scheduler.enqueue(wpid)
		_G.scheduler.processes[wpid].to_return = pcb.exit_code
	end

	for _, fd in ipairs(pcb.fds) do
		local syscall_ok, err = xpcall(handle_syscall, debug.traceback, pcb, { type = "close", fd = fd })
		pcb.state = "dead"

		if not syscall_ok and err then
			err = "error in syscall: " .. err
			pcb.error = err
		end
	end

	if pcb.ppid then
		table.insert(_G.scheduler.processes[pcb.ppid].sigs, signal.SIGCHILD) -- send sigchild signal to parent
	end
end

function _G.scheduler.tick()
	_G.scheduler.ticks = _G.scheduler.ticks + 1
	local now = _G.chip.getTime()

	-- wake up sleeping processes
	for pid, pcb in pairs(_G.scheduler.processes) do
		if pcb.state == "sleeping" and pcb.wake_at <= now then
			pcb.state = "ready"
			_G.scheduler.enqueue(pid)
		end
	end

	local queue = run_queue
	_G.scheduler.load = #queue
	run_queue = {}

	for _, pid in ipairs(queue) do
		local pcb = _G.scheduler.processes[pid]
		if pcb and pcb.state == "ready" then
			_G.scheduler.yields = _G.scheduler.yields + 1
			pcb.yields = pcb.yields + 1
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
				pcb.exit_code = pcb.exit_code or 0

				_G.scheduler.dead(pcb, req)
			elseif not ok then
				-- uncaught error
				pcb.state = "zombie"
				pcb.exit_code = -1

				_G.scheduler.dead(pcb, req)
			else
				local syscall_ok, err = xpcall(handle_syscall, debug.traceback, pcb, req)
				if not syscall_ok and err then
					err = "syscall error: " .. err
					pcb.error = err
				end
			end
		end
	end
	_G.scheduler.ticktime = _G.chip.getTime() - now
end

function _G.scheduler.printProcesses()
	print("PID", "state", "wake_at", "exit_code")
	for _, pcb in pairs(_G.scheduler.processes) do
		print(pcb.pid, pcb.state, pcb.wake_at, pcb.exit_code)
	end
end
