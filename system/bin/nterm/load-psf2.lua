-- jojotastic777, released under CC0
local unistd = require("unistd")
local PSF2_FONT_MAGIC = 0x864ab572

-- The function which _loads the PSF2 file._
local function loadPSF2(path, fontOptions)
	fontOptions = fontOptions or {}
	fontOptions.foreground = fontOptions.foreground or { 255, 255, 255, 255 }
	fontOptions.background = fontOptions.background or { 0, 0, 0, 0 }
	fontOptions.defaultSpacing = fontOptions.defaultSpacing or 0

	local fgData = string.char(table.unpack(fontOptions.foreground))
	local bgData = string.char(table.unpack(fontOptions.background))

	local fd = unistd.open(path, unistd.O_RDONLY | unistd.O_BYTES)

	local magic = string.unpack("I4", unistd.read(fd, 4))
	if magic ~= PSF2_FONT_MAGIC then
		return nil, "not a psf2 file"
	end

	local version = string.unpack("I4", unistd.read(fd, 4))
	if version ~= 0 then
		return nil, "invalid psf2 version"
	end

	-- Get all the header information.
	-- `string.unpack` makes this _so much easier._
	local header_size = string.unpack("I4", unistd.read(fd, 4))
	local flags = string.unpack("I4", unistd.read(fd, 4))
	local glyph_count = string.unpack("I4", unistd.read(fd, 4))
	local bytes_per_glyph = string.unpack("I4", unistd.read(fd, 4))
	local glyph_height = string.unpack("I4", unistd.read(fd, 4))
	local glyph_width = string.unpack("I4", unistd.read(fd, 4))

	unistd.lseek(fd, header_size, unistd.SEEK_SET) -- Go to the _end_ of the header.

	-- Manually create a pixel buffer for a "missing character" glyph.
	local missing_glyph = table.concat({ -- Newline to keep Emacs' formatter from screwing with me.
		string.rep(fgData, glyph_width),
		string.rep(fgData .. string.rep(bgData, glyph_width - 2) .. fgData, glyph_height - 2),
		string.rep(fgData, glyph_width),
	}, "")

	local glyphs = {} -- A table associated glyph indexes with pixel buffers.

	-- Construct a pixel buffer for each glyph in the font, by interating
	-- through each glyph, and then iterating through each _column_ of
	-- each _row_ to construct a pixel buffer for that glyph where a
	-- high bit is colored with `fontSettings.foreground` and a low bit
	-- is colored with `fontSettings.background`.
	for glyphNum = 0, glyph_count - 1 do
		local glyph = {}
		for rowNum = 1, glyph_height do
			local row = {}
			local rawbyte = unistd.read(fd, 1)
			local byte = string.unpack("I1", rawbyte)
			for colNum = 0, glyph_width - 1 do
				local bit = (byte >> colNum) & 1 -- Real bit operators!
				if bit == 0 then
					-- I think the [8 - colNum] is an endian-ness thing?
					row[8 - colNum] = bgData -- Low bits are background.
				else
					row[8 - colNum] = fgData -- High bits are foreground.
				end
			end
			glyph[rowNum] = table.concat(row, "")
		end
		glyphs[glyphNum] = table.concat(glyph, "")
	end

	-- Set up the table which this whole loader function returns, and
	-- expose a few useful values right away.
	local Font = {
		width = glyph_width,
		height = glyph_height,
		glyphCount = glyph_count,
	}

	-- Get the pixel buffer associated with a particular glyph index.
	function Font.getGlyph(index)
		local glyph = glyphs[index]
		if glyph ~= nil then
			return glyph
		else
			return nil, "no such glyph"
		end
	end

	-- Draw a glyph according to its index.
	function Font.drawGlyph(x, y, drawOptions, index)
		drawOptions = drawOptions or {}
		local layer = drawOptions.layer or fontOptions.defaultLayer

		local glyph, err = Font.getGlyph(index)
		if err == nil then
			layer.drawPixels(x, y, glyph, glyph_width, glyph_height)
		elseif err == "no such glyph" then
			layer.drawPixels(x, y, missing_glyph, glyph_width, glyph_height)
		else
			return err
		end
	end

	-- Draw many glyphs according to their indices.
	function Font.drawGlyphs(x, y, drawOptions, ...)
		drawOptions = drawOptions or {}
		local spacing = drawOptions.spacing or fontOptions.defaultSpacing
		local layer = drawOptions.layer or fontOptions.defaultLayer

		local indexes = { ... }
		for i, glyph_index in ipairs(indexes) do
			local charX = x + (i - 1) * (glyph_width + spacing)
			local err = Font.drawGlyph(charX, y, drawOptions, glyph_index)

			if err ~= nil then
				return err
			end

			-- Handle drawing the background between glyphs when `spacing > 0`.
			if i > 1 and spacing > 0 then
				layer.drawPixels(charX - spacing, y, string.rep(bgData, spacing * glyph_height), spacing, glyph_height)
			end
		end
	end

	-- Draw a single character. Doesn't handle unicode, but usually works
	-- for normal ASCII text.
	function Font.drawChar(x, y, drawOptions, char)
		return Font.drawGlyph(x, y, drawOptions, string.byte(char))
	end

	-- Draw a line of text. Doesn't handle newlines or unicode, but usually
	-- works for normal ASCII text.
	function Font.drawLine(x, y, drawOptions, str)
		return Font.drawGlyphs(x, y, drawOptions, string.byte(str, 1, #str))
	end

	-- Unicode handling starts here.
	if flags == 1 then
		-- Conveniently, this means that you can check if a font has unicode
		-- support by checking if `Font.unicode ~= nil`.
		Font.unicode = {}

		-- Go to the start of the unicode table.
		handle.seek("set", header_size + bytes_per_glyph * glyph_count)

		-- A table associating unicode codepoints to a glyph index.
		local codes = {}

		-- The PSF2 unicode table has as many entries as there are glyphs
		-- in the font. Iterate through each entry in that table.
		for glyphNum = 0, glyph_count - 1 do
			local points = {}
			local byte = handle.read(1)

			-- Get all the bytes in this entry of the unicode table.
			while true do
				if byte == string.char(0xFF) then
					break
				elseif byte == "" then
					-- This shouldn't happen for well-formed psf2 files.
					error("unexpected eof")
				end

				table.insert(points, byte)
				byte = handle.read(1)
			end

			-- For each codepoint associated with this table entry,
			-- add it to the `codes` table.
			for _, point in utf8.codes(table.concat(points, "")) do
				codes[point] = glyphNum
			end
		end

		-- Get the glyph index associated with a utf8 codepoint.
		function Font.unicode.getGlyphIndex(codepoint)
			local glyphIndex = codes[point]
			if glyphIndex ~= nil then
				return glyphIndex
			else
				return nil, "no glyph for codepoint"
			end
		end

		-- Get the glyph pixel buffer assocated with a utf8 codepoint.
		function Font.unicode.getGlyph(codepoint)
			local glyphIndex, err = Font.unicode.getGlyphIndex(codepoint)
			if err then
				return nil, err
			else
				return Font.getGlyph(glyphIndex)
			end
		end

		-- Draw the glyph associated with a utf8 codepoint.
		-- See `Font.drawGlyph` for details about `drawOptions`.
		function Font.unicode.drawPoint(x, y, drawOptions, codepoint)
			return Font.drawGlyph(x, y, drawOptions, codes[codepoint])
		end

		-- Draw the glyphs associated with many utf8 codepoints.
		-- See `Font.drawGlyph` for details about `drawOptions`.
		function Font.unicode.drawPoints(x, y, drawOptions, ...)
			drawOptions = drawOptions or {}
			local spacing = drawOptions.spacing or fontOptions.defaultSpacing
			local layer = drawOptions.layer or fontOptions.defaultLayer

			local codepoints = { ... }
			for i, point in ipairs(codepoints) do
				local charX = x + (i - 1) * (glyph_width + spacing)
				local err = Font.unicode.drawPoint(charX, y, drawOptions, point)

				if err ~= nil then
					return err
				end

				-- Handle drawing the background between glyphs when `spacing > 0`.
				if i > 0 and spacing > 0 then
					layer.drawPixels(
						charX - spacing,
						y,
						string.rep(bgData, spacing * glyph_height),
						spacing,
						glyph_height
					)
				end
			end
		end

		-- Draw a single utf8-encoded character.
		-- See `Font.drawGlyph` for details about `drawOptions`.
		function Font.unicode.drawChar(x, y, drawOptions, char)
			return Font.unicode.drawPoint(x, y, drawOptions, utf8.codepoint(char))
		end

		-- Draw a line of utf8-encoded text. Doesn't handle newlines,
		-- obviously.
		-- See `Font.drawGlyph` for details about `drawOptions`.
		function Font.unicode.drawLine(x, y, drawOptions, str)
			drawOptions = drawOptions or {}
			local spacing = drawOptions.spacing or fontOptions.defaultSpacing
			local layer = drawOptions.layer or fontOptions.defaultLayer

			local i = 0
			for _, point in utf8.codes(str) do
				local charX = x + i * (glyph_width + spacing)
				local err = Font.unicode.drawPoint(charX, y, drawOptions, point)

				if err ~= nil then
					return err
				end

				-- Handle drawing the background between glyphs when `spacing > 0`.
				if i > 0 and spacing > 0 then
					layer.drawPixels(
						charX - spacing,
						y,
						string.rep(bgData, spacing * glyph_height),
						spacing,
						glyph_height
					)
				end

				i = i + 1
			end
		end

		function Font.close()
			fontOptions.defaultLayer.close()
		end

		function Font.flip()
			fontOptions.defaultLayer.draw()
		end
	end

	-- Close the file handle, since it's no longer needed.
	unistd.close(fd)

	return Font
end

return loadPSF2
