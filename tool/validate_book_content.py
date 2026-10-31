# -*- coding: utf-8 -*-
"""CI content gate for brew_helper books + seed data.

Checks:
1. manifest.json parses; every chapter file exists; keys are unique.
2. Every chapter has at least one `## ` section (anchor requirement).
3. Seed JSONs parse; required fields present; verified is false;
   source_ref present for every seed row.
Fails (exit 1) with clear messages so CI output is actionable.
"""
import json
import os
import sys
from pathlib import Path

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

ROOT = Path(__file__).resolve().parent.parent
BOOKS_DIR = ROOT / "assets" / "books"
DATA_DIR = ROOT / "assets" / "data"

errors: list[str] = []


def fail(msg: str) -> None:
    errors.append(msg)


def main() -> int:
    # ---------- books ----------
    manifest_path = BOOKS_DIR / "manifest.json"
    if not manifest_path.exists():
        fail("missing manifest.json")
    else:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        seen_keys: set[str] = set()
        book_count = 0
        chapter_count = 0
        for book in manifest.get("books", []):
            book_count += 1
            bid = book.get("book_id", "?")
            for ch in book.get("chapters", []):
                chapter_count += 1
                key = ch.get("key", "")
                rel = ch.get("file", "")
                if not key or not rel:
                    fail("%s: chapter missing key/file" % bid)
                    continue
                if key in seen_keys:
                    fail("duplicate chapter key: %s" % key)
                seen_keys.add(key)
                path = BOOKS_DIR / rel
                if not path.exists():
                    fail("missing chapter file: %s" % rel)
                    continue
                text = path.read_text(encoding="utf-8")
                if "## " not in text:
                    fail("chapter %s has no '## ' section (anchors broken)" % key)
                if text.lstrip().startswith("# ") is False:
                    fail("chapter %s should start with '# ' title" % key)
        print("books: %d books, %d chapters" % (book_count, chapter_count))
        if book_count < 5:
            fail("expected 5 books, found %d" % book_count)

    # ---------- seeds ----------
    required = {
        "sop_procedures.json": ["sop_id", "process", "title", "body_md", "keywords"],
        "process_params.json": ["param_id", "process", "name", "value_range"],
        "fault_diagnosis.json": ["fault_id", "process", "symptom", "cause_md", "steps_md", "remedy_md"],
        "calc_formulas.json": ["formula_id", "name", "formula_md", "explanation_md"],
        "glossary_terms.json": ["term_id", "en", "zh", "category", "definition"],
        "safety_rules.json": ["rule_id", "title", "body_md"],
        "daily_facts.json": ["fact_id", "title", "body_md", "category", "keywords"],
        "app_settings.json": ["key", "value"],
    }
    for fname, fields in required.items():
        path = DATA_DIR / fname
        if not path.exists():
            fail("missing seed file: %s" % fname)
            continue
        try:
            rows = json.loads(path.read_text(encoding="utf-8"))
        except Exception as exc:
            fail("%s: invalid JSON: %s" % (fname, exc))
            continue
        if not isinstance(rows, list):
            fail("%s: top-level must be a list" % fname)
            continue
        if fname == "glossary_terms.json" and len(rows) < 100:
            fail("glossary_terms.json: expected >= 100 terms, got %d" % len(rows))
        if fname == "sop_procedures.json" and len(rows) < 18:
            fail("sop_procedures.json: expected >= 18 entries, got %d" % len(rows))
        if fname == "fault_diagnosis.json" and len(rows) < 16:
            fail("fault_diagnosis.json: expected >= 16 entries, got %d" % len(rows))
        if fname == "calc_formulas.json" and len(rows) < 8:
            fail("calc_formulas.json: expected >= 8 entries, got %d" % len(rows))
        if fname == "daily_facts.json" and len(rows) < 60:
            fail("daily_facts.json: expected >= 60 entries, got %d" % len(rows))
        if fname == "safety_rules.json" and len(rows) < 8:
            fail("safety_rules.json: expected >= 8 entries, got %d" % len(rows))
        for i, row in enumerate(rows):
            for field in fields:
                if field not in row:
                    fail("%s row %d missing field %s" % (fname, i, field))
            # content red line: verified must exist and stay false for now
            if fname != "app_settings.json":
                if "verified" not in row:
                    fail("%s row %d missing verified" % (fname, i))
                elif row["verified"] is not False:
                    fail("%s row %d verified must be false until manually checked" % (fname, i))
                if not row.get("source_ref"):
                    fail("%s row %d missing source_ref" % (fname, i))

    if errors:
        print("CONTENT CHECK FAILED:")
        for e in errors:
            print("  - " + e)
        return 1
    print("content check OK: manifest/books consistent, seeds complete")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
