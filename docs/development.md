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


## Merged D01–D07 baseline and active D08 milestone

D02 supplies five cameras; D03 supplies data-driven movement; D04 supplies
imported skeletal clips, bone sockets and local first-person visibility.
D05 implements authored combat and D06 Bat/Shovel/Gun, muzzle-first physical
hits and optional projectile/reload visuals; D06-01 and D06-02 merged as
PRs #31 and #32. The crouch movement example also uses the same ports.
Use [adding moves](adding-moves.md), [animation](animation.md),
[combat](combat.md), [equipment](equipment.md) and
[ADR-0006](adr/0006-authoritative-gun-and-projectile-visuals.md)
rather than introducing new actor or attack clocks.

D07-01 (merged PR #33) adds four actor-local AI components and two
equipped melee/ranged NPCs. Their only authored battle environment is now
`demo/world/encounter_sector.tscn`, embedded by `demo/main.tscn` with
real navigation, physical obstruction, shared player punch/kick input
and optional skeletal animations. No duplicate Player/ViewManager scene
exists for tests. See [AI authoring](ai.md) for extensions and the
D07-to-D08 handoff.

### D07 verification recipe

```bash
make check
make import
godot --path . res://demo/main.tscn # E at east-side door enters the dungeon
```

`tests/d07_suite.gd`, automatically included in `make check`, verifies
real AI-driven damage, physical range/LoS and nav, target lifecycle,
gun ammo/reload, player input attacks, two independent animation trees,
Bat/Gun clip playback, animated hand sockets, NPC running clips and
equipment cleanup with animation disabled.

Set `[full-e2e]` in the **latest** PR commit message to run native Linux
and Web export checks, the exported native smoke and the real WebGL2
browser test before approval. Superseded PR runs are cancelled and do
not count as final-head evidence. The existing native screenshot and
browser scripts target `demo/main.tscn` by default: they validate
shared rendering/export and the main arena, but **not necessarily an
actual dungeon visit**. The owner's F1–F5 visual review of the two NPCs,
weapon positions, animated firing/swinging and obstruction must be
recorded separately. D07 final verification passed **1,018 Godot assertions (0 failures)**,
Linux/Web builds, native startup/rendering and real WebGL2 Full E2E in
[CI run #42871200034](https://github.com/bravado/ACTION-5/actions/runs/42871200034).
Future NPC visual changes still need an actual E-door dungeon review;
main-arena captures do not prove encounter-specific animation quality.

### D08 persistent-world demo and orientation

PR #34 is rebased on merged D07 `master` and remains a D08
draft. `demo/main.tscn` owns one live Player, Equipment/Health/Combat,
ViewManager and a separately authored `demo/world/encounter_sector.tscn`
dungeon. The arena and dungeon now **share a world-space boundary**:
the arena floor ends at X=14, and the dungeon (origin X=26, floor
half-width 12) starts at X=14 on the same height and orientation. The gateway is centered on Z=0,
so the default F1 side-scroller lane can reach it without switching views.
The arena east wall is split above and below a real opening at
**X=14, Z=0**, with an overlapping `PassageFloor` slab so there
is no unsupported physics seam. The dungeon supplies its other three
enclosing walls.

A **single** `EncounterDoor` spans this common wall. Its `WorldDoor`
component toggles a real CollisionShape3D and NavigationLink3D;
`DoorMesh` is an always-visible two-sided frame, while the separately
configured `BarrierMesh` disappears when open. **E opens the gate,
WASD physically walks through it in either direction.** There is no
`ReturnDoor` in the dungeon, second Player/ViewManager or door-triggered
`travel_to()` teleport. `WorldSession` detects the player's
world-X crossing with a small hysteresis, activates dungeon AI/physics
*before* the player reaches the gate, and pauses them only after the
player moves sufficiently back into the arena. The old standalone
`demo/ai/encounter.tscn` and scene-reloading adapters were removed;
`tests/d07_suite.gd` uses the **same embedded dungeon**.

**Continuous camera bounds:** D02's F1/F2/F5 authored profiles clamp
their camera target to the arena. `demo/world/sector_camera_bounds.gd`
duplicates those Resources per game instance and computes the *union*
of the arena and dungeon bounds, plus any configured connected sectors.
Each profile's local X/Z rectangle is transformed at all four corners
into a union that also supports rotated sectors. It never shifts or snaps
the camera on crossing. Bounded F2/F5 views maintain fixed heading at
edges, and the generic isometric rig uses its authored orbit direction
rather than lag-induced actor look-at to prevent F3 WASD rotation.
`Action5MovementPolicy`, `ActorInputAdapter` and all gameplay
coordinates stay unchanged.

`tests/d08_camera_sector_suite.gd` verifies in all five modes that
W/A/S/D resolves to the same world-plane vectors before/after each
round trip, the same Player/SceneTree remain alive, both floor
edges meet at the doorway, and bounded cameras follow across one
continuous world rectangle. Keep adjoining rooms' global X/Z axes
aligned and do **not** synthesize movement transforms or per-room
camera jumps. New movement modes stay independent of world geometry.

`tests/d08_world_suite.gd` separately covers persistent inventory,
dropped weapons, NPC state, physically authoritative doors, roof
presentation, fresh/restore entry and Restart. The dungeon ceiling
is a **physics-only** StaticBody3D without a rendered Mesh. Its prior
transparent world-space cube at Y=4 tinted only the upper half of the
screen when a side/arcade camera looked underneath it.
`demo/interactions/roof_visibility.gd` now provides a uniform
full-viewport translucent 18%-opacity blue tint with a CanvasLayer
(layer 0, under HUD layer 1), enabled only in the dungeon in
views 1/2/3/5 and hidden for first person. The ColorRect has
`MOUSE_FILTER_IGNORE`, and its anchors span the viewport regardless
of camera orientation/aspect ratio. This is a **presentation** effect:
the ceiling CollisionShape3D remains physically authoritative.
The dungeon's two lights remain modest (0.65 and 0.5), and the shared
world sun is unchanged. Regress both screen coverage and ceiling
physics independently.
The **single boundary gate** uses
`WorldDoor.keep_visual_when_open = true` so its structural frame stays
visible from both sides. Its configurable `barrier_visual_path`
points to the opening panel, which disappears when the physical
barrier collider disables and the navigation link enables. Ordinary
door panels keep the default `false` to hide on opening. The shared
frame and door state persist across all visits, even when dungeon
processing is suspended away from the passage. D08 release readiness
still requires passing fresh head-specific CI, native/WebGL2 traversal
and manual visual checks; these docs do **not** imply PR #34 is merged.

### D08 door occlusion, awareness and remote PackedScene transitions

In `demo/main.tscn`, the teal gate at **X=14, Z=0** joins two
rooms. Physically press E at its near-side handle and then walk
through. A closed door disables its NavigationLink3D, enables its
blocking shape and restores the opaque panel. `RoomVisibility`
hides the opposite room's render nodes, including world pickup
meshes, **without disabling their physics or resetting AI state**.
The linked `DoorAcquisitionFilter` prevents the two NPC sensors
from *first* acquiring an actor across a closed boundary, while
already-detected targets continue chasing until normal forget/Health
rules apply; the door still blocks physical movement and attacks.

A long-distance pursuit is a separate acceptance condition from
initial detection: after the player opens a door, a melee NPC may
walk through to the arena. When the player closes the gate behind
it, the dungeon walls and floor are hidden but **that NPC remains
visible and active on the arena side**. A closed gate prevents
line-of-sight attacks only when player and NPC occupy opposite
sides; it must not erase an acquired target. RoomVisibility performs
the presentation filter separately for static room geometry and
moving NPCs/world weapons; WorldSession keeps alerted/crossed NPCs
processing outside the normal preload radius.

`Action5Interactor` uses an optional
`get_interaction_point(actor)` method so an opaque door can provide
symmetric handles without the ray needing to terminate inside its
own panel. Each of the two **gold handles** at world X=14 aligns
precisely with those near-side E points. A connected door has **no
Label3D nodes**. The teal lintel/solid panel share one physical
coordinate frame, and the mesh uses the same dimensions/position as
the blocking CollisionShape3D. This is important in F2, where the
formerly frontal +Z camera saw the vertical panel edge-on. The AI sensor likewise accepts an optional
`allows_acquisition(observer, candidate)` filter. Both protocols
are replaceable and have no input, camera or combat dependencies.
ArenaNavigation uses a minimal flat demo NavMesh, connected to
the dungeon's authored ring by the physical door link. For a real
game, bake obstacle-aware nav polygons for each sector.

The purple portal at **X=-11.5, Z=0** is *not* a physical doorway.
Its independent `LocationPortal` loads
`demo/world/remote_chamber.tscn` (or can instead target a Marker3D),
then `LocationManager` repositions the **original player** to the
arrival point and caches the detached scene instance. The room has a
return-to-arena marker portal. When cached inactive, its visibility and
processing are disabled **and its physics collision layers/masks and
navigation region/link flags are saved and cleared**, then restored
on re-entry. Two remote scenes may share the same offset with no
invisible physical blockers. The original player and inventory are
never cached or reinitialized. Missing remote arrival markers are
rejected before caching a bad scene.
`WorldSession` stops threshold checking only during detached travel.
Camera bounds change only for the explicit distant jump, not while
walking between adjacent rooms.

Run `make check` and `tests/d08_connections_suite.gd` (through
`tests/run_all.gd`). The tests exercise a real viewport E key,
both-sided gate behavior, room invisibility before entry,
acquisition denial/persistence, nav/collision states, and repeated
detached scene travel with the same inventory/actor identity. The
usual D07 NPC and D08 dropped-equipment/camera regressions still run.


**F2 side-wall reveal (D08):** `beatemup.tres` sets the optional
`lateral_peek_degrees = 6`, with an exponential response of 8.
Use **C → Side peek (deg) / Peek response** to edit these independently
of gameplay state; profile-specific overrides persist and Reset restores
the shipped 6-degree angle.
The camera sidesteps left while the player moves right and vice versa,
holding the last viewing angle when idle. This makes X-normal
walls/door panels visible without rotating F2 movement: WASD remains
world-X/Z, and F1/F3/F4/F5 remain untouched. Set the profile angle to
0 to disable. The `SectorCameraBounds` adapter unions transformed
authored rectangles across all configured sectors. Instancing a
whole level away from the world origin or rotating an added sector
does not leave the camera clamped to the wrong location.

**Portal label policy:** `demo/interactions/location_portal.gd`
offers `show_label` and `label_path`. Defaults show a `Label3D`
child on remote portals; omit the label or call
`set_label_visible(false)` to hide it without changing E eligibility
or where the original Player travels. Connected physical doors have
no labels or scene-transition logic.

**Weapon visibility lifecycle:** `RoomVisibility` observes weapon
pickup/drop and runtime node-creation events, tracks only loose weapons
in the connected rooms during physics ticks, and updates their
visibility if they move across the closed-gate boundary. Once picked up,
`EquipmentController` owns their visible state. The fallback E pickup
cannot collect a hidden weapon through a closed gate. Remote-room
pickups are excluded by their `action5_detached_location` ancestor.
Old visible-state and material weak references are pruned on fresh
dungeon replacement to prevent repeated-visit cache growth.

### Outer perimeter fade without gameplay coupling

The D08 `demo/world/outer_wall_fader.gd` presenter monitors the
player's horizontal distance to authored **outer wall**
CollisionShape3D box footprints. Only `action5_outer_wall` members
fade. When the actor approaches within 3.8 units, the wall mesh
transitions toward 20% opacity, reaching that value at 1.1 units.
The bottom/front `SouthWall` in the arena and dungeon is the main
visibility improvement; other exterior bounds in those rooms and the
remote chamber opt in using the same group. First person keeps walls
opaque. Near/far thresholds, minimum opacity, response rate, and
F4 exemption are exported settings.

Use a cached alpha-enabled **duplicate** of each wall's existing
StandardMaterial3D surface material and restore the original override
when far; generic GeometryInstance3D transparency does not work
with WebGL2 Compatibility. The original opaque resources are never
mutated; no rendering change touches a StaticBody3D, CollisionShape3D,
NavigationLink3D, scene-room visibility, or NPC/Gun line of sight.
Shared boundary walls and the solid door must **not** opt in.
`tests/d08_camera_sector_suite.gd` exercises material opacity,
restoration and no collision changes in all relevant modes.
