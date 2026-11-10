# ACTION-5

**A five-perspective 3D action framework for Godot.** One world, one character, five ways to play.

> **Project status (2026-11-10): D01–D05 merged; D06-01 Bat/Shovel accepted; D06-02 Gun implemented in PR #32, awaiting squash merge.** D06-02 passed **974 pinned Godot assertions (0 failures)**, native screenshot/first-person muzzle checks and real WebGL2 Full E2E ([run #42809417312](https://github.com/bravado/ACTION-5/actions/runs/42809417312)). **The owner confirmed manual five-view visual testing passed on 2026-11-10.** The architecture review found no remaining P1/P2 merge blockers; D07 AI is next. The PR and issue remain open until an explicit merge decision.

ACTION-5 is a planned open-source framework for creating action games that share the **same 3D characters, animations, physics, combat, weapons, AI and level geometry** across several styles of play. The player switches between views at runtime without changing maps, recreating the character, or resetting combat.

It targets side-scrolling beat'em ups, arcade brawlers, isometric dungeon crawlers, third-person action games, first-person dungeon combat, and classic NES-style top-down action.

**D06 demo controls:** E picks up the nearest Bat/Shovel (or the Pistol when close to its separate pickup), Q swaps between carried weapons, G drops the equipped item. **Bat:** left click/J performs a vertical swing and right click/K performs a separate horizontal strike. **Shovel:** left click/J swings and right click/K still kicks. Each attack claims only its configured `input_action`; unassigned inputs retain Punch/Kick. There is no separate swing button. Bat and Shovel pickups are near spawn; the Pistol pickup is farther southeast so existing two-weapon demos stay deterministic. Pistol left click/J fires, R reloads. A second, independently configured heavy-pistol scene uses T for reload. The physical muzzle controls obstruction, never the F4 camera model. Tracers are temporary visual-only effects parented to the world scene, so a shot in flight survives destruction of the weapon. See [equipment authoring](docs/equipment.md) for the extension contract and known limitations.

## Five perspectives

| Key (native and Web) | Mode | Camera and controls | Inspiration |
|---|---|---|---|
| **1** | Side-scroller | True horizontal orthographic X/Y side view; X movement with current Z lane locked | *Mario*, *Altered Beast* |
| **2** | Beat'em up | Close, shallow-angle orthographic framing and X/Z ground movement | *Streets of Rage*, *Golden Axe* |
| **3** | Isometric / over-the-shoulder | **One adjustable orthographic profile:** zoom out for a tilted dungeon view, zoom in for close shoulder framing; mouse orbit and camera-relative movement | Dungeon crawlers and third-person action |
| **4** | First person | Eye-level perspective, mouse look, crosshair aiming | First-person action |
| **5** | Retro top-down | True overhead orthographic, configurable four-/eight-way facing and attacks | *The Legend of Zelda*, *Commando* |

All modes use **one shared 3D scene and authoritative player actor**. Camera changes never recreate actors, reset combat or change world physics. Isometric and over-the-shoulder are **two zoom levels of mode 3**, not two selectable modes.

**Camera tuning:** Press **C** or click **Camera Settings** to adjust each mode live. In **mode 3**, zoom from wide isometric to close over-the-shoulder and customize the wide/close camera distances, viewing angles, shoulder offset and look-ahead. User overrides persist by stable profile ID; existing five-mode settings are migrated automatically.

**Camera controls:** Press **1–5** on native or Web. F1–F5 are optional alternate bindings (browsers can reserve function keys). Five clickable mode buttons and gamepad shoulder-button cycling are also available. See [camera documentation](docs/cameras.md).

## What ACTION-5 will provide

- **Reusable addon:** a self-contained `addons/action5/` module with scene components, view profiles, typed GDScript interfaces and events.
- **Cameras and input:** five view profiles, transitions, follow/bounds/occlusion policies, remappable keyboard and controller input, and camera-independent movement intents.
- **Animated 3D characters:** glTF/GLB imports, `AnimationTree`, skeleton/socket mappings, local first-person presentation.
- **Combat:** attack timelines in fixed physics ticks; collision shapes for hitboxes/hurtboxes; damage, stun, knockback, hit filtering and debugging tools.
- **Weapons:** unarmed punches/kicks, bat, shovel and gun; equipment sockets, pickup/drop, melee sweeps, ammo/reload and correct muzzle-to-target occlusion.
- **Enemies and world:** basic combat AI, navigation, doors, pickups, triggers, destructible props, arena and dungeon environments.
- **Reference game:** a playable demonstration with all five perspectives, melee and ranged enemies, and a retro top-down encounter.
- **Tools and delivery:** debugging overlays, resource validation, automated tests, browser export and Windows/Linux/macOS native builds.

### Deliberately not in the initial scope

Online multiplayer, rollback netcode, full RPG inventory/economy, procedural dungeon generation, advanced animation tooling, mobile touch controls and console ports. These can be future extensions; they are not prerequisites for the core framework.

## Design principles

1. **One world, no mode-specific game forks.** All cameras share world transforms, hit resolution, AI and character health.
2. **Controls do not own combat.** An input adapter produces movement, aim and action intents. Actor and weapon systems do not read raw physical keys.
3. **Physics for bodies, authored hitboxes for attacks.** Do not use animated mesh-to-mesh collision to decide punch, kick or weapon damage.
4. **Configurable views and moves.** Prefer Godot `Resource` definitions, composable nodes and stable public contracts to monolithic controllers.
5. **Browser compatibility from day one.** Target Godot 4's Compatibility renderer and GDScript; verify exports throughout development.
6. **Real verification.** Every deliverable has a playable scene, automated or manual acceptance criteria and reproducible evidence.

## Technology

| Component | Plan |
|---|---|
| Engine | **Godot 4.7.2 stable** (version pinned for development) |
| Language | **Typed GDScript** |
| 3D rendering | Godot **Compatibility** renderer |
| Character assets | **glTF 2.0 / GLB** models and skeletal animations |
| Physics | Godot 3D physics, `CharacterBody3D`, `Area3D`, shape/ray queries |
| Timing | **60 Hz** fixed physics tick for combat scheduling |
| Targets | Browsers via WebAssembly/WebGL 2, and Linux/Windows/macOS executables |
| Planned license | **MIT** for framework code; game/demo assets licensed separately |

A fixed combat tick does **not** imply deterministic rollback/network simulation.

## Planned project layout

```text
addons/action5/       # reusable engine-independent-of-demo addon
demo/                 # playable five-view reference game
tests/                # unit, integration, scenario and browser smoke tests
docs/                 # API, authoring, architecture, assets, export guidance
.github/workflows/    # continuous integration and roadmap automation
PLAN.md               # authoritative product specification
AGENTS.md             # coding agent rules and acceptance workflow
```

The Godot 4.7.2 project contains a **five-camera playable demonstration** of the same 3D arena and actor. Switch camera perspectives with **1–5**, then walk with WASD or arrow keys. D03 uses a reusable locomotion component and InputMap adapter rather than raw demo key polling. Press Space to jump, Shift to run and Alt to dodge. Use **left click / J** (Punch when unarmed, Bat/Shovel swing when equipped) and **right click / K** (Bat horizontal strike, otherwise Kick unless assigned by equipment); gamepad X/Y use the same mapping. F4 has separate camera-space pose assets for correctly framed first-person arms and kicks, while F1/F2/F3/F5 use three dedicated skinned world weapon animations (Bat vertical, Bat horizontal, Shovel overhead) and all views retain one gameplay actor. See [combat and attack authoring](docs/combat.md), [development](docs/development.md), **[how to add a movement](docs/adding-moves.md)**, [animation/model authoring](docs/animation.md), and [camera system](docs/cameras.md) documentation.

## Roadmap

| Release | Deliverables | Exit goal |
|---|---|---|
| **[v0.1 — Foundation](https://github.com/bravado/ACTION-5/milestone/1)** | D01–D03 · 8 issues | Godot project, CI, all five cameras and controls, moving actor; Web and native smoke builds |
| **[v0.2 — Combat](https://github.com/bravado/ACTION-5/milestone/2)** | D04–D07 · 7 issues | Animated character, attack system, bat/shovel/gun, enemy AI |
| **[v0.3 — Gameplay & Tooling](https://github.com/bravado/ACTION-5/milestone/3)** | D08–D10 · 4 issues | Arena/dungeon interactions, playable five-mode demo, debugging and authoring tools |
| **[v1.0 — Distribution](https://github.com/bravado/ACTION-5/milestone/4)** | D11–D12 · 2 issues | Full regression/export matrix, installable addon, documentation and release artifacts |

See [the full product and implementation plan](PLAN.md) for D01–D12, detailed requirements and acceptance cases VT-01–VT-23. See [agent instructions](AGENTS.md) before implementing changes.

All **four GitHub milestones** and **21 DXX-YY implementation issues** are now created and assigned. See [the full issue backlog](https://github.com/bravado/ACTION-5/issues). Each issue has a scope, acceptance criteria, dependencies and test evidence requirements; changes should be reviewed as independently testable pull requests.

The milestone mapping is maintained by [the idempotent roadmap synchronization workflow](.github/workflows/sync-roadmap.yml) and [its script](tools/sync_roadmap.py). It runs when the plan or workflow changes and can be started manually using GitHub Actions. If the backlog gains new issue IDs, create those issues first; the synchronizer will reject an incomplete set rather than silently assign only some of them.

## Working on ACTION-5

Development is incremental. **D01–D05 are merged** (D05 via squash-merged PR #28); the crouch movement example is also merged. **D06-01 Bat/Shovel equipment** is complete in approved PR #31, with authored world/F4 weapon animations, independent attacks, and lifecycle/fast-melee hardening; 908 headless assertions, real WebGL2 Full E2E and manual visual acceptance passed. **D06-02 Gun** is implemented in [PR #32](https://github.com/bravado/ACTION-5/pull/32) and has passed **974/974 Godot assertions**, native screenshots, real WebGL2 Full E2E ([CI #42809417312](https://github.com/bravado/ACTION-5/actions/runs/42809417312)), and the owner's manual F1–F5 visual review. Issue #14 stays open until squash merge. **D07 AI** is next. Neither is part of PR #31. Follow [AGENTS.md](AGENTS.md), [the movement authoring guide](docs/adding-moves.md) and the review gates in PLAN.md.

Run the current five-view demo with **Godot 4.7.2** and GNU Make. All commands automatically import resources and refresh Godot's generated script registry before launching, testing, or exporting:

```bash
make run          # Import, run (1–5 view; WASD move; Space jump; Shift run; Alt dodge)
make test         # Import, then run headless Godot tests
make check        # Same asset + Godot checks as PR CI (requires Node.js)
make editor       # Import, then open the Godot editor
make build        # Import and export Linux + Web
```

Or prepare the project once explicitly with `make import`. For other Godot executable names use `make run GODOT=godot4`. The `.godot/` cache stays local and is not committed. See `make help` for all targets.

Normal PR updates run `CI / Checks` (the same suite as `make check`), while pushes to `master` run `CI / Full E2E` and then publish the validated Web export via `CI / Deploy Pages`. To request full E2E on a PR, put `[full-e2e]` in its latest commit message (subject or body). You can also choose the full E2E option in the workflow's manual dispatch. For details, see [docs/development.md](docs/development.md).

## License and assets

The planned framework license is **MIT**. The license file and the attribution inventory are D01 deliverables. All third-party 3D models, animations, textures and audio must carry compatible licenses and verifiable provenance. References to existing games describe gameplay styles; ACTION-5 does not distribute their characters, artwork or proprietary assets.

**D06-02 gun tracer:** The Pistol fires an optional visible, non-colliding gold projectile trail; the Heavy Pistol fixture uses a blue trail. Their impact point comes from the authoritative physical world-muzzle hitscan. In F4 only, the visual tracer starts at the camera-local `Grip/VisualMuzzle` so it visibly exits the on-screen barrel; other views and camera-free NPCs use the physical muzzle. No visual effect controls damage. Edit the per-gun ProjectileVisual scene to customize or remove the presenter to disable; damage is still immediate.

**Developer extension:** [ADR-0006](docs/adr/0006-authoritative-gun-and-projectile-visuals.md) documents the world-target port, camera-free NPC target provider, optional tracer, reload visual ownership and D07–D12 boundaries. No runtime code under `addons/action5/` imports `demo/`.


### D07 enemy encounter (in review)

Run `make import && godot --path . res://demo/ai/encounter.tscn` to
inspect a melee Bat enemy and ranged Gun enemy navigating an opaque
center obstacle. WASD moves the player; 1–5 switch the same five camera
profiles without restarting either enemy. See [AI authoring](docs/ai.md).
