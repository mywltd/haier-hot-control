"""Render the geometric heating icon at Windows ICO sizes (requires Pillow)."""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SCALE = 4
BLUE = '#0067C0'
image = Image.new('RGBA', (256 * SCALE, 256 * SCALE))
draw = ImageDraw.Draw(image)

def rect(bounds, radius, fill, outline=None, width=0):
    draw.rounded_rectangle(tuple(n * SCALE for n in bounds), radius * SCALE,
                           fill=fill, outline=outline, width=width * SCALE)

def line(points, color='white', width=12):
    draw.line([(x * SCALE, y * SCALE) for x, y in points], fill=color, width=width * SCALE)
    r = width * SCALE / 2
    for x, y in (points[0], points[-1]):
        draw.ellipse((x*SCALE-r, y*SCALE-r, x*SCALE+r, y*SCALE+r), fill=color)

rect((8, 8, 248, 248), 52, BLUE)
for points in [((56, 98), (56, 176)), ((200, 98), (200, 176)),
               ((56, 116), (200, 116)), ((56, 160), (200, 160)),
               ((91, 200), (91, 208)), ((165, 200), (165, 208))]:
    line(points)
for x in (78, 115, 152):
    rect((x - 6, 82, x + 32, 194), 18, 'white')
    rect((x + 6, 94, x + 20, 182), 6, BLUE)
draw.ellipse(tuple(n * SCALE for n in (172, 44, 196, 68)), fill='#FFD580')
image = image.resize((256, 256), Image.Resampling.LANCZOS)
for path in (ROOT/'assets/app_icon.ico', ROOT/'windows/runner/resources/app_icon.ico'):
    image.save(path, sizes=[(n, n) for n in (16, 32, 48, 64, 128, 256)])
