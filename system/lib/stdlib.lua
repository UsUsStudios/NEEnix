local stdlib = {}

function stdlib.getenv(name)
	local var = coroutine.yield({ type = "getenv", name = name })
	if var then
		return var[1]
	end
	return
end

function stdlib.setenv(name, value, replace)
	local prev = coroutine.yield({ type = "getenv" })
	if replace or prev then
		coroutine.yield({ type = "setenv", name = name, value = value })
	end
end

function stdlib.unsetenv(name)
	coroutine.yield({ type = "setenv", name = name, value = nil })
end

function stdlib.export(name)
	local prev = coroutine.yield({ type = "getenv" })
	if not prev then
		return error("environment variable undefined")
	end
	coroutine.yield({ type = "setenv", name = name, value = prev[1], exported = false })
	return
end

return stdlib
