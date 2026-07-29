local unistd = require("unistd")

--print(unistd.getcwd())
coroutine.yield({ type = "write", fd = 2, buffer = "hello" })
coroutine.yield({ type = "exit", code = 0 })
