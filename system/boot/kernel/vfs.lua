_G.vfs = {}

-- fd_list - key: fd, value: table
--                     - must contain key "fs" with value of fs instance that owns fd
--                     - rest of table is up to fs to define
vfs.fd_list = {}
local next_fd = { 0 }

-- [{path = mountpoint, fs = fs}]
vfs.mounts = {}

local function sortMountsCompare(mount1, mount2)
	return #mount1.path > #mount2.path
end

function vfs.mount(mountpoint, fs)
	if string.sub(mountpoint, -1) ~= "/" then
		mountpoint = mountpoint .. "/"
	end
	table.insert(vfs.mounts, { path = mountpoint, fs = fs })
	table.sort(vfs.mounts, sortMountsCompare)
end

-- returns the path to pass to the fs without leading or trailing slashes, and the fs
function vfs.resolvePathFs(path)
	if string.sub(path, -1) ~= "/" then
		path = path .. "/"
	end
	for _, mount in ipairs(vfs.mounts) do
		if string.sub(path, 1, #mount.path) == mount.path then
			if string.sub(path, -1) == "/" then
				return string.sub(path, #mount.path + 1, #path - 1), mount.fs
			end
			return string.sub(path, #mount.path + 1, #path), mount.fs
		end
	end
end

local function mountFromLuaFile(mountpoint, path, args)
	local handle = files.open(path)
	if handle == nil then
		error("cannot mount because fs file handle is nil")
	end
	local data = handle.read("a")
	handle.close()
	local fs = load(data, path, nil, _G)()(vfs.fd_list, next_fd, table.unpack(args))
	vfs.mount(mountpoint, fs)
end

function vfs.mountFromFile(mountpoint, path)
	local data = nil
	local normalized_path, fs = vfs.resolvePathFs(path)
	if normalized_path == nil then
		local handle = files.open(path)
		if handle == nil then
			error("cannot mount from file because mount file handle is nil")
		end
		data = handle.read("a")
		handle.close()
	else
		local fd = fs.open(normalized_path, "r")
		data = fs.read(fd, "a")
		fs.close(fd)
	end
	local fsfile = load(data, path, nil, _G)()
	mountFromLuaFile(mountpoint, fsfile[1], fsfile[2])
end

return vfs
