# ACTION-5

**A six-perspective 3D action framework for Godot.** One world, one character, six ways to play.

> **Project status: D01 foundation implementation in progress.** The repository includes a real Godot project, runnable primitive-character demo, basic addon skeleton, tests and a Linux/Web smoke export pipeline. The production six-view system, combat engine and complete game remain future deliverables.

ACTION-5 is a planned open-source framework for creating action games that share the **same 3D characters, animations, physics, combat, weapons, AI and level geometry** across several styles of play. The player switches between views at runtime without changing maps, recreating the character, or resetting combat.

It targets side-scrolling beat'em ups, arcade brawlers, isometric dungeon crawlers, third-person action games, first-person dungeon combat, and classic NES-style top-down action.

## Six perspectives

| Key (desktop) | Mode | Camera and controls | Inspiration |
|---|---|---|---|
| **F1** | Side | Fixed orthographic; horizontal X movement, current depth lane locked | Classic 2D side-scroller |
| **F2** | Beat'em up | Fixed angled camera; free ground-plane X/Z movement | Arcade beat'em ups |
| **F3** | Isometric | Tilted orthographic camera; camera/screen-relative ground movement | Dungeon action RPGs |
| **F4** | Third person | Following perspective camera; mouse/right-stick look | Third-person action |
| **F5** | First person | Eye-level perspective; mouse look and crosshair aiming | First-person dungeon action |
| **F6** | Retro top-down | True overhead orthographic; configurable four-/eight-way movement, facing and aiming | *The Legend of Zelda*, *Commando* |

All modes use **one shared 3D scene and authoritative player actor**. Switching views changes the camera, input-to-movement mapping, aiming policy and local visual presentation—not the world simulation or combat state.

**Browser controls:** Some function keys are reserved by browsers (especially F1 and F5), and Ctrl+number changes browser tabs. The intended web interface therefore includes **remappable number-row 1–6 shortcuts**, an always-accessible **six-mode view selector**, and controller cycling. Exact mappings will be finalized and tested during implementation.

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

The D01 project can already be opened in Godot 4.7.2. Its one diagnostic camera, procedural arena and keyboard movement are **not** the six finished view modes. See [development and verification instructions](docs/development.md) for actual commands and CI evidence.

## Roadmap

| Release | Deliverables | Exit goal |
|---|---|---|
| **[v0.1 — Foundation](https://github.com/objectivebot/ACTION-5/milestone/1)** | D01–D03 · 8 issues | Godot project, CI, all six cameras and controls, moving actor; Web and native smoke builds |
| **[v0.2 — Combat](https://github.com/objectivebot/ACTION-5/milestone/2)** | D04–D07 · 7 issues | Animated character, attack system, bat/shovel/gun, enemy AI |
| **[v0.3 — Gameplay & Tooling](https://github.com/objectivebot/ACTION-5/milestone/3)** | D08–D10 · 4 issues | Arena/dungeon interactions, playable six-mode demo, debugging and authoring tools |
| **[v1.0 — Distribution](https://github.com/objectivebot/ACTION-5/milestone/4)** | D11–D12 · 2 issues | Full regression/export matrix, installable addon, documentation and release artifacts |

See [the full product and implementation plan](PLAN.md) for D01–D12, detailed requirements and acceptance cases VT-01–VT-23. See [agent instructions](AGENTS.md) before implementing changes.

All **four GitHub milestones** and **21 DXX-YY implementation issues** are now created and assigned. See [the full issue backlog](https://github.com/objectivebot/ACTION-5/issues). Each issue has a scope, acceptance criteria, dependencies and test evidence requirements; changes should be reviewed as independently testable pull requests.

The milestone mapping is maintained by [the idempotent roadmap synchronization workflow](.github/workflows/sync-roadmap.yml) and [its script](tools/sync_roadmap.py). It runs when the plan or workflow changes and can be started manually using GitHub Actions. If the backlog gains new issue IDs, create those issues first; the synchronizer will reject an incomplete set rather than silently assign only some of them.

## Working on ACTION-5

This project is intended for incremental development—**start with D01**, not a complete speculative engine. Follow [AGENTS.md](AGENTS.md). The first meaningful checkpoint is a single actor that can move and switch between **all six views** in a browser and a desktop build.

To run the current D01 diagnostic scene with the pinned Godot editor:\n\n```bash\ngodot --path .\ngodot --headless --path . --import\ngodot --headless --path . --script res://tests/run_all.gd\n```\n\nFor exported builds, matching template installation and CI logs/screenshots, consult [docs/development.md](docs/development.md). **Successful execution is verified by GitHub Actions; commands here do not claim a local run without evidence.**

## License and assets

The planned framework license is **MIT**. The license file and the attribution inventory are D01 deliverables. All third-party 3D models, animations, textures and audio must carry compatible licenses and verifiable provenance. References to existing games describe gameplay styles; ACTION-5 does not distribute their characters, artwork or proprietary assets.
