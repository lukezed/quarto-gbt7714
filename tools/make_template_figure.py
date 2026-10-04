"""Generate the simple workflow figure used by the writing starters (Pillow)."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
image = Image.new('RGB', (1200, 280), 'white')
draw = ImageDraw.Draw(image)
# Pillow's included scalable font keeps the example independent of system fonts.
font = ImageFont.load_default(size=34)
for left, label in ((20, 'Data'), (440, 'Analysis'), (860, 'Interpretation')):
    draw.rounded_rectangle((left, 65, left + 320, 215), radius=8,
                           fill='#f4f4f4', outline='#333333', width=3)
    draw.text((left + 160, 140), label, font=font, fill='#202020', anchor='mm')
for left in (350, 770):
    draw.line((left, 140, left + 76, 140), fill='#333333', width=4)
    draw.polygon(((left + 76, 140), (left + 60, 131), (left + 60, 149)), fill='#333333')
for style in ('manuscript', 'journal'):
    folder = ROOT / 'templates' / style / 'fig'
    folder.mkdir(exist_ok=True)
    image.save(folder / 'workflow.png')
