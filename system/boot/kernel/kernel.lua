function _G.include(path)
	local handle = files.open("system:/boot/kernel/" .. path)
	local data = handle.read("a")
	handle.close()
	return load(data, "system:/boot/kernel/" .. path, nil, _G)
end

local scheduler = include("scheduler.lua")()
if scheduler == nil then
	return
end

scheduler.new_process(function()
	local pid = coroutine.yield({ type = "getpid" })
	local pcb = scheduler.new_process(function()
		coroutine.yield()
		coroutine.yield()
		coroutine.yield()
		coroutine.yield()
		coroutine.yield()
		coroutine.yield()
		print("hi")
	end, pid)

	coroutine.yield({ type = "wait", pid = pcb.pid })
	print("parent")
end)

while true do
	scheduler.tick()
	coroutine.yield()
end
