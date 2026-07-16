-- Copyright 2026 jojotastic777
--
-- Permission is hereby granted, free of charge, to any person
-- obtaining a copy of this software and associated documentation
-- files (the “Software”), to deal in the Software without
-- restriction, including without limitation the rights to use, copy,
-- modify, merge, publish, distribute, sublicense, and/or sell copies
-- of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be
-- included in all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
-- NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
-- BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
-- ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
-- CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

local color = loadfile("neatobios:/common/color.lua")()

local byte = string.byte
local band = bit32.band
local rshift = bit32.rshift

function readUInt(handle, size)
	local bytes = handle.read(size)
	if not bytes or #bytes < size then
		return nil
	end
	local value = 0
	for i = 1, size do
		value = value + byte(bytes, i) * (256 ^ (i - 1))
	end
	return math.floor(value)
end

function makeFont(path)
	local Font = {}

	local handle = files.open(path, "rb")

	local b1 = readUInt(handle, 1)
	local b2 = readUInt(handle, 1)
	local b3 = readUInt(handle, 1)
	local b4 = readUInt(handle, 1)

	local glyphWidth
	local glyphHeight
	local bytesPerGlyph
	local numGlyphs

	local bufferCache = {}

	if b1 == 0x36 and b2 == 0x04 then
		-- PSF1

		local mode = b3
		local charsize = b4

		glyphWidth = 8
		glyphHeight = charsize
		bytesPerGlyph = charsize
		numGlyphs = band(mode, 1) ~= 0 and 512 or 256
	else
		-- Reconstruct the 32-bit little-endian magic
		local magic = b1 + b2 * 256 + b3 * 65536 + b4 * 16777216

		if magic ~= 0x864ab572 then
			return nil
		end

		local version = readUInt(handle, 4)
		local headerSize = readUInt(handle, 4)
		local flags = readUInt(handle, 4)

		numGlyphs = readUInt(handle, 4)
		bytesPerGlyph = readUInt(handle, 4)
		glyphHeight = readUInt(handle, 4)
		glyphWidth = readUInt(handle, 4)

		handle.seek("set", headerSize)
	end

	local glyphs = {}
	for glyphNum = 0, numGlyphs - 1 do
		local glyph = {}
		for _ = 1, bytesPerGlyph do
			local readByte = readUInt(handle, 1)
			for bitNum = 7, 0, -1 do
				table.insert(glyph, band(1, rshift(readByte, bitNum)))
			end
		end
		glyphs[glyphNum] = glyph
	end

	function Font.drawChar(x, y, char, options)
		options = options or {}
		local background = options.background or 0
		local foreground = options.foreground or 0xffffffff
		local charSpacing = options.charSpasing or 1
		local layer = options.layer or screen
		local c = byte(char)

		local bgCache = bufferCache[background]
		if not bgCache then
			bgCache = {}
			bufferCache[background] = bgCache
		end

		local fgCache = bgCache[foreground]
		if not fgCache then
			fgCache = {}
			bgCache[foreground] = fgCache
		end

		local charSpacingCache = bgCache[charSpacing]
		if not charSpacingCache then
			charSpacingCache = {}
			fgCache[charSpacing] = charSpacingCache
		end

		local buffer = charSpacingCache[c]

		if not buffer then
			local glyph = glyphs[byte(char)]
			buffer = {}

			local fr, fg, fb, fa = color.unpackRGBA(foreground)
			local br, bg, bb, ba = color.unpackRGBA(background)

			local i = 1
			local glyphIdx = 1

			for bufferIdx = 1, #glyph + glyphHeight * charSpacing do
				local pixel = glyph[glyphIdx]
				if math.fmod(bufferIdx, glyphWidth + charSpacing) + 1 <= glyphWidth then
					glyphIdx = glyphIdx + 1
				else
					pixel = 0
				end
				if pixel == 1 then
					buffer[i] = fr
					buffer[i + 1] = fg
					buffer[i + 2] = fb
					buffer[i + 3] = fa
					i = i + 4
				else
					buffer[i] = br
					buffer[i + 1] = bg
					buffer[i + 2] = bb
					buffer[i + 3] = ba
					i = i + 4
				end
			end

			if bufferCache[background] == nil then
				bufferCache[background] = {}
			end
			if bufferCache[background][foreground] == nil then
				bufferCache[background][foreground] = {}
			end
			fgCache[c] = buffer
		end
		layer.drawPixels(x, y, buffer, glyphWidth + charSpacing, glyphHeight)
	end

	function Font.drawLine(x, y, str, options)
		options = options or {}
		local charSpacing = options.charSpasing or 1

		for i = 1, #str do
			local char = string.sub(str, i, i + 1)
			local glyphX = x + (glyphWidth + charSpacing) * (i - 1)
			Font.drawChar(glyphX, y, char, options)
		end
	end

	function Font.drawCenteredLine(y, str, options)
		local screenSize, _ = screen.getSize()
		local stringWidth = #str * (Font.getWidth() + 1)
		Font.drawLine((screenSize - stringWidth) / 2, y, str, options)
	end

	function Font.drawRightAlignedLine(x, y, str, options)
		local stringWidth = #str * (Font.getWidth() + 1)
		Font.drawLine(x - stringWidth, y, str, options)
	end

	function Font.getWidth()
		return glyphWidth
	end

	function Font.getHeight()
		return glyphHeight
	end

	function Font.getSize()
		return glyphWidth, glyphHeight
	end
	return Font
end

return makeFont
