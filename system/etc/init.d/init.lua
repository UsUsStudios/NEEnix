local unistd = require("unistd")
local time = require("time")

local function readcputime()
	local fd = unistd.open("/proc/self/cputime", unistd.O_RDONLY)
	unistd.read(fd, 100)
	unistd.close(fd)
	fd = unistd.open("/proc/kernel/ips", unistd.O_RDONLY)
	unistd.read(fd, 100)
	unistd.close(fd)
end

while true do
	local start = time.clock()
	for _ = 0, 100 do
		readcputime()
	end
	print(time.clock() - start)
end
