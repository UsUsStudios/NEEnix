-- Filesystem for an arbitrary partition on an arbitrary disk

local function create(next_fd, partition, disk)
	local fs = {}

	function fs.stringrepr()
		return "partfs - " .. 0 .. ":" .. partition
	end

	function fs.open(pcb, path, mode)
		if not files.exists(partition .. ":/" .. path, disk) then
			return error("file does not exist: " .. path)
		end
		local handle = files.open(partition .. ":/" .. path, mode, disk)
		if not handle then
			return error("file handle is nil")
		end
		local fd = next_fd()
		pcb.fds[fd] = {
			fs = fs,
			handle = handle,
		}
		return fd
	end

	function fs.close(pcb, fd)
		pcb.fds[fd].handle.flush()
		pcb.fds[fd].handle.close()
		pcb.fds[fd] = nil
	end

	function fs.read(pcb, fd, count)
		return pcb.fds[fd].handle.read(count)
	end

	function fs.lseek(pcb, fd, offset, whence)
		return pcb.fds[fd].handle.seek(whence, offset)
	end

	function fs.write(pcb, fd, buffer)
		pcb.fds[fd].handle.write(buffer)
	end

	function fs.fsync(pcb, fd)
		pcb.fds[fd].handle.flush()
	end

	function fs.mkdir(pcb, path)
		files.makeDir(partition .. ":/" .. path, disk)
	end

	function fs.unlink(pcb, path)
		files.delete(partition .. ":/" .. path, disk)
	end

	function fs.readdir(pcb, path)
		return files.getChildren(partition .. ":/" .. path, disk)
	end

	return fs
end

return create
