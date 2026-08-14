local unistd = require("unistd")
local loadPSF2 = require("nterm.load-psf2")

-- initialize the terminal font
local screen = unistd.open("/dev/screen", 1)
local font, err = loadPSF2("/usr/share/consolefonts/Lat15-VGA16.psf", {
	defaultLayer = screen,
})
if not font or err then
	error(err)
end
screen.fill(0, 0, 0)
font.drawLine(10, 10, nil, "Hello, World!")
screen.draw()

-- open the pipes and the program that the terminal should run
local stdout_in, stdout_out = unistd.pipe()
local stderr_in, stderr_out = unistd.pipe()
local program = ... or "/bin/sh.lua"
coroutine.yield({ type = "exec", path = program, stdout = stdout_in, stderr = stderr_in })

local scroll = 1 -- the index of the highest line on the screen
local offx, offy = 4, 4
local termwidth = 99
local termheight = 37
local lines = {
	"",
}

local function appendText(str)
	local lastline = lines[#lines] .. str
	lines[#lines] = nil
	while lastline:len() > termwidth do
		if scroll == #lines - termheight then
			scroll += 1
		end

		lines[#lines + 1] = lastline:sub(1, termwidth)
		lastline = lastline:sub(termwidth, #lastline)
	end

	if scroll == #lines - termheight then
		scroll += 1
	end
	lines[#lines + 1] = lastline:sub(1, termwidth)
end

local function append(str)
	local line_buffer = {}
	for c in str:gmatch(".") do
		if c == "\n" then
			appendText(table.concat(line_buffer))
			lines[#lines + 1] = ""
			line_buffer = {}
		else
			line_buffer[#line_buffer + 1] = c
		end
	end
	appendText(table.concat(line_buffer))
end

local function refresh()
	screen.fill(0, 0, 0)
	for i = 0, termheight do
		if i + scroll > #lines then
			break
		end
		font.drawLine(offx, offy + font.height * i, nil, lines[i + scroll])
	end
	screen.draw()
end

local function fetchpipes()
	-- read stdout
	local stdout_data, err1 = coroutine.yield({ type = "read", fd = stdout_out })
	if err1 then
		error(err1)
	end
	if stdout_data ~= "\0" then
		append(stdout_data)
	end

	-- read stderr
	local stderr_data, err2 = coroutine.yield({ type = "read", fd = stderr_out })
	if err2 then
		error(err2)
	end
	if stderr_data ~= "\0" then
		append(stderr_data)
	end
end

while true do
	fetchpipes()
	refresh()
end
