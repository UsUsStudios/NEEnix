local unistd = require("unistd")

unistd.execvp("nterm")

coroutine.yield({ type = "exit", code = 0 })
