function _G.include(path)
	local handle = files.open("system:/boot/kernel/" .. path)
	local data = handle.read("a")
	handle.close()
	return load(data, "system:/boot/kernel/" .. path, nil, _G)
end

local scheduler = include("scheduler.lua")()

while true do
	scheduler.tick()
	coroutine.yield()
end
