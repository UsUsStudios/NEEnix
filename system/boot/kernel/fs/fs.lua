-- The function signatures for any fs implementation

local function create(get_fd)
	local fs = {}

	function fs.stringrepr()
		return
	end

	function fs.open(pcb, path, mode)
		return
	end

	function fs.close(pcb, fd)
		return
	end

	function fs.read(pcb, fd, count)
		return
	end

	function fs.lseek(pcb, fd, offset, whence)
		return
	end

	function fs.write(pcb, fd, buffer)
		return
	end

	function fs.fsync(pcb, fd)
		return
	end

	function fs.mkdir(pcb, path)
		return
	end

	function fs.unlink(pcb, path)
		return
	end

	function fs.readdir(pcb, path)
		return
	end

	return fs
end

return create
