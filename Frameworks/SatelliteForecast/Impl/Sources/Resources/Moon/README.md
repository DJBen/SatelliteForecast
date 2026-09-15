# Lunar albedo texture

Credit: NASA's Scientific Visualization Studio, Ernie Wright; LRO / LROC WAC
mosaic, NASA / GSFC / Arizona State University.

Source: https://svs.gsfc.nasa.gov/4720/
2025 color map: https://svs.gsfc.nasa.gov/vis/a000000/a004700/a004720/lroc_color_2k.jpg

`lunar-albedo.jpg` is a 512 × 256 downsample of this global, north-up,
longitude/latitude texture, with 0° longitude at the center. It is 38 KB.
The app decodes it once and samples it onto a sphere; no image downloads occur
at runtime. The Moon's rendered icon is 96 × 96 pixels, displayed at the
existing chart size (usually 24 points across).
