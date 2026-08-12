local unistd = require("unistd")

local function printenv()
	for k, v in pairs(unistd.environ()) do
		print(k, v[1], v[2])
	end
end

printenv()

coroutine.yield()
coroutine.yield()
coroutine.yield()
coroutine.yield()
coroutine.yield()
coroutine.yield({ type = "exit", code = 0 })
