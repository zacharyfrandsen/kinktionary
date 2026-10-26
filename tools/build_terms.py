#!/usr/bin/env python3
"""Build assets/data/terms.json from data_source/.

Sources, in priority order:
  1. data_source/yaml/*.yml    your term files (name + definition per term)
  2. data_source/extras.json   extra terms, plus optional details / related /
                               safetyNote / draft fields for any term id

Rules:
  - A YAML term's name, definition and section (category) always win.
  - extras.json only fills in what a YAML term lacks (details, related,
    safetyNote, draft), or supplies a definition when the YAML one is blank.
  - Terms still without a definition are skipped with a warning.

Run:  python3 -I tools/build_terms.py        (needs PyYAML)
"""
import json
import pathlib
import sys

import yaml

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "data_source"
OUT = ROOT / "assets" / "data" / "terms.json"
PATHS = ROOT / "assets" / "data" / "paths.json"

warnings = []


def warn(msg):
    warnings.append(msg)
    print("WARN:", msg)


terms = {}  # id -> dict (insertion ordered)

for f in sorted((SRC / "yaml").glob("*.yml")):
    doc = yaml.safe_load(f.read_text(encoding="utf-8"))
    section = doc["section_name"]
    for entry in doc["terms"]:
        for tid, body in entry.items():
            short = (body.get("definition") or body.get("description") or "").strip()
            if tid in terms:
                old = terms[tid]
                if not short:
                    warn(f"{tid}: blank in {f.name}, keeping {old['category']} version")
                    continue
                warn(f"{tid}: in both {old['category']} and {section}; using {section}")
            terms[tid] = {
                "id": tid,
                "name": body["name"].strip(),
                "category": section,
                "short": short,
            }

for ex in json.loads((SRC / "extras.json").read_text(encoding="utf-8")):
    tid = ex["id"]
    if tid in terms:
        t = terms[tid]
        if not t["short"] and ex.get("short"):
            t["short"] = ex["short"]
        for key in ("details", "related", "safetyNote", "draft"):
            if key in ex and key not in t:
                t[key] = ex[key]
    else:
        terms[tid] = dict(ex)

result = []
for t in terms.values():
    if not t.get("short"):
        warn(f"{t['id']}: no definition anywhere, skipped")
        continue
    result.append(t)

ids = {t["id"] for t in result}
for t in result:
    bad = [r for r in t.get("related", []) if r not in ids]
    if bad:
        warn(f"{t['id']}: dropping unknown related ids {bad}")
        t["related"] = [r for r in t["related"] if r in ids]

paths = json.loads(PATHS.read_text(encoding="utf-8"))
broken = [(p["id"], i) for p in paths for i in p["termIds"] if i not in ids]
if broken:
    print("ERROR: paths reference unknown term ids:", broken)
    sys.exit(1)

OUT.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

by_cat = {}
for t in result:
    by_cat[t["category"]] = by_cat.get(t["category"], 0) + 1
print(f"Wrote {len(result)} terms to {OUT.relative_to(ROOT)}")
for c, n in sorted(by_cat.items()):
    print(f"  {c}: {n}")
drafts = [t["id"] for t in result if t.get("draft")]
print("Drafts needing your review:", drafts or "none")
