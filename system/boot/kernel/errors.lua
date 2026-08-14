local function traceback(err)
	local tbstr = debug.traceback(err, 3)

	-- remove the last three stack frames: global xpcall, errors.lua wrap_process, scheduler.lua
	local tracelist = {}
	for str in string.gmatch(tbstr, "([^\n]+)") do
		table.insert(tracelist, str)
	end

	tracelist[#tracelist] = nil
	tracelist[#tracelist] = nil
	tracelist[#tracelist] = nil
	return table.concat(tracelist, "\n")
end

local function wrap_process(fn)
	local ok, err = xpcall(fn, traceback)

	if not ok then
		local _, err2 = coroutine.yield({ type = "write", fd = 2, buffer = err }) -- write to the fd of STDERR
		if err2 then
			print(
				"an error occurred while reporting error of pid "
					.. coroutine.yield({ type = "getpid" })
					.. ": "
					.. err2
			)
		end
		coroutine.yield({ type = "exit", code = -1 })
	end
	coroutine.yield({ type = "exit", code = 0 })
end

return wrap_process
