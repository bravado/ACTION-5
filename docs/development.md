# ACTION-5 development workflow

ACTION-5 uses **Godot 4.7.2 stable**, standard GDScript and the Compatibility renderer. Linux and macOS developers use GNU Make for an **import-first** workflow; the same commands are exercised in GitHub Actions.

## Prerequisites

Install Godot 4.7.2 (non-.NET) and make sure `godot --version` reports `4.7.2.stable`. You also need GNU Make and Python 3. The Linux/Web export targets additionally require the **matching 4.7.2 export templates** installed in `~/.local/share/godot/export_templates/4.7.2.stable/`.

On systems where the executable has another name, specify `GODOT` when invoking Make (for example, `make run GODOT=godot4`).

## Standard commands

| Command | Behavior |
|---|---|
| `make import` | Scan scripts/resources, refresh Godot's generated `.godot/` registry and imports, fail on parser/runtime log errors |
| `make run` | **Import first**, then launch the game directly |
| `make editor` | Import first, then launch the Godot editor |
| `make test` | Import first, run the headless GDScript suite and validate logs |
| `make check` | Regenerate and verify tracked GLBs (Node.js), then run the Godot tests; matches the standard PR CI tier |
| `make web` | Import, export `build/web/index.html` and check required HTML/JS/WASM/PCK files |
| `make linux` | Import, export `build/linux/action5-demo.x86_64`, verify an executable was produced |
| `make build` | Import and build both native Linux and Web artifacts, validate both exports |
| `make serve-web` | Build Web and serve it on `http://127.0.0.1:8765/` |
| `make clean-build` | Remove **only** generated `build/` files, including prior test logs and exports |
| `make help` | Show all commands |

To get started after cloning:

```bash
git clone https://github.com/bravado/ACTION-5.git
cd ACTION-5

make test
make run
```

Press **1–5** to switch between five camera modes, **WASD/arrow keys** to walk, **Space** to jump, **Shift** to run, **Alt** to dodge, **X** to slide and **Ctrl** to toggle crouch (**R3** on gamepad). F1 now uses a true horizontal Mario/Altered Beast-style side-scrolling projection; F2 is the elevated beat'em-up camera. Click to capture the mouse in F3/F4 and press Esc to release it. The five view buttons offer a browser-friendly fallback.

`make run` launches the **game**, not the editor. Use `make editor` when you want the scene tree and inspector.

### What "import first" means

Godot generates its global `class_name` registry and resource imports under `.godot/`. Those files are machine-local and **must never be committed**. The Makefile runs `godot --headless --path . --import` before every run/test/export; a warm import is normally quick.

Each Make target uses `tools/check_godot_log.py` to fail rather than continuing when the engine reports `SCRIPT ERROR:`, `ERROR:` or a parser error, even if Godot exits with status 0. Import and test logs are written to `build/logs/`.

The camera components also explicitly `preload()` dependencies, so a fresh clone is robust even when a game is invoked directly. **Import-first is still the supported developer workflow.**

If you need to run only the initial resource import:

```bash
make import
```

You can override the Godot binary:

```bash
make run GODOT=/path/to/Godot_v4.7.2-stable_linux.x86_64
```

For a CI/headless launch without opening a window:

```bash
make run RUN_ARGS="--headless --quit-after 20"
```

## D02: unified isometric / shoulder camera

**Five modes, one world:** 1 side-scroller; 2 beat'em up; 3 isometric/over-the-shoulder (one camera resource); 4 first person; 5 retro overhead.

In mode **3**, press **C** to open the camera settings panel. Decrease orthographic zoom from the wide default of 17 toward 4 to transition continuously into the over-the-shoulder composition. Camera collision, left/right shoulder offset, pitch, follow distance and look-ahead are editable in the same mode. Settings are stored in `user://action5_camera_settings.cfg` by named profile IDs; the older six-slot file is migrated automatically.

In mode 2, a low camera and zoom 7 provide closer brawler framing. The one persistent `Camera3D` is shared across all five modes. The reusable locomotion component is included (D03), with a separate animation presenter in D04.

## Export and browser smoke

```bash
make web
make linux
# or both:
make build

make serve-web
# Opens an HTTP server at http://127.0.0.1:8765/
```

Use `make serve-web PORT=9000` to change the server port. Godot WebAssembly exports **must be served through HTTP(S)**; don't open `index.html` using a `file://` URL. The single-threaded Web export does not require SharedArrayBuffer headers.

Godot must have the export templates matching the editor version. The CI installation script (`ci/install-godot.sh`) installs the exact editor and templates on Linux runners, including the single-threaded `web_nothreads_*` templates.

## Tests and CI evidence

The [Godot CI workflow](../.github/workflows/d01-godot.yml) has two tiers:

- **Every PR update:** cold-start parser smoke, reproducible original/alternate GLBs and the entire headless GDScript regression suite. No export-template download, browser installation, native screenshots or WebGL2 startup.
- **Push to `master`:** always runs those fast checks **plus** Linux/Web exports, an exported native executable smoke, native camera screenshots, Chromium/WebGL2 tests and the negative-test runner self-check.
- **Explicit PR full check:** include `[full-e2e]` in the **latest commit message** (subject or body, case-insensitive), then push the commit. The workflow reads the actual PR head commit, not the synthetic merge commit or PR title.
- **Manual dispatch:** select `full_e2e` in GitHub Actions to run the full suite; otherwise the fast tier runs.

Superseded PR runs are cancelled; `master` runs are not cancelled. Fast checks use only the pinned Godot editor; the much larger export templates and Chromium dependencies are installed only by the full tier. Multiple Make goals use one process, so the shared phony import executes only once per run.

```bash
make test     # Local Godot headless tests, requires Godot 4.7.2 and Python 3
make check    # Local PR-equivalent tests, additionally requires Node.js
make build    # Local Linux and Web exports, requires matching templates
```

The workflow uploads `d04-evidence` logs for both tiers; full E2E additionally includes native/Web screenshots and `d04-exports` Linux and Web builds. The full tests are not deleted—only deferred to master merges or explicitly opted-in PR validation. For visual-sensitive PRs, request full E2E before merge; a merge to `master` runs it automatically but cannot gate that merge retrospectively.

D02 provides cameras, D03 adds reusable movement and plug-in moves, and D04 adds imported skeletal clips, bone sockets and local FPS visibility. New move authors and coding agents should start with **[adding-moves.md](adding-moves.md)**, then refer to [locomotion](locomotion.md), [animation](animation.md) and [camera](cameras.md) contracts. The crouch reference is exercised in `tests/crouch_suite.gd` and real browser F4-eye/side-profile captures. Combat and weapons remain separate D05–D07 work.
