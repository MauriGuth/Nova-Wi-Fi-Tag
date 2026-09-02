#!/usr/bin/env python3
"""Genera los íconos sin dependencias (PNG escrito a mano):

    NovaWifiTag/Assets.xcassets/AppIcon.appiconset/AppIcon.png       1024×1024
    NovaWifiTagClip/Assets.xcassets/AppIcon.appiconset/AppIcon.png   1024×1024
    assets/appclip-card-1800x1200.png                                 imagen para la App Clip Experience

Uso: python3 scripts/make-icons.py
"""
import math
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TEAL_TOP = (0x0F, 0x76, 0x6E)
TEAL_BOTTOM = (0x0B, 0x5B, 0x55)
WHITE = (255, 255, 255)


def png_bytes(width, height, row_fn):
    raw = bytearray()
    for y in range(height):
        raw.append(0)  # filtro None
        raw += row_fn(y)

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    header = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")


def clamp01(v):
    return 0.0 if v < 0 else 1.0 if v > 1 else v


def wifi_coverage(x, y, cx, cy, scale):
    """Cobertura 0..1 del glifo Wi-Fi (punto + 3 arcos de 90°) centrado en (cx, cy)."""
    dx, dy = x - cx, y - cy
    dist = math.hypot(dx, dy)
    edge = 1.5
    cov = clamp01((0.075 * scale - dist) / edge + 0.5)  # punto
    if dy < 0:
        angle = abs(math.atan2(dx, -dy))  # 0 = arriba
        angular = clamp01((math.pi / 4 - angle) * dist / edge + 0.5)
        half = 0.055 * scale
        for radius in (0.24 * scale, 0.42 * scale, 0.60 * scale):
            cov = max(cov, clamp01((half - abs(dist - radius)) / edge + 0.5) * angular)
    return cov


def render(width, height, cx, cy, scale):
    def row(y):
        t = y / (height - 1)
        bg = tuple(int(TEAL_TOP[i] * (1 - t) + TEAL_BOTTOM[i] * t) for i in range(3))
        out = bytearray()
        for x in range(width):
            a = wifi_coverage(x + 0.5, y + 0.5, cx, cy, scale)
            if a <= 0:
                out += bytes(bg)
            else:
                out += bytes(int(bg[i] * (1 - a) + WHITE[i] * a) for i in range(3))
        return bytes(out)
    return png_bytes(width, height, row)


def main():
    icon = render(1024, 1024, 512, 690, 1024)
    for target in ("NovaWifiTag", "NovaWifiTagClip"):
        path = ROOT / target / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon.png"
        path.write_bytes(icon)
        print(f"  {path.relative_to(ROOT)}  ({len(icon)} bytes)")
    card = render(1800, 1200, 900, 800, 1150)
    path = ROOT / "assets" / "appclip-card-1800x1200.png"
    path.parent.mkdir(exist_ok=True)
    path.write_bytes(card)
    print(f"  {path.relative_to(ROOT)}  ({len(card)} bytes)")


if __name__ == "__main__":
    main()
