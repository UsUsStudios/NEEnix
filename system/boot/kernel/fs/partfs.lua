-- Filesystem for an arbitrary partition on an arbitrary disk

local function create(fd_list, next_fd, partition, disk)
	local fs = {}

	function fs.stringrepr()
		return "partfs - " .. 0 .. ":" .. partition
	end

	function fs.open(path, mode)
		local handle = files.open(partition .. ":/" .. path, mode, disk)
		if handle == nil then
			error("file handle is nil")
		end
		local fd = next_fd()
		fd_list[fd] = {
			fs = fs,
			handle = handle,
		}
		return fd
	end

	function fs.close(fd)
		fd_list[fd].handle.flush()
		fd_list[fd].handle.close()
		fd_list[fd] = nil
	end

	function fs.read(fd, count)
		return fd_list[fd].handle.read(count)
	end

	function fs.lseek(fd, offset, whence)
		return fd_list[fd].handle.seek(whence, offset)
	end

	function fs.write(fd, buffer)
		fd_list[fd].handle.write(buffer)
	end

	function fs.fsync(fd)
		fd_list[fd].handle.flush()
	end

	function fs.mkdir(path)
		files.makeDir(partition .. ":/" .. path, disk)
	end

	function fs.unlink(path)
		files.delete(partition .. ":/" .. path, disk)
	end

	function fs.readdir(path)
		return files.getChildren(partition .. ":/" .. path, disk)
	end

	return fs
end

return create
