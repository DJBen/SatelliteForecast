#!/usr/bin/env python3
"""Build the dedicated, sharp 16K Metal sky textures.

Requires ffmpeg, ImageMagick, and ARM astcenc (tested with 5.7.0).
Inputs are deliberately explicit: astronomical images must not be AI-upscaled.
Source URLs and SHA-256 checksums are in PlanetariumCredits.txt.
"""
import argparse
import pathlib
import struct
import subprocess
import tempfile


def run(*arguments):
    subprocess.run(arguments, check=True)


def combine_mips(paths, output):
    identifier = b"\xabKTX 11\xbb\r\n\x1a\n"
    parts = []
    base = None
    for level, path in enumerate(paths):
        data = path.read_bytes()
        if data[:12] != identifier:
            raise ValueError("Not a KTX 1 file")
        header = list(struct.unpack("<13I", data[12:64]))
        if header[0] != 0x04030201 or header[11] != 1:
            raise ValueError("Expected little-endian KTX with one mip")
        if base is None:
            base = header.copy()
        if (header[6], header[7]) != (max(1, base[6] >> level), max(1, base[7] >> level)):
            raise ValueError("Invalid mip dimensions")
        offset = 64 + header[12]
        size = struct.unpack("<I", data[offset:offset + 4])[0]
        payload = data[offset + 4:offset + 4 + size]
        if len(payload) != size:
            raise ValueError("Truncated mip")
        parts.append(struct.pack("<I", size) + payload + b"\0" * (-size % 4))
    base[11], base[12] = len(paths), 0
    output.write_bytes(identifier + struct.pack("<13I", *base) + b"".join(parts))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--milky-way-exr", type=pathlib.Path, required=True)
    parser.add_argument("--astcenc", required=True)
    parser.add_argument("--output-directory", type=pathlib.Path,
                        default=pathlib.Path(__file__).resolve().parents[1] / "Frameworks/SatelliteForecast/Impl/Sources/Resources")
    args = parser.parse_args()
    args.output_directory.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="planetarium-textures-") as folder:
        work = pathlib.Path(folder)
        linear, source = work / "linear.png", work / "mip-0.png"
        run("ffmpeg", "-v", "error", "-i", str(args.milky_way_exr), "-frames:v", "1", "-pix_fmt", "rgb48be", str(linear))
        run("magick", str(linear), "-set", "colorspace", "RGB", "-colorspace", "sRGB", "-depth", "8", str(source))
        # Two 8K tiles retain the native 16K detail on GPUs limited to 8192.
        for tile in range(2):
            tile_source = work / f"tile-{tile}.png"
            run("magick", str(source), "-crop", f"8192x8192+{tile * 8192}+0", "+repage", str(tile_source))
            mips = []
            for level in range(14):
                if level:
                    destination = work / f"tile-{tile}-mip-{level}.png"
                    size = f"{max(1, 8192 >> level)}x{max(1, 8192 >> level)}!"
                    run("magick", str(tile_source), "-colorspace", "RGB", "-resize", size, "-colorspace", "sRGB", str(destination))
                    tile_source = destination
                compressed = work / f"tile-{tile}-mip-{level}.ktx"
                run(args.astcenc, "-cs", str(tile_source), str(compressed), "6x6", "-medium")
                mips.append(compressed)
            combine_mips(mips, args.output_directory / f"planetarium-milkyway-{tile}.ktx")


if __name__ == "__main__":
    main()
