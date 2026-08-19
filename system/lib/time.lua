local time = {}

local unistd = require("unistd")

function time.difftime(ending, begin)
	return ending - begin
end

function time.clock()
	local fd = unistd.open("/proc/self/cputime", unistd.O_RDONLY)
	local cputime = tonumber(unistd.read(fd, 100))
	unistd.close(fd)
	return cputime
end

return time
