#!/usr/bin/env python3
"""Generate the GoldSun macOS .icns file from deterministic raster art."""

from __future__ import annotations

import math
import shutil
import struct
import subprocess
import zlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RESOURCES = ROOT / "Resources"
ICONSET = RESOURCES / "GoldSun.iconset"
ICNS = RESOURCES / "GoldSun.icns"

ICON_SIZES = {
    "icon_16x16.png": 16,
    "icon_16x16@2x.png": 32,
    "icon_32x32.png": 32,
    "icon_32x32@2x.png": 64,
    "icon_128x128.png": 128,
    "icon_128x128@2x.png": 256,
    "icon_256x256.png": 256,
    "icon_256x256@2x.png": 512,
    "icon_512x512.png": 512,
    "icon_512x512@2x.png": 1024,
}

CENTER_X = 0.0
CENTER_Y = -0.03
DISK_RADIUS = 0.285
RAY_COUNT = 10


def clamp(value: float, lower: float = 0.0, upper: float = 1.0) -> float:
    return max(lower, min(upper, value))


def smoothstep(edge0: float, edge1: float, value: float) -> float:
    if edge0 == edge1:
        return 1.0 if value >= edge1 else 0.0

    t = clamp((value - edge0) / (edge1 - edge0))
    return t * t * (3.0 - 2.0 * t)


def mix(a: tuple[float, float, float], b: tuple[float, float, float], t: float) -> tuple[float, float, float]:
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def over(
    base: tuple[float, float, float],
    layer: tuple[float, float, float],
    alpha: float,
) -> tuple[float, float, float]:
    alpha = clamp(alpha)
    return mix(base, layer, alpha)


def rounded_rect_alpha(x: float, y: float, half_size: float, radius: float) -> float:
    qx = abs(x) - half_size + radius
    qy = abs(y) - half_size + radius
    outside = math.hypot(max(qx, 0.0), max(qy, 0.0))
    inside = min(max(qx, qy), 0.0)
    distance = outside + inside - radius
    return smoothstep(0.018, -0.018, distance)


def circle_alpha(x: float, y: float, center_x: float, center_y: float, radius: float, edge: float) -> float:
    distance = math.hypot(x - center_x, y - center_y)
    return smoothstep(radius + edge, radius - edge, distance)


def point_in_polygon(x: float, y: float, polygon: list[tuple[float, float]]) -> bool:
    inside = False
    previous_x, previous_y = polygon[-1]

    for current_x, current_y in polygon:
        crosses = (current_y > y) != (previous_y > y)
        if crosses:
            slope_x = (previous_x - current_x) * (y - current_y) / (previous_y - current_y) + current_x
            if x < slope_x:
                inside = not inside

        previous_x, previous_y = current_x, current_y

    return inside


def distance_to_segment(
    x: float,
    y: float,
    start: tuple[float, float],
    end: tuple[float, float],
) -> float:
    start_x, start_y = start
    end_x, end_y = end
    dx = end_x - start_x
    dy = end_y - start_y
    length_squared = dx * dx + dy * dy

    if length_squared == 0.0:
        return math.hypot(x - start_x, y - start_y)

    t = clamp(((x - start_x) * dx + (y - start_y) * dy) / length_squared)
    projection_x = start_x + t * dx
    projection_y = start_y + t * dy
    return math.hypot(x - projection_x, y - projection_y)


def polygon_alpha(x: float, y: float, polygon: list[tuple[float, float]], edge: float) -> float:
    distance = min(
        distance_to_segment(x, y, polygon[index], polygon[(index + 1) % len(polygon)])
        for index in range(len(polygon))
    )
    signed_distance = -distance if point_in_polygon(x, y, polygon) else distance
    return smoothstep(edge, -edge, signed_distance)


def polar(radius: float, angle: float) -> tuple[float, float]:
    return (
        CENTER_X + math.cos(angle) * radius,
        CENTER_Y + math.sin(angle) * radius,
    )


def build_rays() -> list[list[tuple[float, float]]]:
    rays: list[list[tuple[float, float]]] = []

    for index in range(RAY_COUNT):
        angle = -math.pi / 2.0 + index * math.tau / RAY_COUNT
        horizontal_emphasis = abs(math.cos(angle))
        upward_emphasis = max(0.0, -math.sin(angle))
        downward_emphasis = max(0.0, math.sin(angle))
        outer_radius = 0.735 + horizontal_emphasis * 0.075 + upward_emphasis * 0.035 - downward_emphasis * 0.025
        inner_radius = 0.41 + (0.012 if index % 2 else 0.0)
        spread = 0.118 if upward_emphasis > 0.8 else 0.145

        rays.append(
            [
                polar(inner_radius, angle - spread),
                polar(outer_radius, angle),
                polar(inner_radius, angle + spread),
            ]
        )

    return rays


RAYS = build_rays()


def ray_shape_alpha(x: float, y: float, edge: float) -> float:
    alpha = 0.0
    for ray in RAYS:
        alpha = max(alpha, polygon_alpha(x, y, ray, edge))

    return alpha


def metallic_gold(x: float, y: float, size: int) -> tuple[float, float, float]:
    vertical = clamp((y + 0.82) / 1.38)
    diagonal_highlight = clamp(1.0 - math.hypot(x + 0.22, y + 0.34) / 0.92)
    lower_shadow = clamp((y - 0.06) / 0.72)
    grain = math.sin((x * 93.17 + y * 61.11) * 17.0) * math.sin((x * 21.31 - y * 77.73) * 13.0)
    grain_strength = 0.028 if size >= 128 else 0.0

    color = mix((255.0, 236.0, 153.0), (206.0, 121.0, 28.0), vertical)
    color = over(color, (255.0, 252.0, 216.0), diagonal_highlight * 0.42)
    color = over(color, (126.0, 67.0, 12.0), lower_shadow * 0.22)

    if grain > 0.0:
        color = over(color, (255.0, 255.0, 220.0), grain * grain_strength)
    else:
        color = over(color, (116.0, 66.0, 15.0), -grain * grain_strength)

    return color


def background_color(x: float, y: float) -> tuple[float, float, float]:
    vertical = clamp((y + 1.0) / 2.0)
    warm_corner = clamp(1.0 - math.hypot(x - 0.58, y - 0.75) / 1.2)
    center_glow = clamp(1.0 - math.hypot(x - CENTER_X, y - CENTER_Y) / 1.08)
    vignette = clamp((math.hypot(x, y) - 0.42) / 0.8)

    color = mix((31.0, 31.0, 29.0), (58.0, 48.0, 37.0), vertical)
    color = over(color, (121.0, 88.0, 48.0), warm_corner * 0.28)
    color = over(color, (86.0, 71.0, 49.0), center_glow * 0.17)
    color = over(color, (16.0, 16.0, 15.0), vignette * 0.24)
    return color


def write_png(path: Path, size: int) -> None:
    pixels = bytearray()
    edge = 2.0 / size

    for row in range(size):
        scanline = bytearray([0])
        y = (row + 0.5) / size * 2.0 - 1.0

        for column in range(size):
            x = (column + 0.5) / size * 2.0 - 1.0
            icon_alpha = rounded_rect_alpha(x, y, 0.92, 0.22)
            color = background_color(x, y)

            shadow_rays = ray_shape_alpha(x - 0.03, y - 0.045, edge * 1.6)
            shadow_disk = circle_alpha(x, y, CENTER_X + 0.03, CENTER_Y + 0.045, DISK_RADIUS, edge * 2.0)
            color = over(color, (7.0, 7.0, 7.0), max(shadow_rays, shadow_disk) * 0.34)

            ray_alpha = ray_shape_alpha(x, y, edge * 1.35)
            ray_color = metallic_gold(x, y, size)
            ray_tip_highlight = clamp(1.0 - math.hypot(x + 0.2, y + 0.42) / 0.78)
            ray_color = over(ray_color, (255.0, 252.0, 214.0), ray_tip_highlight * 0.12)
            color = over(color, ray_color, ray_alpha)

            disk_alpha = circle_alpha(x, y, CENTER_X, CENTER_Y, DISK_RADIUS, edge * 1.7)
            disk_color = metallic_gold(x, y, size)
            disk_highlight = clamp(1.0 - math.hypot(x + 0.12, y + 0.18) / 0.52)
            disk_shadow = clamp((math.hypot(x - CENTER_X, y - CENTER_Y) - DISK_RADIUS * 0.48) / (DISK_RADIUS * 0.62))
            disk_color = over(disk_color, (255.0, 252.0, 216.0), disk_highlight * 0.20)
            disk_color = over(disk_color, (120.0, 67.0, 14.0), disk_shadow * 0.10)
            color = over(color, disk_color, disk_alpha)

            rim_alpha = circle_alpha(x, y, CENTER_X, CENTER_Y, DISK_RADIUS + 0.012, edge * 1.2) * (
                1.0 - circle_alpha(x, y, CENTER_X, CENTER_Y, DISK_RADIUS - 0.018, edge * 1.2)
            )
            color = over(color, (255.0, 230.0, 127.0), rim_alpha * 0.34)

            shine = smoothstep(-0.48, -0.80, y) * smoothstep(0.78, 0.18, abs(x + 0.12))
            color = over(color, (255.0, 255.0, 255.0), shine * 0.055)

            alpha = round(icon_alpha * 255)
            scanline.extend(round(clamp(channel, 0.0, 255.0)) for channel in color)
            scanline.append(alpha)

        pixels.extend(scanline)

    def png_chunk(chunk_type: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + chunk_type
            + data
            + struct.pack(">I", zlib.crc32(chunk_type + data) & 0xFFFFFFFF)
        )

    header = struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)
    compressed = zlib.compress(bytes(pixels), level=9)
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + png_chunk(b"IHDR", header)
        + png_chunk(b"IDAT", compressed)
        + png_chunk(b"IEND", b"")
    )


def main() -> None:
    iconutil = Path("/usr/bin/iconutil")
    if not iconutil.exists():
        raise SystemExit("iconutil is required to build Resources/GoldSun.icns")

    RESOURCES.mkdir(exist_ok=True)
    if ICONSET.exists():
        shutil.rmtree(ICONSET)
    ICONSET.mkdir()

    for name, size in ICON_SIZES.items():
        write_png(ICONSET / name, size)

    if ICNS.exists():
        ICNS.unlink()

    subprocess.run([str(iconutil), "-c", "icns", "-o", str(ICNS), str(ICONSET)], check=True)
    shutil.rmtree(ICONSET)
    print(ICNS)


if __name__ == "__main__":
    main()
