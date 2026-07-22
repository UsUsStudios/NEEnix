-- Filesystem for /proc/ virtual file system

local function findMatchingProcess(path)
	if string.sub(path, 1, 6) == "kernel" then
		return "kernel", string.sub(path, 8, #path)
	end
	for i, pcb in pairs(scheduler.processes) do
		if string.sub(path, 1, #tostring(i)) == tostring(i) then
			return pcb, string.sub(path, #tostring(i) + 2, #path)
		end
	end
	return nil
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
}

local kernelprop = {
	status = function()
		local str = "" .. "Uptime:             " .. tostring(chip.getTime()) .. "s" .. "\nScheduler Ticks:  " .. tostring(
			scheduler.ticks
		) .. " ticks" .. "\nScheduler Yields: " .. tostring(scheduler.yields) .. " yields" .. "NEEnix Version:    " .. _G.NEENIXVERSION .. "\nLua Version:     " .. (not table.move and rawlen and bit32) and "Lua 5.2" or "unkown Lua version" .. "\nLoad:            " .. tostring(
			scheduler.load
		) .. " processes" .. "\nTick time:       " .. tostring(scheduler.ticktime) .. " seconds" .. "\nMounts:          " .. tostring(
			#vfs.mounts
		)
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
		if not table.move and rawlen and bit32 then
			return "NEEnix " .. _G.NEENIXVERSION .. ", Lua 5.2"
		else
			return "NEEnix " .. _G.NEENIXVERSION .. ", unknown Lua version"
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
	-- memoryusage = function()      -- unusable since collectgarbage is disabled D:
	--	return tostring(collectgarbage("count")) .. "kB"
	-- end,
}

local function generateBuffer(pcb, property)
	if pcb == "kernel" then
		return kernelprop[property]()
	end
	return properties[property](pcb)
end

local function create(fd_list, next_fd)
	local fs = {}

	function fs.stringrepr()
		return "procfs"
	end

	function fs.open(path, mode)
		if string.match(mode, "w") or string.match(mode, "a") or string.match(mode, "+") then
			error("cannot modify procfs")
		end

		local pcb, property = findMatchingProcess(path)

		fd_list[next_fd[1]] = {
			fs = fs,
			pcb = pcb,
			property = property,
			offset = 0,
			buffer = generateBuffer(pcb, property),
		}
		next_fd[1] = next_fd[1] + 1
		return next_fd[1] - 1
	end

	function fs.close(fd)
		fd_list[fd] = nil
	end

	function fs.read(fd, count)
		if fd_list[fd].offset == 0 then
			fd_list[fd].buffer = generateBuffer(fd_list[fd].pcb, fd_list[fd].property)
		end

		if count == "a" then
			count = #fd_list[fd].buffer
		end
		fd_list[fd].offset = fd_list[fd].offset + count

		return string.sub(fd_list[fd].buffer, fd_list[fd].offset - count, fd_list[fd].offset)
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
		error("cannot modify procfs")
	end

	function fs.mkdir()
		error("cannot modify procfs")
	end

	function fs.unlink()
		error("cannot modify procfs")
	end

	function fs.readdir(path)
		local pcb, property = findMatchingProcess(path)
		local dirlist = {}
		if pcb == nil then
			table.insert(dirlist, "kernel")
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

	return fs
end

return create
