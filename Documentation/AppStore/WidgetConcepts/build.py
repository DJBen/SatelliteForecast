"""Build marketing concepts from unchanged native widget renders. Requires Pillow."""
from pathlib import Path
import math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
SOURCES = ROOT / 'Documentation/WidgetPreviews'
W, H = 1320, 2868
TEAL = '#79DFD5'
WHITE = '#F4F7FC'
MUTED = '#A9B9CE'
FONTS = Path('/System/Library/Fonts/Supplemental')

def font(size, bold=False):
    return ImageFont.truetype(str(FONTS / ('Arial Bold.ttf' if bold else 'Arial.ttf')), size)

def text(im, x, y, value, size=42, color=WHITE, bold=False):
    ImageDraw.Draw(im).text((x,y), value, font=font(size,bold), fill=color, spacing=16)

def base(number, category):
    # Procedural editorial backdrop; intentionally no invented astronomical sky.
    small = Image.new('RGB',(330,717))
    px=small.load()
    for y in range(717):
        for x in range(330):
            teal=math.exp(-(((x-320)/240)**2+((y-270)/230)**2))
            violet=math.exp(-(((x-15)/230)**2+((y-620)/190)**2))
            px[x,y]=(int(6+10*teal+17*violet),int(12+28*teal+5*violet),int(24+31*teal+30*violet))
    im=small.resize((W,H),Image.Resampling.BICUBIC).convert('RGBA')
    d=ImageDraw.Draw(im)
    for radius in [700,900,1100]:
        d.ellipse((W-radius,1060-radius,W+radius,1060+radius),outline='#263C4D',width=2)
    d.rounded_rectangle((88,105,605,169),radius=32,fill='#18343F')
    text(im,114,119,'HOME SCREEN WIDGETS',27,TEAL,True)
    d.line((88,2694,1232,2694),fill='#344554',width=2)
    text(im,88,2730,'SPACE STATION PASSES',25,MUTED,True)
    text(im,1050,2730,f'{number} / {category}',23,MUTED)
    return im

def widget(im,name,x,y,width):
    folder='2026-09-25-planets-moon' if name=='large-sky-chart' else '2026-09-25-locales-final'
    card=Image.open(SOURCES/folder/f'{name}.png').convert('RGBA')
    height=round(card.height*width/card.width)
    card=card.resize((width,height),Image.Resampling.LANCZOS)
    shadow=Image.new('RGBA',im.size)
    ImageDraw.Draw(shadow).rounded_rectangle((x,y+30,x+width,y+height+30),radius=width*.09,fill=(0,0,0,125))
    im.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(36)))
    im.alpha_composite(card,(x,y))
    return height

def feature(im,y,n,title,description):
    d=ImageDraw.Draw(im)
    d.ellipse((92,y+4,152,y+64),fill='#24454E')
    text(im,109,y+15,n,27,TEAL,True)
    text(im,184,y,title,43,WHITE,True)
    text(im,184,y+65,description,32,MUTED)

def save(im,name):
    im.convert('RGB').save(HERE/f'{name}.png')

im=base('01','SKY')
text(im,88,248,'Your next pass.\nWritten in the sky.',104,WHITE,True)
text(im,92,526,'See the upcoming flight path\nright on your Home Screen.',43,MUTED)
widget(im,'large-sky-chart',88,774,1144)
feature(im,2070,'1','Know when to step outside','The upcoming pass time, at a glance.')
feature(im,2260,'2','See its path across the sky','A curved track against the surrounding sky.')
text(im,92,2518,'A little more sky in your everyday.',39,TEAL)
save(im,'01-sky-hero')

im=base('02','STYLE')
text(im,88,248,'A little space.\nYour kind of view.',104,WHITE,True)
text(im,92,526,'Choose quick pass times or a simple chart.\nMake room for the details you want.',41,MUTED)
widget(im,'small-stations',88,820,544)
widget(im,'small-chart-tiangong',688,820,544)
text(im,92,1400,'PASS TIMES',29,TEAL,True)
text(im,690,1400,'PASS PROFILE',29,TEAL,True)
text(im,92,1460,'Two stations. One glance.',32,MUTED)
text(im,690,1460,'Choose ISS or Tiangong.',32,MUTED)
widget(im,'medium-stations',88,1680,1144)
text(im,92,2260,'MORE ROOM. MORE DETAIL.',29,TEAL,True)
text(im,92,2320,'Compare upcoming times, heights,\nand directions for both stations.',43,WHITE)
save(im,'02-layout-choices')

im=base('03','GUIDE')
text(im,88,248,'When to look.\nWhere to look.',104,WHITE,True)
text(im,92,526,'Your upcoming pass, explained at a glance.',42,MUTED)
widget(im,'large-sky-chart',120,970,1080)
# External callouts leave the actual widget artwork untouched.
d=ImageDraw.Draw(im)
text(im,730,758,'THE PASS TIME',29,TEAL,True)
text(im,730,806,'Plan your next look up.',31,WHITE)
d.line([(1020,871),(1140,929),(1140,1050)],fill=TEAL,width=3)
d.ellipse((1133,1043,1147,1057),fill=TEAL)
text(im,92,2220,'THE FLIGHT PATH',29,TEAL,True)
text(im,92,2275,'Follow its route across your sky.',35,WHITE)
d.line([(250,2178),(250,2138),(615,1898)],fill=TEAL,width=3)
d.ellipse((608,1891,622,1905),fill=TEAL)
text(im,92,2440,'THE SURROUNDING SKY',29,TEAL,True)
text(im,92,2495,'Stars, visible planets, and the Moon\nput the pass in context.',35,WHITE)
save(im,'03-chart-explained')

sheet=Image.new('RGB',(1320,1020),'#060C18')
for index,name in enumerate(['01-sky-hero','02-layout-choices','03-chart-explained']):
    thumb=Image.open(HERE/f'{name}.png')
    thumb.thumbnail((420,913))
    sheet.paste(thumb,(10+index*440,20))
    ImageDraw.Draw(sheet).text((24+index*440,954),['01 — Sky hero','02 — Layout choices','03 — Chart explained'][index],font=font(23,True),fill=WHITE)
sheet.save(HERE/'concepts-overview.jpg',quality=94)
print('Built three 1320 × 2868 compositions and overview.')
