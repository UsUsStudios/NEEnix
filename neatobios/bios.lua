local function deepCopy(obj, seen)
	if type(obj) ~= "table" then
		return obj
	end

	seen = seen or {}

	if seen[obj] then
		return seen[obj]
	end

	local copy = {}
	seen[obj] = copy

	for k, v in pairs(obj) do
		copy[deepCopy(k, seen)] = deepCopy(v, seen)
	end
	return copy
end

local font
local _G_COPY

local fontHeight
local fontWidth
local screenWidth, screenHeight = screen.getSize()

local bootCfg = {}
local selectedOption = 1

local function drawBootOptions()
	for k, v in pairs(bootCfg) do
		local options = {}
		if selectedOption == k then
			options = { background = 0xffffffff, foreground = 0x000000ff }
			screen.fill(
				3 + fontWidth * 4,
				3 + fontHeight * (5 + k),
				screenWidth - 3 - fontWidth * 4,
				3 + fontHeight * (6 + k),
				255,
				255,
				255
			)
		end

		font.drawLine(3 + fontWidth * 4, 3 + fontHeight * (5 + k), v["OS Name"] .. " v" .. v["OS Version"], options)
		font.drawRightAlignedLine(
			screenWidth - 3 - fontWidth * 4,
			3 + fontHeight * (5 + k),
			v["OS Description"],
			options
		)
	end
end

local function render()
	screen.fill(0, 0, 0)
	screen.drawRectangle(
		fontWidth * 3,
		3 + fontHeight * 5,
		screenWidth - fontWidth * 3,
		screenHeight - 3 - fontHeight * 2,
		255,
		255,
		255
	)

	font.drawCenteredLine(
		3 + fontHeight * 2,
		"Welcome to NeatoBoot. You have " .. #bootCfg .. " operating system(s) installed."
	)
	font.drawCenteredLine(
		3 + fontHeight * 3,
		"Time since startup: " .. math.floor(chip.getTime()) .. "   In-game lunar time: " .. chip.getLunarTime()
	)

	drawBootOptions()
	screen.draw()
end

local function launchBootOption(bootOption)
	local env = deepCopy(_G_COPY)
	local envVars = bootOption["OS Environment Variable Definition"]
	if envVars ~= nil then
		for var, val in pairs(envVars) do
			env[var] = val
		end
	end

	local args = bootOption["OS Args"]
	local OS = loadfile(bootOption["OS Boot Path"], nil, env)
	if args == nil then
		OS()
	elseif type(args) == "table" then
		OS(table.unpack(args))
	else
		OS(args)
	end
	chip.shutdown()
end

local function loadBootCfg()
	for _, disk in pairs(files.getDisks()) do
		local diskCfg = loadfile(disk .. ":system:/boot/cfg/boot.lua", nil, {})()
		if disk == 0 then
			selectedOption = diskCfg["Config"]["DefaultEntry"]
		end
		local autoboot = diskCfg["Config"]["Autoboot"]
		if type(autoboot) == "number" then
			launchBootOption(diskCfg["Bootlist"][autoboot])
		end

		for _, bootOption in ipairs(diskCfg["Bootlist"]) do
			table.insert(bootCfg, bootOption)
		end
	end
end

local function init()
	local options = { foreground = 0x2cd30eff }

	-- load psf renderer
	do
		local handle = files.open("neatobios:/common/psf.lua")
		local data = handle.read("a")
		handle.close()
		font = load(data, "neatobios:/common/psf.lua")()("neatobios:/assets/Lat15-VGA16.psf")

		fontHeight = font.getHeight()
		fontWidth = font.getWidth()
	end
	font.drawLine(3, 3, "[NEATOBIOS] [INFO] Loaded psf renderer", options)
	screen.draw()

	-- Load jojotastic777's files shim and require
	do
		font.drawLine(3, 3 + fontHeight * 1, "[NEATOBIOS] [INFO] Loading files shim", options)
		screen.draw()
		local handle = files.open("neatobios:/common/files-shim.lua")
		local data = handle.read("a")
		handle.close()
		load(data, "0:neatobios:/common/files-shim.lua")()

		font.drawLine(3, 3 + fontHeight * 2, "[NEATOBIOS] [INFO] Loading require implementation", options)
		screen.draw()
		loadfile("0:neatobios:/common/require.lua")()

		font.drawLine(3, 3 + fontHeight * 3, "[NEATOBIOS] [INFO] Setting package.path", options)
		screen.draw()
		package.path = table.concat({ "0:neatobios:/common/?.lua", "0:neatobios:/?.lua" }, ";")
	end

	font.drawLine(3, 3 + fontHeight * 4, "[NEATOBIOS] [INFO] Copying _G", options)
	screen.draw()
	_G_COPY = deepCopy(_G)

	font.drawLine(3, 3 + fontHeight * 5, "[NEATOBIOS] [INFO] Loading boot configs", options)
	screen.draw()
	loadBootCfg()

	font.drawLine(3, 3 + fontHeight * 6, "[NEATOBIOS] [INFO] Starting NeatoBios", options)
	screen.draw()
end

local function main()
	while true do
		local data = event.getFirst("user", "keyPressed")
		while data ~= nil do
			local _, keyPressed, code, letter, modifiers = table.unpack(data)
			if keyPressed == 130 and selectedOption > 1 then
				selectedOption = selectedOption - 1
			elseif keyPressed == 131 and selectedOption < #bootCfg then
				selectedOption = selectedOption + 1
			elseif keyPressed == 32 or keyPressed == 13 then
				launchBootOption(bootCfg[selectedOption])
			end

			data = event.getFirst("user", "keyPressed")
		end
		render()
	end
end

local function benchmark()
	local start = chip.getTime()
	print("Test suite started")
	require("benchmarks/binarytrees")(10)
	print(chip.getTime() - start)
	require("benchmarks/array3d")(130)
	print(chip.getTime() - start)
	require("benchmarks/chameos")(200000)
	print(chip.getTime() - start)
	require("benchmarks/coroutine_ring")(500000)
	print(chip.getTime() - start)
	require("benchmarks/fannkuch_redux")(50)
	print(chip.getTime() - start)
	require("benchmarks/fasta")(90)
	print("Test suite finished in " .. chip.getTime() - start .. " seconds")
end

init()
main()
