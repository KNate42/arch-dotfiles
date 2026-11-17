"""There I render six reproducible luminous silk wallpapers with NumPy and Pillow.

This work made by Anfinogentov Nikita

There I use Python 3, numpy and Pillow only. There I run the whole collection with
python scripts/wallpapers/make_wallpapers.py wallpapers
or choose one stem with --only 01-deep-blue and a resolution with --size 1920x1080.
There I fix every seed; identical dependency versions produce identical JPEG bytes.
There I render the repository images with Python 3.10.11, numpy 2.2.6 and Pillow 12.3.0.
"""

import argparse
import math
from pathlib import Path
import time

import numpy
from PIL import Image, ImageFilter


def colour(value):
    """There I convert a hexadecimal colour to floating point display values."""
    return numpy.array([int(value[index:index + 2], 16) for index in (0, 2, 4)],
                       dtype=numpy.float32) / 255


def gradient(first, second, position):
    """There I blend two pigments along a fold without desaturating its shadows."""
    position = numpy.clip(position, 0, 1)[..., None]
    return colour(first) + (colour(second) - colour(first)) * position


class canvas:
    """There I compose broad colour fields and softly illuminated silk folds."""

    def __init__(self, width, height, background):
        """There I keep coordinates small and use single precision throughout."""
        self.x = numpy.linspace(0, 1, width, dtype=numpy.float32)[None, :]
        self.y = numpy.linspace(0, 1, height, dtype=numpy.float32)[:, None]
        self.pixels = numpy.empty((height, width, 3), dtype=numpy.float32)
        self.pixels[:] = colour(background)
        self.emission = numpy.zeros_like(self.pixels)

    def mix(self, target, mask):
        """There I glaze the image without making clipped additive highlights."""
        if isinstance(target, str):
            target = colour(target)
        mask = numpy.clip(mask, 0, 1)
        for channel in range(3):
            self.pixels[:, :, channel] += (
                target[..., channel] - self.pixels[:, :, channel]) * mask

    def screen(self, target, mask, bloom=0):
        """There I let coloured light approach white smoothly and retain headroom."""
        if isinstance(target, str):
            target = colour(target)
        mask = numpy.clip(mask, 0, 1)
        for channel in range(3):
            light = target[..., channel] * mask
            self.pixels[:, :, channel] += (1 - self.pixels[:, :, channel]) * light
            if bloom:
                self.emission[:, :, channel] += light * bloom

    def fog(self, centre_x, centre_y, radius_x, radius_y, target, strength):
        """There I soften the background with a large elliptical colour field."""
        distance = ((self.x - centre_x) / radius_x) ** 2
        distance = distance + ((self.y - centre_y) / radius_y) ** 2
        self.mix(target, numpy.exp(-distance * 1.6) * strength)

    def silk(self, curve, width, body, light, strength=1, reflection=None,
             focus=0.70, glow=0.85):
        """There I sculpt a coloured face, dark return and locally glowing crest."""
        distance = (self.y - curve) / width
        edge = 0.5 + 0.5 * numpy.tanh((distance + 0.82) / 0.09)
        envelope = edge * numpy.exp(-(numpy.maximum(distance, 0) / 1.28) ** 2)
        sweep = numpy.exp(-((self.x - focus) / 0.36) ** 2)
        self.mix(body, envelope * 0.94 * strength)
        if reflection is not None:
            reflected = numpy.exp(-((distance - 0.02) / 0.68) ** 2) * edge
            self.mix(reflection, reflected * (0.28 + 0.42 * sweep) * strength)
        illumination = numpy.exp(-((distance + 0.48) / 0.37) ** 2) * edge
        self.mix(light, illumination * (0.30 + 0.52 * sweep) * strength)
        # There I light the thin crest and a wider translucent face separately.
        lip = numpy.exp(-((distance + 0.71) / 0.105) ** 2)
        self.screen(light, lip * (0.16 + 0.68 * sweep) * strength * glow, 0.80)
        transmitted = numpy.exp(-((distance + 0.35) / 0.55) ** 2)
        self.screen(light, transmitted * sweep * 0.32 * strength * glow, 0.18)
        halo = numpy.exp(-((distance + 0.64) / 0.95) ** 2)
        self.screen(light, halo * sweep * 0.10 * strength * glow)

    def bloom(self):
        """There I scatter crest light across the silhouette at two soft scales."""
        height, width = self.pixels.shape[:2]
        # There I sample radiance at one eighth size to keep memory and time modest.
        radiance = numpy.clip(self.emission[::8, ::8], 0, 1)
        source = Image.fromarray(numpy.uint8(numpy.rint(radiance * 255)))
        for radius, strength in ((3, 0.24), (13, 0.14)):
            blurred = source.filter(ImageFilter.GaussianBlur(radius * width / 3840))
            blurred = blurred.resize((width, height), Image.Resampling.BILINEAR)
            light = numpy.asarray(blurred, dtype=numpy.float32) / 255
            self.pixels += (1 - self.pixels) * light * strength
        del self.emission


def deep_blue(scene):
    """There I carry electric cyan and azure light through deep blue aurora silk."""
    x = scene.x
    scene.fog(0.77, 0.58, 0.64, 0.60, "073d99", 0.76)
    scene.fog(0.30, 0.87, 0.58, 0.42, "3520a0", 0.54)
    curve = 0.99 - 0.42 * x + 0.11 * numpy.sin(5.4 * x - 0.7)
    scene.silk(curve - 0.22 + 0.04 * numpy.sin(6 * x), 0.14,
               "192b83", gradient("6545e8", "168afa", x), 0.74,
               reflection="3826bc", focus=0.77, glow=0.70)
    scene.silk(curve + 0.24, 0.26, "101d62", "2374f3", 0.90,
               reflection="3436ac", focus=0.81, glow=0.52)
    width = 0.18 + 0.055 * numpy.sin(math.pi * x) ** 2
    scene.silk(curve, width, gradient("182c98", "006fbb", x),
               gradient("197bff", "55f9e9", x), reflection="0757de")
    scene.fog(0.10, 0.08, 0.72, 0.37, "040a23", 0.86)


def ember(scene):
    """There I weave amber, coral and rose light into warm folded silk."""
    x = scene.x
    scene.fog(0.75, 0.65, 0.64, 0.58, "9d2541", 0.58)
    scene.fog(0.28, 0.88, 0.60, 0.42, "651238", 0.62)
    curve = 0.72 + 0.13 * numpy.sin(5.2 * x - 0.9) - 0.06 * x
    scene.silk(curve - 0.19 - 0.035 * numpy.sin(5 * x), 0.14,
               "70183b", gradient("db237e", "ff8269", x), 0.78,
               reflection="b51a60", focus=0.75, glow=0.80)
    scene.silk(curve + 0.30 - 0.05 * x, 0.24, "491440", "f03888", 0.87,
               reflection="9f245b", focus=0.82, glow=0.55)
    scene.silk(curve + 0.07, 0.18 + 0.035 * x,
               gradient("9b234e", "bd4b15", x),
               gradient("ff576d", "ffd56b", x), reflection="f16a36", focus=0.68)
    scene.fog(0.15, 0.08, 0.90, 0.36, "200b21", 0.87)


def forest(scene):
    """There I illuminate emerald folds with teal reflections and lime gold."""
    x = scene.x
    scene.fog(0.76, 0.52, 0.63, 0.58, "006853", 0.66)
    scene.fog(0.28, 0.89, 0.58, 0.44, "003e4b", 0.67)
    curve = 0.52 + 0.08 * numpy.sin(4.8 * x + 0.1) - 0.04 * x
    scene.silk(curve, 0.12, "006455", "35e4c4", 0.62,
               reflection="00867e", focus=0.81, glow=0.68)
    curve = 0.75 + 0.13 * numpy.sin(5 * x - 1.3) - 0.09 * x
    scene.silk(curve, 0.17, gradient("00684f", "38851c", x),
               gradient("23e6b8", "d4f875", x ** 1.7),
               reflection="02a45d", focus=0.68)
    curve = 1.01 + 0.12 * numpy.sin(4.6 * x + 0.2) - 0.20 * x
    scene.silk(curve, 0.18, "00453f", gradient("087768", "3ee6b4", x), 0.92,
               reflection="006c60", focus=0.79, glow=0.67)
    scene.fog(0.12, 0.07, 0.80, 0.34, "031b20", 0.88)


def violet(scene):
    """There I turn violet silk towards a hot pink source above blue shadows."""
    x = scene.x
    scene.fog(0.73, 0.59, 0.63, 0.61, "6213a5", 0.68)
    scene.fog(0.20, 0.89, 0.60, 0.42, "172d98", 0.61)
    curve = 0.86 - 0.22 * x + 0.14 * numpy.sin(6.2 * x - 0.8)
    scene.silk(curve - 0.20 - 0.035 * numpy.sin(5 * x), 0.14,
               "552098", gradient("713cff", "f642c8", x), 0.77,
               reflection="9d17c0", focus=0.78, glow=0.74)
    scene.silk(curve + 0.26 - 0.05 * x, 0.24, "202277", "5269f8", 0.92,
               reflection="4234bb", focus=0.79, glow=0.65)
    scene.silk(curve, 0.18 + 0.025 * numpy.cos(4 * x),
               gradient("4921a5", "981c9e", x),
               gradient("a759ff", "ff74cb", x), reflection="c02fc8", focus=0.68)
    scene.fog(0.11, 0.06, 0.82, 0.35, "100b2c", 0.90)


def graphite(scene):
    """There I graze graphite with steel blue light and one fine warm reflection."""
    x = scene.x
    scene.fog(0.77, 0.59, 0.72, 0.61, "243c56", 0.54)
    curve = 1.10 - 0.46 * x - 0.14 * numpy.sin(math.pi * x)
    scene.silk(curve - 0.20 + 0.04 * numpy.sin(5 * x), 0.15,
               "25303d", "7292b0", 0.58, focus=0.81, glow=0.48)
    scene.silk(curve + 0.20, 0.25, "172331", "386889", 0.78,
               reflection="293e58", focus=0.82, glow=0.44)
    scene.silk(curve, 0.18, "263e53", "97c4de", 0.84,
               reflection="315b80", focus=0.73, glow=0.66)
    distance = (scene.y - curve) / 0.18
    streak = numpy.exp(-((distance + 0.73) / 0.065) ** 2)
    streak *= numpy.exp(-((x - 0.70) / 0.18) ** 2)
    scene.mix("efba86", streak * 0.54)
    scene.screen("ffe0ad", streak * 0.32, 0.65)
    scene.fog(0.11, 0.06, 0.88, 0.38, "0c121d", 0.85)


def dawn(scene):
    """There I shape peach, pink and lilac morning silk around a sky blue fold."""
    x = scene.x
    scene.fog(0.12, 0.10, 0.82, 0.62, "7e82b4", 0.86)
    scene.fog(0.83, 0.64, 0.67, 0.61, "ffd3ae", 0.84)
    scene.fog(0.19, 0.88, 0.64, 0.43, "8dbfe1", 0.75)
    curve = 0.55 + 0.15 * numpy.sin(4.8 * x - 0.5) - 0.05 * x
    scene.silk(curve - 0.12, 0.14, "aa8fc4", "f9b9dc", 0.78,
               reflection="c595d5", focus=0.77, glow=0.43)
    scene.silk(curve + 0.14, 0.21, gradient("be8fb2", "e9a897", x),
               gradient("ffb9cf", "ffdfb4", x),
               reflection="f1acb9", focus=0.71, glow=0.46)
    curve = 1.02 + 0.12 * numpy.sin(5 * x + 0.3) - 0.32 * x
    scene.silk(curve, 0.20, gradient("798bc2", "8da9d7", x),
               gradient("b9b5ec", "a4e4f5", x), 0.91,
               reflection="ac9ad8", focus=0.76, glow=0.40)


def dimensions(value):
    """There I reject malformed and nonpositive canvas dimensions at the CLI."""
    try:
        width, height = (int(part) for part in value.lower().split("x"))
    except ValueError as error:
        raise argparse.ArgumentTypeError("Ooops.. use WIDTHxHEIGHT, e.g. 3840x2160") from error
    if width < 1 or height < 1:
        raise argparse.ArgumentTypeError("Ooops.. both dimensions must be positive")
    return width, height


def finish(scene, seed):
    """There I add 1.2 percent monochrome film grain before JPEG quantisation."""
    scene.bloom()
    height, width = scene.pixels.shape[:2]
    generator = numpy.random.Generator(numpy.random.PCG64(seed))
    grain = generator.standard_normal((height, width), dtype=numpy.float32)
    # There I use a 1.2 percent standard deviation with gently bounded tails.
    grain = numpy.tanh(grain / 2) * (0.012 / 0.4165)
    # There I soften grain in deep shadows to keep the black ground clean.
    luminance = numpy.mean(scene.pixels, axis=2)
    grain *= 0.50 + 0.50 * numpy.sqrt(numpy.clip(luminance, 0, 1))
    for channel in range(3):
        scene.pixels[:, :, channel] += grain
    numpy.clip(scene.pixels, 0, 1, out=scene.pixels)
    scene.pixels *= 255
    numpy.rint(scene.pixels, out=scene.pixels)
    return Image.fromarray(scene.pixels.astype(numpy.uint8))


def main():
    """There I render the requested collection and report time and file sizes."""
    collection = {
        "01-deep-blue": (deep_blue, "070f23", 1103),
        "02-ember": (ember, "160e14", 2207),
        "03-forest": (forest, "091c1c", 3301),
        "04-violet": (violet, "130e24", 4409),
        "05-graphite": (graphite, "10141b", 5501),
        "06-dawn": (dawn, "e4d7df", 6607),
    }
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("out_dir", type=Path)
    parser.add_argument("--size", type=dimensions, default=(3840, 2160),
                        metavar="WIDTHxHEIGHT")
    parser.add_argument("--only", choices=collection, metavar="NAME",
                        help="one filename stem, e.g. 01-deep-blue")
    arguments = parser.parse_args()
    started = time.perf_counter()
    try:
        arguments.out_dir.mkdir(parents=True, exist_ok=True)
        for name, (render, background, seed) in collection.items():
            if arguments.only and name != arguments.only:
                continue
            image_started = time.perf_counter()
            scene = canvas(*arguments.size, background)
            render(scene)
            image = finish(scene, seed)
            destination = arguments.out_dir / (name + ".jpg")
            image.save(destination, format="JPEG", quality=92, subsampling=0,
                       optimize=True, progressive=True)
            print("{}: {}x{}, {:,.0f} bytes, {:.2f} s".format(
                destination, *arguments.size, destination.stat().st_size,
                time.perf_counter() - image_started), flush=True)
            del scene, image
    except (OSError, MemoryError) as error:
        parser.exit(1, "Ooops.. {}\n".format(error))
    print("Total: {:.2f} s".format(time.perf_counter() - started))


if __name__ == "__main__":
    main()
