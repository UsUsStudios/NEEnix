-- Filesystem for /proc/ virtual file system

local function findMatchingProcess(path)
	if string.sub(path, 1, 6) == "kernel" then
		return "kernel", string.sub(path, 8, #path)
	end

	if string.sub(path, 1, #"self") == "self" then
		return "self", string.sub(path, #"self" + 2, #path)
	end
	for i, pcb in pairs(scheduler.processes) do
		if string.sub(path, 1, #tostring(i)) == tostring(i) then
			return pcb, string.sub(path, #tostring(i) + 2, #path)
		end
	end
	return nil
end

local function formatMemory(bytes)
	local units = {
		"B",
		"KiB",
		"MiB",
		"GiB",
		"TiB",
	}
	local prefix = 1
	local value = bytes
	while value > 1024 do
		value /= 1024
		prefix += 1
	end
	value = math.floor(value * 100 + 0.5) / 100
	return value .. " " .. units[prefix]
end

local properties = {
	status = function(pcb)
		local str = ""
			.. "PID:            "
			.. tostring(pcb.pid)
			.. "\nPPID:         "
			.. tostring(pcb.ppid)
			.. "\nState:        "
			.. tostring(pcb.state)
			.. "\nCo. status:   "
			.. tostring(coroutine.status(pcb.co))
			.. "\nWaking at:    "
			.. tostring(pcb.wake_at)
			.. "\nExit code:    "
			.. tostring(pcb.exit_code)
			.. "\nWaiters:      "
			.. tostring(#pcb.waiters)
			.. "\nChildren:     "
			.. tostring(#pcb.children)
			.. "\nOpen FDs:     "
			.. tostring(#pcb.fds)
			.. "\nSighandlers:  "
			.. tostring(#pcb.sighandlers)
			.. "\nMemory usage:  "
			.. formatMemory(coroutine.memoryused(pcb.co, true))
		return str
	end,
	pid = function(pcb)
		return tostring(pcb.pid)
	end,
	ppid = function(pcb)
		return tostring(pcb.ppid)
	end,
	state = function(pcb)
		return tostring(pcb.state)
	end,
	costatus = function(pcb)
		return tostring(coroutine.status(pcb.co))
	end,
	wake_at = function(pcb)
		return tostring(pcb.wake_at)
	end,
	exit_code = function(pcb)
		return tostring(pcb.exit_code)
	end,
	yields = function(pcb)
		return tostring(pcb.yields)
	end,
	waiters = function(pcb)
		local str = ""
		for _, v in ipairs(pcb.waiters) do
			str = str .. v
		end
		return str
	end,
	children = function(pcb)
		local str = ""
		for _, v in ipairs(pcb.children) do
			str = str .. v
		end
		return str
	end,
	fds = function(pcb)
		local str = ""
		for fd, path in pairs(pcb.children) do
			str = str .. fd .. ": " .. path
		end
		return str
	end,
	sighandlers = function(pcb)
		local str = ""
		for _, v in ipairs(pcb.sighandlers) do
			str = str .. v .. "\n"
		end
		return str
	end,
	memoryused = function(pcb)
		return coroutine.memoryused(pcb.co, true)
	end,
}

local kernelprop = {
	status = function()
		local kernelmemory = coroutine.memoryused(0, true)
		local totalmemory = kernelmemory -- in bytes
		for _, pcb in ipairs(scheduler.processes) do
			totalmemory += coroutine.memoryused(pcb.co, true)
		end

		local str = ""
			.. "Uptime:             "
			.. tostring(chip.getTime())
			.. "s\nScheduler Ticks:  "
			.. tostring(scheduler.ticks)
			.. " ticks\nScheduler Yields: "
			.. tostring(scheduler.yields)
			.. " yields\nNEEnix Version:   "
			.. _G.NEENIXVERSION
			.. "\nLua Version:      "
			.. (_VERSION or "unkown lua version, probably 5.2")
			.. "\nLoad:             "
			.. tostring(scheduler.load)
			.. " processes\nTick time:        "
			.. tostring(scheduler.ticktime)
			.. " seconds\nMounts:           "
			.. tostring(#vfs.mounts)
			.. "\nKernel mem used:  "
			.. formatMemory(kernelmemory)
			.. "\nTotal mem used:   "
			.. formatMemory(totalmemory)
		return str
	end,
	uptime = function()
		return tostring(chip.getTime())
	end,
	schedulerticks = function()
		return tostring(scheduler.ticks)
	end,
	scheduleryields = function()
		return tostring(scheduler.yields)
	end,
	version = function()
		if not _VERSION then
			return "NEEnix " .. _G.NEENIXVERSION .. ", unkown Lua version, likely 5.2"
		else
			return "NEEnix " .. _G.NEENIXVERSION .. ", " .. _VERSION
		end
	end,
	load = function()
		return tostring(scheduler.load)
	end,
	ticktime = function()
		return tostring(scheduler.ticktime)
	end,
	mounts = function()
		local str = ""
		for _, mount in ipairs(vfs.mounts) do -- doing it like this so the list is in ascending length order
			str = mount.fs.stringrepr() .. " at " .. mount.path .. "\n" .. str
		end
		return str
	end,
	totalmemoryused = function()
		local sum = coroutine.memoryused(0, true)
		for _, pcb in ipairs(scheduler.processes) do
			sum += coroutine.memoryused(pcb.co, true)
		end
		return sum
	end,
	kernelmemoryused = function()
		return coroutine.memoryused(0, true)
	end,
}

local function generateBuffer(pcb, property)
	local ok, result
	if pcb == "kernel" then
		ok, result = pcall(kernelprop[property])
	else
		ok, result = pcall(properties[property], pcb)
	end
	if ok then
		return result
	end
	error("unable to generate buffer: " .. result)
end

local function create(next_fd)
	local fs = {}

	function fs.stringrepr()
		return "procfs"
	end

	function fs.open(pcb, path, mode)
		if string.match(mode, "w") or string.match(mode, "a") or string.match(mode, "+") then
			error("cannot modify procfs")
		end

		local pathpcb, property = findMatchingProcess(path)

		local fd = next_fd()
		pcb.fds[fd] = {
			fs = fs,
			pcb = pathpcb,
			property = property,
			offset = 0,
			buffer = generateBuffer(pathpcb, property),
		}
		return fd
	end

	function fs.close(pcb, fd)
		pcb.fds[fd] = nil
	end

	function fs.read(pcb, fd, count)
		if pcb.fds[fd].offset == 0 then
			pcb.fds[fd].buffer = generateBuffer(pcb.fds[fd].pcb, pcb.fds[fd].property)
		end

		if count == "a" then
			count = #pcb.fds[fd].buffer
		end
		pcb.fds[fd].offset = pcb.fds[fd].offset + count

		return string.sub(pcb.fds[fd].buffer, pcb.fds[fd].offset - count, pcb.fds[fd].offset)
	end

	function fs.lseek(fd, offset, whence)
		if whence == "set" then
			fd.offset = offset
		elseif whence == "cur" then
			fd.offset = fd.offset + offset
		elseif whence == "end" then
			fd.offset = #fd.buffer + offset
		else
			error("invalid whence: " .. whence)
		end
		return fd.offset
	end

	function fs.write()
		error("invalid operation on " .. fs.stringrepr())
	end

	function fs.fsync()
		error("invalid operation on " .. fs.stringrepr())
	end

	function fs.mkdir()
		error("invalid operation on " .. fs.stringrepr())
	end

	function fs.unlink()
		error("invalid operation on " .. fs.stringrepr())
	end

	function fs.readdir(_, path)
		local pcb, property = findMatchingProcess(path)
		local dirlist = {}
		if pcb == nil then
			table.insert(dirlist, "kernel")
			table.insert(dirlist, "self")
			for pid, _ in pairs(scheduler.processes) do
				table.insert(dirlist, tostring(pid))
			end
		elseif property ~= "" then
			error("not a directory")
		else
			if pcb == "kernel" then
				for propertyName, _ in pairs(kernelprop) do
					table.insert(dirlist, propertyName)
				end
			else
				for propertyName, _ in pairs(properties) do
					table.insert(dirlist, propertyName)
				end
			end
		end
		return dirlist
	end

	function fs.isFile(_, path)
		local pcb, property = findMatchingProcess(path)
		if pcb == nil then
			return false
		elseif property ~= "" then
			return true
		end
		return false
	end

	return fs
end

return create
