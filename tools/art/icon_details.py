"""MV-275: authored native 16x16 icon details; ui.icon() applies the outline once.

The first twelve drawings preserve Parames's reviewed samples pixel for pixel.
All other families use the same integer grid, material ramps and dark contours.
No external generation or resampling occurs in the production pipeline.
"""
from PIL import Image, ImageDraw
from .common import PAL, CLEAR

class Pixel:

    def __init__(self):
        self.img = Image.new('RGBA', (16, 16))
        self.d = ImageDraw.Draw(self.img)

    def rect(self, box, c):
        self.d.rectangle(box, fill=PAL[c] if c else CLEAR)

    def line(self, xy, c, width=1):
        self.d.line(xy, fill=PAL[c], width=width)

    def poly(self, xy, c):
        self.d.polygon(xy, fill=PAL[c])

    def ellipse(self, box, c):
        self.d.ellipse(box, fill=PAL[c] if c else CLEAR)

    def px(self, x, y, c):
        self.img.putpixel((x, y), PAL[c] if c else CLEAR)

def power(p):
    p.poly([(8, 1), (5, 6), (3, 9), (7, 9), (5, 14), (12, 6), (8, 6), (10, 1)], 'yellow2')
    p.poly([(8, 2), (6, 6), (7, 6), (6, 8), (5, 8), (8, 3)], 'yellow3')
    p.line([(10, 8), (7, 12)], 'yellow0')
    p.px(8, 7, 'yellow1')

def water(p):
    p.poly([(8, 2), (4, 7), (3, 10), (4, 12), (6, 14), (10, 14), (12, 12), (13, 10), (12, 7)], 'blue2')
    p.poly([(6, 7), (5, 9), (5, 11), (7, 13), (10, 13), (11, 11), (10, 12), (7, 11)], 'blue3')
    p.line([(12, 9), (11, 12), (10, 13)], 'blue1')
    p.rect((6, 8, 6, 10), 'blue4')
    p.px(7, 7, 'blue3')

def food(p):
    p.rect((4, 4, 12, 13), 'gray4')
    p.rect((11, 5, 12, 12), 'gray3')
    p.line([(4, 4), (11, 4)], 'gray6')
    p.line([(4, 13), (11, 13)], 'gray5')
    p.rect((4, 7, 11, 11), 'red2')
    p.rect((10, 7, 11, 11), 'red1')
    p.rect((6, 8, 8, 9), 'cream2')
    p.px(7, 10, 'cream1')
    p.rect((7, 5, 9, 5), 'gray2')
    p.px(8, 4, 'gray3')
    p.px(5, 6, 'gray5')

def scrap(p):
    p.poly([(2, 8), (8, 3), (13, 5), (13, 10), (7, 14), (2, 11)], 'gray3')
    p.poly([(3, 8), (8, 4), (12, 5), (7, 10)], 'gray5')
    p.poly([(3, 10), (7, 12), (12, 8), (12, 10), (7, 13)], 'gray2')
    p.line([(4, 8), (8, 5), (10, 5)], 'gray6')
    p.rect((10, 7, 11, 8), 'orange1')
    p.px(11, 9, 'orange2')
    p.rect((5, 9, 6, 10), 'ol1')
    p.px(5, 9, 'gray1')
    p.px(9, 6, 'gray3')

def fuel(p):
    p.poly([(4, 3), (8, 3), (9, 2), (12, 2), (12, 5), (13, 6), (13, 13), (3, 13), (3, 5)], 'red1')
    p.rect((4, 6, 10, 12), 'red2')
    p.rect((12, 7, 13, 12), 'red0')
    p.rect((4, 3, 7, 5), 'gray3')
    p.rect((5, 4, 6, 4), None)
    p.rect((10, 1, 12, 2), 'gray4')
    p.px(10, 1, 'gray5')
    p.line([(5, 7), (10, 11)], 'red0')
    p.line([(10, 7), (5, 11)], 'red0')
    p.line([(4, 7), (4, 11)], 'red2')
    p.px(5, 12, 'orange1')
    p.px(11, 6, 'orange2')

def medkit(p):
    p.rect((6, 2, 10, 4), 'cream1')
    p.rect((7, 3, 9, 4), None)
    p.rect((3, 5, 12, 13), 'cream2')
    p.rect((12, 6, 13, 12), 'cream0')
    p.line([(4, 5), (11, 5)], 'cream3')
    p.line([(3, 13), (12, 13)], 'cream1')
    p.rect((7, 7, 8, 11), 'red2')
    p.rect((5, 9, 10, 9), 'red2')
    p.px(4, 7, 'cream1')
    p.px(11, 7, 'cream1')
    p.px(4, 12, 'wood1')
    p.px(11, 12, 'wood1')

def rifle(p):
    p.rect((2, 7, 13, 8), 'gray2')
    p.rect((1, 8, 4, 10), 'wood2')
    p.line([(1, 8), (3, 8)], 'wood3')
    p.rect((5, 6, 9, 9), 'gray3')
    p.line([(5, 6), (9, 6)], 'gray5')
    p.rect((10, 6, 14, 7), 'gray2')
    p.line([(11, 6), (14, 6)], 'gray4')
    p.px(12, 5, 'gray3')
    p.rect((5, 10, 6, 11), 'wood1')
    p.rect((9, 9, 10, 12), 'gray2')
    p.line([(9, 10), (9, 11)], 'gray4')
    p.px(7, 9, 'gray1')
    p.px(4, 7, 'wood1')
    p.px(2, 10, 'wood1')

def armor(p):
    p.poly([(4, 2), (6, 2), (7, 4), (9, 4), (10, 2), (12, 2), (13, 6), (12, 7), (12, 13), (4, 13), (4, 7), (3, 6)], 'green2')
    p.rect((5, 4, 5, 8), 'green4')
    p.rect((10, 4, 11, 8), 'green3')
    p.rect((6, 6, 10, 9), 'green3')
    p.line([(6, 6), (9, 6)], 'green4')
    p.line([(8, 7), (8, 12)], 'green1')
    p.rect((5, 10, 7, 12), 'green1')
    p.rect((9, 10, 11, 12), 'green1')
    p.line([(5, 10), (7, 10)], 'green3')
    p.line([(9, 10), (11, 10)], 'green3')
    p.px(8, 5, 'gray5')
    p.line([(4, 13), (12, 13)], 'green0')
    p.px(11, 3, 'green1')

def wrench(p):
    p.poly([(3, 13), (2, 12), (9, 5), (8, 3), (9, 1), (10, 1), (10, 4), (12, 5), (14, 3), (14, 5), (12, 7), (10, 7), (4, 13)], 'gray3')
    p.line([(3, 11), (8, 6)], 'gray5')
    p.line([(9, 2), (9, 3)], 'gray6')
    p.line([(11, 6), (13, 5)], 'gray5')
    p.px(3, 12, 'gray1')
    p.px(6, 9, 'gray4')
    p.px(10, 5, 'gray2')

def gear(p):
    p.ellipse((3, 3, 12, 12), 'gray4')
    for box in ((6, 1, 9, 3), (12, 6, 14, 9), (6, 12, 9, 14), (1, 6, 3, 9), (2, 2, 4, 4), (11, 2, 13, 4), (2, 11, 4, 13), (11, 11, 13, 13)):
        p.rect(box, 'gray3')
    p.line([(6, 2), (9, 2)], 'gray5')
    p.line([(2, 6), (2, 8)], 'gray5')
    p.px(3, 3, 'gray5')
    p.px(12, 3, 'gray4')
    p.px(12, 12, 'gray2')
    p.line([(5, 4), (10, 4)], 'gray5')
    p.line([(4, 5), (4, 9)], 'gray4')
    p.line([(6, 12), (9, 12)], 'gray2')
    p.rect((6, 6, 9, 9), 'gray1')
    p.rect((7, 7, 8, 8), None)
    p.px(11, 10, 'orange1')
    p.px(10, 11, 'orange2')
    p.px(12, 7, 'gray4')

def map_icon(p):
    p.poly([(2, 4), (5, 2), (9, 4), (13, 2), (13, 12), (9, 14), (5, 12), (2, 14)], 'cream2')
    p.poly([(6, 4), (8, 5), (8, 12), (6, 11)], 'cream1')
    p.poly([(10, 5), (12, 4), (12, 11), (10, 12)], 'cream3')
    p.line([(5, 3), (5, 11)], 'cream0')
    p.line([(9, 5), (9, 13)], 'cream0')
    p.line([(3, 11), (4, 9), (7, 9), (8, 7), (11, 7)], 'green2')
    p.rect((11, 5, 12, 6), 'red2')
    p.px(3, 5, 'cream3')
    p.px(12, 10, 'cream1')

def engine(p):
    p.rect((4, 5, 12, 12), 'gray3')
    p.rect((2, 7, 4, 10), 'gray2')
    p.rect((5, 13, 11, 13), 'gray2')
    p.rect((5, 2, 7, 5), 'gray4')
    p.rect((10, 2, 12, 5), 'gray4')
    p.line([(5, 2), (7, 2)], 'gray6')
    p.line([(10, 2), (12, 2)], 'gray5')
    p.rect((8, 3, 9, 4), 'gray3')
    p.line([(5, 7), (11, 7)], 'gray5')
    p.line([(5, 10), (8, 10)], 'gray1')
    p.line([(5, 6), (9, 6)], 'red1')
    p.rect((3, 10, 5, 12), 'orange1')
    p.px(4, 10, 'orange2')
    p.ellipse((9, 8, 12, 11), 'gray1')
    p.rect((10, 9, 11, 10), 'gray4')
    p.px(10, 9, 'gray6')
    p.px(5, 11, 'gray4')

def _weather(p, name):
    if name in ('rain', 'storm', 'acid', 'ash'):
        base, top, shadow = ('toxic1', 'toxic2', 'toxic0') if name == 'acid' else ('gray3', 'gray5', 'blue1' if name == 'rain' else 'gray2')
        p.poly([(2, 5), (4, 5), (4, 3), (6, 2), (10, 2), (12, 4), (13, 4), (13, 7), (2, 7)], base)
        p.line([(5, 3), (9, 3), (11, 4)], top)
        p.line([(3, 7), (12, 7)], shadow)
        if name in ('rain', 'acid'):
            col = 'toxic3' if name == 'acid' else 'blue3'
            for x in (4, 8, 12):
                p.line([(x, 10), (x - 1, 13)], col)
        elif name == 'storm':
            p.poly([(8, 9), (5, 12), (8, 12), (7, 14), (11, 10), (8, 10)], 'yellow2')
            p.px(8, 10, 'yellow1')
        else:
            for x, y in ((3, 11), (7, 13), (11, 10), (5, 14), (12, 13)):
                p.px(x, y, 'gray5')
    elif name == 'snow':
        for a, b in [((8, 2), (8, 14)), ((3, 5), (13, 11)), ((3, 11), (13, 5))]:
            p.line([a, b], 'cream2')
        for a, b in [((6, 3), (8, 5)), ((10, 3), (8, 5)), ((6, 13), (8, 11)), ((10, 13), (8, 11))]:
            p.line([a, b], 'cream1')
        p.px(8, 7, 'cream3')
        p.px(8, 8, 'cream3')
    elif name == 'fog':
        for y, start, end in ((4, 2, 12), (8, 3, 13), (12, 2, 11)):
            p.line([(start, y), (end, y)], 'cream2')
            p.px(start, y, 'cream1')
    elif name == 'sand':
        for y, start in ((4, 2), (8, 4), (12, 3)):
            p.line([(start, y), (12, y), (13, y - 1)], 'yellow2')
            p.px(start + 2, y + 1, 'yellow1')
    elif name == 'sun':
        p.ellipse((5, 5, 11, 11), 'yellow2')
        p.line([(6, 10), (9, 11)], 'yellow1')
        for a, b in [((8, 1), (8, 3)), ((8, 13), (8, 14)), ((1, 8), (3, 8)), ((13, 8), (14, 8)), ((3, 3), (4, 4)), ((12, 12), (13, 13)), ((3, 13), (4, 12)), ((12, 4), (13, 3))]:
            p.line([a, b], 'yellow1')
    elif name == 'moon':
        p.ellipse((3, 2, 12, 13), 'cream2')
        p.ellipse((6, 1, 14, 10), None)
        p.line([(4, 7), (4, 10), (6, 12), (9, 12)], 'cream1')
        p.px(4, 5, 'cream3')

def _symbol(p, name):
    if name in ('happy', 'sad'):
        base, shadow = ('yellow2', 'yellow1') if name == 'happy' else ('orange3', 'orange1')
        p.ellipse((2, 2, 13, 13), base)
        p.line([(3, 10), (5, 12), (10, 12), (12, 10)], shadow)
        p.px(5, 6, 'ol0')
        p.px(10, 6, 'ol0')
        points = [(5, 9), (6, 10), (9, 10), (10, 9)] if name == 'happy' else [(5, 11), (6, 10), (9, 10), (10, 11)]
        p.line(points, 'ol0')
    elif name == 'pause':
        for x in (3, 10):
            p.rect((x, 3, x + 2, 13), 'cream2')
            p.line([(x, 3), (x, 12)], 'cream3')
            p.line([(x + 2, 4), (x + 2, 13)], 'cream1')
    elif name == 'play':
        p.poly([(4, 3), (12, 8), (4, 13)], 'green3')
        p.line([(4, 4), (4, 12)], 'green4')
        p.line([(6, 11), (10, 9)], 'green1')
    elif name == 'close':
        p.line([(3, 3), (12, 12)], 'red2', 2)
        p.line([(12, 3), (3, 12)], 'red2', 2)
        p.px(4, 4, 'red1')
        p.px(11, 11, 'red1')
    elif name == 'flee':
        p.poly([(2, 8), (7, 3), (7, 6), (13, 6), (13, 10), (7, 10), (7, 13)], 'yellow2')
        p.line([(8, 9), (12, 9)], 'yellow1')
    elif name == 'up':
        p.poly([(8, 2), (3, 7), (6, 7), (6, 13), (10, 13), (10, 7), (13, 7)], 'green3')
        p.line([(7, 8), (7, 12)], 'green4')
        p.line([(9, 8), (9, 12)], 'green1')
    elif name == 'heal':
        p.rect((6, 3, 9, 13), 'green3')
        p.rect((3, 6, 13, 9), 'green3')
        p.line([(7, 4), (7, 6)], 'green4')
        p.line([(4, 7), (5, 7)], 'green4')
        p.line([(10, 9), (13, 9)], 'green1')
    elif name in ('agi', 'dodge'):
        if name == 'agi':
            p.poly([(3, 12), (8, 4), (8, 8), (13, 3), (10, 12), (10, 8), (7, 12)], 'teal2')
            p.line([(5, 10), (7, 7)], 'teal3')
        else:
            for x, col in ((2, 'teal1'), (6, 'teal2'), (10, 'teal3')):
                p.line([(x, 13), (x + 2, 9), (x + 3, 4)], col)
    elif name in ('xp', 'crown'):
        if name == 'xp':
            p.poly([(8, 2), (10, 6), (14, 6), (11, 9), (12, 14), (8, 11), (4, 14), (5, 9), (2, 6), (6, 6)], 'yellow2')
            p.line([(5, 7), (7, 7), (8, 4)], 'yellow1')
        else:
            p.poly([(2, 12), (2, 5), (5, 8), (8, 3), (11, 8), (14, 5), (14, 12)], 'yellow2')
            p.line([(3, 11), (13, 11)], 'yellow1')
            p.px(8, 9, 'red3')
    elif name == 'rad':
        p.ellipse((2, 2, 13, 13), 'yellow2')
        for start in (65, 185, 305):
            p.d.pieslice((3, 3, 12, 12), start, start + 50, fill=PAL['ol0'])
        p.ellipse((6, 6, 9, 9), 'yellow1')
        p.rect((7, 7, 8, 8), 'ol0')
    elif name == 'chat':
        p.rect((2, 3, 13, 10), 'green4')
        p.poly([(4, 10), (4, 13), (7, 10)], 'green4')
        p.line([(3, 10), (12, 10)], 'green3')
        for x in (4, 7, 10):
            p.px(x, 6, 'ol0')
    elif name == 'explore':
        p.poly([(3, 13), (6, 5), (8, 2), (10, 5), (13, 13), (8, 10)], 'orange2')
        p.line([(8, 4), (8, 9)], 'orange3')
        p.px(8, 5, 'yellow2')
    elif name == 'signal':
        p.line([(8, 7), (8, 13)], 'gray5')
        p.line([(6, 14), (10, 14)], 'gray3')
        p.px(8, 5, 'red3')
        p.line([(5, 4), (5, 3), (6, 2)], 'green3')
        p.line([(10, 2), (11, 3), (11, 4)], 'green3')
        p.line([(2, 5), (2, 3), (4, 1)], 'green4')
        p.line([(12, 1), (14, 3), (14, 5)], 'green4')

def _person(p, name):
    if name == 'people':
        p.rect((3, 8, 8, 13), 'blue2')
        p.ellipse((3, 3, 7, 7), 'blue3')
        p.line([(3, 9), (3, 12)], 'blue3')
        p.rect((9, 9, 13, 13), 'red2')
        p.ellipse((9, 4, 13, 8), 'red3')
        p.px(10, 5, 'red2')
    elif name in ('str', 'fist'):
        if name == 'str':
            p.poly([(3, 9), (3, 12), (12, 12), (13, 9), (11, 7), (8, 7), (8, 3), (5, 3), (5, 9)], 'skin2')
            p.line([(6, 4), (6, 9), (4, 10)], 'skin3')
            p.line([(9, 10), (11, 10), (12, 9)], 'skin1')
        else:
            p.rect((4, 5, 12, 11), 'skin2')
            p.rect((4, 11, 8, 13), 'skin1')
            p.rect((3, 8, 5, 10), 'skin3')
            for x in (5, 8, 11):
                p.line([(x, 5), (x, 7)], 'skin1')
            p.line([(5, 9), (10, 9)], 'skin3')
    elif name == 'int':
        p.ellipse((3, 3, 12, 12), 'pink2')
        p.rect((6, 12, 9, 13), 'pink1')
        p.line([(8, 4), (8, 11)], 'pink0')
        p.line([(5, 4), (4, 6), (6, 7), (5, 10)], 'pink1')
        p.line([(10, 5), (11, 7), (9, 9), (11, 10)], 'pink3')
    elif name == 'skull':
        p.ellipse((3, 2, 12, 11), 'cream2')
        p.rect((5, 10, 10, 13), 'cream2')
        p.line([(4, 4), (5, 3), (9, 3)], 'cream3')
        p.rect((5, 6, 6, 8), 'ol0')
        p.rect((9, 6, 10, 8), 'ol0')
        p.px(8, 10, 'cream0')
        p.px(6, 12, 'cream0')
        p.px(9, 12, 'cream0')
    elif name == 'eye':
        p.poly([(2, 8), (5, 5), (10, 5), (13, 8), (10, 11), (5, 11)], 'cream2')
        p.line([(4, 7), (6, 6), (10, 6)], 'cream3')
        p.ellipse((6, 5, 10, 11), 'teal2')
        p.rect((8, 7, 9, 9), 'ol0')
        p.px(7, 6, 'gray6')
    elif name == 'dog':
        p.rect((6, 7, 12, 10), 'wood3')
        p.poly([(2, 7), (3, 5), (5, 5), (6, 7), (7, 10), (4, 10), (3, 9), (2, 9)], 'wood3')
        p.px(3, 5, 'wood1')
        p.px(3, 7, 'ol0')
        p.px(2, 8, 'wood0')
        p.px(6, 10, 'wood4')
        p.line([(6, 11), (6, 13)], 'wood2')
        p.line([(11, 11), (11, 13)], 'wood2')
        p.line([(12, 7), (14, 5), (14, 4)], 'wood2')

def _paper(p, name):
    if name == 'book':
        p.rect((3, 3, 12, 13), 'orange2')
        p.rect((5, 3, 11, 11), 'cream2')
        p.line([(3, 3), (3, 12)], 'orange0')
        p.line([(5, 4), (10, 4)], 'cream3')
        p.line([(6, 7), (9, 7)], 'cream1')
        p.line([(6, 9), (10, 9)], 'cream1')
        p.rect((9, 2, 10, 5), 'red3')
    elif name == 'blueprint':
        p.rect((2, 3, 13, 13), 'blue2')
        p.rect((2, 3, 4, 13), 'blue1')
        p.line([(3, 3), (3, 12)], 'blue3')
        for y in (5, 9, 12):
            p.line([(5, y), (12, y)], 'blue3')
        p.rect((7, 6, 11, 10), 'gray6')
        p.rect((8, 7, 10, 9), 'blue2')
        p.px(12, 4, 'blue4')
    elif name == 'chest':
        p.rect((2, 7, 13, 13), 'wood2')
        p.rect((2, 4, 13, 6), 'wood3')
        p.line([(3, 4), (12, 4)], 'wood4')
        p.line([(3, 11), (12, 11)], 'wood1')
        p.line([(4, 5), (4, 12)], 'gray2')
        p.line([(11, 5), (11, 12)], 'gray2')
        p.rect((7, 7, 8, 9), 'yellow2')
        p.px(7, 7, 'gray5')
    elif name == 'seed':
        p.ellipse((4, 9, 12, 13), 'wood3')
        p.line([(6, 10), (9, 10)], 'gray5')
        p.line([(8, 9), (8, 4)], 'green3')
        p.poly([(7, 6), (4, 3), (7, 3), (8, 5)], 'green3')
        p.poly([(9, 4), (12, 2), (12, 4), (9, 6)], 'green4')
    elif name == 'charm':
        p.line([(8, 2), (8, 5)], 'gray5')
        p.ellipse((4, 5, 12, 13), 'green3')
        p.ellipse((6, 7, 10, 11), 'green4')
        p.line([(7, 9), (9, 9)], 'green2')
        p.px(6, 6, 'gray6')

def _medicine(p, name):
    if name in ('pill', 'radaway'):
        base, lit, dark = ('gray5', 'gray6', 'gray3') if name == 'pill' else ('yellow1', 'yellow2', 'yellow0')
        p.rect((5, 2, 11, 4), 'gray5')
        p.line([(6, 2), (10, 2)], 'gray6' if name == 'pill' else 'gray5')
        p.rect((4, 5, 12, 13), base)
        p.line([(4, 6), (4, 12)], lit)
        p.line([(12, 6), (12, 13)], dark)
        if name == 'pill':
            p.rect((5, 8, 11, 11), 'cream2')
            p.rect((7, 8, 8, 10), 'red2')
        else:
            p.rect((5, 7, 11, 11), 'ol0')
            p.px(8, 8, 'yellow2')
            p.px(6, 10, 'yellow2')
            p.px(10, 10, 'yellow2')
    elif name == 'stimpack':
        p.line([(3, 12), (10, 5)], 'cream2', 3)
        p.line([(4, 11), (10, 5)], 'cream3')
        p.line([(11, 4), (13, 2)], 'gray5')
        p.line([(2, 12), (4, 14)], 'gray3')
        p.rect((6, 8, 7, 9), 'red2')
        p.px(4, 10, 'cream0')
    elif name == 'thermo':
        p.rect((7, 2, 9, 10), 'cream2')
        p.ellipse((5, 9, 11, 14), 'red2')
        p.line([(8, 5), (8, 11)], 'red2')
        p.px(7, 3, 'cream3')
        p.px(7, 12, 'red1')
        p.px(10, 5, 'gray3')
        p.px(10, 8, 'gray3')
    elif name == 'supply':
        p.rect((2, 8, 6, 13), 'red2')
        p.line([(2, 8), (6, 8)], 'gray6')
        p.line([(2, 13), (6, 13)], 'gray3')
        p.rect((10, 3, 12, 4), 'gray5')
        p.poly([(10, 5), (12, 5), (13, 7), (13, 13), (9, 13), (9, 7)], 'blue2')
        p.line([(10, 7), (10, 11)], 'gray5')
    elif name == 'meat':
        p.rect((10, 10, 13, 11), 'gray6')
        p.px(13, 9, 'gray6')
        p.px(13, 12, 'gray6')
        p.ellipse((3, 4, 11, 11), 'red2')
        p.poly([(5, 5), (8, 5), (10, 7), (8, 9), (6, 9), (5, 8)], 'red3')
        p.px(5, 6, 'gray5')
    elif name == 'can':
        p.rect((5, 4, 11, 13), 'gray5')
        p.line([(5, 4), (11, 4)], 'gray6')
        p.line([(11, 5), (11, 12)], 'gray3')
        p.rect((5, 7, 10, 10), 'red2')
        p.rect((9, 7, 10, 10), 'gray3')
        p.line([(5, 13), (10, 13)], 'gray3')

def _weapon(p, name):
    if name in ('pistol', 'smg', 'shotgun', 'laser'):
        if name == 'pistol':
            p.rect((3, 5, 12, 7), 'gray3')
            p.rect((4, 8, 6, 12), 'wood2')
            p.line([(4, 5), (11, 5)], 'gray5')
            p.px(12, 6, 'gray1')
            p.line([(4, 9), (4, 11)], 'gray3')
        elif name == 'smg':
            p.rect((4, 5, 12, 7), 'gray2')
            p.rect((2, 6, 4, 8), 'gray1')
            p.rect((7, 8, 8, 12), 'gray3')
            p.rect((4, 8, 5, 10), 'gray2')
            p.line([(5, 5), (11, 5)], 'gray4')
            p.px(12, 5, 'gray5')
            p.px(7, 10, 'gray1')
        elif name == 'shotgun':
            p.rect((2, 6, 14, 7), 'gray3')
            p.poly([(2, 8), (5, 8), (5, 10), (2, 11)], 'wood2')
            p.rect((9, 8, 12, 9), 'wood3')
            p.line([(6, 6), (13, 6)], 'gray5')
            p.px(10, 8, 'wood2')
            p.px(12, 8, 'wood2')
        else:
            p.rect((2, 6, 13, 8), 'gray6')
            p.rect((4, 9, 6, 11), 'gray3')
            p.line([(5, 7), (12, 7)], 'teal2')
            p.px(13, 7, 'teal3')
            p.px(3, 8, 'blue2')
    elif name == 'ammo':
        for x in (3, 7, 11):
            p.poly([(x, 5), (x + 1, 3), (x + 2, 5), (x + 2, 13), (x, 13)], 'yellow1')
            p.line([(x, 7), (x, 12)], 'yellow2')
            p.rect((x, 5, x + 2, 6), 'orange3')
            p.line([(x, 13), (x + 2, 13)], 'yellow0')
    elif name == 'sword':
        p.poly([(5, 10), (11, 3), (13, 2), (13, 4), (7, 11)], 'gray5')
        p.line([(7, 8), (12, 3)], 'gray6')
        p.line([(3, 9), (7, 13)], 'yellow2', 2)
        p.line([(3, 13), (5, 11)], 'orange1', 2)
    elif name == 'hammer':
        p.line([(3, 13), (10, 6)], 'orange1', 2)
        p.line([(4, 12), (8, 8)], 'wood3')
        p.poly([(7, 4), (11, 2), (14, 5), (12, 7)], 'gray3')
        p.line([(8, 4), (11, 3), (13, 5)], 'gray5')
        p.px(11, 6, 'gray1')

def _vest(p, name):
    base, shadow, lit = {'jacket': ('orange2', 'orange0', 'orange3'), 'mail': ('gray3', 'gray2', 'gray5'), 'riot': ('blue1', 'blue0', 'blue3'), 'powerframe': ('yellow1', 'gray2', 'yellow2')}[name]
    p.poly([(4, 3), (6, 3), (7, 5), (9, 5), (10, 3), (12, 3), (13, 6), (11, 7), (11, 13), (5, 13), (5, 7), (3, 6)], base)
    p.line([(5, 4), (5, 6)], lit)
    p.line([(11, 4), (11, 6)], lit)
    p.line([(8, 6), (8, 12)], shadow)
    if name == 'jacket':
        p.rect((5, 9, 7, 11), shadow)
        p.line([(5, 9), (7, 9)], lit)
    elif name == 'mail':
        for x, y in ((6, 7), (10, 8), (6, 10), (10, 11)):
            p.px(x, y, lit)
    elif name == 'riot':
        p.rect((6, 7, 10, 10), lit)
        p.line([(6, 10), (10, 10)], shadow)
    else:
        p.rect((6, 7, 10, 10), shadow)
        p.rect((7, 8, 9, 9), lit)
        p.line([(5, 12), (11, 12)], shadow)

def _helmet(p, name):
    base, shadow, lit = {'hardhat': ('yellow2', 'yellow0', 'yellow1'), 'helmet': ('green2', 'green1', 'green3'), 'visor': ('gray4', 'gray2', 'gray5'), 'gasmask': ('green1', 'green0', 'green3')}[name]
    if name == 'gasmask':
        p.ellipse((4, 3, 12, 12), base)
        p.rect((4, 6, 6, 8), shadow)
        p.rect((10, 6, 12, 8), shadow)
        p.px(5, 6, lit)
        p.px(11, 6, lit)
        p.rect((7, 10, 10, 14), 'gray3')
        p.line([(7, 12), (10, 12)], 'gray2')
        return
    p.poly([(3, 10), (3, 7), (4, 4), (6, 3), (10, 3), (12, 5), (13, 10)], base)
    p.line([(5, 5), (6, 4), (9, 4)], lit)
    p.line([(3, 11), (13, 11)], shadow)
    p.line([(2, 10), (14, 10)], base)
    if name == 'hardhat':
        p.line([(8, 3), (8, 9)], lit)
    elif name == 'visor':
        p.rect((5, 8, 11, 9), 'teal2')
        p.px(5, 8, 'gray6')

def _boot(p, name):
    base, shadow, lit = {'boots': ('sand2', 'wood1', 'gray6'), 'workboots': ('wood3', 'wood1', 'wood4'), 'tacboots': ('gray2', 'green1', 'gray5'), 'jetboots': ('gray4', 'gray2', 'gray6')}[name]
    p.poly([(6, 3), (11, 3), (11, 11), (12, 11), (12, 13), (2, 13), (2, 11), (5, 10), (5, 4)], base)
    p.line([(6, 4), (10, 4)], lit)
    p.line([(3, 11), (5, 11)], lit)
    p.line([(2, 13), (12, 13)], shadow)
    p.line([(6, 7), (10, 7)], shadow)
    if name == 'workboots':
        p.line([(3, 12), (5, 12)], shadow)
    elif name == 'tacboots':
        p.rect((8, 5, 9, 8), 'green1')
        p.px(3, 12, 'green0')
    elif name == 'jetboots':
        p.px(10, 14, 'yellow2')
        p.px(11, 14, 'red2')

def _pack(p, name):
    base, shadow, lit = {'backpack': ('red2', 'red1', 'skin1'), 'hikingpack': ('blue2', 'blue1', 'blue3'), 'ruck': ('green2', 'green1', 'green3'), 'framepack': ('orange2', 'orange0', 'orange3')}[name]
    p.rect((4, 5, 12, 13), base)
    p.rect((6, 2, 10, 4), shadow)
    p.rect((7, 3, 9, 4), None)
    p.line([(4, 6), (4, 11)], lit)
    p.rect((6, 9, 10, 12), shadow)
    p.line([(6, 9), (10, 9)], lit)
    p.line([(5, 6), (5, 8)], shadow)
    p.line([(11, 6), (11, 8)], shadow)
    if name in ('ruck', 'hikingpack', 'framepack'):
        roll = 'yellow2' if name == 'hikingpack' else 'green2' if name == 'framepack' else 'green1'
        p.rect((3, 2, 13, 4), roll)
        p.px(5, 3, shadow)
        p.px(11, 3, shadow)
    if name == 'framepack':
        p.line([(2, 4), (2, 14), (14, 14), (14, 4)], 'gray3')
        p.px(2, 5, 'gray5')

def _mechanical(p, name):
    if name in ('hull', 'shield'):
        base, shadow, lit = ('gray3', 'gray2', 'gray5') if name == 'hull' else ('blue2', 'blue1', 'blue3')
        p.poly([(8, 2), (13, 4), (12, 10), (8, 14), (4, 10), (3, 4)], base)
        p.poly([(8, 4), (11, 5), (10, 10), (8, 12)], shadow)
        p.line([(5, 5), (7, 4)], lit)
        p.px(5, 8, lit)
        p.px(11, 6, lit)
    elif name == 'plates':
        p.rect((2, 5, 8, 13), 'gray3')
        p.rect((8, 3, 13, 11), 'gray4')
        p.line([(3, 5), (7, 5)], 'gray5')
        p.line([(9, 3), (12, 3)], 'gray6')
        for x, y in ((3, 7), (6, 11), (9, 5), (12, 9)):
            p.px(x, y, 'gray6')
    elif name == 'lock':
        p.rect((4, 7, 12, 13), 'yellow1')
        p.line([(5, 8), (5, 12)], 'yellow2')
        p.line([(12, 8), (12, 12)], 'yellow0')
        p.line([(5, 6), (5, 4), (6, 3), (9, 3), (10, 4), (10, 6)], 'gray5')
        p.rect((7, 9, 8, 10), 'ol0')
        p.px(8, 11, 'ol0')
    elif name == 'zoom':
        p.line([(10, 10), (13, 13)], 'wood2', 3)
        p.ellipse((2, 2, 11, 11), 'gray4')
        p.ellipse((4, 4, 9, 9), 'blue2')
        p.line([(4, 5), (5, 4), (7, 4)], 'gray6')
    elif name == 'chip':
        p.rect((4, 4, 12, 12), 'green2')
        p.rect((6, 6, 10, 10), 'ol1')
        p.line([(6, 6), (9, 6)], 'gray3')
        for x in (5, 8, 11):
            p.line([(x, 2), (x, 3)], 'yellow2')
            p.line([(x, 13), (x, 14)], 'yellow2')
        p.px(8, 8, 'red3')
    elif name in ('cog', 'saw'):
        base, lit, shadow = ('orange2', 'orange3', 'orange0') if name == 'cog' else ('gray4', 'gray6', 'gray2')
        p.ellipse((3, 3, 12, 12), base)
        for box in ((6, 1, 9, 3), (12, 6, 14, 9), (6, 12, 9, 14), (1, 6, 3, 9), (2, 2, 4, 4), (11, 2, 13, 4), (2, 11, 4, 13), (11, 11, 13, 13)):
            p.rect(box, base)
        p.line([(5, 4), (10, 4)], lit)
        p.rect((6, 6, 9, 9), shadow)
        p.rect((7, 7, 8, 8), None)
        p.line([(7, 12), (10, 11)], shadow)
    elif name == 'spikes':
        p.line([(3, 2), (3, 14)], 'gray2')
        for y in (3, 7, 11):
            p.poly([(4, y - 1), (13, y + 1), (4, y + 2)], 'gray3')
            p.line([(5, y), (10, y + 1)], 'gray5')
    elif name == 'plow':
        p.poly([(3, 3), (11, 5), (13, 13), (3, 13)], 'yellow2')
        p.line([(4, 6), (11, 7)], 'orange1')
        p.line([(4, 9), (12, 10)], 'orange1')
        p.line([(3, 13), (13, 13)], 'gray2')
    elif name in ('turret', 'harpoon', 'tesla'):
        p.rect((3, 12, 13, 14), 'gray2')
        p.line([(4, 12), (12, 12)], 'gray3')
        if name == 'tesla':
            p.rect((7, 5, 9, 11), 'blue2')
            for y in (6, 8, 10):
                p.line([(6, y), (10, y)], 'gray3')
            p.ellipse((5, 2, 11, 5), 'teal2')
            p.line([(6, 2), (9, 2)], 'teal3')
        else:
            base = 'green2' if name == 'turret' else 'orange2'
            p.rect((5, 6, 10, 11), base)
            p.line([(5, 6), (9, 6)], 'green3' if name == 'turret' else 'orange3')
            if name == 'turret':
                p.rect((10, 7, 14, 8), 'ol1')
                p.px(13, 7, 'gray3')
            else:
                p.line([(10, 8), (14, 8)], 'gray5')
                p.poly([(12, 6), (14, 8), (12, 10)], 'gray6')
# MV-524 / MV-525 / MV-526: the approved main-stat icons (STR fist, INT lightbulb, AGI zigzag), stored as the
# reviewed native pixels (tools/art/micro/previews/main-stat-icons-final/ic_<stat>-native.png) so a regeneration reproduces
# them exactly. They are finished icons whose dark edge is part of the drawing: ui.icon() ships them without adding
# the usual soot ring (NATIVE_FINAL), and verify_icons expects the same.
_NATIVE = {
    'str': ({'a': 'gray1', 'b': 'ol0', 'c': 'skin0', 'd': 'skin1', 'e': 'skin2', 'f': 'skin3'}, [
        '................',
        '......aaa.......',
        '...cccefdcc.....',
        '...cfededefcdc..',
        '...ceededeededa.',
        '...cdddedeedeea.',
        '..addecdcdddeda.',
        '.aefffeeedcddda.',
        '.afeeeeeedeeecb.',
        '.aeeedddddeeec..',
        '..cddccdeeeeec..',
        '...acddddeeec...',
        '....acdddddcb...',
        '....bcdddda.....',
        '....baaaaab.....',
        '................',
    ]),
    'int': ({'a': 'gray1', 'b': 'gray3', 'c': 'gray5', 'd': 'lamp0', 'e': 'lamp1', 'f': 'ol0', 'g': 'yellow1'}, [
        '................',
        '.....aaaaa......',
        '....bgddddb.....',
        '...agddddedb....',
        '...bgdddddeg....',
        '..agdddddddda...',
        '..agdddedddda...',
        '..aggddddddga...',
        '...aggdddddb....',
        '....bggggga.....',
        '.....agdgb......',
        '.....fabaf......',
        '.....fbcbf......',
        '.....fabaf......',
        '......aaa.......',
        '................',
    ]),
    'agi': ({'a': 'lamp0', 'b': 'ol0', 'c': 'yellow1', 'd': 'yellow2'}, [
        '................',
        '.........c......',
        '........cd......',
        '.......cad......',
        '......cadb......',
        '.....cadb.......',
        '....cadb........',
        '....cadcccb.....',
        '....bcccaac.....',
        '.......cad......',
        '......cadc......',
        '.....cadc.......',
        '.....adb........',
        '.....dc.........',
        '.....b..........',
        '................',
    ]),
}
NATIVE_FINAL = frozenset(_NATIVE)


def _native(name):
    legend, rows = _NATIVE[name]

    def paint(p):
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                if ch != '.':
                    p.px(x, y, legend[ch])
    return paint

_APPROVED = dict(power=power, water=water, food=food, scrap=scrap, fuel=fuel, medkit=medkit, rifle=rifle, armor=armor, wrench=wrench, gear=gear, map=map_icon, engine=engine)
_APPROVED.update({k: _native(k) for k in _NATIVE})   # MV-524..526: replaces the old arm / brain / speed-lines drawings
_FAMILIES = {_weather: 'rain storm acid ash snow fog sand sun moon', _symbol: 'happy sad pause play close flee up heal agi dodge xp crown rad chat explore signal', _person: 'people str fist int skull eye dog', _paper: 'book blueprint chest seed charm', _medicine: 'pill radaway stimpack thermo supply meat can', _weapon: 'pistol smg shotgun laser ammo sword hammer', _vest: 'jacket mail riot powerframe', _helmet: 'hardhat helmet visor gasmask', _boot: 'boots workboots tacboots jetboots', _pack: 'backpack hikingpack ruck framepack', _mechanical: 'hull shield plates lock zoom chip cog saw spikes plow turret harpoon tesla'}
NAMES = frozenset(_APPROVED) | frozenset((n for names in _FAMILIES.values() for n in names.split()))

def draw(image, name):
    """Draw raw integer-pixel material clusters; the existing caller adds one outline."""
    p = Pixel()
    if name in _APPROVED:
        _APPROVED[name](p)
    else:
        for renderer, names in _FAMILIES.items():
            if name in names.split():
                renderer(p, name)
                break
        else:
            raise ValueError(f'No MV-275 icon renderer: {name}')
    image.paste(p.img, (0, 0))
