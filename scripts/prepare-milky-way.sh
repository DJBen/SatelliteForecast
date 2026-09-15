#!/bin/sh
# Requires curl, ffmpeg, and ImageMagick. Keep astronomical registration unchanged.
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
curl -fL 'https://svs.gsfc.nasa.gov/vis/a000000/a004800/a004851/milkyway_2020_4k_gal.exr' -o "$work/source.exr"
printf '%s  %s\n' fad63b36aa632c691d521cd9d8b828de9d29b4c2784276eec44e54c6cb159a49 "$work/source.exr" | shasum -a 256 -c -
ffmpeg -v error -i "$work/source.exr" -frames:v 1 -pix_fmt rgb48be "$work/linear.png"
magick "$work/linear.png" -set colorspace RGB -resize 2048x1024 -blur 0x0.7 -colorspace sRGB -quality 88 "$repo/Frameworks/SatelliteForecast/Impl/Sources/Resources/MilkyWay/milkyway-galactic.jpg"
