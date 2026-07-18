-- Filesystem for an arbitrary partition on an arbitrary disk

local function create(fd_list, next_fd, partition, disk)
	local fs = {}

	function fs.stringrepr()
		return
	end

	function fs.open(path, mode)
		local handle = files.open(partition .. ":/" .. path, mode, disk)
		fd_list[next_fd[1]] = {
			fs = fs,
			handle = handle,
		}
		next_fd[1] = next_fd[1] + 1
		return next_fd[1] - 1
	end

	function fs.close(fd)
		fd.handle.flush()
		fd.handle.close()
		fd.close()
	end

	function fs.read(fd, count)
		return fd.handle.read(count)
	end

	function fs.lseek(fd, offset, whence)
		fd.handle.seek(whence, offset)
	end

	function fs.write(fd, buffer)
		fd.handle.write(buffer)
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
