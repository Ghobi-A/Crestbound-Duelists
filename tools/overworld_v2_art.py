"""Authored pixel definitions for Crestbound Duelists overworld v2 sheets.

The production sheet contract is 40x56 RGBA frames, four walk phases for
Down/Up/East/West.  This module intentionally uses only the Python standard
library so CI and the Pages build can reproduce the PNGs byte-for-byte.
"""
from __future__ import annotations

import struct
import zlib
from pathlib import Path

W, H, FRAMES = 40, 56, 4
DIRS = ("down", "up", "east", "west")
TRANSPARENT = (0, 0, 0, 0)


def hx(value: str, alpha: int = 255) -> tuple[int, int, int, int]:
    value = value.lstrip("#")
    return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4)) + (alpha,)


def shade(colour: tuple[int, int, int, int], factor: float) -> tuple[int, int, int, int]:
    return tuple(max(0, min(255, int(channel * factor))) for channel in colour[:3]) + (colour[3],)


def rect(px, x: int, y: int, width: int, height: int, colour) -> None:
    x0, y0 = max(0, int(x)), max(0, int(y))
    x1, y1 = min(W, int(x + width)), min(H, int(y + height))
    for yy in range(y0, y1):
        for xx in range(x0, x1):
            px[yy][xx] = colour


def dot(px, x: int, y: int, colour) -> None:
    if 0 <= x < W and 0 <= y < H:
        px[y][x] = colour


def line(px, x0: int, y0: int, x1: int, y1: int, colour) -> None:
    dx, sx = abs(x1 - x0), 1 if x0 < x1 else -1
    dy, sy = -abs(y1 - y0), 1 if y0 < y1 else -1
    error = dx + dy
    while True:
        dot(px, x0, y0, colour)
        if x0 == x1 and y0 == y1:
            return
        twice = 2 * error
        if twice >= dy:
            error += dy
            x0 += sx
        if twice <= dx:
            error += dx
            y0 += sy


def outline(px) -> None:
    source = [row[:] for row in px]
    ink = hx("17151b")
    for y in range(H):
        for x in range(W):
            if source[y][x][3]:
                continue
            if any(
                0 <= x + dx < W and 0 <= y + dy < H and source[y + dy][x + dx][3]
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
            ):
                px[y][x] = ink


def draw_sprite(spec: dict[str, str], direction: str, phase: int):
    px = [[TRANSPARENT for _ in range(W)] for _ in range(H)]
    body, accent = hx(spec["body"]), hx(spec["accent"])
    hair = hx(spec.get("hair", "5c4033"))
    skin = hx(spec.get("skin", "d9ad85"))
    boot = hx(spec.get("boot", "29262b"))
    dark = shade(body, 0.62)
    kind, gear = spec.get("kind", "coat"), spec.get("gear", "none")
    bob, stride = (0, 1, 0, 1)[phase], (-2, 0, 2, 0)[phase]
    cx = 20 + (1 if direction == "east" else -1 if direction == "west" else 0)
    ground, head_y, torso_y = 51, 11 + bob, 26 + bob

    rect(px, 13, 52, 14, 2, hx("0e0e14", 110))
    rect(px, 16, 54, 8, 1, hx("0e0e14", 80))

    if kind in ("robe", "sorcerer", "cloak"):
        if direction == "east":
            rect(px, cx - 8, torso_y + 2, 6, 22, shade(body, 0.52))
        elif direction == "west":
            rect(px, cx + 2, torso_y + 2, 6, 22, shade(body, 0.52))
        elif direction == "up":
            rect(px, cx - 8, torso_y, 16, 23, shade(body, 0.52))
    if kind == "assassin":
        tail_x = cx - 9 if direction != "west" else cx + 5
        rect(px, tail_x, torso_y + 2, 5, 4, accent)
        rect(px, tail_x - 2 if direction != "west" else tail_x + 2, torso_y + 6, 5, 3, shade(accent, 0.8))

    if kind in ("robe", "sorcerer"):
        for index in range(17):
            half = 5 + index // 4
            rect(px, cx - half, torso_y + 8 + index, half * 2 + 1, 1, body if index % 3 else shade(body, 0.88))
        rect(px, cx - 8, ground - 3, 6, 3, boot)
        rect(px, cx + 2, ground - 3, 6, 3, boot)
    elif direction in ("east", "west"):
        front = cx + 2 + (stride if direction == "east" else -stride)
        back = cx - 4 - (stride if direction == "east" else -stride)
        rect(px, back, torso_y + 13, 5, 20, shade(body, 0.68))
        rect(px, front, torso_y + 13, 5, 20, dark)
        rect(px, back - 1, ground - 2, 7, 3, shade(boot, 0.8))
        rect(px, front - 1, ground - 2, 7, 3, boot)
    else:
        rect(px, cx - 7, torso_y + 13, 5, 20 + stride // 2, dark)
        rect(px, cx + 2, torso_y + 13, 5, 20 - stride // 2, dark)
        rect(px, cx - 8, ground - 2 + stride // 2, 7, 3, boot)
        rect(px, cx + 1, ground - 2 - stride // 2, 7, 3, boot)

    if kind == "guardian":
        for offset in (-10, 3):
            rect(px, cx + offset, torso_y + 12, 7, 10, shade(body, 0.82))
            rect(px, cx + offset, torso_y + 12, 7, 2, accent)
    if kind == "warrior":
        for offset in (-9, 3):
            rect(px, cx + offset, torso_y + 11, 6, 8, shade(body, 0.8))
            rect(px, cx + offset, torso_y + 11, 6, 2, accent)

    half = {"guardian": 10, "warrior": 9, "robe": 6, "sorcerer": 7, "assassin": 6, "neutral": 7, "coat": 7, "cloak": 8}.get(kind, 7)
    rect(px, cx - half, torso_y, half * 2 + 1, 16, body)
    rect(px, cx - half, torso_y, half * 2 + 1, 2, shade(body, 1.15))
    rect(px, cx - half, torso_y, 2, 16, shade(body, 0.75))
    rect(px, cx + half - 1, torso_y, 2, 16, shade(body, 0.72))

    if direction == "down":
        rect(px, cx - 1, torso_y + 2, 3, 13, accent)
        dot(px, cx, torso_y + 4, hx("f1deb0"))
    elif direction == "up":
        rect(px, cx - half + 3, torso_y + 3, half * 2 - 5, 3, shade(body, 0.78))
    else:
        side = -1 if direction == "east" else 1
        rect(px, cx + side * (half - 3), torso_y + 2, 3, 12, accent)

    if kind == "guardian":
        for shoulder in (cx - half - 3, cx + half - 2):
            rect(px, shoulder, torso_y - 2, 6, 5, hx("8593a5"))
            rect(px, shoulder, torso_y - 2, 6, 1, hx("c6d0dc"))
    elif kind == "warrior":
        rect(px, cx - half - 2, torso_y - 1, 5, 4, hx("7f858e"))
        rect(px, cx + half - 2, torso_y - 1, 5, 4, hx("7f858e"))
    elif kind == "sorcerer":
        rect(px, cx - half - 3, torso_y - 3, 5, 15, shade(body, 1.18))
        rect(px, cx - half - 3, torso_y - 3, 2, 4, accent)
    elif kind == "neutral":
        rect(px, cx - half - 2, torso_y - 1, half + 2, 3, shade(body, 0.62))
        rect(px, cx + half - 2, torso_y + 1, 3, 8, accent)

    if direction in ("east", "west"):
        side = 1 if direction == "east" else -1
        arm_x = cx + side * (half + 1)
        rect(px, arm_x - 2, torso_y + 4 + stride // 2, 4, 12, shade(body, 0.9))
        rect(px, arm_x - 2, torso_y + 16 + stride // 2, 4, 3, skin)
    else:
        rect(px, cx - half - 3, torso_y + 4 + stride // 2, 4, 12, shade(body, 0.9))
        rect(px, cx + half, torso_y + 4 - stride // 2, 4, 12, shade(body, 0.9))
        rect(px, cx - half - 3, torso_y + 16 + stride // 2, 4, 3, skin)
        rect(px, cx + half, torso_y + 16 - stride // 2, 4, 3, skin)

    if direction in ("east", "west"):
        side = 1 if direction == "east" else -1
        rect(px, cx - 6, head_y, 12, 13, skin)
        rect(px, cx - 6 if side == 1 else cx + 4, head_y, 2, 13, shade(skin, 0.84))
        rect(px, cx - 6, head_y, 12, 5, hair)
        rect(px, cx - 7 if side == -1 else cx + 3, head_y + 2, 5, 7, hair)
        dot(px, cx + side * 3, head_y + 7, hx("2c2624"))
        dot(px, cx + side * 6, head_y + 8, skin)
    else:
        rect(px, cx - 6, head_y, 13, 13, skin)
        rect(px, cx - 6, head_y, 2, 13, shade(skin, 0.84))
        rect(px, cx - 6, head_y, 13, 5, hair)
        if direction == "up":
            rect(px, cx - 6, head_y + 4, 13, 9, hair)
        else:
            dot(px, cx - 3, head_y + 7, hx("2c2624"))
            dot(px, cx + 3, head_y + 7, hx("2c2624"))
            rect(px, cx - 2, head_y + 11, 5, 1, shade(skin, 0.76))

    hair_style = spec.get("hstyle", "messy")
    if hair_style == "messy":
        for dx, dy in ((-7, 2), (-4, -2), (0, -3), (4, -2), (7, 1)):
            rect(px, cx + dx, head_y + dy, 3, 4, hair)
    elif hair_style == "bun":
        rect(px, cx + 4 if direction != "west" else cx - 7, head_y - 3, 6, 6, hair)
    elif hair_style == "ponytail":
        tail_x = cx - 8 if direction != "west" else cx + 5
        rect(px, tail_x, head_y + 3, 5, 12, hair)
        rect(px, tail_x - 2 if direction != "west" else tail_x + 2, head_y + 12, 4, 8, hair)
    elif hair_style == "long":
        rect(px, cx - 8, head_y + 4, 4, 17, hair)
        rect(px, cx + 5, head_y + 4, 4, 17, hair)
    elif hair_style == "hood":
        rect(px, cx - 8, head_y - 2, 16, 7, shade(body, 0.7))
        rect(px, cx - 8, head_y + 4, 4, 10, shade(body, 0.7))
        rect(px, cx + 5, head_y + 4, 4, 10, shade(body, 0.7))
    elif hair_style == "cap":
        rect(px, cx - 7, head_y - 1, 14, 5, hair)
        rect(px, cx + 4 if direction != "west" else cx - 9, head_y + 2, 7, 2, hair)

    side = 1 if direction != "west" else -1
    if gear == "sword":
        gx = cx + side * (half + 5)
        line(px, gx, torso_y + 5, gx + side * 4, ground - 7, hx("b6c1cd"))
        line(px, gx - side, torso_y + 7, gx + side * 3, ground - 6, hx("6d7682"))
        rect(px, gx - 2, torso_y + 3, 5, 2, accent)
    elif gear == "shield":
        gx = cx + side * (half + 4)
        rect(px, gx - 5, torso_y + 5, 10, 16, hx("73869e"))
        rect(px, gx - 4, torso_y + 6, 8, 14, shade(body, 0.82))
        rect(px, gx - 2, torso_y + 9, 4, 8, accent)
    elif gear == "book":
        gx = cx + side * (half + 4)
        rect(px, gx - 4, torso_y + 8, 8, 7, hx("5b3a2a"))
        rect(px, gx - 3, torso_y + 9, 3, 5, hx("e2cf9e"))
        rect(px, gx + 1, torso_y + 9, 2, 5, hx("e2cf9e"))
    elif gear == "staff":
        gx = cx + side * (half + 5)
        line(px, gx, torso_y - 2, gx, ground, hx("6e596e"))
        rect(px, gx - 3, torso_y - 6, 7, 7, accent)
        dot(px, gx, torso_y - 3, hx("eee4ff"))
    elif gear == "daggers":
        for gear_side in (-1, 1):
            gx = cx + gear_side * (half + 3)
            line(px, gx, torso_y + 8, gx + gear_side * 5, torso_y + 18, hx("c7d2da"))
    elif gear == "magic_sword":
        gx = cx + side * (half + 4)
        line(px, gx, torso_y + 5, gx + side * 4, ground - 7, hx("b8c4cb"))
        rect(px, cx - side * (half + 5) - 3, torso_y + 7, 7, 7, hx(spec["accent"], 130))
        dot(px, cx - side * (half + 5), torso_y + 10, hx("eaffcf"))
    elif gear == "spear":
        gx = cx + side * (half + 5)
        line(px, gx, torso_y - 5, gx, ground, hx("795c43"))
        line(px, gx, torso_y - 8, gx, torso_y - 3, hx("c3cbd2"))
    elif gear == "torch":
        gx = cx + side * (half + 5)
        line(px, gx, torso_y + 3, gx, ground - 5, hx("755035"))
        rect(px, gx - 2, torso_y - 3, 5, 7, hx("e68a35"))
        rect(px, gx - 1, torso_y - 6, 3, 5, hx("ffd46a"))
    elif gear == "satchel":
        rect(px, cx - side * (half + 4), torso_y + 10, 7, 8, hx("6f4b34"))

    outline(px)
    return px


KAI = [
    dict(body="9e3038", accent="e6bc55", kind="warrior", gear="sword", hair="65452f", hstyle="messy"),
    dict(body="315f9d", accent="d9c26d", kind="guardian", gear="shield", hair="65452f", hstyle="messy"),
    dict(body="a85c29", accent="f0bd58", kind="robe", gear="book", hair="65452f", hstyle="messy"),
    dict(body="3d285e", accent="a77ae4", kind="sorcerer", gear="staff", hair="65452f", hstyle="messy"),
    dict(body="343b43", accent="b8dcea", kind="assassin", gear="daggers", hair="65452f", hstyle="messy"),
    dict(body="456a46", accent="78d18a", kind="neutral", gear="magic_sword", hair="65452f", hstyle="messy"),
]

CAST = [
    dict(body="365f91", accent="d6dde5", kind="cloak", gear="shield", hair="d6d6db", hstyle="bun"),
    dict(body="9c5a39", accent="e6c99d", kind="robe", gear="book", hair="623a30", hstyle="ponytail"),
    dict(body="6f5437", accent="d1ad61", kind="coat", gear="none", hair="6a4931", hstyle="messy"),
    dict(body="4f7250", accent="d3b56d", kind="robe", gear="satchel", hair="713f32", hstyle="long"),
    dict(body="54505b", accent="c6b58a", kind="cloak", gear="none", hair="b8b0a3", hstyle="long"),
    dict(body="6b593e", accent="b99552", kind="coat", gear="none", hair="554334", hstyle="cap"),
    dict(body="47586c", accent="c9d2db", kind="guardian", gear="sword", hair="42372f", hstyle="messy"),
    dict(body="563d77", accent="bf8ee8", kind="coat", gear="sword", hair="2d2738", hstyle="long"),
    dict(body="533039", accent="d0a55b", kind="cloak", gear="sword", hair="33292b", hstyle="messy"),
    dict(body="485a68", accent="bbc7d0", kind="coat", gear="spear", hair="514335", hstyle="cap"),
    dict(body="6a554b", accent="c8ab72", kind="robe", gear="none", hair="a79b89", hstyle="bun"),
    dict(body="664b34", accent="e0a44a", kind="coat", gear="torch", hair="68615b", hstyle="cap"),
    dict(body="35313e", accent="795e8c", kind="cloak", gear="none", hair="2c2932", hstyle="hood"),
    dict(body="6d2f33", accent="d56b50", kind="assassin", gear="daggers", hair="352a29", hstyle="hood"),
    dict(body="493d35", accent="b98e55", kind="warrior", gear="sword", hair="49352b", hstyle="messy"),
    dict(body="39254b", accent="9c67ce", kind="sorcerer", gear="staff", hair="2a2430", hstyle="hood"),
]


def _png_chunk(tag: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)


def write_png(path: Path, width: int, height: int, rgba) -> None:
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        for x in range(width):
            raw.extend(rgba[y][x])
    payload = (
        b"\x89PNG\r\n\x1a\n"
        + _png_chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
        + _png_chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + _png_chunk(b"IEND", b"")
    )
    path.write_bytes(payload)


def build_sheet(specs: list[dict[str, str]], path: Path) -> None:
    width, height = W * FRAMES * len(DIRS), H * len(specs)
    sheet = [[TRANSPARENT for _ in range(width)] for _ in range(height)]
    for row, spec in enumerate(specs):
        for direction_index, direction in enumerate(DIRS):
            for phase in range(FRAMES):
                frame = draw_sprite(spec, direction, phase)
                ox, oy = (direction_index * FRAMES + phase) * W, row * H
                for y in range(H):
                    sheet[oy + y][ox : ox + W] = frame[y]
    write_png(path, width, height, sheet)
