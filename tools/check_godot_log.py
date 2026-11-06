#!/usr/bin/env python3
"""Fail closed on Godot parse/runtime errors even if the editor exits with status 0."""
import pathlib
import re
import sys

ERROR = re.compile(r"^\s*(?:SCRIPT ERROR:|ERROR:|Parse Error:|Parser Error:)", re.IGNORECASE)

if len(sys.argv) < 2:
    raise SystemExit("usage: check_godot_log.py path.log [more.log ...]")

problems = []
for filename in sys.argv[1:]:
    p = pathlib.Path(filename)
    if not p.is_file():
        problems.append(f"Missing expected log: {p}")
        continue
    for num, line in enumerate(p.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
        if ERROR.search(line):
            problems.append(f"{p}:{num}: {line.strip()}")

if problems:
    print("\n".join(problems), file=sys.stderr)
    raise SystemExit(1)

print("ACTION5_LOG_CHECK_OK", *sys.argv[1:])
