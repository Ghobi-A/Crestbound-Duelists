"""Presentation contract for the Hollow Court battle staging.

Phase 3A changed how units are placed on screen without touching combat
rules: `position` ("front"/"back") still means exactly what
battle_resolver.gd says it means, only the pixel coordinates changed. This
module pins the two things a future rendering change could silently break:

  - the background must reach exactly the row the HUD's opaque bottom
    panel starts at, or a seam reappears between the floor and the panel
  - front is always closer to the camera than back, for both teams alike
    (the earlier version reversed this between player and enemy)

Both are read directly out of the GDScript source, not re-implemented,
so they can only drift if someone edits the actual constants.
"""

from __future__ import annotations

import json
import re
import struct
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
CONTROLLER_GD = REPO_ROOT / "game" / "scripts" / "battle" / "battle_controller.gd"
HUD_GD = REPO_ROOT / "game" / "scripts" / "ui" / "battle" / "battle_hud.gd"
BACKGROUND_PNG = REPO_ROOT / "game" / "assets" / "battle" / "backgrounds" / "hollow_court.png"
METRICS_GD = REPO_ROOT / "game" / "scripts" / "core" / "presentation_metrics.gd"
ASSETS = REPO_ROOT / "game" / "assets"


def _int_const(source: str, name: str) -> int:
    """A constant is either a literal or a `PresentationMetrics.SOMETHING`
    reference — resolve either way rather than requiring every constant to
    be a locally-duplicated literal, which is exactly what
    PresentationMetrics exists to avoid."""
    match = re.search(rf"const {name} := (\d+)", source)
    if match:
        return int(match.group(1))
    ref = re.search(rf"const {name} := PresentationMetrics\.(\w+)", source)
    assert ref, f"Could not locate {name}"
    metrics_source = METRICS_GD.read_text(encoding="utf-8")
    metrics_match = re.search(rf"const {ref.group(1)} := (\d+)", metrics_source)
    assert metrics_match, f"Could not locate PresentationMetrics.{ref.group(1)}"
    return int(metrics_match.group(1))


def _float_const(source: str, name: str) -> float:
    match = re.search(rf"const {name} := ([\d.]+)", source)
    assert match, f"Could not locate {name}"
    return float(match.group(1))


def png_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as handle:
        header = handle.read(24)
    assert header[:8] == b"\x89PNG\r\n\x1a\n", f"{path} is not a PNG"
    return struct.unpack(">II", header[16:24])


def test_background_height_matches_hud_bottom_panel() -> None:
    controller_source = CONTROLLER_GD.read_text(encoding="utf-8")
    hud_source = HUD_GD.read_text(encoding="utf-8")

    background_height = _int_const(controller_source, "BACKGROUND_HEIGHT")

    match = re.search(
        r"bottom\.position = Vector2\(0, (\d+|PresentationMetrics\.\w+)\)", hud_source
    )
    assert match, "Could not locate the bottom panel's Y position in battle_hud.gd"
    raw_y = match.group(1)
    if raw_y.isdigit():
        panel_y = int(raw_y)
    else:
        metrics_source = METRICS_GD.read_text(encoding="utf-8")
        metrics_match = re.search(rf"const {raw_y.split('.')[1]} := (\d+)", metrics_source)
        assert metrics_match, f"Could not locate {raw_y}"
        panel_y = int(metrics_match.group(1))

    assert background_height == panel_y, (
        "The generated background height must equal the HUD bottom panel's Y "
        "position, or a seam shows between the floor and the panel."
    )


def test_generated_background_matches_declared_height() -> None:
    controller_source = CONTROLLER_GD.read_text(encoding="utf-8")
    background_height = _int_const(controller_source, "BACKGROUND_HEIGHT")
    metrics_source = METRICS_GD.read_text(encoding="utf-8")
    canvas_match = re.search(r"const CANVAS_SIZE := Vector2i\((\d+),\s*(\d+)\)", metrics_source)
    assert canvas_match, "Could not locate PresentationMetrics.CANVAS_SIZE"
    canvas_width = int(canvas_match.group(1))
    width, height = png_size(BACKGROUND_PNG)
    assert width == canvas_width
    assert height == background_height


def test_front_row_is_closer_to_camera_than_back_row_for_both_teams() -> None:
    """The depth convention must not differ between player and enemy —
    that mismatch was the original "inverted" bug."""
    source = CONTROLLER_GD.read_text(encoding="utf-8")
    front_y = _float_const(source, "FRONT_Y")
    back_y = _float_const(source, "BACK_Y")
    # Larger Y is lower on screen, i.e. closer to the camera/HUD.
    assert front_y > back_y, "Front row must render closer to the camera than back row."


def test_team_formations_are_on_opposite_halves_of_the_arena() -> None:
    source = CONTROLLER_GD.read_text(encoding="utf-8")
    player_x = _float_const(source, "PLAYER_CENTER_X")
    enemy_x = _float_const(source, "ENEMY_CENTER_X")
    metrics_source = METRICS_GD.read_text(encoding="utf-8")
    canvas_match = re.search(r"const CANVAS_SIZE := Vector2i\((\d+),\s*(\d+)\)", metrics_source)
    assert canvas_match, "Could not locate PresentationMetrics.CANVAS_SIZE"
    arena_width = float(canvas_match.group(1))
    assert player_x < arena_width / 2 < enemy_x, (
        "Player and enemy formation centres must sit on opposite halves "
        "of the arena so the two sides read as opposing at a glance."
    )


def _extent(sidecar: dict) -> tuple[float, float]:
    """Mirrors battle_controller.gd's _sprite_extent(): the authored
    silhouette's own left/right reach from its anchor."""
    frame_w = float(sidecar["frame_width"])
    anchor_x = float(sidecar["anchor"][0])
    left = float(sidecar.get("left_extent", anchor_x))
    right = float(sidecar.get("right_extent", frame_w - anchor_x))
    return left, right


def _edge_envelope(sidecar: dict, ring_scale: float) -> tuple[float, float]:
    """Mirrors battle_controller.gd's _edge_envelope(): the art's own
    extent, or the widest highlight ring DuelistSprite ever draws around
    it, whichever reaches further — used only against the canvas edge."""
    left, right = _extent(sidecar)
    ring_half = float(sidecar["frame_width"]) * ring_scale
    return max(left, ring_half), max(right, ring_half)


def _formation_constants() -> dict:
    source = CONTROLLER_GD.read_text(encoding="utf-8")
    metrics_source = (REPO_ROOT / "game" / "scripts" / "core" / "presentation_metrics.gd").read_text(
        encoding="utf-8"
    )
    canvas_match = re.search(r"const CANVAS_SIZE := Vector2i\((\d+),\s*(\d+)\)", metrics_source)
    assert canvas_match
    return {
        "safe_margin": _float_const(source, "SAFE_MARGIN"),
        "team_gap": _float_const(source, "TEAM_GAP"),
        "unit_gap": _float_const(source, "UNIT_GAP"),
        "ring_scale": _float_const(source, "RING_ENVELOPE_SCALE"),
        "desired_spread": _float_const(source, "DESIRED_SPREAD"),
        "player_x": _float_const(source, "PLAYER_CENTER_X"),
        "enemy_x": _float_const(source, "ENEMY_CENTER_X"),
        "canvas_width": float(canvas_match.group(1)),
    }


def _team_positions(rows: list[str], sidecars: list[dict], center_x: float, zone: tuple[float, float], c: dict) -> list[tuple[float, float]]:
    """Reimplements battle_controller.gd's _team_positions()/
    _sequential_positions() exactly, so a test failure here means the
    real GDScript would also produce an overlapping or clipped
    formation, not just a divergent Python model of it. `rows` is
    accepted (mirroring the GDScript signature) but, like the real
    algorithm, every adjacent pair gets full clearance regardless of
    row — a discounted cross-row clearance was tried and a real render
    showed it still let bounding boxes collide (see battle_controller.gd's
    _team_positions() docstring)."""
    zone_left, zone_right = zone
    count = len(sidecars)
    extents = [_extent(s) for s in sidecars]
    edges = [_edge_envelope(s, c["ring_scale"]) for s in sidecars]
    if count == 1:
        x = min(max(center_x, zone_left + edges[0][0]), zone_right - edges[0][1])
        return [(x, edges[0])]

    min_gaps, desired_gaps = [], []
    for i in range(count - 1):
        need = extents[i][1] + c["unit_gap"] + extents[i + 1][0]
        min_gaps.append(need)
        desired_gaps.append(max(need, c["desired_spread"]))

    def sequential(gaps: list[float]) -> list[float]:
        xs = [0.0]
        for gap in gaps:
            xs.append(xs[-1] + gap)
        return xs

    gaps = desired_gaps
    xs = sequential(gaps)
    span_left, span_right = xs[0] - edges[0][0], xs[-1] + edges[-1][1]
    if span_right - span_left > zone_right - zone_left:
        gaps = min_gaps
        xs = sequential(gaps)
        span_left, span_right = xs[0] - edges[0][0], xs[-1] + edges[-1][1]

    shift = center_x - (span_left + span_right) / 2.0
    shift = min(max(shift, zone_left - span_left), zone_right - span_right)
    return [x + shift for x in xs]


def test_default_roster_formation_has_no_overlap_or_clipping() -> None:
    """Regression test for the actual bug this fix targets: the shipped
    640x360 formation math positioned the default roster's lone back-row
    unit (Mira, a mage) close enough to a front-row unit's own X that
    their bounding boxes visually overlapped — the two rows are only
    FRONT_Y - BACK_Y apart, less than either sprite's own height, so
    row-independent centring alone doesn't prevent it. Runs the actual
    default party/enemy roster (game_state.gd's _build_default_party(),
    the encounter's default enemies) through the same algorithm
    battle_controller.gd uses and asserts every adjacent pair (including
    across the front/back seam) clears its own required gap, and no
    unit's edge envelope crosses its team's safe zone."""
    c = _formation_constants()
    mid = c["canvas_width"] / 2.0
    player_zone = (c["safe_margin"], mid - c["team_gap"] / 2.0)
    enemy_zone = (mid + c["team_gap"] / 2.0, c["canvas_width"] - c["safe_margin"])

    def sidecar_for(key: str) -> dict:
        for folder in ("characters", "enemies"):
            path = ASSETS / folder / key / "battle.json"
            if path.is_file():
                return json.loads(path.read_text(encoding="utf-8"))
        raise AssertionError(f"No battle.json found for {key!r}")

    # Mirrors game_state.gd's _build_default_party(): Aren (warrior,
    # front), Warden Elara Thorne (guardian, front), Mira Solen (mage,
    # back) — and encounters.json's hollow_court_battle enemy_party
    # (Riven-touched Raider front, Hexbound Adept back, Unbound
    # Mercenary front): a genuine front/back mix on both sides, which is
    # exactly the case a same-row-only check would miss.
    player_roster = [
        ("front", sidecar_for("aren/warrior")),
        ("front", sidecar_for("elara")),
        ("back", sidecar_for("mira")),
    ]
    enemy_roster = [
        ("front", sidecar_for("riven_raider")),
        ("back", sidecar_for("hexbound_adept")),
        ("front", sidecar_for("unbound_mercenary")),
    ]

    def assert_no_overlap(roster: list[tuple[str, dict]], center_x: float, zone: tuple[float, float], label: str) -> None:
        rows = [r for r, _ in roster]
        sidecars = [s for _, s in roster]
        extents = [_extent(s) for s in sidecars]
        edges = [_edge_envelope(s, c["ring_scale"]) for s in sidecars]
        xs = _team_positions(rows, sidecars, center_x, zone, c)
        for i in range(len(xs) - 1):
            gap = xs[i + 1] - xs[i]
            need = extents[i][1] + c["unit_gap"] + extents[i + 1][0]
            assert gap >= need - 1e-6, (
                f"{label}: unit {i} and {i + 1} are {gap:.1f}px apart, needs "
                f"{need:.1f}px — their silhouettes would overlap."
            )
        assert xs[0] - edges[0][0] >= zone[0] - 1e-6, (
            f"{label}: leftmost unit's edge envelope crosses the zone's left bound."
        )
        assert xs[-1] + edges[-1][1] <= zone[1] + 1e-6, (
            f"{label}: rightmost unit's edge envelope crosses the zone's right bound."
        )

    assert_no_overlap(player_roster, c["player_x"], player_zone, "player")
    assert_no_overlap(enemy_roster, c["enemy_x"], enemy_zone, "enemy")
