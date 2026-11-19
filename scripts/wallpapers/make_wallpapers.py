"""There I render six deterministic cyberpunk wallpapers with NumPy and Pillow.

This work made by Anfinogentov Nikita

There I run the collection with python scripts/wallpapers/make_wallpapers.py wallpapers.
There I select a scene with --only 01-harbour and dimensions with --size 1920x1080.
There I light every scene in linear HDR, scatter it through a bloom pyramid and tone-map it last.
There I reproduce the repository images with numpy 2.2.6 and Pillow 12.3.0.
"""

import argparse
import math
from pathlib import Path
import time

import numpy
from PIL import Image


cyan = (0, 229, 255)
magenta = (255, 43, 214)
mint = (122, 255, 212)
amber = (255, 158, 63)
violet = (126, 87, 255)
ice = (196, 232, 255)
warm = (255, 196, 140)
signal_red = (255, 40, 52)


def linear(rgb, gain=1):
    """There I convert a display colour to linear light."""
    return numpy.array([(channel / 255) ** 2.2 * gain for channel in rgb], dtype=numpy.float32)


def mix(first, second, position):
    """There I interpolate colours along a scalar field."""
    position = numpy.asarray(position, dtype=numpy.float32)[..., None]
    return first + (second - first) * position


def smooth(low, high, value):
    """There I ease a field between two thresholds."""
    t = numpy.clip((value - low) / (high - low), 0, 1)
    return t * t * (3 - 2 * t)


def hashed(a, b, seed):
    """There I turn integer lattice coordinates into stable random numbers in [0, 1)."""
    h = (numpy.asarray(a, numpy.int64) * 374761393 + numpy.asarray(b, numpy.int64) * 668265263
         + seed * 2246822519) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    h = h ^ (h >> 16)
    return (h & 0xFFFFFF).astype(numpy.float32) / 16777216


class noise_field:
    """There I keep one lattice of random values for smooth value noise."""

    def __init__(self, seed):
        """There I fill a 256 by 256 periodic lattice."""
        self.table = numpy.random.default_rng(seed).random((256, 256), dtype=numpy.float32)

    def value(self, x, y):
        """There I interpolate the lattice with a smoothstep kernel."""
        x = numpy.asarray(x, dtype=numpy.float32)
        y = numpy.asarray(y, dtype=numpy.float32)
        fx = numpy.floor(x)
        fy = numpy.floor(y)
        tx = x - fx
        ty = y - fy
        tx = tx * tx * (3 - 2 * tx)
        ty = ty * ty * (3 - 2 * ty)
        ix = fx.astype(numpy.int64) & 255
        iy = fy.astype(numpy.int64) & 255
        jx = (ix + 1) & 255
        jy = (iy + 1) & 255
        a = self.table[iy, ix]
        b = self.table[iy, jx]
        c = self.table[jy, ix]
        d = self.table[jy, jx]
        return a + (b - a) * tx + (c - a) * ty + (a - b - c + d) * tx * ty

    def fbm(self, x, y, octaves=5, gain=.5):
        """There I sum rotated octaves so the lattice never shows."""
        total = 0
        amplitude = 1
        norm = 0
        for octave in range(octaves):
            total = total + amplitude * self.value(x, y)
            norm += amplitude
            x, y = x * 1.93 + y * .42 + 13.7, y * 1.93 - x * .42 + 7.3
            amplitude *= gain
        return total / norm


def box_rows(field, radius):
    """There I average a sliding window along the first axis with a running sum."""
    if radius < 1:
        return field
    padding = [(radius + 1, radius)] + [(0, 0)] * (field.ndim - 1)
    total = numpy.cumsum(numpy.pad(field, padding, mode="edge"), axis=0, dtype=numpy.float64)
    return ((total[2 * radius + 1:] - total[:-2 * radius - 1]) / (2 * radius + 1)).astype(numpy.float32)


def blur(field, sigma, vertical=None):
    """There I approximate a Gaussian with three box passes on every axis."""
    vertical = sigma if vertical is None else vertical
    for axis_sigma, across in ((vertical, False), (sigma, True)):
        radius = int(round((math.sqrt(4 * axis_sigma ** 2 + 1) - 1) / 2))
        if radius < 1:
            continue
        if across:
            field = numpy.swapaxes(field, 0, 1)
        for repeat in range(3):
            field = box_rows(field, radius)
        if across:
            field = numpy.ascontiguousarray(numpy.swapaxes(field, 0, 1))
    return field


def shrink(field, factor):
    """There I average square blocks of pixels."""
    height = field.shape[0] // factor * factor
    width = field.shape[1] // factor * factor
    block = field[:height, :width].reshape(height // factor, factor, width // factor, factor, -1)
    return block.mean(axis=(1, 3), dtype=numpy.float32)


def grow(field, height, width):
    """There I stretch every channel back with bilinear filtering."""
    channels = []
    for channel in range(field.shape[2]):
        plane = Image.fromarray(numpy.ascontiguousarray(field[..., channel], dtype=numpy.float32))
        channels.append(numpy.asarray(plane.resize((width, height), Image.Resampling.BILINEAR)))
    return numpy.stack(channels, axis=-1)


def stamp(hdr, x, y, radius, rgb):
    """There I add a soft point light whose energy survives below one pixel."""
    reach = int(math.ceil(radius * 3 + 2))
    left = max(0, int(x) - reach)
    right = min(hdr.shape[1], int(x) + reach + 1)
    top = max(0, int(y) - reach)
    bottom = min(hdr.shape[0], int(y) + reach + 1)
    if left >= right or top >= bottom:
        return
    xx = numpy.arange(left, right, dtype=numpy.float32)[None, :] + .5 - x
    yy = numpy.arange(top, bottom, dtype=numpy.float32)[:, None] + .5 - y
    spread = radius * radius + .3
    weight = numpy.exp(-(xx * xx + yy * yy) / (2 * spread)) * (radius * radius + .08) / spread
    hdr[top:bottom, left:right] += weight[..., None] * rgb


class canvas:
    """There I hold the output size, the design scale and the random stream of one scene."""

    def __init__(self, width, height, seed):
        """There I use a 1920 by 1080 design space for every size."""
        self.width = width
        self.height = height
        self.scale = width / 1920
        self.vertical = height / 1080
        self.random = numpy.random.default_rng(seed)
        self.seed = seed
        self.u = ((numpy.arange(width, dtype=numpy.float32) + .5) / width)[None, :]
        self.v = ((numpy.arange(height, dtype=numpy.float32) + .5) / height)[:, None]
        self.pixels = None

    def empty(self):
        """There I start a black HDR buffer."""
        return numpy.zeros((self.height, self.width, 3), dtype=numpy.float32)


def bloom(scene, hdr, gain=1):
    """There I scatter light at four radii, from lens halo to atmosphere."""
    result = hdr.copy()
    for factor, sigma, weight in ((2, 2.5, .10), (4, 9, .12), (8, 28, .12), (16, 80, .10)):
        small = shrink(hdr, factor)
        small = blur(small, sigma * scene.scale / factor)
        result += weight * gain * grow(small, scene.height, scene.width)
    return result


def develop(scene, hdr, exposure=1):
    """There I tone-map linear light with a soft shoulder and encode it for display."""
    mapped = 1 - numpy.exp(-numpy.maximum(hdr, 0) * exposure)
    scene.pixels = 255 * mapped ** (1 / 2.2)


def harbour_light(scene, reflection=True, beams=True):
    """There I build a megacity across black water and return its linear light."""
    rng = scene.random
    clouds = noise_field(scene.seed + 11)
    s = scene.scale
    waterline = round(scene.height * .70)
    shore = waterline / scene.vertical

    level = waterline / scene.height
    rise = numpy.clip((level - scene.v) / level, 0, 1)
    sky = mix(linear((46, 16, 58)), linear((3, 4, 14)), rise ** .42)
    sky = sky + linear(amber, .2) * numpy.exp(-rise * 15)[..., None]
    density = clouds.fbm(scene.u * 1920 / 330, scene.v * 1080 / 70, 6)
    deck = smooth(.47, .78, density) * smooth(.04, .45, rise)
    underlit = linear((160, 52, 128), .6) * numpy.exp(-rise * 2.4)[..., None]
    hdr = sky * (1 - .6 * deck[..., None]) + deck[..., None] * underlit * (.5 + density[..., None])
    stars = (rng.random((scene.height, scene.width), dtype=numpy.float32) > .99965) * rise ** 2
    hdr += (stars * (1 - deck))[..., None] * linear(ice, .5)
    hdr = numpy.ascontiguousarray(hdr, dtype=numpy.float32)
    haze = linear((58, 22, 70))

    def block(left, right, top, base, fog, layer):
        """There I paint one opaque mass with lit windows, fogged by its distance."""
        x0 = max(0, int(round(left * s)))
        x1 = min(scene.width, int(round(right * s)))
        y0 = max(0, int(round(top * scene.vertical)))
        y1 = min(scene.height, int(round(base * scene.vertical)))
        if x1 - x0 < 1 or y1 - y0 < 1:
            return
        rows = numpy.arange(y0, y1, dtype=numpy.float32)
        ground = numpy.exp(-(waterline - rows) / (scene.vertical * 60))
        amount = numpy.clip(fog + (1 - fog) * .8 * ground, 0, 1)[:, None, None]
        shade = numpy.ones((1, x1 - x0, 1), dtype=numpy.float32)
        shade[:, int((x1 - x0) * .7):] = .6
        hdr[y0:y1, x0:x1] = linear((8, 10, 20)) * shade * (1 - amount) + haze * amount
        hdr[y0:y1, x0] += linear(cyan, .07) * (1 - amount[:, 0])
        cell_x = max(2, int(round((3.2 + layer * .9) * s)))
        cell_y = max(3, int(round((5 + layer * 1.3) * scene.vertical)))
        inner = hdr[y0 + cell_y:y1 - cell_y, x0 + max(1, cell_x // 2):x1 - max(1, cell_x // 2)]
        count_y = inner.shape[0] // cell_y
        count_x = inner.shape[1] // cell_x
        if count_y < 1 or count_x < 1:
            return
        lit = rng.random((count_y, count_x)) < rng.uniform(.04, .3) * (.5 + .5 * smooth(.9, .2, fog))
        lit &= rng.random((count_y, 1)) > .18
        tone = linear([warm, ice, cyan, magenta][int(rng.choice(4, p=[.5, .3, .14, .06]))])
        cells = (rng.uniform(.3, 1, (count_y, count_x)) * lit)[..., None] * tone
        odd = rng.random((count_y, count_x)) < .1
        cells[odd] = cells[odd].sum(axis=-1, keepdims=True) * linear(amber) / tone.sum()
        cells *= 1.3 * (1 - fog) ** 1.2
        pixels = numpy.repeat(numpy.repeat(cells, cell_y, 0), cell_x, 1)
        glass_y = (numpy.arange(count_y * cell_y) % cell_y) < max(1, cell_y // 2)
        glass_x = (numpy.arange(count_x * cell_x) % cell_x) < max(1, round(cell_x * .55))
        inner[:count_y * cell_y, :count_x * cell_x] += pixels * (glass_y[:, None] & glass_x[None, :])[..., None]

    def sign(x, top, length, fog, tone):
        """There I hang a vertical neon sign of abstract glyph blocks."""
        x0 = int(round(x * s))
        width = max(3, int(round(6 * s)))
        y0 = int(round(top * scene.vertical))
        count = max(3, int(length / 9))
        cell = max(2, int(round(9 * scene.vertical)))
        if x0 < 0 or x0 + width > scene.width or y0 + count * cell > waterline:
            return
        hdr[y0 - 2:y0 + count * cell + 2, x0 - 1:x0 + width + 1] = linear((4, 4, 9))
        glyphs = rng.random((count, 3)) > .35
        glyphs[:, 1] |= rng.random(count) > .5
        pattern = numpy.repeat(numpy.repeat(glyphs, cell, 0), int(math.ceil(width / 3)), 1)[:, :width]
        pattern[numpy.arange(count * cell) % cell == cell - 1] = False
        hdr[y0:y0 + count * cell, x0:x0 + width] += pattern[..., None] * linear(tone, 2.6 * (1 - fog))

    def billboard(left, top, width, height, fog):
        """There I mount a holographic billboard with scanlines and dark glyph bars."""
        x0 = int(round(left * s))
        x1 = min(scene.width, int(round((left + width) * s)))
        y0 = int(round(top * scene.vertical))
        y1 = int(round((top + height) * scene.vertical))
        if x1 - x0 < 4 or y1 - y0 < 4 or x0 < 0:
            return
        first, second = [(cyan, magenta), (magenta, amber), (violet, cyan)][int(rng.integers(3))]
        across = numpy.linspace(0, 1, x1 - x0, dtype=numpy.float32)[None, :]
        face = mix(linear(first), linear(second), across * numpy.ones((y1 - y0, 1), numpy.float32))
        scan = (numpy.arange(y1 - y0) % max(2, int(round(3 * scene.vertical))) == 0)[:, None]
        face *= numpy.where(scan, .45, 1)[..., None]
        for bar in range(int(rng.integers(2, 5))):
            by = int(rng.uniform(.15, .8) * (y1 - y0))
            bx = int(rng.uniform(.08, .5) * (x1 - x0))
            face[by:by + max(1, (y1 - y0) // 9), bx:bx + int(rng.uniform(.2, .45) * (x1 - x0))] *= .08
        hdr[y0:y1, x0:x1] = hdr[y0:y1, x0:x1] * .2 + face * 1.1 * (1 - fog)

    def arcology(centre, top, fog):
        """There I raise one tapered megastructure with ring decks and a crown of searchlights."""
        y0 = int(round(top * scene.vertical))
        rows = numpy.arange(y0, waterline, dtype=numpy.float32)
        along = (rows - y0) / (waterline - y0)
        half = (14 + 70 * along ** 1.5) * s
        cx = centre * s
        cols = numpy.arange(scene.width, dtype=numpy.float32)[None, :] + .5
        inside = numpy.abs(cols - cx) < half[:, None]
        ground = numpy.exp(-(waterline - rows) / (scene.vertical * 60))[:, None, None]
        amount = numpy.clip(fog + (1 - fog) * .8 * ground, 0, 1)
        body = linear((6, 8, 16)) * (1 - amount) + haze * amount
        region = hdr[y0:waterline]
        region[:] = numpy.where(inside[..., None], body, region)
        offset = numpy.abs(cols - cx) / half[:, None]
        decks = ((rows - y0) / scene.vertical % 31 < 1.6)[:, None] & inside
        region += (decks * (1 - offset ** 4))[..., None] * linear(cyan, .7 * (1 - fog))
        spine = (numpy.abs(cols - cx) < 1.3 * s) & (rows[:, None] > y0 + 40 * scene.vertical)
        region += spine[..., None] * linear(magenta, 2.2 * (1 - fog))
        dots = inside & (hashed(rows[:, None] // max(2, round(4 * scene.vertical)),
                                cols // max(2, round(4 * s)), scene.seed) < .07)
        region += dots[..., None] * linear(warm, .7 * (1 - fog))
        spire = int(round(70 * scene.vertical))
        hdr[y0 - spire:y0, int(cx) - max(1, int(s)):int(cx) + max(1, int(s))] = linear((10, 12, 22))
        stamp(hdr, cx, y0 - spire, 1.6 * s, linear(signal_red, 5))
        stamp(hdr, cx, y0 + 2, 4 * s, linear(ice, 4))
        # There I sweep two searchlights from the crown through the low cloud deck.
        yy = numpy.arange(y0, dtype=numpy.float32)[:, None] + .5
        for angle, gain in (((62, .32), (108, .22)) if beams else ()):
            dx = math.cos(math.radians(angle))
            dy = -math.sin(math.radians(angle))
            px = cols - cx
            py = yy - y0
            distance = px * dx + py * dy
            across_beam = numpy.abs(px * dy - py * dx)
            width = (2.5 + distance * .09).clip(1)
            beam = numpy.exp(-(across_beam / width) ** 2) * numpy.exp(-distance / (650 * s))
            beam *= smooth(0, 25 * s, distance) * (distance > 0)
            hdr[:y0] += (beam * gain * (1 + deck[:y0] * 2))[..., None] * linear(ice)

    def traffic(count, low, high, fog):
        """There I streak flying traffic along gently curved sky lanes."""
        for lane in range(4):
            base = rng.uniform(low, high)
            slope = rng.uniform(-.05, .05)
            heading = 1 if lane % 2 else -1
            tone = linear(warm if heading > 0 else signal_red, 2.4 * (1 - fog))
            for car in range(count):
                x = rng.uniform(0, 1920)
                y = base + slope * (x - 960)
                length = rng.uniform(6, 34) * s
                x0 = int(x * s)
                yp = int(y * scene.vertical)
                span = numpy.arange(int(length), dtype=numpy.float32)
                xs = x0 - heading * span.astype(int)
                keep = (xs >= 0) & (xs < scene.width)
                fade = (1 - span / length) ** 2
                if 0 <= yp < scene.height:
                    hdr[yp, xs[keep]] += fade[keep][:, None] * tone * .6
                stamp(hdr, x0 + .5, yp + .5, .7 * s, tone * 1.5)

    skyline = noise_field(scene.seed + 23)
    for layer in range(6):
        depth = 1 - layer / 5
        fog = .08 + .84 * depth ** 1.1
        x = float(rng.uniform(-60, 0))
        while x < 1960:
            width = float(rng.uniform(18, 46) * (1 + layer * .42))
            cluster = .5 + 1.1 * float(skyline.value(x / 260, layer * 7.3))
            height = float(rng.uniform(70, 230) * cluster * [1.3, 1.15, 1, .85, .6, .4][layer])
            if 1250 < x < 1700 and layer in (0, 1, 2):
                height *= 1.4
            top = shore - height
            block(x, x + width, top, shore, fog, layer)
            if rng.random() < .45:
                inset = width * rng.uniform(.12, .3)
                lift = height * rng.uniform(.12, .35)
                block(x + inset, x + width - inset * .6, top - lift, top, fog, layer)
                top -= lift
            if rng.random() < .3 and 0 <= (x + width * .5) * s < scene.width:
                mast = rng.uniform(12, 50) * (1 + layer * .2)
                xm = int((x + width * .5) * s)
                hdr[int((top - mast) * scene.vertical):int(top * scene.vertical), xm] = haze * fog
                stamp(hdr, xm + .5, (top - mast) * scene.vertical, .8 * s,
                      linear(signal_red, 3 * (1 - fog * .7)))
            if layer >= 3 and rng.random() < .22:
                sign(x + width - 3, top + rng.uniform(15, 50), rng.uniform(50, 150), fog,
                     [magenta, cyan, amber][int(rng.integers(3))])
            if 2 <= layer <= 4 and width > 50 and rng.random() < .12:
                billboard(x + width * .1, top + height * .15, width * .8, width * .42, fog)
            x += width + float(rng.uniform(2, 14))
        if layer == 1:
            traffic(9, 380, 520, .55)
        if layer == 3:
            arcology(1480, 250, .35)
            traffic(6, 470, 600, .25)

    if reflection:
        # There I mirror the city into rippled water and smear it along the line of sight.
        rows = numpy.arange(waterline, scene.height)
        distance = rows - waterline + 1
        source = numpy.clip(waterline - distance, 0, scene.height - 1)
        ripple = clouds.fbm(scene.u * 1920 / 9, (rows[:, None] / scene.vertical) / 2.2, 3) - .5
        swing = (1.5 + distance[:, None] * .05) * s * ripple * 2
        columns = numpy.clip(numpy.arange(scene.width)[None, :] + swing.astype(int), 0, scene.width - 1)
        mirror = hdr[source[:, None], columns]
        mirror = blur(mirror, 2 * s, 9 * s)
        streaks = .55 + .45 * smooth(.35, .7, clouds.fbm(scene.u * 1920 / 140, rows[:, None] / scene.vertical / 3, 4))
        near = (distance / (scene.height - waterline))[:, None]
        mirror *= ((.5 - .32 * near) * streaks ** 2)[..., None]
        hdr[waterline:] = linear((3, 4, 10)) + mirror
        glow = numpy.exp(-numpy.abs(numpy.arange(scene.height) - waterline) / (6 * scene.vertical))
        hdr += glow[:, None, None] * linear(magenta, .05)
    return hdr


def harbour(scene):
    """There I develop the megacity over water."""
    hdr = harbour_light(scene)
    develop(scene, bloom(scene, hdr, 1.1), 1.25)


def corridor(scene):
    """There I trace an endless service tunnel ribbed with neon frames over a wet floor."""
    width_half = 1.2
    floor = -1.0
    ceiling = .85
    period = 1.7
    focal = .95
    yaw = math.radians(6)
    origin = (.22, -.42, 0.0)
    end = 46.0
    seed = scene.seed
    puddles = noise_field(seed + 5)
    palette = numpy.stack([linear(cyan), linear(cyan), linear(magenta), linear(violet), linear(ice)])
    fog_colour = linear((26, 52, 84), .16)

    def ring(index, channel):
        """There I give every frame its own stable random traits."""
        return hashed(index, channel, seed)

    def surface(ox, oy, oz, dx, dy, dz, reflected):
        """There I hit the box tunnel analytically and shade walls, ceiling and the far gate."""
        with numpy.errstate(divide="ignore", invalid="ignore"):
            tx = numpy.where(dx > 0, (width_half - ox) / dx, (-width_half - ox) / dx)
            ty = numpy.where(dy > 0, (ceiling - oy) / dy, (floor - oy) / dy)
            tz = (end - oz) / dz
        tx = numpy.where(numpy.abs(dx) < 1e-6, numpy.inf, tx)
        ty = numpy.where(numpy.abs(dy) < 1e-6, numpy.inf, ty)
        t = numpy.minimum(numpy.minimum(tx, ty), tz)
        wall = tx <= numpy.minimum(ty, tz)
        gate = tz < numpy.minimum(tx, ty)
        flat = ~wall & ~gate
        top = flat & (dy > 0)
        ground = flat & (dy <= 0)
        px = ox + t * dx
        py = oy + t * dy
        pz = oz + t * dz
        across = numpy.where(wall, py + numpy.sign(px) * 3, px)
        facing = numpy.where(wall, numpy.abs(dx), numpy.where(gate, numpy.abs(dz), numpy.abs(dy)))
        footprint = numpy.clip(t / (focal * scene.height) / numpy.maximum(facing, .03), 1e-4, period * .3)
        k = numpy.floor(pz / period)
        light = numpy.zeros(px.shape + (3,), dtype=numpy.float32) + .015
        emission = numpy.zeros_like(light)
        for step in (-1, 0, 1):
            index = k + step
            on = ring(index, 1) > .22
            power = (.25 + 1.0 * ring(index, 2) ** 2) * on
            tone = palette[numpy.minimum((ring(index, 3) * 5).astype(int), 4)]
            gap = numpy.abs(pz - (index + .5) * period)
            light += (power / (1 + (gap / .4) ** 2))[..., None] * tone * .4
            if step == 0:
                band = numpy.clip((.04 - gap) / footprint + .5, 0, 1)
                pieces = (numpy.mod(across * 2.3 + ring(index, 4) * 7, 1) > .13)
                emission += (band * pieces * power * 3.2)[..., None] * tone
        guide = wall & (numpy.abs(py + .9) < .012 + footprint) & (numpy.mod(pz * 2.5, 1) < .5)
        emission += guide[..., None] * linear(amber, 1.8)
        tint = .6 + .4 * hashed(numpy.floor(pz / (period * .5)), numpy.floor(across * 3), seed + 1)
        seam = (numpy.mod(pz / (period * .5), 1) < footprint / (period * .5) + .01) | \
               (numpy.mod(across * 3, 1) < .02)
        albedo = linear((70, 76, 92)) * (tint * numpy.where(seam, .3, 1))[..., None]
        albedo = numpy.where(ground[..., None], linear((22, 24, 30)), albedo)
        door = gate & (numpy.abs(px) < .4) & (py < .4)
        emission += door[..., None] * linear(ice, 9)
        colour = albedo * light + emission
        transmit = numpy.exp(-t * .048)[..., None]
        colour = colour * transmit + fog_colour * (1 - transmit)
        if reflected:
            return colour
        return colour, ground, px, py, pz, t

    width = scene.width
    height = scene.height
    cols = (numpy.arange(width, dtype=numpy.float32) + .5 - width / 2) / height
    base = scene.empty()
    reflection = scene.empty()
    wetness = numpy.zeros((height, width), dtype=numpy.float32)
    for start in range(0, height, 240):
        rows = numpy.arange(start, min(height, start + 240), dtype=numpy.float32)
        sx = numpy.broadcast_to(cols[None, :], (len(rows), width))
        sy = numpy.broadcast_to(((height / 2 - rows - .5) / height)[:, None], sx.shape)
        dx = sx * math.cos(yaw) + focal * math.sin(yaw)
        dz = -sx * math.sin(yaw) + focal * math.cos(yaw)
        norm = numpy.sqrt(dx * dx + sy * sy + dz * dz)
        dx, dy, dz = dx / norm, sy / norm, dz / norm
        colour, ground, px, py, pz, t = surface(origin[0], origin[1], origin[2], dx, dy, dz, False)
        bounce = surface(px, py, pz, dx, -dy, dz, True)
        travelled = numpy.exp(-t * .048)[..., None]
        fresnel = .04 + .96 * (1 - numpy.abs(dy)) ** 5
        wet = smooth(.42, .58, puddles.fbm(px * 1.4, pz * .45, 4))
        base[start:start + len(rows)] = colour
        reflection[start:start + len(rows)] = bounce * travelled * (ground * fresnel)[..., None]
        wetness[start:start + len(rows)] = wet * ground
    rough = blur(reflection, 1.5 * scene.scale, 9 * scene.vertical)
    hdr = base + rough * .45 + (reflection - rough * .45) * wetness[..., None] * .9
    develop(scene, bloom(scene, hdr, 1.25), 1.15)


def ridges(scene):
    """There I fly over moonlit ridges whose contour lines glow like a live survey."""
    rng = scene.random
    land = noise_field(scene.seed + 3)
    width = scene.width
    height = scene.height
    s = scene.scale
    horizon = height * .40
    focal = width * .62

    def terrain(x, z):
        """There I mix ridged octaves into broad basins that hold the cities."""
        basin = land.fbm(x * .0021, z * .0021, 4)
        ridge = 0
        amplitude = .5
        xx = x * .0055
        zz = z * .0055
        for octave in range(7):
            fold = 1 - numpy.abs(2 * land.value(xx, zz) - 1) ** .8
            ridge = ridge + amplitude * fold * fold
            xx, zz = xx * 2.03 + zz * .37 + 3.1, zz * 2.03 - xx * .37 + 9.7
            amplitude *= .48
        return ridge * smooth(.22, .66, basin) * 360 + basin * 40

    camera = float(terrain(numpy.float32(0), numpy.float32(0))) + 105
    depths = 2.5 * 1.0042 ** numpy.arange(1550, dtype=numpy.float32)
    lateral = (numpy.arange(width, dtype=numpy.float32) + .5 - width / 2) / focal
    rows_y = numpy.empty((len(depths), width), dtype=numpy.float32)
    for index, z in enumerate(depths):
        rows_y[index] = horizon - (terrain(lateral * z, numpy.float32(z)) - camera) / z * focal
    lowest = numpy.minimum.accumulate(rows_y, axis=0)
    centres = numpy.arange(height, dtype=numpy.float32) + .5
    found = numpy.empty((height, width), dtype=numpy.int64)
    for column in range(width):
        found[:, column] = numpy.searchsorted(-lowest[:, column], -centres, side="left")
    ground = found < len(depths)
    safe = numpy.clip(found, 1, len(depths) - 1)
    cols = numpy.broadcast_to(numpy.arange(width)[None, :], found.shape)
    after = rows_y[safe, cols]
    before = rows_y[safe - 1, cols]
    fraction = numpy.clip((before - centres[:, None]) / numpy.maximum(before - after, 1e-3), 0, 1)
    z_map = depths[safe - 1] + fraction * (depths[safe] - depths[safe - 1])

    z = z_map[ground]
    x = (cols[ground] + .5 - width / 2) / focal * z
    h = terrain(x, z)
    step = .6
    slope_x = (terrain(x + step, z) - terrain(x - step, z)) / (2 * step)
    slope_z = (terrain(x, z + step) - terrain(x, z - step)) / (2 * step)
    length = numpy.sqrt(slope_x ** 2 + 1 + slope_z ** 2)
    nx, ny, nz = -slope_x / length, 1 / length, -slope_z / length

    moon_x = width * .68
    moon_y = height * .19
    view = numpy.sqrt(x * x + (h - camera) ** 2 + z * z)
    facing = numpy.abs(nx * x + ny * (h - camera) + nz * z) / view
    rim = (1 - facing) ** 4
    lowland = smooth(70, 20, h)
    colour = (linear((40, 44, 70), .25) * ny[:, None] + linear(ice, .5) * rim[:, None]
              + linear(magenta, .22) * (lowland * ny)[:, None])
    colour = colour * linear((60, 64, 80))

    footprint = z / focal
    cell = 2.6
    cx = numpy.floor(x / cell)
    cz = numpy.floor(z / cell)
    chance = hashed(cx, cz, scene.seed)
    spot_x = (cx + hashed(cx, cz, scene.seed + 1)) * cell
    spot_z = (cz + hashed(cx, cz, scene.seed + 2)) * cell
    gap = (x - spot_x) ** 2 + (z - spot_z) ** 2
    spread = .12 + footprint ** 2
    lamp = numpy.exp(-gap / (2 * spread)) * .12 / spread * (chance < .09 * lowland)
    tone = numpy.where((hashed(cx, cz, scene.seed + 3) < .2)[:, None], linear(cyan), linear(warm))
    colour += (lamp * 5)[:, None] * tone

    mist = lowland * smooth(1600, 200, z)
    colour = colour * (1 - .5 * mist[:, None]) + mist[:, None] * linear((120, 40, 130), .07)

    sky_colour = linear((30, 22, 62))
    transmit = numpy.exp(-z * .0012)
    colour = colour * transmit[:, None] + sky_colour * (1 - transmit)[:, None]

    height_map = numpy.full((height, width), numpy.nan, dtype=numpy.float32)
    height_map[ground] = h
    grad_y, grad_x = numpy.gradient(height_map)
    rate = numpy.sqrt(grad_x ** 2 + grad_y ** 2)[ground]
    rate = numpy.where(numpy.isfinite(rate), rate, 1e9)
    interval = 12
    offset = numpy.abs(h / interval - numpy.round(h / interval)) * interval
    contour = numpy.clip(1.1 - offset / numpy.maximum(rate, 1e-3), 0, 1) * (rate < 12) * (rate > .02) * smooth(45, 90, h)
    contour *= smooth(1300, 150, z) * smooth(3 * s, 12 * s, z)
    line_tone = mix(linear(magenta), linear(cyan), smooth(90, 300, h))
    colour += (contour * 1.7 * transmit)[:, None] * line_tone

    hdr = scene.empty()
    rise = numpy.clip((horizon - scene.v) / horizon, 0, 1)
    sky = mix(sky_colour, linear((3, 4, 15)), rise ** .5)
    hdr[:] = sky
    yy = scene.v * height
    xx = scene.u * width
    distance = numpy.sqrt((xx - moon_x) ** 2 + (yy - moon_y) ** 2)
    hdr += numpy.exp(-distance / (110 * s))[..., None] * linear(ice, .22)
    hdr += numpy.exp(-distance / (520 * s))[..., None] * linear(violet, .08)
    stars = (rng.random((height, width), dtype=numpy.float32) > .9993) * rise ** 1.5
    hdr += (stars * rng.random((height, width), dtype=numpy.float32))[..., None] * linear(ice, .7)
    radius = 34 * s
    disc = numpy.clip(radius - distance + .5, 0, 1)
    craters = .82 + .18 * land.fbm(xx / (9 * s), yy / (9 * s), 4)
    hdr = hdr * (1 - disc[..., None]) + (disc * craters)[..., None] * linear((236, 228, 255), 3.2)
    hdr[ground] = colour
    develop(scene, bloom(scene, hdr, 1.0), 1.35)


def signal(scene):
    """There I trace thousands of particles through a curl field into one luminous current."""
    rng = scene.random
    flow = noise_field(scene.seed + 5)
    s = scene.scale
    grid_x = numpy.arange(0, 2400, 4, dtype=numpy.float32)
    grid_y = numpy.arange(-200, 1300, 4, dtype=numpy.float32)
    gx, gy = numpy.meshgrid(grid_x, grid_y)
    potential = flow.fbm(gx / 520, gy / 520, 4) + .35 * flow.fbm(gx / 160 + 40, gy / 160, 3)
    d_y, d_x = numpy.gradient(potential, 4)
    vx = d_y * 260 + 1
    vy = -d_x * 260 + .12 * numpy.sin(gx / 400)
    speed = numpy.sqrt(vx * vx + vy * vy) + 1e-6
    vx /= speed
    vy /= speed

    def velocity(x, y):
        """There I sample the precomputed field bilinearly."""
        fx = numpy.clip((x - grid_x[0]) / 4, 0, len(grid_x) - 1.001)
        fy = numpy.clip((y - grid_y[0]) / 4, 0, len(grid_y) - 1.001)
        ix = fx.astype(int)
        iy = fy.astype(int)
        tx = fx - ix
        ty = fy - iy
        result = []
        for field in (vx, vy):
            top = field[iy, ix] * (1 - tx) + field[iy, ix + 1] * tx
            low = field[iy + 1, ix] * (1 - tx) + field[iy + 1, ix + 1] * tx
            result.append(top * (1 - ty) + low * ty)
        return result

    count = 30000
    x = rng.uniform(-400, 1800, count).astype(numpy.float32)
    centre = 640 - .2 * (x - 960) + 80 * numpy.sin(x / 310)
    spread = rng.normal(0, 1, count) * 150
    y = (centre + spread).astype(numpy.float32)
    kind = numpy.where(numpy.abs(spread) < 80, 0, 1)
    kind = numpy.where(rng.random(count) < .25, 2 * (numpy.abs(spread) < 80), kind)
    kind = numpy.where(rng.random(count) < .025, 3, kind)
    tones = numpy.stack([linear(cyan), linear(magenta), linear(mint), linear(amber)])
    colour = tones[kind]
    brightness = rng.lognormal(-1.2, .7, count).astype(numpy.float32) * .035
    life = rng.integers(250, 1100, count)
    far = rng.random(count) < .35
    steps = 1100
    near_light = numpy.zeros(scene.width * scene.height * 3, dtype=numpy.float64)
    far_light = numpy.zeros_like(near_light)
    batch_x = []
    batch_y = []
    batch_w = []
    for index in range(steps):
        dx, dy = velocity(x, y)
        x = x + dx * .5
        y = y + dy * .5
        progress = index / life
        weight = numpy.sin(numpy.pi * numpy.clip(progress, 0, 1)) ** 1.2 * (progress < 1) * brightness
        batch_x.append(x * s)
        batch_y.append(y * scene.vertical)
        batch_w.append(weight)
        if len(batch_x) == 50 or index == steps - 1:
            px = numpy.concatenate(batch_x).astype(int)
            py = numpy.concatenate(batch_y).astype(int)
            pw = numpy.concatenate(batch_w)
            owner = numpy.tile(numpy.arange(count), len(batch_x))
            keep = (px >= 0) & (px < scene.width) & (py >= 0) & (py < scene.height) & (pw > 0)
            flat = (py * scene.width + px)[keep]
            for target, chosen in ((near_light, ~far[owner][keep]), (far_light, far[owner][keep])):
                for channel in range(3):
                    target[channel::3] += numpy.bincount(
                        flat[chosen], weights=(pw[keep] * colour[owner[keep], channel])[chosen],
                        minlength=scene.width * scene.height)
            batch_x = []
            batch_y = []
            batch_w = []
    near_light = near_light.reshape(scene.height, scene.width, 3).astype(numpy.float32)
    far_light = far_light.reshape(scene.height, scene.width, 3).astype(numpy.float32)
    hdr = blur(near_light, .5 * s) * 1.6 + blur(far_light, 4 * s) * 1.3
    rise = numpy.clip(scene.v, 0, 1)
    hdr += mix(linear((4, 6, 16)), linear((14, 6, 22)), rise * numpy.ones_like(scene.u))
    develop(scene, bloom(scene, hdr, 1.3), 1.4)


def rain_glass(scene):
    """There I look at the harbour through a rain-beaded, half-fogged window."""
    rng = scene.random
    s = scene.scale
    behind = canvas(scene.width // 2, scene.height // 2, scene.seed + 17)
    city = harbour_light(behind, beams=False)
    sharp = grow(blur(city, 1.5 * behind.scale), scene.height, scene.width)
    medium = grow(blur(city, 8 * behind.scale), scene.height, scene.width)
    soft = grow(blur(city, 26 * behind.scale), scene.height, scene.width)
    drops = numpy.zeros((scene.height, scene.width), dtype=numpy.float32)
    clear = numpy.zeros((scene.height, scene.width), dtype=numpy.float32)

    def drop(cx, cy, radius, stretch=1):
        """There I raise one spherical cap of water on the glass."""
        r = radius * s
        reach_x = int(r) + 2
        reach_y = int(r * stretch) + 2
        x0 = max(0, int(cx) - reach_x)
        x1 = min(scene.width, int(cx) + reach_x + 1)
        y0 = max(0, int(cy) - reach_y)
        y1 = min(scene.height, int(cy) + reach_y + 1)
        if x0 >= x1 or y0 >= y1:
            return
        xx = (numpy.arange(x0, x1, dtype=numpy.float32)[None, :] + .5 - cx) / r
        yy = (numpy.arange(y0, y1, dtype=numpy.float32)[:, None] + .5 - cy) / (r * stretch)
        cap = numpy.sqrt(numpy.clip(1 - xx * xx - yy * yy, 0, 1)) * r
        drops[y0:y1, x0:x1] = numpy.maximum(drops[y0:y1, x0:x1], cap)

    for trail in range(16):
        x = rng.uniform(80, 1840) * s
        y = rng.uniform(-50, 500) * scene.vertical
        bottom = y + rng.uniform(250, 700) * scene.vertical
        size = rng.uniform(2.2, 3.6)
        while y < bottom:
            drop(x, y, size * rng.uniform(.6, .9), 1.6)
            x0 = max(0, int(x - size * 2.5 * s))
            clear[int(y):int(y + 3 * scene.vertical), x0:int(x + size * 2.5 * s)] = 1
            if rng.random() < .06:
                drop(x, y, size * rng.uniform(1.2, 1.8))
            x += rng.normal(0, .8) * s
            y += 2 * scene.vertical
        drop(x, y + 6 * s, size * rng.uniform(3, 4.2), 1.15)
    clear = blur(clear[..., None], 3 * s)[..., 0]
    for large in range(140):
        drop(rng.uniform(0, scene.width), rng.uniform(0, scene.height), rng.uniform(7, 16), 1.1)
    for medium_drop in range(1600):
        drop(rng.uniform(0, scene.width), rng.uniform(0, scene.height), rng.uniform(2.5, 7))
    for tiny in range(16000):
        cx = rng.uniform(0, scene.width)
        cy = rng.uniform(0, scene.height)
        if clear[int(cy), int(cx)] < .3:
            drop(cx, cy, rng.uniform(.7, 2.2))

    grad_y, grad_x = numpy.gradient(drops)
    wet = drops > 0
    bend = 14 * s
    sample_x = numpy.clip(numpy.arange(scene.width)[None, :] + (grad_x * bend).astype(int), 0, scene.width - 1)
    sample_y = numpy.clip(numpy.arange(scene.height)[:, None] + (grad_y * bend).astype(int), 0, scene.height - 1)
    lens = sharp[sample_y, sample_x]
    edge = numpy.exp(-drops / (1.3 * s))
    shine = numpy.clip(-(grad_x + grad_y) * .6, 0, None) ** 10 * wet
    lens = lens * 1.3 * (1 - .7 * edge)[..., None] + numpy.minimum(shine, 1)[..., None] * linear(ice, .12)
    mist = numpy.clip(1 - clear, 0, 1)[..., None]
    glass = medium * (1 - mist) + (soft * .85 + linear((40, 40, 60), .02)) * mist
    hdr = numpy.where(wet[..., None], lens, glass)
    develop(scene, bloom(scene, hdr, .9), 1.5)


def monolith(scene):
    """There I stand one dark slab with a burning seam on a flooded plain."""
    rng = scene.random
    clouds = noise_field(scene.seed + 9)
    s = scene.scale
    horizon = int(scene.height * .64)
    level = horizon / scene.height
    rise = numpy.clip((level - scene.v) / level, 0, 1)
    sky = mix(linear((30, 14, 44)), linear((3, 3, 10)), rise ** .5)
    centre = scene.width * .68
    cols = numpy.arange(scene.width, dtype=numpy.float32)[None, :] + .5
    density = clouds.fbm(scene.u * 1920 / 380, scene.v * 1080 / 90, 6)
    deck = smooth(.42, .75, density) * smooth(.35, .8, rise)
    spot = numpy.exp(-((cols - centre) / (230 * s)) ** 2)
    hdr = sky * (1 - .5 * deck[..., None]) + (deck * spot * (.4 + density))[..., None] * linear((120, 200, 255), .35)
    hdr += (deck * .05)[..., None] * linear(violet)
    hdr = numpy.array(numpy.broadcast_to(hdr, (scene.height, scene.width, 3)), dtype=numpy.float32)
    stars = (rng.random((scene.height, scene.width), dtype=numpy.float32) > .99955) * rise ** 2 * (1 - deck)
    hdr += stars[..., None] * linear(ice, .6)

    top = int(scene.height * .13)
    half = 38 * s
    rows = numpy.arange(top, horizon, dtype=numpy.float32)[:, None]
    body = numpy.abs(cols - centre) < half
    near_seam = numpy.exp(-numpy.abs(cols - centre) / (9 * s))
    face = linear((7, 8, 14)) + near_seam[..., None] * linear((40, 60, 90), .1)
    region = hdr[top:horizon]
    region[:] = numpy.where(body[..., None], face * numpy.ones_like(rows)[..., None], region)
    along = (rows - top) / (horizon - top)
    seam = numpy.clip(1.1 * s - numpy.abs(cols - centre), 0, 1) * (numpy.mod(along * 23, 1) > .06)
    region += (seam * 4.5)[..., None] * mix(linear(cyan), linear(magenta), along)
    beam_rows = numpy.arange(top, dtype=numpy.float32)[:, None]
    lift = (top - beam_rows) / top
    beam = numpy.exp(-((cols - centre) / ((1.5 + 40 * lift) * s)) ** 2) * (1 - lift) ** 1.5
    hdr[:top] += (beam * .45)[..., None] * linear(ice)
    stamp(hdr, centre, top, 3 * s, linear(ice, 5))

    for light in range(70):
        x = rng.uniform(0, 1920) * s
        if abs(x - centre) < 120 * s:
            continue
        tone = linear([warm, cyan, amber][int(rng.integers(3))], rng.uniform(.6, 2.2))
        stamp(hdr, x, horizon - rng.uniform(0, 3) * s, rng.uniform(.4, 1.1) * s, tone)

    rows = numpy.arange(horizon, scene.height)
    distance = rows - horizon + 1
    source = numpy.clip(horizon - distance, 0, scene.height - 1)
    ripple = clouds.fbm(scene.u * 1920 / 7, (rows[:, None] / scene.vertical) / 1.6, 3) - .5
    swing = (1 + distance[:, None] * .04) * s * ripple * 2.2
    columns = numpy.clip(numpy.arange(scene.width)[None, :] + swing.astype(int), 0, scene.width - 1)
    mirror = blur(hdr[source[:, None], columns], 1.2 * s, 4 * s)
    near = (distance / (scene.height - horizon))[:, None]
    hdr[horizon:] = linear((3, 3, 8)) + mirror * (.55 - .3 * near)[..., None]
    band = numpy.exp(-numpy.abs(numpy.arange(scene.height) - horizon) / (14 * scene.vertical))
    hdr += band[:, None, None] * linear((70, 40, 110), .1)
    develop(scene, bloom(scene, hdr, 1.2), 1.3)


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
    pixels = numpy.asarray(scene.pixels, dtype=numpy.float32)
    x = numpy.linspace(0, 1, scene.width, dtype=numpy.float32)[None, :]
    y = numpy.linspace(0, 1, scene.height, dtype=numpy.float32)[:, None]
    # There I dim the capsule and clock with broad smooth masks, without hard cutouts.
    capsule = numpy.exp(-((x - .5) / .25) ** 4 - (y / .16) ** 2)
    clock = numpy.exp(-(x / .31) ** 4 - ((y - .91) / .25) ** 4)
    comfort = (1 - .7 * capsule) * (1 - .75 * clock)
    vignette = 1 - .22 * numpy.clip(((x - .56) / .8) ** 2 + ((y - .5) / .9) ** 2, 0, 1)
    for channel, ground in enumerate((5, 4, 10)):
        pixels[:, :, channel] = ground + (pixels[:, :, channel] - ground) * comfort * vignette
    rng = numpy.random.default_rng(scene.seed + 90000)
    # There I use sub-code-value monochrome grain plus uniform quantisation dither.
    grain = rng.normal(0, .8, (scene.height, scene.width)).astype(numpy.float32)
    grain += rng.uniform(-.5, .5, grain.shape).astype(numpy.float32)
    pixels += grain[..., None]
    return Image.fromarray(numpy.uint8(numpy.clip(numpy.rint(pixels), 0, 255)))


def main():
    """There I render selected scenes and report their actual size and elapsed time."""
    collection = {
        "01-harbour": (harbour, 1103),
        "02-corridor": (corridor, 2207),
        "03-ridges": (ridges, 3301),
        "04-signal": (signal, 4409),
        "05-rain-glass": (rain_glass, 5501),
        "06-monolith": (monolith, 6607),
    }
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("out_dir", type=Path)
    parser.add_argument("--size", type=dimensions, default=(3840, 2160), metavar="WIDTHxHEIGHT")
    parser.add_argument("--only", choices=collection, metavar="NAME",
                        help="one filename stem, e.g. 01-harbour")
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
