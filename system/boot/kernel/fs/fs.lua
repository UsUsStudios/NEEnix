-- The function signatures for any fs implementation

local function create(fd_list, next_fd)
	local fs = {}

	function fs.stringrepr()
		return
	end

	function fs.open(path, mode)
		return
	end

	function fs.close(fd)
		return
	end

	function fs.read(fd, buffer, count)
		return
	end

	function fs.lseek(fd, offset, whence)
		return
	end

	function fs.write(fd, buffer)
		return
	end

	function fs.mkdir(path)
		return
	end

	function fs.unlink(path)
		return
	end

	function fs.rename(oldpath, newpath)
		return
	end

	function fs.readdir(path)
		return
	end

	return fs
end

return create
