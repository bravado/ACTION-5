# ADR-0007: One persistent world with a reusable dungeon scene

- **Status:** Accepted (D08 persistent-world architecture)
- **Date:** 2026-11-10
- **Related:** D07 AI foundation, D08 issue #16, delivered D09-01 reference scenario

## Context

D07 introduced independent equipped melee/ranged enemies and their
standalone `demo/ai/encounter.tscn` test stage, with a duplicate Player
and ViewManager. Early D08 experiments also implemented E portals via
`SceneTree.change_scene_to_packed()`, one-shot weapon/HP serialization
and reload-based enemy/pickup snapshots. This duplicated the battle
layout, split inventory and actor lifecycles, and could not meet D08's
**same live player and world** acceptance requirement.

## Decision

The game owns exactly one SceneTree world at `demo/main.tscn`, and
authors the dungeon independently at
`demo/world/encounter_sector.tscn`. Its origin is world X=26:
its western floor edge (local X=-12) **meets** the arena eastern edge
(world X=14), on the same Y elevation and without rotating the axes.
The dungeon owns its obstacles, navigation ring, two D07 equipped NPCs,
three outer walls and a physically authoritative ceiling.

One **two-sided physical passage** at **X=14, Z=0** joins both spaces:
the arena's east wall consists of two collidable segments around a
2.5-meter opening, plus a short overlapping PassageFloor slab. There
is only one `EncounterDoor`, parented to the shared main world.
Its `WorldDoor` owns a real collider and NavigationLink3D; the visual
door frame persists from both sides while `BarrierMesh` hides when
open. The dungeon has no remote return portal or duplicated door.
**Press E to open the physical barrier and walk through**; the E action
does not move the player.

`WorldSession` observes the original player's X coordinate on each
physics tick, with a hysteresis around the common boundary. It
activates dungeon physics and AI before the player reaches the
passage, suspends them when the player moves far into the arena,
and changes room state on *physical crossing*. Original Player,
Camera, Health, Combat, Equipment and weapon nodes survive both ways.
The optional explicit `travel_to()` warp is used for scripted actions
and test setup, never by the interactive doorway.

Optional **Start fresh** remains a destination-only policy; normal
crossings restore the actual live objects. Fresh mode may reinitialize
the destination room and its loose items but never the player's own
inventory. Head-specific CI must still prove this behavior.

The main arena authors one `PickupSpawns` scene-local participant with a
list of pickup node paths instead of weapon-specific or per-item state
wrappers. Its `capture_state()` returns availability keyed by stable authored
paths; `restore_state()` and `reset_to_initial()` manage only the world
spawn copies, preserving any inventory-owned originals. It remembers the
original PackedScene, parent, transform and node name so fresh pickups
remain addressable at their authored paths. This is independent of
`Action5EquipmentController` and `Action5Interactor`, and remains outside
`addons/action5/`. D08 tests cover multiple weapons, partial snapshots,
fresh resets and carried-item preservation.

F1/F2/F5 camera clamps use one world-space bounds rectangle covering
the **union** of arena and translated dungeon. They do not move or
snap when the player crosses the threshold. The camera and WASD
orientation remain continuous; F2/F5 use stable fixed headings and F3
uses its intended orbit vector rather than rotating due to follow lag.
D03 locomotion, Combat, Equipment and AI do not import world-session
or door scripts.

The roof is physics-only. A full-viewport ColorRect (CanvasLayer 0,
below the HUD) provides a subtle dungeon-only tint in views 1/2/3/5,
disabled in first person. The roof's collision still obstructs
navigation and projectile/weapon raycasts. Neither this overlay nor
the doorway appearance defines collision authority.

## Explicitly different connection types

**Connected physical gate — `WorldDoor`:** Adjacent arena/dungeon floors
meet at the same boundary. E toggles an opaque physical panel,
collision and the shared NavigationLink3D; neither the player nor
the camera is teleported. `RoomVisibility` hides the opposite
room's render nodes while the gate is closed, even when its floor/AI
is preloaded for physics. The scene-level
`DoorAcquisitionFilter` implements the optional
`allows_acquisition(observer, candidate)` protocol of
`Action5AITargetSensor`: first discovery is denied across a closed
gate, but an already-acquired target is retained if the door closes.
This does not bypass the existing world-space combat LoS or collision.
The generic Interactor may query a near-side door handle through
`get_interaction_point(actor)`; no door-specific input branch exists.

**Nonadjacent travel — `LocationPortal`:** For a marker elsewhere,
explicit E moves the same actor to a Marker3D. For a separate
PackedScene, `LocationManager` loads its *environment only* as a
detached child scene and moves the original actor to its entry marker.
The scene is cached, hidden and CPU-paused when inactive. It also
uses CollisionObject3D.DISABLE_MODE_REMOVE to let Godot automatically
remove/recreate inactive collision bodies without modifying their
authored layers/masks. Navigation regions/links still snapshot and
restore enabled flags explicitly. Two cached remote scenes may
overlap without leaving invisible solid walls.
Player, equipment and camera are never paused or cloned. Another
Marker3D portal returns the actor to the arena. The example
`demo/world/remote_chamber.tscn` is **not** another connected room
and does not contain a duplicate Player, Combat, Equipment, camera or
input adapter. `WorldSession` suspends its physical room-threshold
observer only while that detached location is active. A
`SectorCameraBounds` adapter reframes only on such deliberate
nonadjacent jumps, never on normal adjacent doorway crossing.

These are separate components because they solve different movement
semantics and lifecycle problems. A `SceneTree.change_scene`
replacement that recreated the player would require an explicit
save/restore protocol and is not part of normal D08 traversal.

## One dungeon for gameplay **and** D07 tests

The old `demo/ai/encounter.tscn` and its script, scene-travel handoff
implementation, superseded `tests/d07_transition_suite.gd` and
`tests/d07_scene_visit_suite.gd`, and their unused one-shot snapshot
adapters have been removed.

`tests/d07_suite.gd` now instantiates `demo/main.tscn`, positions the
world away from other test fixtures, enters the existing dungeon via
WorldSession and exercises real NPC decisions, navigation, physical
damage, model/weapon sockets, reloads, deaths and player combat input
on the **same scene** that the user plays. The suite has no second
player, camera or test-only enemy map.

`tests/d08_world_suite.gd` covers normal world travel and optional
entry state; `tests/d08_camera_sector_suite.gd` covers identical WASD
directions and bounded-camera orientation across all five views.
Do not create a standalone encounter scene for new AI tests: author
more NPC configurations in the existing dungeon or inject temporary
test actors into that scene.

## Simplification follow-up

`LocationManager.current_location` is derived from the single
`active_scene` reference instead of maintained as a second mutable
identifier. Godot's `CollisionObject3D.DISABLE_MODE_REMOVE` handles
cached room physics, including scenes originally authored with
`KEEP_ACTIVE`; only navigation-region/link enabled flags require
an explicit snapshot. The unused `WorldSector`, alternate equipment
input, enemy visit-state and portable weapon snapshot adapters were
removed; the D08 room policy keeps live NPC state or re-instantiates
the authored dungeon for Start fresh.

`RoomVisibility` filters pickup-group creation before any deferred
registration work and still owns only room-root occlusion and loose
pickup/enemy visibility. `OuterWallFader` now owns both optional F1
front-wall mesh hiding and proximity materials, restoring original
state when removed. The door remains the physical blocker; no
additional global world, input or combat manager was introduced.

## Performance tradeoffs

| Strategy | Memory | Idle CPU | Player/equipment identity | Result |
|---|---|---|---|---|
| Reload each room and hand off inventory | Low | Low | Recreated | Rejected for normal D08 travel |
| Keep independent complete game scenes | High | Potential double player/camera/input | Duplicated | Rejected |
| **One world, instanced sectors, pause inactive NPCs** | Retains sector nodes | Pausable | **Same live actors** | Chosen |
| Compact explicit fresh-entry reset | Transient reinitialization | Infrequent | Same player | Optional, requires testing |

RoomVisibility uses equipment and SceneTree pickup-node events to
register loose connected-world pickups (unrelated Node3D additions do
not schedule deferred work), then tracks only those items for
changes of room position. It excludes tagged detached scene roots,
releases visual ownership on pickup, and prunes dead weak references
after room resets. OuterWallFader similarly prunes dead material entries.
Visibility paths remain a scene-composition policy, not an addon core
dependency.

SectorCameraBounds unions the four transformed X/Z corners of local
profile rectangles across arbitrary additional configured connected
sector roots, including rotated layouts. It only reframes for explicit
remote portals; physical door crossings remain continuous.

No measured frame-time/memory/native/WebGL2 comparison has been
completed; do not claim performance superiority without profiling.

## Remaining release gates

D08's architecture now satisfies the structural same-world requirement,
and its owner F1–F5 manual visual verification passed on
November 11, 2026. The 1,212-assertion headless test suite covers
the independent D07 encounter, fresh-entry item/NPC lifetimes,
physics isolation, navigation restoration and camera continuity.
Native and WebGL2 export/browser checks remain standard release gates.
The original scene-loading prototype is historical context, not a
supported alternative at runtime.

## Presentation at enclosing outer walls

In F2 the shallow camera can obscure actors near the lower/front
room boundary. The playable scene installs one independent
`OuterWallFader` whose only inputs are the shared player transform,
optional camera mode and opt-in `action5_outer_wall` physical wall
footprints. It fades exterior wall **materials only** within
3.8 units to a minimum 20% opacity by 1.1 units. Main arena,
instanced dungeon and detached remote chamber use the same group.
The component cannot affect a shared interior wall, opaque door,
enemy LoS, collision, pathfinding or actor state. FPS remains opaque.

The material is duplicated and cached per MeshInstance3D to preserve
the source asset and minimize per-frame allocations; the original
surface override is restored at full distance. Alpha blended
StandardMaterial3D supports the native and WebGL2 Compatibility
pipelines, unlike the `GeometryInstance3D.transparency` multiplier,
which Compatibility ignores. This decision explicitly separates
the *perimeter visibility effect* from `RoomVisibility`'s hiding of
the opposite area behind a **closed** connected door.
