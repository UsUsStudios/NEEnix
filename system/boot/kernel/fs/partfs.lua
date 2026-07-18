-- Filesystem for an arbitrary partition on an arbitrary disk

local function create(fd_list, next_fd, partition, disk)
	local fs = {}

	function fs.open(path, mode) end
	function fs.close(fd) end
	function fs.read(fd, buffer, count) end
	function fs.lseek(fd, offset, whence) end
	function fs.write(fd, buffer) end
	function fs.mkdir(path) end
	function fs.unlink(path) end
	function fs.rename(oldpath, newpath) end
	function fs.readdir(path) end
end

return create
