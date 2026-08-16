local unistd = _G.require("unistd")
local loadPSF2 = _G.require("nterm.load-psf2")

local VERSION = "v1.2"

-- initialize the terminal font
local screen = unistd.open("/dev/screen", 1)
local font, err = loadPSF2("/usr/share/consolefonts/Lat15-VGA16.psf", {
	defaultLayer = screen,
})
if not font or err then
	error(err)
end

-- open the pipes and the program that the terminal should run
local stdout_in, stdout_out = unistd.pipe()
local stderr_in, stderr_out = unistd.pipe()
local program = ... or "/bin/sh.lua"
local program_pid =
	coroutine.yield({ type = "exec", path = program, stdout = stdout_in, stderr = stderr_in, cwd = "/" })

local scroll = 1 -- the index of the highest line on the screen
local offx, offy = 4, 4
local termwidth = 99
local termheight = 35
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
	screen.set(0x000000FF)
	font.drawLine(offx, offy + font.height * 0.2, nil, "    nterm " .. VERSION .. ": " .. program)
	font.drawLine(offx, offy + font.height, nil, string.rep("-", termwidth))

	for i = 0, termheight do
		if i + scroll > #lines then
			break
		end
		font.drawLine(offx, offy + font.height * (i + 2), nil, lines[i + scroll]) -- to leave room for the tab name
	end
	screen.draw()
end

local function fetchpipes()
	-- read stdout
	local stdout_data = unistd.read(stdout_out, 1)
	if stdout_data ~= "\0" then
		append(stdout_data)
	end

	-- read stderr
	local stderr_data = unistd.read(stderr_out, 1)
	if stderr_data ~= "\0" then
		append(stderr_data)
	end
end

-- spawn a process that reports when the child process died
coroutine.yield({
	type = "spawn",
	fn = function()
		local exit_code = coroutine.yield({ type = "wait", pid = program_pid })
		coroutine.yield()
		coroutine.yield() -- wait a sec to let the parent print the error
		coroutine.yield()
		append("\n\nProcess with PID " .. program_pid .. " ended with exit code " .. exit_code .. "\n")
	end,
})

while true do
	fetchpipes()
	refresh()
end
