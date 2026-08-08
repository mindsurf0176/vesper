#!/usr/bin/env python3
"""Validate the Vesper Corridor PixelLab asset queue contract."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "assets/pipeline/pixellab/manifest.json"
GAME_STATE = ROOT / "game_state.gd"

EXPECTED_ANIMS = {
    "walk": 8,
    "aim": 4,
    "attack": 6,
}
ALLOWED_STAGES = ["base_needed", "base_processing", "state_needed", "state_processing", "animation_needed", "animation_processing", "ready"]


def fail(message: str) -> None:
    print(f"FAIL validate_pixellab_queue: {message}", file=sys.stderr)
    sys.exit(1)


def res_to_path(res_path: str) -> Path:
    if not res_path.startswith("res://"):
        fail(f"expected res:// path, got {res_path}")
    return ROOT / res_path.removeprefix("res://")


def load_json(path: Path) -> dict:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001
        fail(f"could not parse {path}: {exc}")


def validate_spec_template(char: dict) -> None:
    path = res_to_path(char["spec_template"])
    if not path.is_file():
        fail(f"{char['slug']} missing spec template: {path}")
    spec = load_json(path)
    if spec.get("slug") != char["slug"]:
        fail(f"{char['slug']} spec slug mismatch")
    if spec.get("out") != str(ROOT / f"assets/sprites/{char['slug']}_pl"):
        fail(f"{char['slug']} spec out mismatch: {spec.get('out')}")
    anims = {a.get("name"): a for a in spec.get("anims", [])}
    for name, count in EXPECTED_ANIMS.items():
        if name not in anims:
            fail(f"{char['slug']} spec missing anim {name}")
        if int(anims[name].get("expected_count", -1)) != count:
            fail(f"{char['slug']} {name} expected_count mismatch")
        if not isinstance(anims[name].get("frames"), list):
            fail(f"{char['slug']} {name} frames must be list")
    idle = spec.get("idle_from", {})
    if idle.get("anim") != "aim" or int(idle.get("index", -1)) != 0:
        fail(f"{char['slug']} idle_from must be aim[0]")


def game_state_contracts() -> dict[str, tuple[str, str]]:
    text = GAME_STATE.read_text(encoding="utf-8")
    found: dict[str, tuple[str, str]] = {}
    pattern = re.compile(
        r'"name":\s*"([^"]+)".{0,400}?'
        r'"asset_pipeline":\s*"pixellab_combat_state".{0,200}?'
        r'"asset_pipeline_slug":\s*"([^"]+)".{0,200}?'
        r'"asset_pipeline_stage":\s*"([^"]+)"',
        re.DOTALL,
    )
    for name, slug, stage in pattern.findall(text):
        found[slug] = (name, stage)
    return found


def main() -> None:
    if not MANIFEST.is_file():
        fail(f"missing manifest: {MANIFEST}")
    manifest = load_json(MANIFEST)
    if manifest.get("pipeline") != "pixellab_combat_state":
        fail("manifest pipeline must be pixellab_combat_state")
    chars = manifest.get("characters")
    if not isinstance(chars, list) or len(chars) != 6:
        fail("manifest must contain exactly 6 queued characters")

    game_contracts = game_state_contracts()
    seen: set[str] = set()
    priorities: list[int] = []
    for char in chars:
        for key in ["priority", "name", "slug", "stage", "output", "spec_template", "create_character_prompt"]:
            if not char.get(key):
                fail(f"character entry missing {key}: {char}")
        slug = char["slug"]
        if slug in seen:
            fail(f"duplicate slug: {slug}")
        seen.add(slug)
        priorities.append(int(char["priority"]))
        if char["stage"] not in ALLOWED_STAGES:
            fail(f"{slug} invalid stage: {char['stage']}")
        if char["stage"] != "base_needed" and not char.get("base_character_id"):
            fail(f"{slug} stage {char['stage']} requires base_character_id")
        if char["stage"] in ["state_processing", "animation_needed", "animation_processing", "ready"]:
            state_ids = char.get("state_character_ids", {})
            if not state_ids.get("aim_base") or not state_ids.get("run_base"):
                fail(f"{slug} stage {char['stage']} requires aim_base and run_base state ids")
        if char["stage"] in ["animation_processing", "ready"]:
            anims = char.get("animation_requests", {})
            for anim_name in EXPECTED_ANIMS:
                if not anims.get(anim_name, {}).get("character_id"):
                    fail(f"{slug} stage {char['stage']} requires animation request {anim_name}")
        expected_output = f"res://assets/sprites/{slug}_pl"
        if char["output"] != expected_output:
            fail(f"{slug} output mismatch: {char['output']}")
        if slug not in game_contracts:
            fail(f"{slug} missing game_state PixelLab contract")
        game_name, game_stage = game_contracts[slug]
        if game_name != char["name"]:
            fail(f"{slug} game_state name mismatch: {game_name} != {char['name']}")
        if game_stage != char["stage"]:
            fail(f"{slug} stage mismatch: game_state={game_stage}, manifest={char['stage']}")
        validate_spec_template(char)

    if priorities != sorted(priorities):
        fail(f"priorities must be sorted: {priorities}")

    print("PASS validate_pixellab_queue")


if __name__ == "__main__":
    main()
