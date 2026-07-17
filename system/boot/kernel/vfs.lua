local vfs = {}

-- fd_list - key: fd, value: table
--                     - must contain key "fs" with value of fs instance that owns fd
--                     - rest of table is up to fd to put
vfs.fd_list = {}
local next_fd = { 0 }

vfs.mounts = {}

local function sortMountsCompare(mount1, mount2)
	return #mount1.path > #mount2.path
end

-- when initialized, vfs.fd_list and next_fd must be passed as arg to fs in that order
function vfs.mount(mountpoint, fs)
	table.insert(vfs.mounts, { path = mountpoint, fs = fs })
	table.sort(vfs.mounts, sortMountsCompare)
end

-- returns the path to pass to the fs without leading or trailing slashes, and the fs
function vfs.resolvePathFs(path)
	for _, mount in ipairs(vfs.mounts) do
		if string.sub(path, 1, #mount.path) == mount.path then
			if string.sub(path, -1) == "/" then
				return string.sub(path, #mount.path + 1, #path - 1), mount.fs
			end
			return string.sub(path, #mount.path + 1, #path), mount.fs
		end
	end
end

return vfs
