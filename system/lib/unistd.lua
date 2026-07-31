local unistd = {}

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

	local modestr = getModestr(flags)
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
	return data, #data
end

function unistd.readall(fd)
	local data, count = "", 1000
	while count == 1000 do
		local newdata, newcount = unistd.read(fd, 1000)
		count = newcount
		data = data .. newdata
	end
	return data
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

-------------------------------------------------------------------------------------
------------------------------- FILE SYSTEM INTERFACE -------------------------------
-------------------------------------------------------------------------------------

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

return unistd
