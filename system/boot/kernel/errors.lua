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
		print(err)
		coroutine.yield({ type = "exit", code = -1 })
	end
	coroutine.yield({ type = "exit", code = 0 })
end

return wrap_process
