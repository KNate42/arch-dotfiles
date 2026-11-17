"""There I render six reproducible calm glass wallpapers with NumPy and Pillow.

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
from PIL import Image


def colour(value):
    """There I convert a hexadecimal colour to floating point display values."""
    return numpy.array([int(value[index:index + 2], 16) for index in (0, 2, 4)],
                       dtype=numpy.float32) / 255


class canvas:
    """There I compose broad colour fields and softly illuminated silk folds."""

    def __init__(self, width, height, background):
        """There I keep coordinates small and use single precision throughout."""
        self.x = numpy.linspace(0, 1, width, dtype=numpy.float32)[None, :]
        self.y = numpy.linspace(0, 1, height, dtype=numpy.float32)[:, None]
        self.pixels = numpy.empty((height, width, 3), dtype=numpy.float32)
        self.pixels[:] = colour(background)

    def mix(self, target, mask):
        """There I glaze the image without making clipped additive highlights."""
        target = colour(target)
        mask = numpy.clip(mask, 0, 1)
        for channel in range(3):
            self.pixels[:, :, channel] += (
                target[channel] - self.pixels[:, :, channel]) * mask

    def fog(self, centre_x, centre_y, radius_x, radius_y, target, strength):
        """There I soften the background with a large elliptical colour field."""
        distance = ((self.x - centre_x) / radius_x) ** 2
        distance = distance + ((self.y - centre_y) / radius_y) ** 2
        self.mix(target, numpy.exp(-distance * 1.6) * strength)

    def silk(self, curve, width, body, light, strength=1):
        """There I shade a wide translucent fold with a feathered luminous lip."""
        distance = (self.y - curve) / width
        edge = 0.5 + 0.5 * numpy.tanh((distance + 0.82) / 0.055)
        envelope = edge * numpy.exp(-(numpy.maximum(distance, 0) / 1.18) ** 2)
        self.mix(body, envelope * 0.94 * strength)
        illumination = numpy.exp(-((distance + 0.56) / 0.33) ** 2) * edge
        sweep = 0.76 + 0.24 * numpy.sin(self.x * 4.1 + 0.5)
        self.mix(light, illumination * sweep * 0.69 * strength)
        lip = numpy.exp(-((distance + 0.79) / 0.052) ** 2)
        self.mix(light, lip * sweep * 0.22 * strength)
        shadow = numpy.exp(-((distance - 0.46) / 0.40) ** 2)
        self.mix(body, shadow * 0.48 * strength)

    def dune(self, curve, width, body, light, strength=1):
        """There I let a misty ridge flow into a broad quiet foreground."""
        distance = (self.y - curve) / width
        face = 0.5 + 0.5 * numpy.tanh(distance * 5)
        self.mix(body, face * strength)
        crest = numpy.exp(-((distance - 0.25) / 0.50) ** 2) * face
        self.mix(light, crest * 0.52 * strength)


def deep_blue(scene):
    """There I suspend blue aurora folds above a deep navy background."""
    x = scene.x
    scene.fog(0.76, 0.53, 0.72, 0.72, "123b72", 0.62)
    scene.fog(0.18, 0.91, 0.58, 0.48, "122754", 0.65)
    curve = 0.93 - 0.64 * x + 0.13 * numpy.sin(5.4 * x - 0.7)
    scene.silk(curve - 0.20 + 0.045 * numpy.sin(6 * x), 0.16,
               "122e61", "426da0", 0.67)
    scene.silk(curve + 0.22, 0.26, "112753", "2855a3", 0.92)
    width = 0.15 + 0.055 * numpy.sin(math.pi * x) ** 2
    scene.silk(curve, width, "16447d", "7ab8ce")
    scene.fog(0.72, 0.49, 0.40, 0.19, "66abc4", 0.12)
    scene.fog(0.12, 0.13, 0.72, 0.39, "060e22", 0.70)


def ember(scene):
    """There I drape amber and muted rose silk across a warm black ground."""
    x = scene.x
    scene.fog(0.23, 0.61, 0.70, 0.64, "6b312d", 0.45)
    scene.fog(0.88, 0.86, 0.52, 0.51, "4b2334", 0.65)
    curve = 0.66 + 0.15 * numpy.sin(5.5 * x - 0.9) - 0.13 * x
    scene.silk(curve - 0.15 - 0.06 * numpy.sin(5 * x), 0.15,
               "4f2833", "b78182", 0.70)
    scene.silk(curve + 0.34 - 0.12 * x, 0.24, "3a2029", "ad7667", 0.90)
    scene.silk(curve + 0.10, 0.18 + 0.04 * x, "74422f", "e9b57c")
    scene.fog(0.15, 0.51, 0.38, 0.28, "c58b52", 0.18)
    scene.fog(0.88, 0.67, 0.35, 0.32, "b8797d", 0.20)
    scene.fog(0.54, 0.06, 1.00, 0.35, "160f16", 0.78)


def forest(scene):
    """There I stack green teal dunes and let their distant crests dissolve in fog."""
    x = scene.x
    scene.fog(0.73, 0.39, 0.70, 0.64, "285b53", 0.65)
    curve = 0.42 + 0.12 * numpy.sin(4.8 * x + 0.1) + 0.08 * x
    scene.dune(curve, 0.12, "193b37", "68988a", 0.70)
    curve = 0.62 + 0.10 * numpy.sin(5.8 * x - 1.8) - 0.09 * x
    scene.dune(curve, 0.10, "113831", "4a8a73", 0.94)
    curve = 0.85 + 0.14 * numpy.sin(4.6 * x + 0.2) - 0.22 * x
    scene.dune(curve, 0.13, "0c2523", "34746a")
    scene.fog(0.68, 0.43, 0.40, 0.12, "82a695", 0.12)
    scene.fog(0.12, 0.10, 0.80, 0.34, "081b1b", 0.74)


def violet(scene):
    """There I turn a broad violet ribbon through a softer magenta reflection."""
    x = scene.x
    scene.fog(0.64, 0.52, 0.68, 0.65, "442552", 0.60)
    scene.fog(0.15, 0.84, 0.60, 0.54, "25204d", 0.72)
    curve = 0.79 - 0.36 * x + 0.20 * numpy.sin(7.0 * x - 1.0)
    scene.silk(curve - 0.18 - 0.06 * numpy.sin(5 * x), 0.15,
               "3b244d", "bf8bb3", 0.75)
    scene.silk(curve + 0.25 - 0.08 * x, 0.23, "261d4b", "8074bd", 0.92)
    scene.silk(curve, 0.18 + 0.03 * numpy.cos(4 * x), "50346e", "c0a9dc")
    scene.fog(0.76, 0.60, 0.28, 0.23, "b16e9b", 0.22)
    scene.fog(0.46, 0.04, 0.90, 0.37, "120e23", 0.85)


def graphite(scene):
    """There I light restrained graphite silk with a trace of cool silver."""
    x = scene.x
    scene.fog(0.70, 0.49, 0.86, 0.68, "353d48", 0.50)
    curve = 1.08 - 0.65 * x - 0.14 * numpy.sin(math.pi * x)
    scene.silk(curve - 0.17 + 0.05 * numpy.sin(5 * x), 0.16,
               "242a33", "727d89", 0.54)
    scene.silk(curve + 0.20, 0.25, "1a2028", "4c5664", 0.80)
    scene.silk(curve, 0.19, "303945", "87939f", 0.80)
    scene.fog(0.38, 0.06, 0.92, 0.40, "0e1219", 0.77)


def dawn(scene):
    """There I float peach morning light across pale lilac mist and soft dunes."""
    x = scene.x
    scene.fog(0.08, 0.20, 0.77, 0.85, "f7ddc8", 0.84)
    scene.fog(0.91, 0.41, 0.70, 0.80, "c2b7d8", 0.65)
    scene.fog(0.50, 0.10, 0.64, 0.50, "f7e7df", 0.40)
    curve = 0.62 + 0.13 * numpy.sin(4.7 * x - 0.6) - 0.10 * x
    scene.dune(curve, 0.16, "d6bbc4", "f4d9cb", 0.74)
    curve = 0.91 + 0.12 * numpy.sin(5.0 * x + 0.3) - 0.30 * x
    scene.dune(curve, 0.19, "bcb5cf", "e4ced9", 0.77)
    scene.fog(0.18, 0.42, 0.50, 0.42, "ffe5cf", 0.20)


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
