#!/usr/bin/env python3
"""Check text scene/resource comments before Godot imports anything.

Godot .tres/.tscn comments use ';', not '#'. A stray hash comment can
produce a misleading Parse Error on the last line of a resource file.
This small preflight gives the actual filename and offending line.
"""

from pathlib import Path
import sys

EXCLUDED_DIRS = {".git", ".godot", "build", "node_modules", ".venv"}


def main() -> int:
    issues: list[str] = []
    for suffix in ("*.tres", "*.tscn"):
        for path in sorted(Path(".").rglob(suffix)):
            if any(part in EXCLUDED_DIRS for part in path.parts):
                continue
            seen_subresource_or_node = False
            for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
                if line.startswith(("[sub_resource ", "[node ", "[resource]")):
                    seen_subresource_or_node = True
                if seen_subresource_or_node and line.startswith("[ext_resource "):
                    issues.append(f"{path}:{number}: external resources must precede subresources and nodes")
                if line.lstrip().startswith("#"):
                    issues.append(
                        f"{path}:{number}: invalid '#' comment in Godot resource; "
                        "use ';' or move documentation into a .md file"
                    )
    if issues:
        print("\n".join(issues), file=sys.stderr)
        return 1
    print("ACTION5_TEXT_RESOURCE_COMMENT_SYNTAX_OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
