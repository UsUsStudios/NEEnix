local stdlib = {}

local signal = require("signal")

stdlib.EXIT_SUCCESS = 0
stdlib.EXIT_FAILURE = 1

local atexit = nil

function stdlib.getenv(name)
	local var = coroutine.yield({ type = "getenv", name = name })
	if var then
		return var[1]
	end
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
end

function stdlib.atexit(f)
	atexit = f
end

function stdlib.exit(status)
	if atexit then
		atexit()
	end
	coroutine.yield({ type = "exit", code = status })
end

function stdlib.abort()
	signal.kill(coroutine.yield({ type = "getpid" }), signal.SIGABRT)
end

-- PSEUDORANDOM NUMBERS
stdlib.RAND_MAX = 2 ^ 32 - 1

local x = 1 -- for GNU rand()

function stdlib.rand()
	x = math.fmod(x * 1664525 + 1013904223, stdlib.RAND_MAX + 1)
	x = math.fmod(x ~ x >> 30, stdlib.RAND_MAX + 1)
	x = math.fmod(x * 1664525 + 1013904223, stdlib.RAND_MAX + 1)
	x = math.fmod(x ~ x >> 27, stdlib.RAND_MAX + 1)
	x = math.fmod(x * 1664525 + 1013904223, stdlib.RAND_MAX + 1)
	x = math.fmod(x ~ x >> 31, stdlib.RAND_MAX + 1)
	return x
end

function stdlib.srand(seed)
	x = seed
end

return stdlib
