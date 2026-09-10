#!/usr/bin/env python3
"""Seeded inputs and independent mathematical FIR outputs for native UVM."""
import argparse
import json
import random
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from reference_model import golden_filter, random_coef


def generate(path, width, height, kernel, seed, coefficient_json=None):
    if not (24 <= width <= 1440 and 24 <= height <= 4096 and kernel in range(1, 50, 2)):
        raise ValueError("Expected W=24..1440, H=24..4096, odd kernel=1..49")
    rng = random.Random(seed)
    coeff = random_coef(rng, kernel)
    if coefficient_json:
        coeff = json.loads(coefficient_json.read_text())["coefficient_half"]
        if len(coeff)!=(kernel+1)//2 or any(not isinstance(c,int) or not 0<=c<=128 for c in coeff) or 2*sum(coeff[:-1])+coeff[-1]!=128:
            raise ValueError("Learned coefficients violate the hardware contract")
    image = [[tuple(rng.randrange(1024) for _ in range(4)) for _ in range(width)] for _ in range(height)]
    output = golden_filter(image, height, width, kernel, coeff)
    words = []
    for frame in (image, output):
        for row in frame:
            for x in range(0, width, 4):
                value = 0
                for p in range(min(4, width - x)):
                    for c in range(4):
                        value |= row[x + p][c] << ((p * 4 + c) * 10)
                words.append(f"{value:040x}")
    packed = sum(c << (8 * i) for i, c in enumerate(coeff))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(f"{width} {height} {kernel} {packed:050x}\n" + "\n".join(words) + "\n")
    return {"width": width, "height": height, "kernel": kernel, "seed": seed,
            "beats": height * ((width + 3) // 4), "coefficient_half": coeff}


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("output", type=Path)
    p.add_argument("--width", type=int, default=25)
    p.add_argument("--height", type=int, default=56)
    p.add_argument("--kernel", type=int, default=3)
    p.add_argument("--seed", type=int, default=20260910)
    p.add_argument("--coefficient-json", type=Path)
    a = p.parse_args()
    print(json.dumps(generate(a.output, a.width, a.height, a.kernel, a.seed, a.coefficient_json)))
