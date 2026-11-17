"""There I render six deterministic cyberpunk wallpapers with NumPy and Pillow.

This work made by Anfinogentov Nikita

There I run the collection with python scripts/wallpapers/make_wallpapers.py wallpapers.
There I select a scene with --only 01-neon-grid and dimensions with --size 1920x1080.
There I use independent fixed seeds, JPEG quality 92, and full-resolution film dither.
There I reproduce the repository images with numpy 2.2.6 and Pillow 12.3.0.
"""

import argparse
import math
from pathlib import Path
import time

import numpy
from PIL import Image, ImageChops, ImageDraw, ImageFilter


cyan = (0, 229, 255)
magenta = (255, 43, 214)
mint = (122, 255, 212)
amber = (255, 158, 63)


def pigment(rgb, intensity=1):
    """There I scale light without changing its hue."""
    return tuple(max(0, min(255, round(channel * intensity))) for channel in rgb)


def blend(first, second, position):
    """There I interpolate two display colours."""
    return tuple(round(a + (b - a) * position) for a, b in zip(first, second))


class canvas:
    """There I combine atmospheric fields, opaque geometry, and scattered light."""

    def __init__(self, width, height, seed):
        """There I use a 1920 by 1080 drawing space and independent random streams."""
        self.width = width
        self.height = height
        self.scale = width / 1920
        self.vertical = height / 1080
        self.random = numpy.random.default_rng(seed)
        self.seed = seed
        self.image = Image.new("RGB", (width, height), (5, 4, 10))
        self.light = Image.new("RGB", (width, height))

    def points(self, points):
        """There I translate design coordinates to output pixels."""
        return [(round(x * self.scale), round(y * self.vertical)) for x, y in points]

    def line(self, points, rgb, width=1, light=True):
        """There I draw continuous traces at native output resolution."""
        target = self.light if light else self.image
        ImageDraw.Draw(target).line(self.points(points), fill=rgb,
                                    width=max(1, round(width * self.scale)), joint="curve")

    def box(self, bounds, rgb, light=True):
        """There I draw architectural details and small luminous fragments."""
        target = self.light if light else self.image
        ImageDraw.Draw(target).rectangle(self.points([(bounds[0], bounds[1]),
                                                      (bounds[2], bounds[3])]), fill=rgb)

    def circle(self, x, y, radius, rgb, width=0, light=True):
        """There I draw small light sources and plated circuit nodes."""
        target = self.light if light else self.image
        bounds = self.points([(x - radius, y - radius), (x + radius, y + radius)])
        draw = ImageDraw.Draw(target)
        if width:
            draw.ellipse(bounds, outline=rgb, width=max(1, round(width * self.scale)))
        else:
            draw.ellipse(bounds, fill=rgb)

    def polygon(self, points, rgb):
        """There I occlude distant architecture with solid foreground silhouettes."""
        ImageDraw.Draw(self.image).polygon(self.points(points), fill=rgb)

    def fog(self, x, y, rx, ry, rgb, strength):
        """There I evaluate smooth atmospheric illumination on a small canvas."""
        width = max(1, self.width // 4)
        height = max(1, self.height // 4)
        xx = numpy.linspace(0, 1920, width, dtype=numpy.float32)[None, :]
        yy = numpy.linspace(0, 1080, height, dtype=numpy.float32)[:, None]
        field = numpy.exp(-2 * (((xx - x) / rx) ** 2 + ((yy - y) / ry) ** 2))
        pixels = field[..., None] * numpy.array(rgb, dtype=numpy.float32) * strength
        veil = Image.fromarray(numpy.uint8(numpy.clip(pixels, 0, 255)))
        self.image = ImageChops.screen(self.image, veil.resize(self.image.size,
                                                             Image.Resampling.BILINEAR))

    def expose(self, strength=1, broad=1):
        """There I scatter light at three scales before adding its sharp source."""
        # There I retain thin emitters at full resolution before downsampling bloom.
        near = self.light.filter(ImageFilter.GaussianBlur(2.2 * self.scale))
        self.image = ImageChops.screen(self.image, near.point(lambda p: round(p * .38)))
        small = self.light.resize((max(1, self.width // 4), max(1, self.height // 4)),
                                  Image.Resampling.BOX)
        for radius, gain in ((5, .65), (23, .48 * broad)):
            glow = small.filter(ImageFilter.GaussianBlur(radius * self.scale))
            glow = glow.point(lambda p: min(255, round(p * gain)))
            self.image = ImageChops.screen(self.image, glow.resize(self.image.size,
                                                                  Image.Resampling.BILINEAR))
        self.image = ImageChops.screen(self.image,
                                      self.light.point(lambda p: min(255, round(p * strength))))
        self.light = Image.new("RGB", self.image.size)


def rain(scene, count, strength=1):
    """There I separate distant misting rain from occasional sharp foreground drops."""
    rng = scene.random
    for index in range(count):
        x, y = rng.uniform(-60, 1980), rng.uniform(-80, 1120)
        length = rng.uniform(7, 34) if index % 7 else rng.uniform(35, 90)
        tone = blend(cyan, magenta, float(rng.uniform(.15, .85)))
        gain = rng.uniform(.025, .12) * strength
        scene.line([(x, y), (x - length * .36, y + length)], pigment(tone, gain),
                   .6 if index % 7 else 1)


def neon_grid(scene):
    """There I suspend a cut sunset above a receding electric grid and black hills."""
    rng = scene.random
    horizon = 639
    scene.fog(1250, 530, 800, 340, magenta, .14)
    scene.fog(1240, 630, 850, 110, amber, .14)
    scene.fog(1540, 820, 1100, 450, cyan, .045)
    for index in range(280):
        x, y = rng.uniform(35, 1890), rng.uniform(50, 600)
        intensity = rng.uniform(.1, .43) * (1 - y / 760)
        scene.circle(x, y, rng.choice([.35, .45, .65, .9]),
                     pigment((140, 181, 217), intensity))
    scene.expose()
    # There I cut progressively wider black gaps into a true circular sunset.
    disc = Image.new("RGB", scene.image.size)
    mask = Image.new("L", scene.image.size)
    bounds = scene.points([(1030, 215), (1430, 615)])
    ImageDraw.Draw(mask).ellipse(bounds, fill=255)
    draw = ImageDraw.Draw(disc)
    for y in range(round(215 * scene.vertical), round(616 * scene.vertical)):
        position = (y / scene.vertical - 215) / 400
        draw.line([(0, y), (scene.width, y)], fill=blend(magenta, amber, position))
    cut = ImageDraw.Draw(mask)
    for y, gap in ((370, 3), (397, 5), (426, 7), (457, 10), (491, 14),
                   (527, 18), (566, 24), (603, 16)):
        cut.rectangle(scene.points([(1010, y), (1450, y + gap)]), fill=0)
    scene.light = Image.composite(disc, scene.light, mask)
    scene.expose(.72, 1.7)
    for offset, tone in ((0, (11, 9, 23)), (19, (6, 7, 15))):
        peaks = [(0, horizon + 20)]
        for x in range(0, 1960, 28):
            envelope = .45 + .55 * abs(x - 1230) / 1230
            peaks.append((x, horizon - rng.uniform(3, 45) * envelope + offset))
        peaks.extend([(1920, horizon + 45), (0, horizon + 45)])
        scene.polygon(peaks, tone)
    scene.box((0, horizon + 20, 1920, 1080), (4, 5, 12), light=False)
    # There I project equally spaced world lines through a single vanishing point.
    vp = 1230
    for bottom in range(-4000, 6000, 240):
        near = ((bottom - vp) ** 2 / 11000000)
        tone = blend(cyan, magenta, min(1, near))
        start = (vp + (bottom - vp) * .024, horizon + 11)
        scene.line([start, (bottom, 1150)], pigment(tone, .36), .85)
    for depth in (1.0, 1.2, 1.47, 1.84, 2.38, 3.2, 4.6, 7.3, 12, 23, 49):
        y = horizon + 420 / depth
        scene.line([(0, y), (1920, y)], pigment(blend(cyan, magenta, .28),
                                              .13 + .27 / depth), .9)
    fade = Image.new("L", (1, scene.height))
    fade.putdata([round(255 * min(1, max(0, (y / scene.vertical - horizon) / 180)) ** .7)
                  for y in range(scene.height)])
    scene.light = Image.composite(scene.light, Image.new("RGB", scene.image.size),
                                  fade.resize(scene.image.size))
    scene.expose(1.1)
    scene.fog(1230, 654, 940, 34, magenta, .10)
    scene.fog(1280, 685, 750, 80, cyan, .045)


def night_city(scene):
    """There I stack detailed megastructures through polluted nocturnal atmosphere."""
    rng = scene.random
    scene.fog(1250, 480, 1000, 560, (51, 72, 109), .40)
    scene.fog(1670, 690, 560, 520, magenta, .13)
    scene.fog(550, 650, 780, 310, cyan, .07)
    for layer in range(4):
        baseline = 755 + layer * 85
        x = -30
        while x < 1950:
            width = float(rng.uniform(26, 100) * (1 + layer * .18))
            height = float(rng.uniform(75, 280) * (1 + layer * .10))
            if 1070 < x < 1570:
                height *= 1.40
            top = baseline - height
            shade = [(16, 22, 36), (11, 16, 27), (7, 10, 19), (4, 6, 12)][layer]
            chamfer = min(16, width * .18)
            scene.polygon([(x, baseline), (x, top + chamfer), (x + chamfer, top),
                           (x + width - 10, top), (x + width, top + 10),
                           (x + width, baseline)], shade)
            scene.box((x + width * .72, top + 12, x + width - 4, baseline),
                      pigment(shade, .7), False)
            scene.line([(x + 3, top + chamfer), (x + 3, baseline)],
                       pigment(cyan, .025 + layer * .009), light=False)
            if rng.random() < .46:
                tip = rng.uniform(10, 57)
                scene.line([(x + width * .5, top), (x + width * .5, top - tip)],
                           shade, 1.1, False)
                scene.circle(x + width * .5, top - tip, .85, pigment(magenta, .40))
            spacing = 6 if layer < 2 else 8
            building_tone = [cyan, amber, magenta][int(rng.choice(3, p=[.53, .38, .09]))]
            occupation = rng.uniform(.16, .60)
            for row in numpy.arange(top + 15, baseline - 5, spacing + 3):
                for col in numpy.arange(x + 8, x + width - 7, spacing):
                    if rng.random() > occupation:
                        continue
                    tone = building_tone if rng.random() < .88 else amber
                    gain = rng.uniform(.10, .46) * (.5 + .17 * layer)
                    scene.box((col, row, col + rng.uniform(1, 2.5), row + 2.5),
                              pigment(tone, gain))
            for ledge in numpy.arange(top + 25, baseline - 10, 47):
                scene.line([(x + 4, ledge), (x + width - 3, ledge)],
                           pigment((37, 63, 78), .12 + .02 * layer), .75, False)
            if width > 60:
                scene.box((x + 12, top - 6, x + width * .4, top - 1), shade, False)
            if layer > 0 and width > 52 and rng.random() < .32:
                sx = x + width * .74
                sy = top + height * .22
                tone = [cyan, magenta, amber][int(rng.integers(3))]
                scene.box((sx - 2, sy - 5, sx + 5, sy + height * .40), (8, 8, 19), False)
                for segment in range(int(height * .035)):
                    yy = sy + segment * 9
                    scene.box((sx, yy, sx + 2, yy + rng.uniform(3, 6)), pigment(tone, .72))
            x += width + rng.uniform(5, 17)
        scene.expose(.85, 1.3)
        if layer < 2:
            scene.image = scene.image.filter(ImageFilter.GaussianBlur((1.4 - layer) * scene.scale))
        scene.fog(1200, baseline, 1250, 95, (21, 44, 65), .22 - layer * .035)
    # There I give the right-hand skyline one recognisable tiered spire.
    scene.polygon([(1420, 1080), (1420, 472), (1440, 452), (1440, 320),
                   (1452, 308), (1452, 241), (1478, 241), (1478, 304),
                   (1491, 318), (1491, 452), (1516, 477), (1516, 1080)], (5, 8, 16))
    scene.line([(1465, 241), (1465, 170)], (21, 44, 57), 1, False)
    scene.circle(1465, 170, 1.2, pigment(magenta, .8))
    for x in (1446, 1485):
        scene.line([(x, 331), (x, 693)], pigment(cyan, .35), 1)
    for y in range(477, 980, 11):
        scene.box((1430, y, 1454, y + 1), pigment(cyan, rng.uniform(.12, .29)))
        scene.box((1475, y, 1504, y + 1), pigment(amber, rng.uniform(.10, .30)))
    scene.box((1461, 417, 1464, 579), pigment(magenta, .85))
    scene.expose(1, 2)
    scene.fog(1450, 760, 550, 210, magenta, .055)
    rain(scene, 1050, .6)
    scene.expose(.75, .3)


def circuit(scene):
    """There I route asymmetrical conductor bundles through a detailed multilayer board."""
    rng = scene.random
    scene.fog(1250, 530, 830, 650, cyan, .055)
    scene.fog(1620, 830, 600, 430, mint, .035)
    # There I blur a separate population of conductors below the focal plane.
    for index in range(110):
        x, y = rng.uniform(0, 1920), rng.uniform(140, 1080)
        run = rng.uniform(70, 380)
        direction = rng.choice([-1, 1])
        path = [(x, y), (x + run * .4, y), (x + run * .7, y + direction * run * .3),
                (x + run, y + direction * run * .3)]
        scene.line(path, pigment(cyan if index % 3 else mint, rng.uniform(.025, .09)), .8)
    scene.light = scene.light.filter(ImageFilter.GaussianBlur(3 * scene.scale))
    scene.expose()
    for x in range(70, 1920, 48):
        for y in range(145, 1060, 48):
            scene.circle(x, y, .75, (9, 20, 25), light=False)
    # There I bend several separate buses through a loose diagonal composition.
    bundles = [(340, 420, 810, 245, 14, 1), (610, 610, 1080, 370, 18, -1),
               (840, 850, 1450, 590, 19, 1), (1160, 680, 1630, 330, 13, -1),
               (1240, 1010, 1720, 790, 12, 1)]
    for group, (left, top, end, rise, count, direction) in enumerate(bundles):
        for index in range(count):
            y = top + index * 10
            start = left + float(rng.uniform(-95, 25))
            knee = left + 150 + index * 8
            turn = rise + index * 3
            finish = end + float(rng.uniform(-50, 110))
            path = [(start, y), (knee, y), (knee + turn * .6, y - turn * .6),
                    (finish, y - turn * .6)]
            if direction < 0:
                path.append((finish + 70, y - turn * .6 - 70))
                path.append((finish + 70, y - turn * .6 - rng.uniform(110, 220)))
            tone = magenta if index == 4 and group in (1, 3) else [cyan, mint][group % 2]
            gain = rng.uniform(.22, .56)
            scene.line(path, pigment(tone, gain), .8 if index % 3 else 1.2)
            for px, py in (path[0], path[-1]):
                scene.circle(px, py, 3.4, pigment(tone, gain * 1.2), .85)
                scene.circle(px, py, .85, pigment(tone, .8))
            if index % 5 == 0:
                scene.circle(*path[2], 2.1, pigment(tone, .7))
                scene.line([(knee + 10, y + 5), (knee + 45, y + 5)], pigment(tone, .15), .6)
    scene.expose(.95, 1.1)
    for x, y, width, height in ((1510, 515, 95, 75), (920, 455, 54, 84),
                               (1620, 850, 130, 94), (1250, 200, 66, 48)):
        edge = [(x, y + 8), (x + 8, y), (x + width - 8, y), (x + width, y + 8),
                (x + width, y + height), (x, y + height), (x, y + 8)]
        scene.polygon(edge, (5, 9, 14))
        scene.line(edge, pigment(cyan, .18), .75)
        for pin in range(7, int(width) - 5, 6):
            scene.box((x + pin, y - 7, x + pin + 1, y - 1), pigment(mint, .23))
            scene.box((x + pin, y + height + 1, x + pin + 1, y + height + 7), pigment(cyan, .19))
        for mark in range(4):
            scene.line([(x + 12, y + 18 + mark * 5), (x + width * .55, y + 18 + mark * 5)],
                       pigment(cyan, .055), .65)
    for index in range(160):
        x, y = rng.uniform(100, 1830), rng.uniform(170, 1010)
        tone = mint if index % 3 else cyan
        scene.circle(x, y, 2.5, pigment(tone, .12), .7)
        if index % 5 == 0:
            scene.box((x + 9, y - 3, x + 19, y + 3), (11, 24, 29), False)
            scene.line([(x + 10, y - 3), (x + 10, y + 3)], pigment(tone, .2))
            scene.line([(x + 18, y - 3), (x + 18, y + 3)], pigment(tone, .2))
    scene.expose(1, 1.5)


def bokeh(scene, x, y, radius, tone, gain, blur):
    """There I blur a locally rendered aperture with a brighter irregular rim."""
    padding = math.ceil(radius * 1.8 + blur * 4)
    size = max(3, round(padding * 2 * scene.scale))
    patch = Image.new("RGB", (size, size))
    draw = ImageDraw.Draw(patch)
    r = radius * scene.scale
    centre = size / 2
    bounds = (centre - r, centre - r, centre + r, centre + r)
    draw.ellipse(bounds, fill=pigment(tone, gain * .46),
                 outline=pigment(tone, gain), width=max(1, round(r * .035)))
    patch = patch.filter(ImageFilter.GaussianBlur(blur * scene.scale))
    left, top = round(x * scene.scale - centre), round(y * scene.vertical - centre)
    layer = Image.new("RGB", scene.image.size)
    layer.paste(patch, (left, top))
    scene.image = ImageChops.screen(scene.image, layer)


def neon_rain(scene):
    """There I photograph an imaginary neon street through a rain-wet defocused lens."""
    rng = scene.random
    scene.fog(1500, 420, 640, 900, magenta, .075)
    scene.fog(800, 640, 650, 640, cyan, .07)
    # There I mix overlapping lenses with uneven exposure and distinct focal depths.
    for index in range(65):
        x, y = rng.uniform(390, 2010), rng.uniform(150, 1150)
        radius = rng.uniform(9, 78)
        tone = [cyan, magenta, amber][int(rng.choice(3, p=[.39, .40, .21]))]
        bokeh(scene, x, y, radius, tone, float(rng.uniform(.09, .34)),
              float(rng.uniform(4, 18)))
    for x, y, radius, tone in ((1120, 418, 83, cyan), (1500, 614, 108, magenta),
                               (1750, 315, 47, amber), (930, 820, 48, cyan)):
        bokeh(scene, x, y, radius, tone, .34, 4)
    for index in range(35):
        x, y = rng.uniform(650, 1900), rng.uniform(330, 950)
        scene.line([(x, y), (x - 18, y + rng.uniform(45, 180))],
                   pigment([cyan, magenta, amber][index % 3], .06), rng.uniform(3, 9))
    scene.light = scene.light.filter(ImageFilter.GaussianBlur(9 * scene.scale))
    scene.expose()
    rain(scene, 2100, 1.1)
    scene.expose(.95, .2)
    # There I catch a few bright beads on nearer streaks without filling the shadows.
    for index in range(80):
        x, y = rng.uniform(420, 1890), rng.uniform(110, 1030)
        length = rng.uniform(8, 31)
        scene.line([(x, y), (x - length * .36, y + length)],
                   pigment(blend(cyan, magenta, float(rng.random())), rng.uniform(.13, .32)), .8)
    scene.expose(.8)


def glitch(scene):
    """There I fracture a ghost signal inside a fine chamfered instrument frame."""
    rng = scene.random
    scene.fog(1320, 560, 790, 370, cyan, .055)
    scene.fog(1460, 600, 620, 240, magenta, .06)
    frame = [(290, 226), (1610, 226), (1660, 276), (1660, 827),
             (1610, 877), (290, 877), (250, 837), (250, 266), (290, 226)]
    scene.line(frame, pigment(cyan, .10), .65)
    for points in ([(250, 335), (250, 266), (290, 226), (365, 226)],
                   [(1535, 226), (1610, 226), (1660, 276), (1660, 330)],
                   [(1660, 770), (1660, 827), (1610, 877), (1535, 877)],
                   [(250, 770), (250, 837), (290, 877), (365, 877)]):
        scene.line(points, pigment(cyan, .28), 1.2)
    for x in range(400, 1510, 14):
        scene.line([(x, 240), (x, 240 + (7 if x % 70 == 0 else 3))], pigment(cyan, .12), .65)
    for y in range(365, 747, 13):
        scene.line([(1644, y), (1644 - (9 if y % 5 == 0 else 3), y)],
                   pigment(mint, .16), .65)
    # There I split coherent source slices into displaced red, green, and blue edges.
    for index in range(47):
        y = rng.normal(558, 103)
        x = rng.uniform(580, 1620)
        width = rng.uniform(50, 440)
        height = rng.choice([1, 1, 2, 3, 5, 10, 19])
        tone = [cyan, magenta, mint][index % 3]
        gain = float(rng.uniform(.08, .30))
        scene.box((x, y, min(x + width, 1760), y + height), pigment(tone, gain))
        split = rng.uniform(5, 24)
        scene.line([(x - split, y - 2), (x + width * .7, y - 2)],
                   pigment((255, 20, 65), gain * .8), .75)
        scene.line([(x + split, y + height + 2), (min(x + width + split, 1770), y + height + 2)],
                   pigment((30, 95, 255), gain * 1.3), .75)
        for fragment in range(int(width / 7)):
            xx = x + rng.uniform(0, width)
            scene.box((xx, y, xx + rng.uniform(1, 8), y + height),
                      pigment(tone, gain * rng.uniform(.4, 1.5)))
    for index in range(190):
        x, y = rng.uniform(720, 1690), rng.normal(560, 115)
        scene.line([(x, y), (x + rng.uniform(1, 18), y)],
                   pigment(cyan if index % 4 else magenta, rng.uniform(.10, .36)), .7)
    for x, y in ((350, 290), (1520, 794), (1430, 296)):
        for index in range(14):
            xx = x + index * 5
            scene.line([(xx, y), (xx, y + rng.choice([2, 4, 7, 9]))],
                       pigment(mint, .25), .7)
    scene.expose(1, .5)
    for y in range(0, 1080, 3):
        scene.line([(0, y), (1920, y)], (3, 3, 7), .45, False)


def void(scene):
    """There I leave one restrained spectral horizon suspended in near-black space."""
    scene.fog(1280, 661, 850, 115, cyan, .026)
    scene.fog(1560, 661, 640, 110, magenta, .025)
    for x in range(120, 1870):
        fade = math.sin(math.pi * (x - 120) / 1750) ** 1.7
        tone = blend(cyan, magenta, (x - 120) / 1750)
        scene.line([(x, 661), (x + 1, 661)], pigment(tone, .39 * fade), .65)
    scene.expose(1, 2)


def dimensions(value):
    """There I reject malformed and nonpositive output dimensions."""
    try:
        width, height = (int(part) for part in value.lower().split("x"))
    except ValueError as error:
        raise argparse.ArgumentTypeError("Ooops.. use WIDTHxHEIGHT, e.g. 3840x2160") from error
    if width < 1 or height < 1:
        raise argparse.ArgumentTypeError("Ooops.. both dimensions must be positive")
    return width, height


def finish(scene):
    """There I protect desktop widgets and dither every gradient before quantisation."""
    pixels = numpy.asarray(scene.image, dtype=numpy.float32)
    x = numpy.linspace(0, 1, scene.width, dtype=numpy.float32)[None, :]
    y = numpy.linspace(0, 1, scene.height, dtype=numpy.float32)[:, None]
    # There I dim the capsule and clock with broad smooth masks, without hard cutouts.
    capsule = numpy.exp(-((x - .5) / .25) ** 4 - (y / .16) ** 2)
    clock = numpy.exp(-(x / .31) ** 4 - ((y - .91) / .25) ** 4)
    comfort = (1 - .82 * capsule) * (1 - .88 * clock)
    vignette = 1 - .19 * numpy.clip(((x - .56) / .8) ** 2 + ((y - .5) / .9) ** 2, 0, 1)
    for channel, ground in enumerate((5, 4, 10)):
        pixels[:, :, channel] = ground + (pixels[:, :, channel] - ground) * comfort * vignette
    rng = numpy.random.default_rng(scene.seed + 90000)
    # There I use sub-code-value monochrome grain plus uniform quantisation dither.
    grain = rng.normal(0, .63, (scene.height, scene.width)).astype(numpy.float32)
    grain += rng.uniform(-.5, .5, grain.shape).astype(numpy.float32)
    pixels += grain[..., None]
    return Image.fromarray(numpy.uint8(numpy.clip(numpy.rint(pixels), 0, 255)))


def main():
    """There I render selected scenes and report their actual size and elapsed time."""
    collection = {
        "01-neon-grid": (neon_grid, 1103),
        "02-night-city": (night_city, 2207),
        "03-circuit": (circuit, 3301),
        "04-neon-rain": (neon_rain, 4409),
        "05-glitch": (glitch, 5501),
        "06-void": (void, 6607),
    }
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("out_dir", type=Path)
    parser.add_argument("--size", type=dimensions, default=(3840, 2160), metavar="WIDTHxHEIGHT")
    parser.add_argument("--only", choices=collection, metavar="NAME",
                        help="one filename stem, e.g. 01-neon-grid")
    arguments = parser.parse_args()
    started = time.perf_counter()
    try:
        arguments.out_dir.mkdir(parents=True, exist_ok=True)
        for name, (render, seed) in collection.items():
            if arguments.only and name != arguments.only:
                continue
            image_started = time.perf_counter()
            scene = canvas(*arguments.size, seed)
            render(scene)
            image = finish(scene)
            destination = arguments.out_dir / (name + ".jpg")
            image.save(destination, format="JPEG", quality=92, subsampling=0,
                       optimize=True, progressive=True)
            print("{}: {}x{}, {:,} bytes, {:.2f} s".format(
                destination, *arguments.size, destination.stat().st_size,
                time.perf_counter() - image_started), flush=True)
            del scene, image
    except (OSError, MemoryError) as error:
        parser.exit(1, "Ooops.. {}\n".format(error))
    print("Total: {:.2f} s".format(time.perf_counter() - started))


if __name__ == "__main__":
    main()
