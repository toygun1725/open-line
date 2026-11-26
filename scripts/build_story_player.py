#!/usr/bin/env python3
"""
Builds the self-contained playable Açık Hat (Open Line) Multi-Story Player
(`tools/story_player.html`) from OpenLine/Resources/Story/catalog.json
and assets/free/audio/*.wav.
"""

from __future__ import annotations

import base64
import io
import json
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STORY_DIR = ROOT / "OpenLine" / "Resources" / "Story"
TEMPLATE_PATH = ROOT / "scripts" / "story_player_template.html"
WORKSPACE_OUT = ROOT / "tools" / "story_player.html"
def load_story_bundle() -> dict:
    with (STORY_DIR / "catalog.json").open("r", encoding="utf-8") as f:
        catalog = json.load(f)

    stories: dict[str, dict] = {}
    for entry in catalog.get("stories", []):
        sid = entry["id"]
        folder = STORY_DIR / entry["folder"]
        with (folder / "manifest.json").open("r", encoding="utf-8") as f:
            manifest = json.load(f)
        nodes: dict[str, dict] = {}
        for act_file in sorted(folder.glob("act*.json")):
            with act_file.open("r", encoding="utf-8") as f:
                data = json.load(f)
            for node in data.get("nodes", []):
                nodes[node["id"]] = node
        stories[sid] = {"manifest": manifest, "nodes": nodes}

    return {"catalog": catalog, "stories": stories}


def wav_to_compact_b64(path: Path) -> str:
    if not path.exists():
        return ""
    with wave.open(str(path), "rb") as w:
        nch = w.getnchannels()
        sw = w.getsampwidth()
        fr = w.getframerate()
        frames = w.readframes(w.getnframes())
    if sw == 2:
        fmt = "<" + ("h" * (len(frames) // 2))
        samples = struct.unpack(fmt, frames)
        mono = [sum(samples[i : i + nch]) // nch for i in range(0, len(samples), nch)]
        flt = [s / 32768.0 for s in mono]
    elif sw == 1:
        samples = list(frames)
        mono = [sum(samples[i : i + nch]) // nch for i in range(0, len(samples), nch)]
        flt = [(s - 128) / 128.0 for s in mono]
    else:
        return ""

    target_fr = 16000
    target_len = max(1, int(len(flt) * target_fr / fr))
    res = []
    for i in range(target_len):
        pos = i * (len(flt) - 1) / max(1, target_len - 1)
        idx = int(pos)
        frac = pos - idx
        val = flt[idx] + (flt[min(idx + 1, len(flt) - 1)] - flt[idx]) * frac
        res.append(max(0, min(255, int(round((val + 1.0) * 127.5)))))

    buf = io.BytesIO()
    with wave.open(buf, "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(1)
        out.setframerate(target_fr)
        out.writeframes(bytes(res))
    return base64.b64encode(buf.getvalue()).decode("ascii")


def main() -> int:
    bundle = load_story_bundle()
    bundle_json = json.dumps(bundle, ensure_ascii=False, separators=(",", ":"))
    click_b64 = json.dumps(wav_to_compact_b64(ROOT / "assets" / "free" / "audio" / "click2.wav"))
    switch_b64 = json.dumps(wav_to_compact_b64(ROOT / "assets" / "free" / "audio" / "switch2.wav"))

    html = TEMPLATE_PATH.read_text(encoding="utf-8")
    wallpaper = ROOT / "OpenLine/Resources/Assets.xcassets/NightCity.imageset/night-city.jpg"
    html = html.replace("/*__PREVIEW_STORY__*/", (ROOT / "scripts/preview_story.js").read_text(encoding="utf-8"))
    html = html.replace("/*__PREVIEW_UI__*/", (ROOT / "scripts/preview_ui.js").read_text(encoding="utf-8"))
    html = html.replace("__NIGHT_CITY__", base64.b64encode(wallpaper.read_bytes()).decode("ascii"))
    html = html.replace("/*__STORY_BUNDLE_JSON__*/null", bundle_json, 1)
    html = html.replace('/*__CLICK_B64__*/""', click_b64, 1)
    html = html.replace('/*__SWITCH_B64__*/""', switch_b64, 1)

    WORKSPACE_OUT.parent.mkdir(parents=True, exist_ok=True)
    WORKSPACE_OUT.write_text(html, encoding="utf-8")
    total_nodes = sum(len(s["nodes"]) for s in bundle["stories"].values())
    print(f"Wrote {WORKSPACE_OUT} ({len(html)} bytes, {len(bundle['stories'])} stories, {total_nodes} nodes)")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
