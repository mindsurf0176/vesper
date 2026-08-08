#!/usr/bin/env python3
"""Validate the Vesper Corridor illustration production manifest."""

from __future__ import annotations

import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "assets/pipeline/illustration/manifest.json"
ALLOWED_STATUSES = {
    "reference_ready",
    "hero_needed",
    "hero_processing",
    "hero_review",
    "hero_ready",
    "card_cutout_needed",
    "card_cutout_ready",
    "connected",
    "legacy_connected_review_needed",
}


def res_exists(path: str) -> bool:
    if not path.startswith("res://"):
        return False
    return (ROOT / path.removeprefix("res://")).exists()


def fail(msg: str) -> None:
    print(f"FAIL validate_illustration_queue: {msg}", file=sys.stderr)
    sys.exit(1)


def main() -> None:
    if not MANIFEST.exists():
        fail(f"missing manifest: {MANIFEST}")
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if data.get("pipeline") != "sodeungsa_quality_hero_illustration":
        fail("unexpected pipeline")
    if not res_exists(str(data.get("style_anchor", ""))):
        fail("style_anchor missing or not res://")

    refs = data.get("accepted_reference_assets", {})
    for key in ("hero", "card", "face"):
        if not res_exists(str(refs.get(key, ""))):
            fail(f"accepted reference asset missing: {key}")

    gate = data.get("quality_gate", {})
    if len(gate.get("must_have", [])) < 8:
        fail("quality_gate.must_have too weak")
    if len(gate.get("reject_if", [])) < 8:
        fail("quality_gate.reject_if too weak")

    chars = data.get("characters", [])
    if len(chars) < 8:
        fail("expected at least 8 character entries")
    priorities = set()
    slugs = set()
    for ch in chars:
        name = str(ch.get("name", ""))
        slug = str(ch.get("slug", ""))
        status = str(ch.get("status", ""))
        priority = ch.get("priority")
        if not name or not slug:
            fail(f"bad character identity: {ch}")
        if status not in ALLOWED_STATUSES:
            fail(f"{name} invalid status: {status}")
        if priority in priorities:
            fail(f"duplicate priority: {priority}")
        priorities.add(priority)
        if slug in slugs:
            fail(f"duplicate slug: {slug}")
        slugs.add(slug)
        if status in {"hero_needed", "hero_processing", "hero_review"}:
            if len(str(ch.get("prompt_core_en", ""))) < 80:
                fail(f"{name} prompt_core_en too short")
            if not ch.get("signature_palette"):
                fail(f"{name} missing signature_palette")
        for ref_path in ch.get("reference_assets", {}).values():
            if not res_exists(str(ref_path)):
                fail(f"{name} reference asset missing: {ref_path}")

    print("PASS validate_illustration_queue")


if __name__ == "__main__":
    main()
