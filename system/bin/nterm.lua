local unistd = require("unistd")
local loadPSF2 = require("nterm.load-psf2")

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
