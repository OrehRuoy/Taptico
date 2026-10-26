"""Write adaptive_monochrome_432.png from the foreground PNG's alpha.

White where alpha > 16, transparent elsewhere. Does not create the foreground,
background, or 192px launcher icon.
"""

import struct
import sys
import zlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "assets" / "icons" / "android" / "adaptive_foreground_432.png"
DST = ROOT / "assets" / "icons" / "android" / "adaptive_monochrome_432.png"
ALPHA_CUTOFF = 16


def _paeth(a: int, b: int, c: int) -> int:
	p = a + b - c
	pa = abs(p - a)
	pb = abs(p - b)
	pc = abs(p - c)
	if pa <= pb and pa <= pc:
		return a
	if pb <= pc:
		return b
	return c


def read_png_rgba(path: Path) -> tuple[int, int, bytearray]:
	data = path.read_bytes()
	if data[:8] != b"\x89PNG\r\n\x1a\n":
		raise SystemExit(f"{path} is not a PNG")
	offset = 8
	width = height = bit_depth = color_type = interlace = 0
	idat = bytearray()
	palette = b""
	transparency = b""
	while offset + 8 <= len(data):
		length = struct.unpack(">I", data[offset:offset + 4])[0]
		chunk = data[offset + 4:offset + 8]
		payload = data[offset + 8:offset + 8 + length]
		offset += 12 + length
		if chunk == b"IHDR":
			width, height, bit_depth, color_type, _comp, _filter, interlace = struct.unpack(">IIBBBBB", payload)
		elif chunk == b"PLTE":
			palette = payload
		elif chunk == b"tRNS":
			transparency = payload
		elif chunk == b"IDAT":
			idat.extend(payload)
		elif chunk == b"IEND":
			break
	if interlace != 0:
		raise SystemExit(f"{path} is interlaced; export a non-interlaced PNG")
	if bit_depth != 8:
		raise SystemExit(f"{path} must be 8-bit")
	channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}.get(color_type)
	if channels is None:
		raise SystemExit(f"{path} has unsupported color type {color_type}")
	raw = zlib.decompress(bytes(idat))
	stride = width * channels
	rows: list[bytearray] = []
	cursor = 0
	for _y in range(height):
		filter_type = raw[cursor]
		cursor += 1
		row = bytearray(raw[cursor:cursor + stride])
		cursor += stride
		prev = rows[-1] if rows else bytearray(stride)
		if filter_type == 1:
			for i in range(stride):
				left = row[i - channels] if i >= channels else 0
				row[i] = (row[i] + left) & 255
		elif filter_type == 2:
			for i in range(stride):
				row[i] = (row[i] + prev[i]) & 255
		elif filter_type == 3:
			for i in range(stride):
				left = row[i - channels] if i >= channels else 0
				row[i] = (row[i] + ((left + prev[i]) // 2)) & 255
		elif filter_type == 4:
			for i in range(stride):
				left = row[i - channels] if i >= channels else 0
				up_left = prev[i - channels] if i >= channels else 0
				row[i] = (row[i] + _paeth(left, prev[i], up_left)) & 255
		elif filter_type != 0:
			raise SystemExit(f"{path} has unknown PNG filter {filter_type}")
		rows.append(row)
	rgba = bytearray(width * height * 4)
	for y, row in enumerate(rows):
		for x in range(width):
			i = (y * width + x) * 4
			if color_type == 6:
				base = x * 4
				rgba[i:i + 4] = row[base:base + 4]
			elif color_type == 2:
				base = x * 3
				rgba[i:i + 3] = row[base:base + 3]
				rgba[i + 3] = 255
			elif color_type == 4:
				base = x * 2
				rgba[i:i + 3] = bytes((row[base], row[base], row[base]))
				rgba[i + 3] = row[base + 1]
			elif color_type == 0:
				value = row[x]
				rgba[i:i + 3] = bytes((value, value, value))
				rgba[i + 3] = 255
			else:
				index = row[x]
				rgba[i:i + 3] = palette[index * 3:index * 3 + 3]
				rgba[i + 3] = transparency[index] if index < len(transparency) else 255
	return width, height, rgba


def write_png_rgba(path: Path, width: int, height: int, rgba: bytes) -> None:
	def chunk(tag: bytes, payload: bytes) -> bytes:
		return struct.pack(">I", len(payload)) + tag + payload + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF)

	raw = bytearray()
	stride = width * 4
	for y in range(height):
		raw.append(0)
		raw.extend(rgba[y * stride:(y + 1) * stride])
	path.write_bytes(
		b"\x89PNG\r\n\x1a\n"
		+ chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
		+ chunk(b"IDAT", zlib.compress(bytes(raw), 9))
		+ chunk(b"IEND", b"")
	)


def main() -> None:
	if not SRC.is_file():
		raise SystemExit(f"Missing {SRC}. Supply the AI foreground PNG first.")
	width, height, rgba = read_png_rgba(SRC)
	mono = bytearray(width * height * 4)
	for i in range(width * height):
		alpha = rgba[i * 4 + 3]
		mono[i * 4:i * 4 + 4] = bytes((255, 255, 255, 255 if alpha > ALPHA_CUTOFF else 0))
	DST.parent.mkdir(parents=True, exist_ok=True)
	write_png_rgba(DST, width, height, mono)
	print(f"Wrote {DST}")


if __name__ == "__main__":
	sys.exit(main())
