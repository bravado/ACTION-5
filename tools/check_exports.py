#!/usr/bin/env python3
"""Validate concrete native and Web export outputs. No Godot installation needed."""
import pathlib
import sys

web = pathlib.Path("build/web")
linux = pathlib.Path("build/linux/action5-demo.x86_64")
required = [
    web / "index.html",
    web / "index.js",
    web / "index.wasm",
    web / "index.pck",
    linux,
]
errors = [f"Missing/empty export: {p}" for p in required if not p.is_file() or p.stat().st_size <= 0]
if linux.exists() and not (linux.stat().st_mode & 0o111):
    errors.append(f"Native export lacks executable bit: {linux}")
if errors:
    print("\n".join(errors), file=sys.stderr)
    sys.exit(1)
print("ACTION5_EXPORT_CHECK_OK")
for p in required:
    print(f"  {p}: {p.stat().st_size} bytes")
