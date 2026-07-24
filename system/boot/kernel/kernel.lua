function _G.include(path)
	local handle = files.open("system:/boot/kernel/" .. path)
	local data = handle.read("a")
	handle.close()
	return load(data, "system:/boot/kernel/" .. path, nil, _G)
end

_G.NEENIXVERSION = "v0.0.1"
_G.cwd = "/"

include("scheduler.lua")()
include("vfs.lua")()

do
	local handle = files.open("system:/etc/initd/init.lua")
	local data = handle.read("a")
	handle.close()
	scheduler.new_process(load(data, "system:/etc/initd/init.lua", nil, scheduler.create_env()))
end

while true do
	scheduler.tick()
	coroutine.yield()
end
