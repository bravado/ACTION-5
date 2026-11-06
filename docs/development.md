# D01 — Development and verification

## Engine

Use official **Godot 4.7.2-stable**, standard (non-.NET) build and its matching export templates. The project targets the **Compatibility** renderer (WebGL 2 on the Web), typed GDScript, 60 Hz physics and the standard X/Y/Z world convention.

This D01 bootstrap contains **one diagnostic camera**, a fully 3D arena with collision, and a capsule actor. F1–F6 camera management is explicitly in D02 and is **not** claimed complete.

## Run

Clone the repository, switch to the D01 branch/merged version, and open `project.godot` with Godot 4.7.2. Press F6 in the *editor* to run the main scene, or use F5 to run the project; in this D01 demo, **WASD and arrow keys move the debug actor**. (These are Godot editor shortcuts, not ACTION-5 modes.)

From a shell:

```bash
godot --path .
godot --headless --path . --import
godot --headless --path . --script res://tests/run_all.gd
# Negative self-test: MUST exit nonzero.
godot --headless --path . --script res://tests/run_all.gd -- --self-test-failure
```

## Export

Install the matching Godot export templates in `~/.local/share/godot/export_templates/4.7.2.stable/`, then:

```bash
mkdir -p build/web build/linux
godot --headless --path . --export-release "Web" build/web/index.html
godot --headless --path . --export-release "Linux" build/linux/action5-demo.x86_64
python3 tools/check_exports.py
python3 -m http.server 8765 --directory build/web
# Open http://127.0.0.1:8765 in a WebGL-2-capable browser.
```

Web exports must be served through HTTP(S), not opened directly as file URLs. Single-threaded Web export does not require SharedArrayBuffer/COOP/COEP headers.

## CI and evidence

The D01 GitHub Actions workflow downloads the pinned Linux editor and official matching templates, runs an import and static smoke, tests runtime movement, proves the negative test path exits nonzero, exports Linux/Web, serves the Web build, tests browser startup, and captures native/website screenshots where supported.

CI uploads import/test/export logs and screenshots to the `d01-evidence` artifact and native/Web executables to `d01-exports`. A workflow passing is not equivalent to the complete D01 gate until the screenshots, actual browser behavior and independently runnable native artifact have been checked.

### D01 gate handoff checklist

- [ ] Clone → import → run real scene.
- [ ] Godot 4.7.2 headless test suite green.
- [ ] Negative test demonstrably fails and CI treats it as expected.
- [ ] Web export starts over HTTP and displays arena/actor.
- [ ] Native export runs.
- [ ] Parser/runtime logs contain no errors.
- [ ] Screenshots and logs attached to pull request or workflow artifacts.
- [ ] MIT license and procedural-asset inventory committed.

D02 must not begin until D01 gate is reviewed and approved or the owner explicitly records an exception.

## D02 — Six-camera demo

The current D02 branch adds one persistent camera and six runtime presets. Use **1–6** in the native editor run or Web build; F1–F6 are optional alternate shortcuts. WASD/arrows move a placeholder capsule; F4 and F5 allow click-to-capture mouse look, and Esc releases it. A six-button HUD provides a browser-safe fallback. Gamepad shoulder buttons cycle views.

All camera profile values are editable in `addons/action5/views/*.tres`. The reusable camera components are under `addons/action5/camera/`. See [cameras.md](cameras.md) for API and integration instructions.

```bash
godot --path .
godot --headless --path . --import
godot --headless --path . --script res://tests/run_all.gd
```

The D02 visual evidence suite captures `native-view-1.png` to `native-view-6.png` and corresponding `web-view-*.png` screenshots into the GitHub Actions `d02-evidence` artifact. These screenshots show each perspective on the same world and are reviewed as part of D02 acceptance.

No D03 locomotion, D04 animation, D05 combat or weapons are claimed as part of D02.
