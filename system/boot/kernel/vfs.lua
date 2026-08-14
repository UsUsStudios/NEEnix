_G.vfs = {}

local next_fd_num = 128 -- fds 1 to 128 are reserved
local function next_fd()
	next_fd_num += 1
	return next_fd_num
end

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
	local fs = load(data, path, nil, _G)()(next_fd, table.unpack(args))
	vfs.mount(mountpoint, fs)
end

function vfs.mountFromFile(pcb, mountpoint, path)
	local data
	local normalized_path, fs = vfs.resolvePathFs(path)
	if not normalized_path then
		local handle = files.open(path)
		if not handle then
			error("cannot mount from file because mount file handle is nil")
		end
		data = handle.read("a")
		handle.close()
	else
		local fd = fs.open(pcb, normalized_path, "r")
		data = fs.read(pcb, fd, "a")
		fs.close(pcb, fd)
	end
	local fsfileloader, err = load(data, path, nil, _G)
	if err or not fsfileloader then
		error(err)
	end

	local fsfile = fsfileloader()
	mountFromLuaFile(mountpoint, fsfile[1], fsfile[2])
end

return vfs
