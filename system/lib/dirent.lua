local dirent = {}

local nextfd = 0
-- entry: fd = {
--  	dirname = dirname,
--  	children = children,
--  	idx = idx of readdir iteration
--  	closed = boolean
-- }
local dirfds = {}

function dirent.opendir(dirname)
	nextfd += 1

	if dirname:sub(#dirname, #dirname) ~= "/" then
		dirname = dirname .. "/"
	end

	local children, err = coroutine.yield({ type = "readdir", path = dirname })
	if err then
		error(err, 2)
	end

	dirfds[nextfd] = {
		dirname = dirname,
		children = children,
		idx = 1,
	}
	return nextfd
end

-- returns file or directory name
function dirent.readdir(fd)
	local dir = dirfds[fd]
	if dir.closed then
		error("directory file descriptor is closed", 2)
	end
	if dir.idx > #dir.children then
		return nil
	end
	local childname = dir.children[dir.idx]
	dir.idx += 1

	return childname
end

function dirent.closedir(fd)
	dirfds[fd].closed = true
end

function dirent.rewinddir(fd)
	local dir = dirfds[fd]

	local children, err = coroutine.yield({ type = "readdir", path = dir.dirname })
	if err then
		error(err, 2)
	end

	dir.children = children
	dir.idx = 1
end

function dirent.scandir(fd)
	return dirfds[fd].children
end

function dirent.ftw(dirname, func)
	if dirname:sub(#dirname, #dirname) ~= "/" then
		dirname = dirname .. "/"
	end

	local fd = dirent.opendir(dirname)
	for _, child in ipairs(dirent.scandir(fd)) do
		func(dirname .. child)
		if not coroutine.yield({ type = "isfile", path = dirname .. child }) then
			dirent.ftw(dirname .. child, func)
		end
	end
end

return dirent
