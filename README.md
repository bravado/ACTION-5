# ACTION-5

**A six-perspective 3D action framework for Godot.** One world, one character, six ways to play.

> **Project status: D02 six-camera foundation under review.** A runnable Godot 4.7.2 project, six configurable camera profiles, native/Web smoke builds and tests exist. Generalized movement, weapons, combat and finished game content remain future deliverables.

ACTION-5 is a planned open-source framework for creating action games that share the **same 3D characters, animations, physics, combat, weapons, AI and level geometry** across several styles of play. The player switches between views at runtime without changing maps, recreating the character, or resetting combat.

It targets side-scrolling beat'em ups, arcade brawlers, isometric dungeon crawlers, third-person action games, first-person dungeon combat, and classic NES-style top-down action.

## Six perspectives

| Key (native and Web) | Mode | Camera and controls | Inspiration |
|---|---|---|---|
| **1** | Side-scroller | True horizontal orthographic camera (Mario / Altered Beast), X movement, fixed depth lane | Classic 2D platform/action scrolling |
| **2** | Beat'em up | Close, shallow-angle orthographic framing, X/Z movement | *Streets of Rage*, *Golden Axe* |
| **3** | Isometric | Tilted orthographic camera; camera/screen-relative ground movement | Dungeon action RPGs |
| **4** | Third person | Close over-the-shoulder follow, adjustable height and look-ahead | Third-person action |
| **5** | First person | Eye-level perspective; mouse look and crosshair aiming | First-person dungeon action |
| **6** | Retro top-down | True overhead orthographic; configurable four-/eight-way movement, facing and aiming | *The Legend of Zelda*, *Commando* |

All modes use **one shared 3D scene and authoritative player actor**. Switching views changes the camera, input-to-movement mapping, aiming policy and local visual presentation—not the world simulation or combat state.

**Camera tuning:** Click **Camera Settings [C]** or press **C** to adjust the active view's zoom, height and follow characteristics. Third-person includes shoulder offset, pitch and look-ahead. Settings persist per view between sessions; **Reset this camera** restores the shipped defaults. See [camera system documentation](docs/cameras.md).

**Camera controls:** Press **1–6** on the number row in native or Web builds to switch cameras instantly. F1–F6 are optional alternate bindings (browser function keys can be reserved, especially F5). The demo also offers six on-screen view buttons and gamepad shoulder-button cycling. See [camera system documentation](docs/cameras.md).

## What ACTION-5 will provide

- **Reusable addon:** a self-contained `addons/action5/` module with scene components, view profiles, typed GDScript interfaces and events.
- **Cameras and input:** six view profiles, transitions, follow/bounds/occlusion policies, remappable keyboard and controller input, and camera-independent movement intents.
- **Animated 3D characters:** glTF/GLB imports, `AnimationTree`, skeleton/socket mappings, local first-person presentation.
- **Combat:** attack timelines in fixed physics ticks; collision shapes for hitboxes/hurtboxes; damage, stun, knockback, hit filtering and debugging tools.
- **Weapons:** unarmed punches/kicks, bat, shovel and gun; equipment sockets, pickup/drop, melee sweeps, ammo/reload and correct muzzle-to-target occlusion.
- **Enemies and world:** basic combat AI, navigation, doors, pickups, triggers, destructible props, arena and dungeon environments.
- **Reference game:** a playable demonstration with all six perspectives, melee and ranged enemies, and a retro top-down encounter.
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
demo/                 # playable six-view reference game
tests/                # unit, integration, scenario and browser smoke tests
docs/                 # API, authoring, architecture, assets, export guidance
.github/workflows/    # continuous integration and roadmap automation
PLAN.md               # authoritative product specification
AGENTS.md             # coding agent rules and acceptance workflow
```

The Godot 4.7.2 project contains a **six-camera playable demonstration** of the same 3D arena and actor. Switch camera perspectives with **1–6**, then walk with WASD or arrow keys. The temporary movement adapter will be replaced by a reusable locomotion component in D03. See [development](docs/development.md) and [camera system](docs/cameras.md) documentation.

## Roadmap

| Release | Deliverables | Exit goal |
|---|---|---|
| **[v0.1 — Foundation](https://github.com/bravado/ACTION-5/milestone/1)** | D01–D03 · 8 issues | Godot project, CI, all six cameras and controls, moving actor; Web and native smoke builds |
| **[v0.2 — Combat](https://github.com/bravado/ACTION-5/milestone/2)** | D04–D07 · 7 issues | Animated character, attack system, bat/shovel/gun, enemy AI |
| **[v0.3 — Gameplay & Tooling](https://github.com/bravado/ACTION-5/milestone/3)** | D08–D10 · 4 issues | Arena/dungeon interactions, playable six-mode demo, debugging and authoring tools |
| **[v1.0 — Distribution](https://github.com/bravado/ACTION-5/milestone/4)** | D11–D12 · 2 issues | Full regression/export matrix, installable addon, documentation and release artifacts |

See [the full product and implementation plan](PLAN.md) for D01–D12, detailed requirements and acceptance cases VT-01–VT-23. See [agent instructions](AGENTS.md) before implementing changes.

All **four GitHub milestones** and **21 DXX-YY implementation issues** are now created and assigned. See [the full issue backlog](https://github.com/bravado/ACTION-5/issues). Each issue has a scope, acceptance criteria, dependencies and test evidence requirements; changes should be reviewed as independently testable pull requests.

The milestone mapping is maintained by [the idempotent roadmap synchronization workflow](.github/workflows/sync-roadmap.yml) and [its script](tools/sync_roadmap.py). It runs when the plan or workflow changes and can be started manually using GitHub Actions. If the backlog gains new issue IDs, create those issues first; the synchronizer will reject an incomplete set rather than silently assign only some of them.

## Working on ACTION-5

Development is incremental. **D01 is merged; D02 implements the six-camera foundation; D03 is next after D02 approval.** Follow [AGENTS.md](AGENTS.md) and the review gates in PLAN.md.

Run the current six-view demo with **Godot 4.7.2** and GNU Make. All commands automatically import resources and refresh Godot's generated script registry before launching, testing, or exporting:

```bash
make run          # Import, then launch the game (press 1–6 to switch cameras)
make test         # Import, then run headless tests
make editor       # Import, then open the Godot editor
make build        # Import and export Linux + Web
```

Or prepare the project once explicitly with `make import`. For other Godot executable names use `make run GODOT=godot4`. The `.godot/` cache stays local and is not committed. See `make help` for all targets.

For export template installation, browser/native builds, screenshots and CI logs, see [docs/development.md](docs/development.md).

## License and assets

The planned framework license is **MIT**. The license file and the attribution inventory are D01 deliverables. All third-party 3D models, animations, textures and audio must carry compatible licenses and verifiable provenance. References to existing games describe gameplay styles; ACTION-5 does not distribute their characters, artwork or proprietary assets.
