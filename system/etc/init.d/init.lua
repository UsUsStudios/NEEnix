local unistd = require("unistd")

local function read(proc)
	local fd = unistd.open("/proc/" .. proc .. "/status", unistd.O_RDONLY)
	print(unistd.readall(fd))
	unistd.close(fd)
end

read(1)
read(2)
read("kernel")

coroutine.yield()
coroutine.yield()
coroutine.yield()
coroutine.yield()
coroutine.yield()
coroutine.yield({ type = "exit", code = 0 })
