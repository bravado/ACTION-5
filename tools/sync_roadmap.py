#!/usr/bin/env python3
"""Synchronize ACTION-5 release milestones and existing DXX-YY issues.

This is intentionally idempotent: it never duplicates matching milestones or issues,
never closes anything, and never replaces hand-edited issue descriptions.
Run inside GitHub Actions with GITHUB_TOKEN and issues:write permission.
"""
from __future__ import annotations

import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

API = "https://api.github.com"
REPOSITORY = os.environ["GITHUB_REPOSITORY"]
TOKEN = os.environ["GITHUB_TOKEN"]
BASE = f"/repos/{REPOSITORY}"
PLAN = Path("PLAN.md").read_text(encoding="utf-8")

RELEASES = [
    ("v0.1 — Foundation", "D01–D03: pinned project, headless/CI smoke exports, six camera profiles, actor locomotion and input.", range(1, 4), "0.1"),
    ("v0.2 — Combat", "D04–D07: animation integration, hitbox/tick combat, bat/shovel/gun, basic 3D enemy AI.", range(4, 8), "0.2"),
    ("v0.3 — Gameplay & Tooling", "D08–D10: arena/dungeon interactions, playable six-view demo and authoring/debug tools.", range(8, 11), "0.3"),
    ("v1.0 — Distribution", "D11–D12: browser/native regression, performance, installable addon, docs and release artifacts.", range(11, 13), "1.0"),
]
ISSUE_CODE = re.compile(r"^(D\d{2}-\d{2})\s+[—-]")
BACKLOG_CODE = re.compile(r"^- `(D\d{2}-\d{2})` ", re.MULTILINE)


def request(method: str, endpoint: str, data: dict | None = None):
    url = API + endpoint
    payload = None if data is None else json.dumps(data, ensure_ascii=False).encode("utf-8")
    headers = {
        "Accept": "application/vnd.github+json",
        "Authorization": f"Bearer {TOKEN}",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "action5-roadmap-sync",
    }
    if payload is not None:
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, payload, headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            raw = response.read()
            return json.loads(raw.decode("utf-8")) if raw else None
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"GitHub API {method} {endpoint}: HTTP {exc.code}: {detail[:700]}") from exc


def pages(endpoint: str):
    page = 1
    while True:
        sep = "&" if "?" in endpoint else "?"
        chunk = request("GET", f"{endpoint}{sep}per_page=100&page={page}")
        if not isinstance(chunk, list):
            raise RuntimeError(f"Expected paginated list at {endpoint}")
        yield from chunk
        if len(chunk) < 100:
            break
        page += 1


def release_for(code: str):
    n = int(code[1:3])
    return next(((title, version) for title, _, entries, version in RELEASES if n in entries), None)


def main():
    expected_codes = set(BACKLOG_CODE.findall(PLAN))
    if len(expected_codes) != 21:
        raise RuntimeError(f"Expected 21 planned DXX-YY issues in PLAN.md, found {len(expected_codes)}")

    existing_milestones = {m["title"]: m for m in pages(BASE + "/milestones?state=all")}
    release_numbers = {}
    for title, description, _, version in RELEASES:
        milestone = existing_milestones.get(title)
        if milestone is None:
            milestone = request("POST", BASE + "/milestones", {
                "title": title, "state": "open",
                "description": description + " See PLAN.md for acceptance gates and assigned implementation issues.",
            })
            print(f"Created milestone: {title} (#{milestone['number']})")
        else:
            print(f"Reusing milestone: {title} (#{milestone['number']})")
        release_numbers[version] = milestone["number"]

    issues = {
        match.group(1): issue
        for issue in pages(BASE + "/issues?state=all")
        if "pull_request" not in issue
        if (match := ISSUE_CODE.match(issue["title"])) is not None
    }
    missing = sorted(expected_codes - issues.keys())
    if missing:
        raise RuntimeError("Missing planned GitHub issues, refusing partial sync: " + ", ".join(missing))

    count = 0
    for code in sorted(expected_codes):
        issue = issues[code]
        release = release_for(code)
        if release is None:
            raise RuntimeError(f"No target release for {code}")
        title, version = release
        milestone_number = release_numbers[version]
        if issue.get("milestone") and issue["milestone"].get("number") == milestone_number:
            continue
        request("PATCH", BASE + f"/issues/{issue['number']}", {
            "milestone": milestone_number,
        })
        print(f"Linked {code} (issue #{issue['number']}) to {title}")
        count += 1

    summary = [
        "## ACTION-5 roadmap synchronization",
        "",
        f"Linked **{count}** issues; total tracked: **{len(expected_codes)}**.",
        "",
        "| Milestone | Issues |",
        "|---|---:|",
    ]
    for title, _, ids, version in RELEASES:
        qty = sum(int(code[1:3]) in ids for code in expected_codes)
        summary.append(f"| {title} | {qty} |")
    summary.append("")
    summary.append("No issues were duplicated or closed. Existing issue descriptions were preserved.")
    msg = "\n".join(summary) + "\n"
    print(msg)
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as out:
            out.write(msg)


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"ROADMAP SYNC FAILED: {exc}", file=sys.stderr)
        sys.exit(1)
