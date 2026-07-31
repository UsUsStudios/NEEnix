local unistd = require("unistd")
local dirent = require("dirent")

coroutine.yield()
coroutine.yield()
coroutine.yield()
coroutine.yield()
coroutine.yield()
coroutine.yield({ type = "exit", code = 0 })
