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

The [ACTION-5 CI workflow](../.github/workflows/godot-ci.yml) has two stable job names (independent of D01–D12 milestones):

- **`CI / Checks` (every PR update):** cold-start parser smoke, reproducible original/alternate GLBs and the entire headless GDScript regression suite. No export-template download, browser installation, native screenshots or WebGL2 startup.
- **`CI / Full E2E` (conditional):** Linux/Web exports, an exported native executable smoke, native camera screenshots, Chromium/WebGL2 tests and the negative-test runner self-check. Runs on **every push to `master`**, or when explicitly requested. Depends on `CI / Checks`, but does not repeat its tests.
- **Explicit PR full check:** include `[full-e2e]` in the **latest commit message** (subject or body, case-insensitive), then push the commit. The workflow reads the actual PR head commit, not the synthetic merge commit or PR title.
- **Manual dispatch:** select `full_e2e` in GitHub Actions to run the full suite; otherwise the fast tier runs.

Superseded PR runs are cancelled; `master` runs are not cancelled. Fast checks use only the pinned Godot editor; the much larger export templates and Chromium dependencies are installed only by the full E2E job. Each job shares the phony Godot import across its Make targets in one invocation.

**Action runtime maintenance:** workflows use Node.js 24-native versions of GitHub's checkout, artifact and Pages actions (GitHub-hosted runners on Ubuntu 24.04). Keep these dependencies upgraded together; changing the JavaScript action runtime does not change Godot's pinned version or Playwright's pinned test version. The full E2E browser test uses the **headless Chromium shell only** (no unused headed browser download), with a 10-minute bound on real WebGL2 smoke. The full E2E job has an 18-minute safety limit, compared with the prior 30-minute limit. The WebGL2 screenshot/timing assertions are unchanged.

```bash
make test     # Local Godot headless tests, requires Godot 4.7.2 and Python 3
make check    # Local PR-equivalent tests, additionally requires Node.js
make build    # Local Linux and Web exports, requires matching templates
```

The workflow uploads `ci-checks-evidence` for fast checks and `ci-full-e2e-evidence` plus `ci-full-e2e-exports` for full E2E. The full tests are not deleted—only deferred to master merges or explicitly opted-in PR validation. For visual-sensitive PRs, request full E2E before merge; a merge to `master` runs it automatically but cannot gate that merge retrospectively.

### GitHub Pages deployment

On every **push to `master`** (including merged PRs), `CI / Checks` and `CI / Full E2E` run first. Only after both jobs succeed does `CI / Deploy Pages` publish the **same `build/web/` export already verified in Chromium/WebGL2**. A PR, a manually dispatched workflow or a failing E2E run **never deploys**. The game is exported to `index.html` and its associated JavaScript, WASM and PCK assets; no `gh-pages` branch or separate export is created.

**Repository setup (one-time):**

1. Open **Settings → Pages → Build and deployment → Source**, choose **GitHub Actions**.
2. Under **Settings → Environments → github-pages**, allow deployments from **`master` only**. If you add reviewers, deployment will wait for that approval.
3. Ensure **Settings → Actions → General → Workflow permissions** permits the needed `GITHUB_TOKEN` rights. The workflow scopes `pages: write` and `id-token: write` **only** to the deployment job (normal CI retains `contents: read`).

The resulting project site should appear at **https://bravado.github.io/ACTION-5/**, unless the organization has configured a custom Pages domain. Confirm the actual address from the `github-pages` environment after the first successful deployment. The first publish can only be verified following a successful push to `master` with Pages enabled.

`CI / Deploy Pages` is **not a required PR status check**: it is intended to run *after* merging, while the checks below guard the merge itself.

### GitHub branch protection

Under **Settings → Rules → Rulesets** (or **Settings → Branches → Branch protection rules**) for `master`, require these **exact** job check names from **GitHub Actions**:

- `CI / Checks` — always executes on each PR and must pass.
- `CI / Full E2E` — normal PRs skip this job; GitHub treats conditionally skipped jobs as passing required checks. When `[full-e2e]` requests E2E, its failure blocks the merge.

Do **not** require the workflow display name (`ACTION-5 CI`), deployment job (`CI / Deploy Pages`), individual step names, old milestone-specific job names, or `sync-roadmap`. No workflow-level path filters are used, since skipping an entire required workflow could leave checks pending. Select **Require status checks to pass before merging**; avoid **Require branches to be up to date before merging** if minimizing repeated runner time is important. Check names appear in the required-check selector after the revised workflow has run.


D02 provides cameras, D03 adds reusable movement and plug-in moves, and D04 adds imported skeletal clips, bone sockets and local FPS visibility. New move authors and coding agents should start with **[adding-moves.md](adding-moves.md)**, then refer to [locomotion](locomotion.md), [animation](animation.md) and [camera](cameras.md) contracts. The crouch reference is exercised in `tests/crouch_suite.gd` and real browser F4-eye/side-profile captures. D05 combat and D06-01 Bat/Shovel equipment are complete. For the accepted D06-01 extension ports see [equipment authoring](equipment.md) and [ADR-0005](adr/0005-equipment-lifecycle.md); D06-02 Gun is implemented in PR #32 (the final Full E2E and owner visuals are review gates), and D07 AI is next; both stay independent of core movement/animation classes. See [ADR-0006](adr/0006-authoritative-gun-and-projectile-visuals.md) for camera-free ranged AI, muzzle ray and tracer ownership.


### D06-02 review matrix

Use `make check` (pinned Godot 4.7.2; latest test log prints
`ACTION5_TEST_RESULT assertions=958 failures=0`), and opt into the
existing PR Full E2E by including `[full-e2e]` in the final commit
message. Full E2E checks real native F1–F5 Gun scenes, F3/F4 in-flight
tracer screenshots, rendered reload/near-wall frames and actual
WebGL2 E pickup/J attack/R reload input. On software-rendered CI,
browser walking distance is not proportional to wall-clock sleeps;
use bounded real-input pickup attempts instead of a fixed movement
delay, and never add a test-only teleport or a separate game clock.
Only after latest-head automated checks pass should the PR be marked
ready for external review. The owner must visually approve F1–F5
alignment, projectile/trail readability and muzzle occlusion before
squash/merge. Do not mark issue #14 complete in advance.
