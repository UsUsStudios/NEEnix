function _G.include(path)
	local handle = files.open("system:/boot/kernel/" .. path)
	local data = handle.read("a")
	handle.close()
	load(data, "system:" .. path, nil, _G)()
end

local scheduler = include("scheduler.lua")
