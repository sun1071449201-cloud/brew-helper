# -*- coding: utf-8 -*-
"""锚点校验：daily_facts / book_learning 的 chapter_key+anchor 必须能解析到
真实书籍章节的真实小节标题（节号前缀匹配，与 App resolveAnchor 同口径）。"""
import io
import json
import os
import re
import sys

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BOOKS = os.path.join(ROOT, "assets", "books")
DATA = os.path.join(ROOT, "assets", "data")

NUM = re.compile(r"^([0-9]+(?:\.[0-9]+)*)")


def load_headings():
    """chapter_key → [节号列表]（从 md 的 ##/### 标题提取）。"""
    manifest = json.load(io.open(os.path.join(BOOKS, "manifest.json"),
                                 encoding="utf-8"))
    heads = {}
    for book in manifest["books"]:
        for ch in book["chapters"]:
            text = io.open(os.path.join(BOOKS, ch["file"]),
                           encoding="utf-8").read()
            nums = []
            for line in text.splitlines():
                m = re.match(r"^#{2,3}\s+(.+)$", line.strip())
                if m:
                    n = NUM.match(m.group(1))
                    if n:
                        nums.append(n.group(1))
            heads[ch["key"]] = (nums, os.path.exists(
                os.path.join(BOOKS, ch["file"])))
    return heads


def anchor_ok(anchor, nums):
    if not anchor:
        return True  # 无锚点只跳章首
    return any(n == anchor or n.startswith(anchor + ".") for n in nums)


def main():
    heads = load_headings()
    errors = []
    checked = 0

    daily = json.load(io.open(os.path.join(DATA, "daily_facts.json"),
                              encoding="utf-8"))
    for r in daily:
        ck = r.get("chapter_key")
        if not ck:
            continue
        checked += 1
        if ck not in heads:
            errors.append("%s: unknown chapter %s" % (r["fact_id"], ck))
            continue
        nums, _ = heads[ck]
        if not anchor_ok(r.get("anchor"), nums):
            errors.append("%s: anchor %s.%s not found in %s"
                          % (r["fact_id"], ck, r.get("anchor"), nums))

    bl = json.load(io.open(os.path.join(DATA, "book_learning.json"),
                           encoding="utf-8"))
    for c in bl.get("chapters", []):
        ck = c.get("chapter_key")
        if ck not in heads:
            errors.append("book_learning: unknown chapter %s" % ck)

    print("anchors checked: %d (daily with chapter_key)" % checked)
    if errors:
        print("ANCHOR ERRORS (%d):" % len(errors))
        for e in errors:
            print("  -", e)
        return 1
    print("ALL ANCHORS OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
