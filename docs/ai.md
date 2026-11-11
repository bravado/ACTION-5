# D07 — Actor-local enemy AI

D07 composes the **same** `Action5Actor`, Locomotion, MovementController,
Health, Hurtbox, CombatController and EquipmentController used by the
player. The only new reusable classes are actor-local AI decisions, target
sensing, navigation and attack selection. Nothing in `addons/action5/`
imports `demo/`, and no camera mode controls AI authority.

## Architecture and extension points

| Component | Responsibility | Does not own |
|---|---|---|
| `Action5AITargetSensor` | Acquire/forget living targets in a group, optional explicit target, physical LoS | Damage or camera aiming |
| `Action5AINavigation` | Query a world-authored `NavigationAgent3D` for an X/Z waypoint | Locomotion, door/navmesh world policy |
| `Action5AIAttackPolicy` | Select an authored `attack_id`, min/max range, optional `reload_command` | D05 attack timeline or D06 ammo state |
| `Action5AIController` | Decide Idle/Pursue/Attack/Recover/Dead and submit existing move and attack ports | A second movement/animation FSM |

The world owns the `NavigationRegion3D` polygons and all opaque collision
geometry. A missing or unsynchronized navigation map must not cause direct
steering through walls. The AI uses `Action5Actor.apply_move_intent()`,
actor-owned Equipment actions, `CombatController.request_attack()` and
the replaceable `Action5ActorTargetAimProvider` for ranged targets.
No global AI registry, duplicate equipment owner or view-specific aim logic.

**Attack ownership:** On every physics tick, including startup and active
phases, the controller rechecks the same target's life, configured range and
physical line of sight. If invalid, it cancels **only an accepted
AI-owned** attack request; independent combat logic continues to own
startup/active/recovery, actual Hitbox/Hurtbox filtering, muzzle hits,
knockback and damage. Dry, reloading or rejected attacks are not
reported as attacks. Death clears the AI target/aim, stops its physics
processing and disables the ordinary actor movement. A restored actor
may call `AIController.reactivate()` **only after** restoring
`Health.current_health > 0` and `actor.alive = true`.

**Timing contract:** D03 queued movement IDs resolve against the *latest*
submitted intent at physics time; D05 attack requests snapshot their
world-plane heading on submission. Two attack requests in the same
physics tick cannot override one another. These semantics are
independent of skeleton/camera state.

## Adding an enemy archetype

1. Instantiate `demo/ai/enemy.tscn` or compose the four AI components
   beside an ordinary Actor, Health, Hurtbox, Combat, Locomotion and
   EquipmentController in your own scene. Give each actor its own
   component instances.
2. Configure `TargetSensor.target_group` and target ranges, a world
   `NavigationRegion3D` with an actor-local `NavigationAgent3D`, and
   `AttackPolicy.attack_id`, `minimum_range`, `maximum_range` and
   `requires_equipment`. Set `reload_command` explicitly when the
   weapon supports reloading; do not assume the first command binding
   means reload.
3. Register an existing D05 attack resource or equip an ordinary
   D06 weapon carrying the configured ID. A new attack is selected by
   **ID**, not by attack-array position or a weapon-name conditional.
   If `requires_equipment=false`, the policy requests the D05 action
   directly. The demo's `InitialWeapon` shows pickup before equipping.
4. Optionally install a skeletal model, `SkeletonProfile`,
   `AnimationPresenter`, `CombatAnimationAdapter` and
   `GunReloadVisualAdapter`. Neither Combat nor AI needs these nodes.
   Use a replaceable mount provider that returns an animated socket or
   a static fallback. Test a second attack/weapon setup without editing
   Actor, MovementController, CombatController, AnimationPresenter or
   EquipmentController.

The existing `melee_enemy.tscn` holds a Bat and requests `bat_swing`;
`ranged_enemy.tscn` holds a Gun and requests `gun_fire` with an
authored minimum standoff range and `weapon_reload`.

## Animated NPC composition

Both demo NPCs reuse `action5_training_character.glb` with the
`demo/assets/enemy_skeleton_profile.tres` clip mapping and shared
D04/D05/D06 presentation adapters:

- Bat attack `bat_swing` → `bat_vertical` upper-body clip;
  physical damage still follows the authored D05 attack window.
- Gun attack `gun_fire` → NPC-only `gun_fire` mapping to the
  training rig's **forward-arm `punch` clip**. This is a placeholder
  visual pose, not a second physical punch or a player animation change.
  A more specific shooting clip can replace this mapping in another rig.
- `GunReloadVisualAdapter` observes equipped Gun reload signals.
  `CombatAnimationAdapter` observes attack/hit/death signals.
  Each adapter clears only the visual channel it owns.
- `SocketSource.get_mount(socket_id)` returns the presenter's animated
  hand-bone socket when available; its original static `Visual/Socket`
  remains the fallback for actors without animation presentation.
- Configure `AnimationPresenter.run_speed_threshold` **between** each
  NPC's `Locomotion.walk_speed` and `run_speed` (melee 3.7,
  ranged 3.2). The default player threshold is too high for either
  slower enemy's running cycle.
- Demo-only `EnemyAppearance` gives independent NPC instances
  translucent red/blue tints; it never changes shared imported GLB
  materials or determines collision/Health.

Visual attachment does not modify Gun's physical first-hit ray:
opaque world geometry blocks shots even if the animated muzzle or
F4 camera sees another target. A live solid actor receives damage
only through its enabled owned Hurtbox/Health. The world-owned
projectile tracer cannot cause damage.

## Regression and visual acceptance

`tests/d07_suite.gd` is exercised by `make check`. It validates
two live independent NPCs, correct ownership of Bat/Gun and hit clocks,
real navigation around an opaque obstacle, F1–F5 switches, gated
player input, autonomous melee/ranged damage, range and cover changes
during startup, rejected attack/reload behavior, target
death/free/reacquisition, NPC death and teardown. It also verifies
real `CombatInputAdapter` punch/kick damage in the embedded dungeon,
valid individual animation trees, animated sockets, swing/fire/reload/
death clip activation and clearing, locomotion run clips and the
unanimated equipment fallback.

```bash
make check
make import
godot --path . res://demo/main.tscn
```

In the main demo, use E at the arena's east-side portal to enter the
shared dungeon. Use WASD to move, **LMB/J** to punch,
**RMB/K** to kick and **1–5** to change view. Verify the red Bat
pursuer visibly swings and holds its weapon during the animation,
and the blue Gun pursuer shows fire/reload/death poses without
firing through the center obstacle. Inspect F1–F5, weapon alignment,
physical muzzle obstruction, character hit/death response, player
attack input and persistence of the enemy's HP/decision state while
switching views.

**D07 is merged** (implementation D07-01). Final verification:
[CI run #42871200034](https://github.com/bravado/ACTION-5/actions/runs/42871200034)
passed **1,018 Godot assertions with zero failures**, Linux/Web exports,
native rendering and real WebGL2 Full E2E. The native screenshots/browser
harness target `demo/main.tscn` but do not necessarily navigate through
the dungeon; future changes to enemy models/animations require an actual
E-door visit and F1–F5 dungeon review, not only a main-stage screenshot.

## D08 successor boundary

D07 remains the merged AI component baseline, but its old standalone
`demo/ai/encounter.tscn` has been removed. `tests/d07_suite.gd`
instantiates `demo/main.tscn`, enters the *same*
`demo/world/encounter_sector.tscn` as real gameplay and exercises both
NPCs there. D08 provides the scene-local Interactor, Door,
WorldPickup, roof presentation, Restart and optional fresh/restore
room policy. Normal world travel preserves the live player, inventory
and enemies instead of calling `change_scene_to_packed()`. The one-shot
scene-handoff prototype and its obsolete test suites were removed.
Keep future AI regression coverage in this shared dungeon, without
reintroducing another Player/Camera scene or touching combat-core APIs.

## D08 closed-gate detection and retained aggro

`Action5AITargetSensor.set_acquisition_gate(node)` accepts an
optional, map-composed `allows_acquisition(observer, candidate) -> bool`
protocol. The example `demo/interactions/door_acquisition_filter.gd`
uses a physical door's opening plane: it rejects **new** player
detection across a closed gate but permits acquisition within the
same room and across an opened gate. When the gate closes, the
already-acquired target remains valid until the ordinary forget-range
or Health lifecycle clears it. AI keeps its navigation/pursuit intent
but cannot physically cross a closed door or attack through its
blocked world-space LoS.

`WorldSession` connects the two dungeon sensors to this gate on
normal startup and after a **Start fresh** room reinstance; the
reusable sensor, AI FSM, navigation and combat do not import
WorldDoor or scene coordinates. The demo now includes an arena
NavigationRegion3D plus a conditional door NavigationLink3D.
When adding more doors, compose independent acquisition filters and
navigation links rather than testing global is_dungeon flags.

When an enemy physically crosses into the arena while the gate is
open, closing the gate does **not** make that enemy invisible or stop
its movement just because it was instanced in the dungeon. The
D08 `RoomVisibility` adapter hides static sector render nodes but
presents each mobile enemy according to its *current* physical
side of the door. `WorldSession` keeps previously alerted or
crossed enemies active after the dungeon preload window is left.
The closed gate blocks sight **only when the enemy and player remain
on opposite sides**. Aggro is retained either way.

`tests/d08_connections_suite.gd` verifies that enemies stay
unalerted as the player approaches a **closed** adjacent door,
become alerted when it opens, and keep their acquired target after
closure while physical cover continues blocking attacks. D07
same-room detection and obstacle pursuit remain separately tested.
