package.path = table.concat({
	"0:neatobios:/?.lua",
}, ";")

local wget = require("installer/wget")
local font = require("common/psf")("0:neatobios:/assets/Lat15-VGA16.psf")
local fontHeight = font.getHeight()
local fontWidth = font.getWidth() + 1
local currentTypedText = ""
local accepted = false

local function loopRender()
	screen.fill(0, 0, 0)
	font.drawLine(3, 3, "Checking internet access...")
	font.drawLine(3, 3 + fontHeight, "Internet access is available and ready to use!", { foreground = 0x2cd30eff })
	local linkLine = "Enter OS installer URL: " .. currentTypedText
	font.drawLine(3, 3 + fontHeight * 2, linkLine)

	if math.fmod(chip.getTime(), 1) > 0.5 then
		screen.fill(
			3 + fontWidth * (#linkLine + 0.1),
			fontHeight * 3,
			3 + fontWidth * (#linkLine + 0.9),
			fontHeight * 3 + 1,
			255,
			255,
			255
		)
	end

	screen.draw()
end

local function handleKeyboard()
	local data = event.getFirst("user", "keyPressed")
	while data ~= nil do
		local _, keyPressed, code, _, _ = table.unpack(data)
		if keyPressed == 8 and #currentTypedText > 0 then
			currentTypedText = string.sub(currentTypedText, 1, #currentTypedText - 1)
		elseif keyPressed == 13 and #currentTypedText > 0 then
			accepted = true
		elseif code ~= "" then
			currentTypedText = currentTypedText .. code
		end

		data = event.getFirst("user", "keyPressed")
	end
end

local function main()
	while true do
		screen.fill(0, 0, 0)

		font.drawLine(3, 3, "Checking internet access...")
		screen.draw()

		if not internet.hasAccess() then
			font.drawLine(3, 3 + fontHeight, "Internet access disabled in config.", { foreground = 0xd30e0eff })
			screen.draw()
			while true do
			end
		end
		while not internet.isReady() do
			coroutine.yield()
		end

		font.drawLine(3, 3 + fontHeight, "Internet access is available and ready to use!", { foreground = 0x2cd30eff })
		screen.draw()

		while not accepted do
			handleKeyboard()
			loopRender()
		end

		font.drawLine(3, 3 + fontHeight * 3, "Downloading OS installer from " .. currentTypedText)
		screen.draw()
		if not files.isDir("0:system:/temp") then
			files.makeDir("0:system:/temp")
		end

		if wget(currentTypedText, "0:system:/temp/installer.lua") then
			font.drawLine(
				3,
				3 + fontHeight * 4,
				"Successfully downloaded installer! Executing...",
				{ foreground = 0x2cd30eff }
			)
			screen.draw()

			local start = chip.getTime()
			while chip.getTime() - start < 1 do
				coroutine.yield()
			end

			loadfile("0:system:/temp/installer.lua")()

			files.delete("0:system:/temp/installer.lua")
			return
		else
			font.drawLine(3, 3 + fontHeight * 4, "Download failed.", { foreground = 0xd30e0eff })
			screen.draw()

			local start = chip.getTime()
			while chip.getTime() - start < 3 do
				coroutine.yield()
			end

			currentTypedText = ""
			accepted = false
		end
	end
end

main()
