local unistd = require("unistd")

print("hello, world!")

coroutine.yield({ type = "exit", code = 0 })
