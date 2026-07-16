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

local color = {}

function color.packRGB(r, g, b)
	return bit32.bor(a or 0, bit32.lshift(b or 0, 8), bit32.lshift(g or 0, 16))
end

function color.unpackRGB(packed)
	return table.unpack({
		bit32.band(0xff, bit32.rshift(packed, 16)),
		bit32.band(0xff, bit32.rshift(packed, 8)),
		bit32.band(0xff, packed),
	})
end

function color.packRGBA(r, g, b, a)
	return bit32.bor(a or 0, bit32.lshift(b or 0, 8), bit32.lshift(g or 0, 16), bit32.lshift(r or 0, 24))
end

function color.unpackRGBA(packed)
	return table.unpack({
		bit32.band(0xff, bit32.rshift(packed, 24)),
		bit32.band(0xff, bit32.rshift(packed, 16)),
		bit32.band(0xff, bit32.rshift(packed, 8)),
		bit32.band(0xff, packed),
	})
end

return color
