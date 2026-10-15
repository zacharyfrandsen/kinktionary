#!/usr/bin/env python3
"""Arrange unboxed, rotated motifs from the original wallpaper.

Requires Pillow and opencv-python-headless. Writes a separate asset so the
source artwork remains unchanged.
"""
from pathlib import Path
import math
import random

import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "assets" / "images" / "background.webp"
OUTPUT = ROOT / "assets" / "images" / "background_items.webp"

REFERENCE_COLUMNS = 8
GROUP_KERNEL = 13
BACKGROUND_LEVEL = 22
MIN_MOTIF_AREA = 24
PLACEMENT_GAP = 24
PLACEMENT_ATTEMPTS = 800
SIMILARITY_THRESHOLD = 0.72
SIMILAR_MOTIF_DISTANCE = 900


def _motif_signature(motif):
    alpha = np.asarray(motif.getchannel("A"))
    height, width = alpha.shape
    scale = 30 / max(height, width)
    resized = cv2.resize(
        alpha,
        (max(1, round(width * scale)), max(1, round(height * scale))),
        interpolation=cv2.INTER_AREA,
    )
    signature = np.zeros((32, 32), dtype=np.uint8)
    top = (32 - resized.shape[0]) // 2
    left = (32 - resized.shape[1]) // 2
    signature[top:top + resized.shape[0], left:left + resized.shape[1]] = resized
    return signature > 32


def _shape_similarity(first, second):
    best = 0.0
    for rotation in range(4):
        rotated = np.rot90(second, rotation)
        union = np.logical_or(first, rotated).sum()
        if union:
            best = max(best, np.logical_and(first, rotated).sum() / union)
    return best


def main():
    source = Image.open(SOURCE).convert("RGB")
    pixels = np.asarray(source)
    gray = cv2.cvtColor(pixels, cv2.COLOR_RGB2GRAY)
    foreground = np.uint8(gray > BACKGROUND_LEVEL)
    kernel = cv2.getStructuringElement(
        cv2.MORPH_ELLIPSE, (GROUP_KERNEL, GROUP_KERNEL)
    )
    grouped = cv2.dilate(foreground, kernel)
    count, _, stats, _ = cv2.connectedComponentsWithStats(grouped, 8)
    motifs = []
    rng = random.Random(23)

    for x, y, width, height, area in stats[1:count]:
        if area < MIN_MOTIF_AREA:
            continue
        region = foreground[y:y + height, x:x + width]
        rows, columns = np.nonzero(region)
        if not len(rows):
            continue
        item_left = int(x + columns.min())
        item_top = int(y + rows.min())
        item_right = int(x + columns.max())
        item_bottom = int(y + rows.max())
        if (item_left == 0 or item_top == 0 or
                item_right == source.width - 1 or
                item_bottom == source.height - 1):
            continue

        left = max(0, item_left - 8)
        top = max(0, item_top - 8)
        right = min(source.width, item_right + 9)
        bottom = min(source.height, item_bottom + 9)
        rgb_crop = pixels[top:bottom, left:right]
        gray_crop = gray[top:bottom, left:right].astype(np.float32)
        alpha = np.clip((gray_crop - 18) * 5, 0, 255).astype(np.uint8)
        motif = Image.fromarray(np.dstack((rgb_crop, alpha)), "RGBA")
        signature = _motif_signature(motif)
        angle = -15 + rng.uniform(-13, 13)
        motif = motif.rotate(angle, resample=Image.Resampling.BICUBIC, expand=True)
        motifs.append((motif, signature))

    reference_width = round(source.width / REFERENCE_COLUMNS - 36)
    reference_height = round(source.height / REFERENCE_COLUMNS - 36)
    prepared = []
    for motif, signature in motifs:
        motif.thumbnail((reference_width, reference_height), Image.Resampling.LANCZOS)
        scale = rng.uniform(0.72, 1.2)
        if scale != 1:
            motif = motif.resize(
                (round(motif.width * scale), round(motif.height * scale)),
                Image.Resampling.LANCZOS,
            )
        prepared.append((motif, signature))

    rng.shuffle(prepared)
    prepared.sort(
        key=lambda item: item[0].width * item[0].height, reverse=True
    )
    wallpaper = Image.new("RGB", source.size, (14, 14, 16))
    placements = []

    for motif, signature in prepared:
        similar_centers = [
            (other_x, other_y)
            for other_x, other_y, _, other_signature in placements
            if _shape_similarity(signature, other_signature) >= SIMILARITY_THRESHOLD
        ]
        placed = False
        for shrink in range(20):
            scale = 0.9 ** shrink
            candidate = motif
            if shrink:
                candidate = motif.resize(
                    (max(1, round(motif.width * scale)),
                     max(1, round(motif.height * scale))),
                    Image.Resampling.LANCZOS,
                )
            for _ in range(PLACEMENT_ATTEMPTS):
                center_x = rng.randrange(source.width)
                center_y = rng.randrange(source.height)
                too_close = False
                for other_x, other_y, other, _ in placements:
                    delta_x = abs(center_x - other_x)
                    delta_y = abs(center_y - other_y)
                    delta_x = min(delta_x, source.width - delta_x)
                    delta_y = min(delta_y, source.height - delta_y)
                    if (delta_x < (candidate.width + other.width) / 2 + PLACEMENT_GAP and
                            delta_y < (candidate.height + other.height) / 2 + PLACEMENT_GAP):
                        too_close = True
                        break
                if not too_close:
                    too_close = any(
                        math.hypot(
                            min(abs(center_x - other_x),
                                source.width - abs(center_x - other_x)),
                            min(abs(center_y - other_y),
                                source.height - abs(center_y - other_y)),
                        ) < SIMILAR_MOTIF_DISTANCE
                        for other_x, other_y in similar_centers
                    )
                if not too_close:
                    placements.append((center_x, center_y, candidate, signature))
                    left = center_x - candidate.width // 2
                    top = center_y - candidate.height // 2
                    for offset_x in (-source.width, 0, source.width):
                        for offset_y in (-source.height, 0, source.height):
                            wallpaper.paste(
                                candidate,
                                (left + offset_x, top + offset_y),
                                candidate.getchannel("A"),
                            )
                    placed = True
                    break
            if placed:
                break
        if not placed:
            raise RuntimeError("Could not place all motifs without overlap")

    wallpaper.save(OUTPUT, format="WEBP", quality=96, method=6)
    print(f"Wrote {OUTPUT.relative_to(ROOT)} with {len(motifs)} unboxed motifs")


if __name__ == "__main__":
    main()