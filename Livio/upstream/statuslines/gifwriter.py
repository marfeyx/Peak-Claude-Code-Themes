"""Minimal animated GIF89a writer — pure stdlib, no Pillow.

Enough of the format to emit a looping, palette-indexed animation with one
transparent colour:

    Header / Logical Screen Descriptor / Global Colour Table
    NETSCAPE2.0 application extension  (loop forever)
    per frame: Graphic Control Extension, Image Descriptor, LZW image data
    Trailer

`write_gif` takes frames as flat bytes-like index buffers of length width*height.
"""

import struct

MAX_CODE_SIZE = 12


class _BitWriter:
    """LSB-first bit packer, which is the order GIF's LZW stream uses."""

    def __init__(self):
        self.buf = bytearray()
        self.acc = 0
        self.nbits = 0

    def write(self, code, size):
        self.acc |= code << self.nbits
        self.nbits += size
        while self.nbits >= 8:
            self.buf.append(self.acc & 0xFF)
            self.acc >>= 8
            self.nbits -= 8

    def flush(self):
        if self.nbits:
            self.buf.append(self.acc & 0xFF)
            self.acc = 0
            self.nbits = 0
        return bytes(self.buf)


def lzw_encode(indices, min_code_size):
    """GIF-flavoured LZW. Returns the raw code stream (no sub-blocking)."""
    clear = 1 << min_code_size
    eoi = clear + 1

    out = _BitWriter()
    code_size = min_code_size + 1
    table = {}
    next_code = eoi + 1

    out.write(clear, code_size)

    prefix = None
    for value in indices:
        if prefix is None:
            prefix = value
            continue
        key = (prefix, value)
        found = table.get(key)
        if found is not None:
            prefix = found
            continue

        out.write(prefix, code_size)
        if next_code < (1 << MAX_CODE_SIZE):
            table[key] = next_code
            next_code += 1
            # giflib's rule: widen once the next code would not fit. The decoder
            # trails by one entry and widens at `== 1 << code_size`, so encoding
            # with `==` here desynchronises every real decoder.
            if next_code > (1 << code_size) and code_size < MAX_CODE_SIZE:
                code_size += 1
        else:
            out.write(clear, code_size)
            table.clear()
            next_code = eoi + 1
            code_size = min_code_size + 1
        prefix = value

    if prefix is not None:
        out.write(prefix, code_size)
    out.write(eoi, code_size)
    return out.flush()


def lzw_decode(data, min_code_size):
    """Inverse of `lzw_encode`, used by the round-trip self-test."""
    clear = 1 << min_code_size
    eoi = clear + 1

    bits = 0
    nbits = 0
    pos = 0
    code_size = min_code_size + 1
    table = None
    prev = None
    out = bytearray()

    def reset():
        return {i: bytes([i]) for i in range(clear)}, min_code_size + 1, eoi + 1

    table, code_size, next_code = reset()

    while True:
        while nbits < code_size:
            if pos >= len(data):
                return bytes(out)
            bits |= data[pos] << nbits
            nbits += 8
            pos += 1
        code = bits & ((1 << code_size) - 1)
        bits >>= code_size
        nbits -= code_size

        if code == clear:
            table, code_size, next_code = reset()
            prev = None
            continue
        if code == eoi:
            return bytes(out)

        if code in table:
            entry = table[code]
        elif prev is not None:
            entry = prev + prev[:1]
        else:
            raise ValueError("corrupt LZW stream")

        out += entry
        if prev is not None and next_code < (1 << MAX_CODE_SIZE):
            table[next_code] = prev + entry[:1]
            next_code += 1
            if next_code == (1 << code_size) and code_size < MAX_CODE_SIZE:
                code_size += 1
        prev = entry


def _sub_blocks(data):
    out = bytearray()
    for i in range(0, len(data), 255):
        chunk = data[i:i + 255]
        out.append(len(chunk))
        out += chunk
    out.append(0)
    return bytes(out)


def _colour_table(palette):
    """Pad the palette up to the next power of two; returns (bytes, size_bits)."""
    size = 2
    while size < len(palette):
        size <<= 1
    size = max(2, size)
    bits = size.bit_length() - 2      # GCT size field is log2(size) - 1
    table = bytearray()
    for i in range(size):
        r, g, b = palette[i] if i < len(palette) else (0, 0, 0)
        table += bytes((r & 0xFF, g & 0xFF, b & 0xFF))
    return bytes(table), bits


def write_gif(path, width, height, palette, frames, delay_cs=8,
              transparent_index=0, loop=0, disposal=2):
    """Write an animated GIF.

    frames        iterable of index buffers, each width*height bytes
    delay_cs      frame delay in centiseconds (8 = 80 ms)
    transparent_index  palette slot rendered as transparent, or None
    loop          0 = forever
    disposal      2 = clear the frame before the next one is drawn (the right
                  choice whenever frames contain transparent pixels: with 1,
                  "leave in place", every transparent pixel keeps whatever the
                  previous frame painted there and the animation smears until
                  the loop restarts). 1 only pays off for true delta frames.
    """
    table, gct_bits = _colour_table(palette)
    min_code_size = max(2, gct_bits + 1)

    out = bytearray(b"GIF89a")
    packed = 0x80 | (0x70) | gct_bits      # GCT present, 8-bit colour resolution
    out += struct.pack("<HHBBB", width, height, packed, 0, 0)
    out += table

    out += b"\x21\xFF\x0B" + b"NETSCAPE2.0" + b"\x03\x01" + struct.pack("<H", loop) + b"\x00"

    for frame in frames:
        if len(frame) != width * height:
            raise ValueError("frame has %d bytes, expected %d"
                             % (len(frame), width * height))
        flags = (disposal & 0x07) << 2      # bits 2-4 of the GCE packed field
        if transparent_index is not None:
            flags |= 0x01
        out += b"\x21\xF9\x04" + bytes((flags,)) + struct.pack("<H", delay_cs)
        out += bytes((transparent_index or 0,)) + b"\x00"

        out += b"\x2C" + struct.pack("<HHHHB", 0, 0, width, height, 0)
        out += bytes((min_code_size,))
        out += _sub_blocks(lzw_encode(frame, min_code_size))

    out += b"\x3B"

    with open(path, "wb") as fh:
        fh.write(out)
    return len(out)
