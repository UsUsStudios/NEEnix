#!/usr/bin/env python3
import os
import struct
import sys

src = sys.argv[1]
os.system("gunzip " + src)

src = src[:-3]
dst = src

data = open(src, "rb").read()

magic, mode, charsize = struct.unpack_from("<HBB", data, 0)

if magic != 0x0436:
    raise ValueError(f"Not PSF1: {magic:#x}")

numglyphs = 512 if (mode & 0x01) else 256

glyph_start = 4
glyph_end = glyph_start + numglyphs * charsize

if len(data) < glyph_end:
    raise ValueError("File ends before glyph data")

glyphs = data[glyph_start:glyph_end]

width = 8
height = charsize
bytes_per_row = (width + 7) // 8
charsize2 = bytes_per_row * height

assert charsize2 == charsize

header = struct.pack(
    "<8I",
    0x864AB572,  # magic
    0,  # version
    32,  # header size
    0,  # flags
    numglyphs,  # length
    charsize2,  # charsize
    height,
    width,
)

with open(dst, "wb") as f:
    f.write(header)
    f.write(glyphs)

print(f"PSF1: {numglyphs} glyphs, {charsize} bytes/glyph")
print(f"PSF2: {numglyphs} glyphs, {charsize2} bytes/glyph")
print(f"Output size: {32 + len(glyphs)} bytes")
