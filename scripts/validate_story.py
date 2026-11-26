#!/usr/bin/env python3
"""
CI Story Catalog, Graph, Pacing & Localization Validator for Açık Hat (Open Line).
Validates Story/catalog.json and every story under Story/<folder>/manifest.json + act*.json.
"""

from __future__ import annotations

import json
import re
import sys
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STORY_DIR = ROOT / "OpenLine" / "Resources" / "Story"
VAR_PATTERN = re.compile(r"\{([a-zA-Z0-9_]+)\}")
FORBIDDEN_LEGACY_NAMES = ("Kaan", "KAAN", "Liam", "LIAM", "Eylül", "EYLÜL", "Maya", "MAYA")
ROBOTIC_TIME_PATTERN = re.compile(r"\b\d+\s*(?:dk|dakika|min|minutes?)\s+sonra\b", re.IGNORECASE)


def load_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def check_legacy_names(obj: object, ctx: str, errors: list[str]) -> None:
    if isinstance(obj, str):
        for bad in FORBIDDEN_LEGACY_NAMES:
            if re.search(rf"\b{re.escape(bad)}\b", obj):
                errors.append(f"{ctx}: contains forbidden legacy character name '{bad}'")
    elif isinstance(obj, list):
        for i, item in enumerate(obj):
            check_legacy_names(item, f"{ctx}[{i}]", errors)
    elif isinstance(obj, dict):
        for k, v in obj.items():
            check_legacy_names(v, f"{ctx}.{k}", errors)


def check_localized(obj: object, ctx: str, variables: dict, errors: list[str]) -> None:
    if not isinstance(obj, dict):
        errors.append(f"{ctx}: expected LocalizedText object")
        return
    for lang in ("tr", "en"):
        val = obj.get(lang)
        if not isinstance(val, str) or not val.strip():
            errors.append(f"{ctx}.{lang}: missing or empty localized string")
            continue
        for m in VAR_PATTERN.finditer(val):
            var_name = m.group(1)
            if var_name not in variables:
                errors.append(f"{ctx}.{lang}: undefined variable placeholder {{{var_name}}}")


def check_effects(effects: object, ctx: str, variables: dict, errors: list[str]) -> None:
    if effects is None:
        return
    if not isinstance(effects, list):
        errors.append(f"{ctx}.effects: must be a list")
        return
    for idx, eff in enumerate(effects):
        if not isinstance(eff, dict):
            errors.append(f"{ctx}.effects[{idx}]: must be an object")
            continue
        v = eff.get("var")
        op = eff.get("op")
        if v not in variables:
            errors.append(f"{ctx}.effects[{idx}]: unknown variable '{v}'")
        if op not in ("set", "add", "clamp"):
            errors.append(f"{ctx}.effects[{idx}]: invalid op '{op}'")


def check_condition(cond: object, ctx: str, variables: dict, errors: list[str]) -> None:
    if not isinstance(cond, dict):
        errors.append(f"{ctx}: condition must be an object")
        return
    if "all" in cond:
        for i, sub in enumerate(cond["all"]):
            check_condition(sub, f"{ctx}.all[{i}]", variables, errors)
        return
    if "any" in cond:
        for i, sub in enumerate(cond["any"]):
            check_condition(sub, f"{ctx}.any[{i}]", variables, errors)
        return
    v = cond.get("var")
    op = cond.get("op")
    if v not in variables:
        errors.append(f"{ctx}: unknown condition variable '{v}'")
    if op not in ("eq", "neq", "gt", "gte", "lt", "lte"):
        errors.append(f"{ctx}: invalid condition op '{op}'")


def check_items(items: object, ctx: str, variables: dict, errors: list[str]) -> None:
    if not isinstance(items, list) or not items:
        errors.append(f"{ctx}.items: must be a non-empty list")
        return
    for idx, item in enumerate(items):
        ictx = f"{ctx}.items[{idx}]"
        if not isinstance(item, dict):
            errors.append(f"{ictx}: must be an object")
            continue
        t = item.get("type")
        if t == "message":
            txt_obj = item.get("text")
            check_localized(txt_obj, f"{ictx}.text", variables, errors)
            if isinstance(txt_obj, dict):
                for lang in ("tr", "en"):
                    s = txt_obj.get(lang, "")
                    if "%" in s or re.search(r"\{(?:[a-z_]*(?:percent|battery)[a-z_]*)\}", s):
                        errors.append(f"{ictx}.text.{lang}: percentage readout not allowed in story text")
                    if ROBOTIC_TIME_PATTERN.search(s):
                        errors.append(f"{ictx}.text.{lang}: robotic minute countdown '{s}' not allowed")
        elif t == "system":
            txt_obj = item.get("text")
            check_localized(txt_obj, f"{ictx}.text", variables, errors)
            if isinstance(txt_obj, dict):
                for lang in ("tr", "en"):
                    s = txt_obj.get(lang, "")
                    if "%" in s or re.search(r"\{(?:[a-z_]*(?:percent|battery)[a-z_]*)\}", s):
                        errors.append(f"{ictx}.text.{lang}: percentage readout not allowed in system text")
            if item.get("severity") not in ("info", "warning", "critical", "success"):
                errors.append(f"{ictx}.severity: invalid severity")
        elif t == "conditional":
            check_condition(item.get("condition"), f"{ictx}.condition", variables, errors)
            check_items(item.get("thenItems"), f"{ictx}.thenItems", variables, errors)
            if item.get("elseItems") is not None:
                check_items(item.get("elseItems"), f"{ictx}.elseItems", variables, errors)
        else:
            errors.append(f"{ictx}: unknown item type '{t}'")


def validate_story_entry(entry: dict) -> tuple[list[str], str]:
    errors: list[str] = []
    sid = entry.get("id", "?")
    folder = entry.get("folder")
    if not folder:
        return [f"catalog[{sid}]: missing folder"], ""

    check_legacy_names(entry, f"catalog[{sid}]", errors)
    story_path = STORY_DIR / folder
    manifest_path = story_path / "manifest.json"
    if not manifest_path.exists():
        return [f"story[{sid}]: missing {manifest_path}"], ""

    manifest = load_json(manifest_path)
    check_legacy_names(manifest, f"{sid}/manifest.json", errors)
    variables = manifest.get("variables", {})
    start_id = manifest.get("startNodeId")
    checkpoints = manifest.get("checkpoints", [])

    if not isinstance(entry.get("isFree"), bool):
        errors.append(f"catalog[{sid}].isFree: expected bool")
    if entry.get("theme") not in ("ice_blue", "warm_rose"):
        errors.append(f"catalog[{sid}].theme: unsupported theme '{entry.get('theme')}'")
    for field in ("title", "subtitle", "badge", "senderName", "waitingHeadline", "metricLabel", "invitation", "synopsis"):
        check_localized(entry.get(field), f"catalog[{sid}].{field}", {}, errors)
    stages_meta = entry.get("stageLabels", [])
    if len(stages_meta) != 4:
        errors.append(f"catalog[{sid}].stageLabels: must have 4 localized entries")
    else:
        for sidx, st in enumerate(stages_meta):
            check_localized(st, f"catalog[{sid}].stageLabels[{sidx}]", {}, errors)
    if entry.get("metricVar") not in variables:
        errors.append(f"catalog[{sid}].metricVar '{entry.get('metricVar')}' missing from manifest.variables")

    declared_endings = entry.get("endings", {})
    if not isinstance(declared_endings, dict) or not declared_endings:
        errors.append(f"catalog[{sid}].endings: must declare at least 1 ending")
    else:
        for eid, meta in declared_endings.items():
            if not isinstance(meta, dict):
                errors.append(f"catalog[{sid}].endings[{eid}]: expected object")
                continue
            check_localized(meta.get("badge"), f"catalog[{sid}].endings[{eid}].badge", {}, errors)

    allowed_ending_ids = set(declared_endings.keys()) if isinstance(declared_endings, dict) else set()

    nodes: dict[str, dict] = {}
    act_files = sorted(story_path.glob("act*.json"))
    if not act_files:
        errors.append(f"story[{sid}]: no act*.json files found")
        return errors, ""

    for act_path in act_files:
        data = load_json(act_path)
        check_legacy_names(data, f"{sid}/{act_path.name}", errors)
        for node in data.get("nodes", []):
            nid = node.get("id")
            if not nid:
                errors.append(f"{sid}/{act_path.name}: node missing id")
                continue
            if nid in nodes:
                errors.append(f"{sid}/{act_path.name}: duplicate node id '{nid}'")
                continue
            nodes[nid] = node

    if start_id not in nodes:
        errors.append(f"{sid}: manifest.startNodeId '{start_id}' does not exist")

    for cp in checkpoints:
        cid = cp.get("id", "?")
        nid = cp.get("nodeId")
        if nid not in nodes:
            errors.append(f"{sid}: manifest.checkpoint '{cid}' points to missing node '{nid}'")
        check_localized(cp.get("title"), f"{sid}:manifest.checkpoints[{cid}].title", variables, errors)

    edges: dict[str, list[str]] = {}
    non_choice_edges: dict[str, list[str]] = {}
    ending_nodes: set[str] = set()
    seen_ending_ids: set[str] = set()
    delay_count = 0
    total_delay_sec = 0.0
    choice_count = 0
    act_breaks: list[tuple[int, int]] = []

    for nid, node in nodes.items():
        ctx = f"{sid}:node[{nid}]"
        if node.get("act") not in (1, 2, 3):
            errors.append(f"{ctx}.act: expected 1..3")
        check_effects(node.get("effects"), ctx, variables, errors)
        check_items(node.get("items"), ctx, variables, errors)

        tr = node.get("transition")
        if not isinstance(tr, dict):
            errors.append(f"{ctx}: missing transition")
            continue

        ttype = tr.get("type")
        targets: list[str] = []

        if ttype == "next":
            tgt = tr.get("target")
            if not tgt:
                errors.append(f"{ctx}.transition.next: missing target")
            else:
                targets.append(tgt)
            non_choice_edges[nid] = list(targets)

        elif ttype == "conditionalNext":
            branches = tr.get("branches", [])
            for bidx, br in enumerate(branches):
                check_condition(br.get("condition"), f"{ctx}.transition.branches[{bidx}]", variables, errors)
                tgt = br.get("target")
                if tgt:
                    targets.append(tgt)
            fb = tr.get("fallback")
            if not fb:
                errors.append(f"{ctx}.transition.conditionalNext: missing fallback")
            else:
                targets.append(fb)
            non_choice_edges[nid] = list(targets)

        elif ttype == "delay":
            delay_count += 1
            sec = tr.get("seconds")
            if not isinstance(sec, (int, float)) or sec <= 0:
                errors.append(f"{ctx}.transition.delay: invalid seconds '{sec}'")
            else:
                total_delay_sec += float(sec)
            tgt = tr.get("target")
            if tgt:
                targets.append(tgt)
            la = tr.get("liveActivity")
            if not isinstance(la, dict):
                errors.append(f"{ctx}.transition.delay: missing liveActivity payload")
            else:
                cur = la.get("currentStage")
                tot = la.get("totalStages")
                stages = la.get("stages", [])
                if tot != 4 or not isinstance(cur, int) or not (1 <= cur <= 4):
                    errors.append(f"{ctx}.liveActivity: expected currentStage 1..4 and totalStages == 4")
                if len(stages) != 4:
                    errors.append(f"{ctx}.liveActivity.stages: must contain 4 stage labels")
                for sidx, st in enumerate(stages):
                    check_localized(st, f"{ctx}.liveActivity.stages[{sidx}]", variables, errors)
                stitle = la.get("shortTitle")
                check_localized(stitle, f"{ctx}.liveActivity.shortTitle", variables, errors)
                if isinstance(stitle, dict):
                    for lang in ("tr", "en"):
                        if isinstance(stitle.get(lang), str) and len(stitle[lang]) > 20:
                            errors.append(
                                f"{ctx}.liveActivity.shortTitle.{lang}: '{stitle[lang]}' exceeds 20 chars ({len(stitle[lang])})"
                            )
                check_localized(la.get("statusBody"), f"{ctx}.liveActivity.statusBody", variables, errors)
            non_choice_edges[nid] = list(targets)

        elif ttype == "actBreak":
            c_act = tr.get("completedAct")
            n_act = tr.get("nextAct")
            if c_act not in (1, 2) or n_act != c_act + 1:
                errors.append(f"{ctx}.transition.actBreak: expected completedAct in (1,2) and nextAct == completedAct + 1")
            else:
                act_breaks.append((c_act, n_act))
            check_localized(tr.get("title"), f"{ctx}.actBreak.title", variables, errors)
            check_localized(tr.get("subtitle"), f"{ctx}.actBreak.subtitle", variables, errors)
            tgt = tr.get("target")
            if not tgt:
                errors.append(f"{ctx}.transition.actBreak: missing target")
            else:
                targets.append(tgt)
            non_choice_edges[nid] = list(targets)

        elif ttype == "choice":
            choice_count += 1
            if tr.get("choiceKind") not in ("standard", "memory_anchor", "memory_inject"):
                errors.append(f"{ctx}.transition.choiceKind: invalid choiceKind")
            opts = tr.get("options", [])
            if len(opts) != 2:
                errors.append(f"{ctx}.transition.options: must have exact length 2 (found {len(opts)})")
            for oidx, opt in enumerate(opts):
                octx = f"{ctx}.options[{oidx}]"
                lbl = opt.get("label")
                check_localized(lbl, f"{octx}.label", variables, errors)
                if isinstance(lbl, dict):
                    for lang in ("tr", "en"):
                        val = lbl.get(lang)
                        if isinstance(val, str):
                            if len(val) > 45:
                                errors.append(
                                    f"{octx}.label.{lang}: '{val}' exceeds 45 chars ({len(val)})"
                                )
                            if VAR_PATTERN.search(val):
                                errors.append(
                                    f"{octx}.label.{lang}: raw variable placeholder not allowed in choice button '{val}'"
                                )
                check_effects(opt.get("effects"), octx, variables, errors)
                tgt = opt.get("target")
                if tgt:
                    targets.append(tgt)
            non_choice_edges[nid] = []

        elif ttype == "ending":
            ending_nodes.add(nid)
            eid = tr.get("endingId")
            if eid not in allowed_ending_ids:
                errors.append(f"{ctx}.transition.endingId: '{eid}' not in catalog[{sid}].endings {sorted(allowed_ending_ids)}")
            else:
                seen_ending_ids.add(eid)
            check_localized(tr.get("title"), f"{ctx}.ending.title", variables, errors)
            check_localized(tr.get("summary"), f"{ctx}.ending.summary", variables, errors)
            non_choice_edges[nid] = []
        else:
            errors.append(f"{ctx}.transition.type: unknown type '{ttype}'")

        for tgt in targets:
            if tgt not in nodes:
                errors.append(f"{ctx}: broken target '{tgt}'")
        edges[nid] = [t for t in targets if t in nodes]

    # Pacing & Act-Break checks (10h - 33h pure timer waits -> 1-1.5 day span)
    if not (36000 <= total_delay_sec <= 120000):
        errors.append(f"{sid}: total delay seconds {total_delay_sec:.0f}s outside [36000, 120000]")

    if sid == "masa_7" and sorted(act_breaks) != [(1, 2), (2, 3)]:
        errors.append(f"{sid}: expected actBreak gates [(1, 2), (2, 3)], got {sorted(act_breaks)}")

    # BFS reachability from startNodeId
    reachable: set[str] = set()
    if start_id in nodes:
        q = deque([start_id])
        reachable.add(start_id)
        while q:
            cur = q.popleft()
            for nxt in edges.get(cur, []):
                if nxt not in reachable:
                    reachable.add(nxt)
                    q.append(nxt)

    orphans = sorted(set(nodes.keys()) - reachable)
    if orphans:
        errors.append(f"{sid}: orphan nodes unreachable from '{start_id}': {orphans}")

    missing_endings = sorted(allowed_ending_ids - seen_ending_ids)
    if missing_endings:
        errors.append(f"{sid}: declared endings missing ending node: {missing_endings}")

    rev_edges: dict[str, list[str]] = {k: [] for k in nodes}
    for src, tgts in edges.items():
        for t in tgts:
            rev_edges[t].append(src)

    can_end: set[str] = set(ending_nodes)
    rq = deque(ending_nodes)
    while rq:
        cur = rq.popleft()
        for prev in rev_edges.get(cur, []):
            if prev not in can_end:
                can_end.add(prev)
                rq.append(prev)

    dead_ends = sorted(reachable - can_end)
    if dead_ends:
        errors.append(f"{sid}: dead-end nodes unable to reach any ending: {dead_ends}")

    color: dict[str, int] = {k: 0 for k in nodes}

    def has_cycle(u: str) -> bool:
        color[u] = 1
        for v in non_choice_edges.get(u, []):
            if v not in nodes:
                continue
            if color[v] == 1:
                return True
            if color[v] == 0 and has_cycle(v):
                return True
        color[u] = 2
        return False

    for nid in nodes:
        if color[nid] == 0 and has_cycle(nid):
            errors.append(f"{sid}: choice-free cycle detected involving node '{nid}'")
            break

    hours = total_delay_sec / 3600.0
    free_tag = "FREE" if entry.get("isFree") else "PAID"
    summary = (
        f"  - {sid} [{free_tag} · {entry.get('theme')}]: {len(nodes)} nodes, "
        f"{choice_count} choices, {delay_count} delays ({hours:.1f}h waits), "
        f"{len(act_breaks)} act-breaks, {len(ending_nodes)} endings"
    )
    return errors, summary


def main() -> int:
    catalog_path = STORY_DIR / "catalog.json"
    if not catalog_path.exists():
        print(f"ERROR: missing {catalog_path}", file=sys.stderr)
        return 1

    catalog = load_json(catalog_path)
    stories = catalog.get("stories", [])
    if not isinstance(stories, list) or not stories:
        print("ERROR: catalog.json has no stories", file=sys.stderr)
        return 1

    all_errors: list[str] = []
    summaries: list[str] = []
    check_legacy_names(catalog, "catalog.json", all_errors)
    check_localized(catalog.get("appTitle"), "catalog.appTitle", {}, all_errors)
    check_localized(catalog.get("iapPriceDisplay"), "catalog.iapPriceDisplay", {}, all_errors)
    if not isinstance(catalog.get("iapProductId"), str) or not catalog.get("iapProductId"):
        all_errors.append("catalog.iapProductId: missing IAP product ID")

    if catalog.get("defaultStoryId") != "masa_7":
        all_errors.append(f"catalog.defaultStoryId expected 'masa_7', got '{catalog.get('defaultStoryId')}'")

    free_stories = [s.get("id") for s in stories if s.get("isFree") is True]
    if free_stories != ["masa_7"]:
        all_errors.append(f"catalog: expected only ['masa_7'] as free story, got {free_stories}")

    for entry in stories:
        errs, summary = validate_story_entry(entry)
        all_errors.extend(errs)
        if summary:
            summaries.append(summary)

    if all_errors:
        for e in all_errors:
            print(f"ERROR: {e}", file=sys.stderr)
        print(f"Catalog validation FAILED with {len(all_errors)} error(s).", file=sys.stderr)
        return 1

    print(f"Catalog validation PASSED ({len(stories)} stories):")
    for s in summaries:
        print(s)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
