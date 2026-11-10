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

Keep **one** gameplay world at `demo/main.tscn` and **one** separately
authored dungeon sector at `demo/world/encounter_sector.tscn`. The
sector is instanced into the main world at a translated but unrotated
position; it owns the floor, obstacle/navigation ring, two equipped
D07 NPCs, physical portal and presentation-only roof.

- The original player, camera, input, Health, Combat, Equipment and
  weapon instances remain alive on regular round trips. Normal E-door
  travel calls `WorldSession.travel_to`, **not** scene replacement.
- Inactive dungeon processing can be disabled without discarding NPC
  Health, gun ammo, aim/decision state, or world weapon instances.
- Optional **Start fresh** is a separately configured room-entry policy,
  not the default; any necessary reinitialization must be scoped to the
  destination sector, never silently reset the player's inventory.
- Physical door collision and NavigationLink3D are tied to open/locked
  state. RoofVisibility hides only meshes/shadows and cannot change
  physics, navigation or Gun muzzle ray authority.
- The single `demo/world/dungeon_navigation.gd` builds a static
  navigation ring for the dungeon. AI/Combat/Equipment do not depend on
  demo-specific room or scene-transition classes.
- `SectorCameraBounds` adjusts F1/F2/F5 camera target clamps to the
  sector's global offset. Neither map nor WASD world axes are rotated;
  F2/F5 headings stay fixed at the boundary while F3/F4 keep orbit/aim
  behavior.

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
