# ACTION-5

**A five-perspective 3D action framework for Godot.** One world, one character, five ways to play.

> **Project status (November 2026): D01–D09-02 implemented.** The five-view reference demo includes persistent arena/dungeon traversal, doors and portals, AI encounters, Sword/Bat/Shovel/Gun equipment, four-way Sword/eight-way Gun retro directional combat, F5 independent movement/aim and a responsive HUD. Pinned Godot tests and native/WebGL2 smoke have passed on the D09 implementation; prolonged owner exploratory acceptance remains a separate release gate. **Next: D10 diagnostics and editor tooling**, then D11–D12 packaging/distribution. Actor, Combat, Equipment, Animation and Camera cores remain independent of demo composition.

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

**Camera tuning:** Press **C** (or use the Camera Settings button inside **F6 Help**) to adjust each mode live. In **mode 3**, zoom from wide isometric to close over-the-shoulder and customize the wide/close camera distances, viewing angles, shoulder offset and look-ahead. User overrides persist by stable profile ID; existing five-mode settings are migrated automatically.

**Camera controls:** Press **1–5** on native or Web. F1–F5 are optional alternate bindings (browsers can reserve function keys). Five clickable mode buttons are available in **F6 Help** instead of covering the gameplay screen; gamepad shoulder-button cycling is also available. See [camera documentation](docs/cameras.md).

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

The Godot 4.7.2 project contains a **five-camera playable demonstration** of the same 3D arena and actor. Switch camera perspectives with **1–5**, using the view-specific movement and attack mappings below. D03 uses a reusable locomotion component and InputMap adapter rather than raw demo key polling. Press Space to jump, Shift to run and Alt to dodge. Use **left click / J** (Punch when unarmed, Bat/Shovel swing when equipped) and **right click / K** (Bat horizontal strike, otherwise Kick unless assigned by equipment); gamepad X/Y use the same mapping. F4 has separate camera-space pose assets for correctly framed first-person arms and kicks, while F1/F2/F3/F5 use three dedicated skinned world weapon animations (Bat vertical, Bat horizontal, Shovel overhead) and all views retain one gameplay actor. See [combat and attack authoring](docs/combat.md), [development](docs/development.md), **[how to add a movement](docs/adding-moves.md)**, [animation/model authoring](docs/animation.md), and [camera system](docs/cameras.md) documentation.

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

Development is incremental. **D01–D09-02 and the independent crouch example are implemented.** The core now supports Bat/Shovel and two independently configured Guns, a camera-independent enemy encounter, physical same-world door traversal, inventory preservation and explicit cached remote-scene travel. New features should reuse the existing actor, movement, animation, combat, equipment, AI and camera ports rather than introducing parallel subsystems. **Next:** D10 tools, then D11–D12 release work. Follow [AGENTS.md](AGENTS.md), [AI authoring](docs/ai.md), [the movement authoring guide](docs/adding-moves.md) and [PLAN.md](PLAN.md).


Run the current five-view demo with **Godot 4.7.2** and GNU Make. All commands automatically import resources and refresh Godot's generated script registry before launching, testing, or exporting:

```bash
make run          # Import and run; 1–5 select view; HUD shows view-specific input
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


### D07 enemy AI in the shared dungeon

Run `make import && godot --path . res://demo/main.tscn`, then press
**E at the east-side gate** to open its panel and **walk right** into the
adjoining dungeon. To return, walk left through that **same doorway**.
No teleport or second scene is involved. The dungeon is an
instance of `demo/world/encounter_sector.tscn`, not a second game scene.
It hosts the D07 Bat melee and Gun ranged enemies navigating an opaque
obstacle. LMB/J and RMB/K issue normal combat actions, 1–5 switch the
camera, Q swaps inventory weapons and G drops one. The same player and
equipment persist on the return trip. Both NPCs retain their shared
skeletal presentation adapters and animated weapon sockets.

`tests/d07_suite.gd` runs the actual embedded dungeon inside
`demo/main.tscn` for camera-free AI, weapons, attack animations, real
navigation and combat input regressions. The obsolete standalone
`demo/ai/encounter.tscn` and its duplicate player/camera, old
scene-reload handoff, and superseded transition tests have been removed.
New NPC regression scenarios must extend the **same dungeon scene**
without authoring a second encounter map. See
[AI authoring](docs/ai.md).

### D08 connected persistent world

`demo/main.tscn` contains the arena (X=-14..14) and the instanced
`demo/world/encounter_sector.tscn` dungeon (X=14..38), on the
**same floor elevation and global axes**. The former ten-unit void and
dungeon's far-side return door are removed. A single physical gate at
**X=14, Z=0** joins both floors; its split flanking wall segments
and overlapping floor slab form a real passable doorway. **E opens or
closes the gate; walking across switches the active sector**, without
replacing/teleporting the original player. The frame and two-sided
signage remain visible from both rooms.

Health, Combat, Equipment and enemy nodes retain their live instances
on normal visits. A world-local `SectorCameraBounds` now configures
one **continuous** F1/F2/F5 camera clamp spanning both areas, so there
is no camera snap or WASD orientation change when crossing the wall.
The dungeon now uses a **full-screen 18%-opacity blue ceiling tint**
in external views (1/2/3/5), removed in first person (4). Its
CanvasLayer covers the entire viewport below the HUD instead of drawing
a horizontal 3D roof, which previously tinted only the top half of
side/arcade cameras. The overhead roof still has its **physical
ceiling collider**, but no visual mesh/shadows; two subdued interior
lights complement the shared world sun. D08 regression tests cover fresh-entry lifecycle, continuous
camera behavior and physical door state. Manual F1–F5 and portal
visual acceptance was completed on November 11, 2026; native and
WebGL2 exports remain subject to the standard CI gates.

### F1 shared combat lane

Switching to side-scroller (view 1) aligns the player and living
enemies on a single collision-tested world-Z plane so punches and kicks
can reach enemies that spawned at different beat'em-up depths.
`SideLaneController` composes the existing Locomotion lock; the
connected world and each cached remote room use configurable local Z
(default 0). Freshly spawned or recreated enemies join that lane
automatically. Temporary enemy-to-enemy collision exceptions prevent
same-line body blocking and remain only until opponents separate
after switching back to free 3D movement. Walls, doors, player collision,
health and aggro remain authoritative.

### Two travel connections

**Connected gate:** Walk right from the initial arena to **X=14, Z=0**.
Press **E** at either **visible gold handle** on the teal door to toggle
its real physical barrier; then walk through to the dungeon. There
are **no text labels** on connected doors (no duplicated headings
over the entrance). The handles on both faces are aligned with the
actual interaction points and collision panel. In beat'em-up view 2
the camera now subtly turns **opposite lateral movement** to reveal
X-facing walls instead of presenting the doorway edge-on, retaining
its last tilt at rest. WASD stays world-aligned. With the gate **closed**, the other room is hidden
from rendering in all five cameras. The dungeon's floor and physics
are independently preloaded, but enemies **do not acquire the player**
through that closed door. Once they discover the player through an
opened gate, they retain aggro if it shuts again; collision, weapon
sight and the navigation link remain authoritative, so they cannot
shoot or walk through a closed panel.

**Remote portal:** The **purple portal** at **X=-11.5, Z=0** is a
different component. Unlike physical doors, it has an **optional
destination label** (configure `show_label` or omit its Label3D).
Press **E** to load
`demo/world/remote_chamber.tscn` at a detached location, with **the
same live player, camera, inventory and combat components**. In that
chamber, walk toward the **RETURN TO ARENA [E]** portal to go back.
Remote environments are cached and CPU-paused when absent; there is
no second Player/ViewManager. `LocationPortal` can alternatively
target any authored Marker3D in the existing world, without a new
PackedScene. Explicit remote travel may reframe the camera; adjacent
door crossing never changes camera bounds.

Enemies that **already crossed into the arena** remain visible
and continue to fight on the arena side even if the door closes
behind them. Only the opposite room's static geometry is hidden;
the gate still blocks sight and movement for enemies on its other
side.

The generic `Action5Interactor` accepts optional near-side
`get_interaction_point(actor)` handles for large opaque doors. AI
`Action5AITargetSensor` has an optional
`allows_acquisition(observer, candidate)` filter; the example
`DoorAcquisitionFilter` is plugged in by the demo WorldSession, not
hardcoded into AI/movement/combat cores. Tests:
`tests/d08_connections_suite.gd` (real E input, visibility, aggro,
remote cached visits), `tests/d08_world_suite.gd` (inventory, fresh
entry and door physics), and `tests/d08_camera_sector_suite.gd`.

**Near-wall readability:** In views 1/2/3/5, the surrounding
**outer walls**, especially the lower/front walls, progressively
become translucent as the player approaches (from 3.8 to 1.1 units,
minimum 20% opacity); moving away restores opacity. First person
keeps solid walls. This is a **visual-only** effect: collision,
enemy sight and combat remain blocked. Inner walls, props and
the door panel never fade. The F2 camera's lateral peek has also
been reduced to **6°**, adjustable per profile in Camera Settings.
The optional outer-wall presenter now hides foreground perimeter meshes
in **all three** F1 areas (arena, dungeon and remote chamber), leaving
rear scenery and solid collision intact. F4 first-person and F5
top-down walls remain opaque; proximity opacity only applies to the
other eligible views. Neither the door frame nor its collider disappears.


## D09-01 — Playable reference scenario

`make run` starts the same persistent arena/dungeon and player used by D08.
Follow the HUD objective, use the physical east gate, defeat the dungeon
enemies, then interact with the unlocked **EXIT** marker to show the victory
screen. **Play Again** restarts the reference scene; the separate death
overlay still offers **Restart**. A remote portal demonstrates cached
location travel. The HUD observes public ViewManager, Health, Combat,
MovementController, Equipment and weapon state; it shows active view,
HP, attack, equipment/ammo/reload and commands, and obtains help labels
from InputMap, active view-control resources and AttackDefinitions.

### Default controls by view

| View | W / ↑ | S / ↓ | A / D | ← / → |
|---|---|---|---|---|
| 1 — Side-scroller | Jump | Hold crouch | Move left/right | Move left/right |
| 2 — Beat'em Up | Move up stage | Move down stage | Move left/right | Move left/right |
| 3 — Isometric/shoulder | Forward | Backward | Move left/right | Move left/right |
| 4 — First person | Forward | Backward | Strafe | Turn |
| 5 — Retro top-down | Move up | Move down | Move left/right | Move left/right |

**Space** also jumps in every view; **Ctrl** toggles crouch and Shift
runs. F1 S/Down holds crouch, including crouch-walk while moving;
F4 arrow turning defaults to 135°/s while A/D remain strafing. The
`Action5ViewControlProfile` resources in
`addons/action5/input/profiles/` map globally remappable InputMap
actions onto view-local roles. New view-specific bindings require
a new/edited profile resource, not branches in Actor, Combat or Camera.
See [locomotion](docs/locomotion.md) and [cameras](docs/cameras.md).

### Gun targeting and physical correctness

F4 selects its target through the screen-center Camera3D ray.
F1's orthographic center ray points through Z depth, so the F1 aim
provider instead selects a horizontal target along the shared X/Y
combat lane at configurable **1.25-unit upper-torso height**
(`Action5ViewAimTargetProvider.side_center_height`). The
**world-space muzzle** still casts the authoritative collision ray;
walls block damage and the tracer starts at the actual muzzle
(or the F4 visual-only grip). Camera-free NPCs use their independent
world-target provider. See [equipment](docs/equipment.md) and
`tests/d09_side_aim_suite.gd`.

### Verification

Pinned Godot 4.7.2 headless suite passed **1,275 assertions, zero
failures** in [CI / Checks](https://github.com/bravado/ACTION-5/actions/runs/43135267448).
Native Linux export/render capture and real WebGL2 browser startup passed
in [CI / Full E2E](https://github.com/bravado/ACTION-5/actions/runs/43135511963).
The side-view trajectory was visually accepted by the project owner.
A separate prolonged manual playthrough/focus-loss exploration is
not covered by automated evidence. D09-02 adds the independent four-way/
eight-way retro behavior and scrolling described below.


### D09-02 — Retro overhead combat (view 5)

View **5** keeps the same actor, equipment, collision world and combat clock as views 1–4. The starting arena and the connected dungeon both have a pick-up **Sword**: interact with **E**, attack with configured **LMB/J**, and swap equipment with **Q**. Its D05 melee hitbox uses **four cardinal** headings in view 5 but continuous input heading in view 3. The existing Pistol uses **eight directions** in view 5 and continuous heading in other views. In view 5, **WASD moves** and **arrow keys aim independently** (or use left stick/right stick); view 1–4 controls are unchanged. The camera follows the player through the connected arena/dungeon without teleporting or creating another world. First-person sword presentation is optional and visual-only. Pickups in the dungeon reuse the D08 scene persistence policy.

To configure another weapon without editing Actor, CombatController, MovementController, AnimationPresenter or Gun: create an `Action5ViewFacingPolicy` resource with `view_mode = 4` and `sector_count = 4`, `8` or another count from 2–32, then add it to `Action5WeaponDefinition.view_facing_policies`. Set its attack's `facing_sectors = Free` so the rule does not affect other views. Wire one `Action5EquippedViewFacing` beside the actor's Equipment component and pass its path to ActorInputAdapter, CombatInputAdapter and ViewAimTargetProvider. On unsupported or unspecified views the fallback is the original free heading. The same policy instance is read on demand, with no cached weapon identity or mutated attack definitions. View-specific direction affects aim selection and visible heading only: the world muzzle still decides hits, obstruction and ammo costs. An actor without the policy retains existing behavior.

Regression: `make check` runs `tests/d09_retro_suite.gd` with the shared headless runner; full Linux/WebGL2 smoke is opt-in via the repository's Full E2E workflow. A manual complete encounter and the separate 20-minute exploratory acceptance still require owner verification.

The arena light switch is the labelled **LIGHT SWITCH [E]** console on the southwest side of the starting map, near the low step (world X = -5.5, Z = 4.3). It has a permanent pedestal and bright amber **OFF** / green **ON** indicator even when its room light is disabled. Use E within interaction distance to toggle the room light; the separate detached-room portal remains near the western wall at X = -11.5, Z = 0. Neither prop should compete for the same E press.

**Top-down Gun aiming (D09-02):** In view 5, the visible tracer starts at the **real gun muzzle**. The aim provider selects the first target on the player's *forward horizontal centerline* (or the centerline's far point when unobstructed); the existing Gun then fires its physical muzzle ray toward that point, respecting muzzle-side obstruction. This aligns projectiles with targets in front of the player without spawning them inside the body. F4 still uses the camera-local barrel tip for tracer visuals; other exterior views and camera-free guns still use the physical muzzle. Gun damage, ammunition and the combat clock are unchanged.

**First-person Gun reload (view 4):** Press **R** with the Pistol equipped after firing at least one round (Heavy Pistol uses **T**). The gripped Gun and arm should lower/tilt during the per-weapon reload countdown, then return to the idle grip as ammunition refills. The shared `gun_reload_grip.tres` animation must contain valid pose keys spanning **0.0 to 1.0**; an endpoint at 0.8 silently invalidates its pose sampling. This F4 animation is presentation-only; ammo, command timing and cancellation stay with the Gun, and both Gun variants reuse the same authored reload profile.

**D09-02 F1 arena-to-exit traversal:** The arena Gun pickup is authored at `Z = 1.0`, matching the Bat/Shovel row so a player locked to the F1 `Z = 0` lane can collect it with **E**. The dungeon's central Obstacle is **1.1 m tall** (matching mesh and collision, resting on the floor), permitting the normal grounded jump and horizontal movement in F1 to cross it and reach the physical EXIT. No view-specific collision bypass, teleport or movement tuning is required. The reference suite performs a real F1 Gun pickup and a physics-driven running jump to the exit.


### D09-03 — Iron Reliquary HUD (PR #38, in progress)

The reference HUD uses the same two bottom-corner panels in F1–F5: **health on the left**, **equipped weapon, ammo/actions and smaller next-item name on the right**. The center stays clear; optional icons come from weapon definition resources. **Q** swaps to the next carried item with the normal Equipment controller (the small label previews the next item and follows remapped controls). **H** completely shows/hides gameplay HUD chrome without changing gameplay. **F6** opens the keyboard/gamepad-help and clickable camera-selector panel; **C** opens camera settings. Interaction prompts are selected by the same Interactor as pressing E. A small first-person aim reticle only appears when a gun is equipped.

This design is based on the original *Iron Reliquary* Diablo / Symphony of the Night visual direction. It contains no copied game artwork, and its icons are original minimal SVGs. CI/native/Web screenshot and manual release gates are tracked in [issue #37](https://github.com/bravado/ACTION-5/issues/37).
