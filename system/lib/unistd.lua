local unistd = {}

local stdlib = require("stdlib")

local function resolveFilename(filename)
	if filename:sub(1, 1) ~= "/" then
		filename = _G.cwd .. filename
	end

	return filename
end

-------------------------------------------------------------------------------------
-------------------------------- FILE I/O PRIMITIVES --------------------------------
-------------------------------------------------------------------------------------

unistd.O_RDONLY = 1
unistd.O_WRONLY = 2
unistd.O_RDWR = 4
unistd.O_CREAT = 8
unistd.O_TRUNC = 16
unistd.O_APPEND = 32
unistd.O_BYTES = 64

unistd.SEEK_SET = 0
unistd.SEEK_CUR = 1
unistd.SEEK_END = 2

local function getModestr(flags)
	if flags == unistd.O_RDONLY then
		return "r"
	elseif flags == unistd.O_RDONLY | unistd.O_BYTES then
		return "rb"
	elseif flags == unistd.O_WRONLY | unistd.O_TRUNC then
		return "w"
	elseif flags == unistd.O_WRONLY | unistd.O_CREAT | unistd.O_TRUNC | unistd.O_BYTES then
		return "wb"
	elseif flags == unistd.O_WRONLY | unistd.O_CREAT | unistd.O_APPEND then
		return "a"
	elseif flags == unistd.O_WRONLY | unistd.O_CREAT | unistd.O_APPEND | unistd.O_BYTES then
		return "ab"
	elseif flags == unistd.O_RDWR then
		return "r+"
	elseif flags == unistd.O_RDWR | unistd.O_BYTES then
		return "rb+"
	elseif flags == unistd.O_RDWR | unistd.O_TRUNC then
		return "w+"
	elseif flags == unistd.O_RDWR | unistd.O_CREAT | unistd.O_TRUNC | unistd.O_BYTES then
		return "wb+"
	elseif flags == unistd.O_RDWR | unistd.O_CREAT | unistd.O_APPEND then
		return "a+"
	elseif flags == unistd.O_RDWR | unistd.O_CREAT | unistd.O_APPEND | unistd.O_BYTES then
		return "ab+"
	elseif flags & unistd.O_RDONLY ~= 0 and flags & unistd.O_WRONLY ~= 0 then
		error("invalid flags: RDONLY + WRONLY should be represented as RDWR", 3)
	elseif flags & unistd.O_APPEND ~= 0 and flags & unistd.O_TRUNC ~= 0 then
		error("invalid flags: can only have one of APPEND and TRUNC", 3)
	else
		error(
			"invalid flags due to NeetComputers API limitations, please consult files API for available file modes",
			3
		)
	end
end

function unistd.open(filename, flags)
	filename = resolveFilename(filename)
	if not (filename and flags) then
		error("invalid arguments", 2)
	end

	local modestr
	if type(flags) == "number" then
		modestr = getModestr(flags)
	else
		modestr = flags
	end

	local fd, err = coroutine.yield({ type = "open", path = filename, mode = modestr })
	if (not fd) or err then
		error(err, 2)
	end
	return fd
end

function unistd.close(fd)
	local _, err = coroutine.yield({ type = "close", fd = fd })
	if err then
		error(err, 2)
	end
end

function unistd.read(fd, count)
	local data, err = coroutine.yield({ type = "read", fd = fd, count = count })
	if err then
		error(err, 2)
	end
	return data
end

function unistd.readall(fd)
	local buffer, count = { "" }, 1000
	while count == 1000 do
		local data = unistd.read(fd, 1000)
		count = #data
		table.insert(buffer, data)
	end
	return table.concat(buffer, "")
end

function unistd.write(fd, buffer)
	if type(buffer) ~= "string" then
		error("cannot write anything but string to file")
	end
	local _, err = coroutine.yield({ type = "write", fd = fd, buffer = buffer })
	if err then
		error(err, 2)
	end
end

function unistd.fsync(fd)
	local _, err = coroutine.yield({ type = "fsync", fd = fd })
	if err then
		error(err, 2)
	end
end

function unistd.lseek(fd, offset, whence)
	local whencestr
	if whence == unistd.SEEK_SET then
		whencestr = "set"
	elseif whence == unistd.SEEK_CUR then
		whencestr = "cur"
	elseif whence == unistd.SEEK_END then
		whencestr = "end"
	else
		error("invalid whence", 2)
	end
	local location, err = coroutine.yield({ type = "lseek", fd = fd, offset = offset, whence = whencestr })
	if err then
		error(err, 2)
	end
	return location
end

function unistd.pipe()
	return table.unpack(unistd.open("/dev/popen", 1))
end

--------------------------------------------------------------------------------------
----------------------------- OPERATING SYSTEM INTERFACE -----------------------------
--------------------------------------------------------------------------------------

function unistd.getcwd()
	return _G.cwd
end

function unistd.chdir(filename)
	filename = resolveFilename(filename)
	if filename:sub(#filename, #filename) ~= "/" then
		filename = filename .. "/"
	end
	_G.cwd = filename
end

function unistd.remove(filename)
	filename = resolveFilename(filename)
	local _, err = coroutine.yield({ type = "unlink", path = filename })
	if err then
		error(err, 2)
	end
end

function unistd.rename(oldname, newname)
	oldname = resolveFilename(oldname)
	newname = resolveFilename(newname)
	local fd = unistd.open(oldname, unistd.O_RDONLY)
	local data = unistd.readall(fd)
	unistd.close(fd)
	unistd.remove(oldname)

	fd = unistd.open(newname, unistd.O_WRONLY | unistd.O_CREAT | unistd.O_TRUNC | unistd.O_BYTES)
	unistd.write(fd, data)
	unistd.close(fd)
end

function unistd.mkdir(dirname)
	dirname = resolveFilename(dirname)
	local _, err = coroutine.yield({ type = "mkdir", path = dirname })
	if err then
		error(err, 2)
	end
end

function unistd.environ()
	local env = coroutine.yield({ type = "environ" })
	return env
end

--- getopt(3)-like functionality for Lua 5.1 and later, https://github.com/skeeto/getopt-lua/blob/master/getopt.lua
-- This is free and unencumbered software released into the public domain.

--- getopt(argv, optstring [, nonoptions])
--
-- Returns a closure suitable for "for ... in" loops. On each call the
-- closure returns the next (option, optarg). For unknown options, it
-- returns ('?', option). When a required optarg is missing, it returns
-- (':', option). It's reasonable to continue parsing after errors.
-- Returns nil when done.
--
-- The optstring follows the same format as POSIX getopt(3). However,
-- this function will never print output on its own.
--
-- Non-option arguments are accumulated, in order, in the optional
-- "nonoptions" table. If a "--" argument is encountered, appends the
-- remaining arguments to the nonoptions table and returns nil.
--
-- The input argv table is left unmodified.
function unistd.getopt(argv, optstring, nonoptions)
	local optind = 1
	local optpos = 2
	nonoptions = nonoptions or {}
	return function()
		while true do
			local arg = argv[optind]
			if arg == nil then
				return nil
			elseif arg == "--" then
				for i = optind + 1, #argv do
					table.insert(nonoptions, argv[i])
				end
				return nil
			elseif arg:sub(1, 1) == "-" then
				local opt = arg:sub(optpos, optpos)
				local start, stop = optstring:find(opt .. ":?")
				if not start then
					optind = optind + 1
					optpos = 2
					return "?", opt
				elseif stop > start and #arg > optpos then
					local optarg = arg:sub(optpos + 1)
					optind = optind + 1
					optpos = 2
					return opt, optarg
				elseif stop > start then
					local optarg = argv[optind + 1]
					optind = optind + 2
					optpos = 2
					if optarg == nil then
						return ":", opt
					end
					return opt, optarg
				else
					optpos = optpos + 1
					if optpos > #arg then
						optind = optind + 1
						optpos = 2
					end
					return opt, nil
				end
			else
				optind = optind + 1
				table.insert(nonoptions, arg)
			end
		end
	end
end

function unistd.execv(filename, argv, cwd)
	if cwd:sub(#cwd, #cwd) ~= "/" then
		cwd = cwd .. "/"
	end

	local pid, err = coroutine.yield({ type = "exec", path = filename, args = argv, cwd = cwd })
	if err then
		error(err)
	end
	return pid
end

function unistd.execvp(filename, argv)
	local function test(path, cwd)
		local isfile, err = coroutine.yield({ type = "isfile", path = path })
		if err then
			error(err)
		end
		if isfile then
			return unistd.execv(path, argv, cwd)
		end
	end
	if filename:sub(1, 1) == "/" then
		return unistd.execv(filename, argv)
	else
		filename = "/" .. filename
	end

	for path in string.gmatch(stdlib.getenv("PATH"), "([^;]+)") do
		local result = test(path .. filename, path)
		if result then
			return result
		end

		result = test(path .. filename .. "/init.lua", path .. filename)
		if result then
			return result
		end
	end
	error("file not found in PATH")
end

function unistd.waitpid(pid)
	return coroutine.yield({ type = "wait", pid = pid })
end

return unistd
