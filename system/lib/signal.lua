local signal = {}

signal.SIGKILL = 1 -- force kill: unblockable, unhandlable
signal.SIGTERM = 2 -- politely ask a program to terminate after cleanup
signal.SIGINT = 3 -- user types program interupt character: usually ctrl-C
signal.SIGHUP = 4 -- user's terminal disconnected
signal.SIGABRT = 5 -- user's terminal disconnected

signal.SIGCHILD = 6 -- a parent's child process terminated
signal.SIGUSR1 = 7 -- use however you want! very simple interprocess communication
signal.SIGUSR2 = 8 -- use however you want! very simple interprocess communication
signal.SIGWINCH = 9 -- the window or terminal dimensions changed

signal.SIG_IGN = function() end

function signal.signal(signum, action)
	coroutine.yield({ type = "signal", sig = signum, handler = action })
end

function signal.raise(signum)
	local pid = coroutine.yield({ type = "getpid" })
	coroutine.yield({ type = "kill", pid = pid, sig = signum })
end

function signal.kill(pid, signum)
	coroutine.yield({ type = "kill", pid = pid, sig = signum })
end

return signal
