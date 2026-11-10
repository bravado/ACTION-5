# ADR-0007: Scene handoff prototype vs. persistent-world traversal

- **Status:** Proposed / interim D08 design; **not** acceptance of D08-01
- **Date:** 2026-11-10
- **Context:** D07 implements camera-independent AI; D08 requires doors, pickups,
  roof occlusion, obstacle-aware navigation and arena-to-dungeon movement in
  **one persistent world without mandatory scene reload**.

## Decision

Separate D07 AI from D08 interaction infrastructure. PR #33 retains only
the independent two-enemy AI demo and tests. D08 PR #34 is an **explicitly
temporary scene-loading integration prototype** built on top of D07.

The current Door uses `SceneTree.change_scene_to_packed()`. A
destination-scoped, one-shot `SceneHandoff` transports player inventory,
ammunition/HP, collected original map pickups and scene visit snapshots.
The per-door `entry_policy` selects restore or fresh. The old scene is
freed. Source and destination never share the same live Actor instance.

This is **not** the D08 exit criterion. A future D08 revision must compose
an arena and dungeon in a single authoritative `World3D` with the same
player and enemy instances traversing the connection, while leaving
D03/D05/D06/AI/Camera core unchanged.

## Why keep the prototype for now?

We can verify ownership, replay-free pickups and local interaction
boundaries before building full traversal. It exposes public ports and
testable behavior, but is intentionally demo-scoped. Its inventory
restoration and one-use snapshots must not be mistaken for continuous
scene/actor identity.

## Performance and alternative strategies

| Technique | Retained memory | Inactive CPU | Transition work | Contract |
| --- | --- | --- | --- | --- |
| Keep inactive scenes in the tree | High | Potential physics/AI cost | Low | Reuses old actors but risks concurrent worlds |
| Detach and cache entire scenes | High | Usually none | Reattach scene | Old node references and lifecycle stay complex |
| Serialize compact values, recreate scene | Scales with snapshot | None | Reload + restore | Current interim prototype, **not** seamless |
| **One world with connected arena/dungeon** | Loaded geometry/actors in world | Live active-world systems | No scene reload | **D08 requirement**; use authoring and streaming optimizations as needed |

There are no measured memory or frame-time figures yet. The scene
snapshot solution is a reasonable short-term browser-friendly alternative
to caching inactive whole Node trees, but real D08 persistent-world
navigation still needs profiling on native and WebGL2.

## Extension and authority boundaries

- `SceneDoor` and the demo InteractInput resolve scene actions only.
  No raw keyboard input belongs in Actor, Combat or Equipment.
- `SceneVisitState` consumes opt-in `capture_state()/restore_state()`
  adapters only at transition boundaries. This is **session state**, not
  serialized disk saves, network sync, global inventory or replay.
- Mutable Gun state is per instance; reconstitution uses ordinary
  Equipment pickup/equip ports, not direct registry access.
- The health adapters retain HP/death and stable poses. Current combat
  phases, AI target/node references, navigation paths and projectiles
  are intentionally not serialized.
- D08's future Door/WorldPickup/Interactor must use the same
  `interact(actor)` port with world-range, line-of-sight, permissions,
  collider/nav authority, camera-only roof visibility and a camera-free
  script/NPC caller. This prototype does **not** satisfy those gates.

## Required D08 follow-up before merge

1. Add a shared-world arena/dungeon passage and retain original player
   actor, equipped weapon, HP, reload timing, nearby enemies and effects
   while crossing.
2. Replace scene-changing demo door with physically authoritative Door
   and actor-local Interactor with view-independent selection, LOS and
   script/NPC callers; collision/nav transition tracks locked/open state.
3. Author a separate WorldPickup component; integrate RoofVisibility as
   view-local *render-only* change. Prove muzzle obstruction and
   navigation do not change when roofs hide.
4. Add steps, gaps, ledges, overhangs and two-area navigation tests,
   native/WebGL2 traversal and projectile cleanup regressions.
5. Decide whether to retain the snapshot module as an **optional**
   scene-reset/checkpoint adapter, or remove it once same-world level
   integration makes that complexity unnecessary. Do not retain both
   systems without a concrete use-case and comparative profile.

## Verification

- D07 independent branch PR #33: 995 assertions; native/WebGL2 E2E
  green on original head `cf59acc` (run #42825194678).
- Full scene-handoff prototype source tree previously passed 1,045
  Godot assertions at `0c6e290` (run #42840710655). New stacked PR
  #34 must run its own CI before claiming release readiness.
- D08-01 remains open: [issue #16](https://github.com/bravado/ACTION-5/issues/16).
