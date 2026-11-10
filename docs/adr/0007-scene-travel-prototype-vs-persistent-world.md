# ADR-0007: One persistent world with a reusable dungeon scene

- **Status:** Adopted in D08 PR #34 (pending full D08 acceptance)
- **Date:** 2026-11-10
- **Related:** merged D07 PR #33, D08 issue #16, D08 PR #34

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

## Performance tradeoffs

| Strategy | Memory | Idle CPU | Player/equipment identity | Result |
|---|---|---|---|---|
| Reload each room and hand off inventory | Low | Low | Recreated | Rejected for normal D08 travel |
| Keep independent complete game scenes | High | Potential double player/camera/input | Duplicated | Rejected |
| **One world, instanced sectors, pause inactive NPCs** | Retains sector nodes | Pausable | **Same live actors** | Chosen |
| Compact explicit fresh-entry reset | Transient reinitialization | Infrequent | Same player | Optional, requires testing |

No measured frame-time/memory/native/WebGL2 comparison has been
completed; do not claim performance superiority without profiling.

## Remaining release gates

D08's architecture now satisfies the structural same-world requirement,
but PR #34 remains **draft** until head-specific Godot tests (including
the independent D07 suite), fresh-entry item/NPC lifetime regressions,
native/WebGL2 tests and owner camera/interaction visual review all pass.
The original scene-loading prototype is historical context, not a
supported alternative at runtime.
