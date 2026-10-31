# -*- coding: utf-8 -*-
"""Delete old GitHub Actions artifacts (keep the newest N) to free storage quota.
Reads token from tool/github_token.txt.
Usage: python tool/clean_artifacts.py [keep=1]
"""
import io
import json
import os
import sys
import urllib.request

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
token = io.open(os.path.join(ROOT, "tool", "github_token.txt"),
                encoding="utf-8").read().strip()
REPO = "sun1071449201-cloud/brew-helper"
keep = int(sys.argv[1]) if len(sys.argv) > 1 else 1

def api(url, method="GET"):
    req = urllib.request.Request(url, method=method, headers={
        "Authorization": "Bearer " + token,
        "User-Agent": "brew-helper-maint",
        "Accept": "application/vnd.github+json",
    })
    return urllib.request.urlopen(req, timeout=60)

arts = []
page = 1
while True:
    with api("https://api.github.com/repos/%s/actions/artifacts?per_page=100&page=%d"
             % (REPO, page)) as resp:
        data = json.load(resp)
    batch = data.get("artifacts", [])
    arts.extend(batch)
    if len(batch) < 100:
        break
    page += 1

print("total artifacts:", len(arts))
arts.sort(key=lambda a: a["created_at"], reverse=True)
removed = 0
for i, a in enumerate(arts):
    if i < keep:
        print("KEEP  %s  %s  %s" % (a["name"], a["created_at"], a["id"]))
        continue
    if a["expired"]:
        continue
    try:
        api("https://api.github.com/repos/%s/actions/artifacts/%d"
            % (REPO, a["id"]), method="DELETE")
        removed += 1
    except Exception as exc:
        print("FAIL  %s: %s" % (a["id"], exc))
print("removed:", removed)
