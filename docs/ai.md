# D07 — Actor-local enemy AI

The D07 NPCs use the **same** `Action5Actor`, Locomotion, MovementController,
Health, Hurtbox, CombatController and EquipmentController as the player.
Nothing in the reusable addon depends on `demo/`.

The independent pieces are:

- `Action5AITargetSensor`: nearest living member of a configured group,
  explicit test/scripted target override and physical opaque line of sight.
  Dead/freed targets are rejected; no view manager is referenced.
- `Action5AINavigation`: feeds waypoints from a Godot
  `NavigationAgent3D` to ordinary world X/Z move intents. The
  `NavigationRegion3D` and traversable polygons belong to the world.
  Missing/unsynchronized maps do **not** turn into straight-line wall
  penetration.
- `Action5AIAttackPolicy`: configured action, min/max range, weapon
  action ID and explicit optional gun reload command. D05 alone owns attack
  startup/active/recovery and D06 Gun owns ammunition.
- `Action5AIController`: small Idle/Pursue/Attack/Recover/Dead **decision**
  states, not another locomotion FSM or combat clock. It connects the
  other components to `Actor.apply_move_intent()` and
  `CombatController.request_attack()` / Equipment's action port.

## Author an enemy archetype

Instantiate `demo/ai/enemy.tscn` (or compose the same addon nodes in your
own scene). Set `TargetSensor.target_group`, navigation-agent geometry,
the action resource registered with this actor's Combat/Equipment, and
`AttackPolicy.attack_id`, `maximum_range`, `minimum_range`,
`requires_equipment` and optional `reload_command` as appropriate.
Equip an ordinary weapon instance through EquipmentController; a demo-only
`InitialWeapon` node demonstrates pickup. The Gun must use the actor-local
`AimTargetProvider`, never a camera ray. A third policy can subclass
`Action5AIAttackPolicy` without editing any shared actor, movement, combat,
equipment, presentation or camera class.

For a Gun, `AttackPolicy` resolves the equipped action by `attack_id`,
not by a fragile authored array index, and invokes the explicitly configured
`reload_command` when the magazine runs dry (if reserve ammunition exists).
An unarmed policy requests the D05 action directly.

`AIController` accepts attack requests only within the configured range and
with direct physical sensor line of sight. It monitors range/LoS on every
physics frame, including startup and active frames, cancelling **only its own
accepted** attack if its target changes, moves out of range or enters cover.
D05 still controls all startup/active/recovery and hit authority. Missing
weapons, rejected attacks and reload do not produce false `attack` states.
On death, AI processing stops; a restored actor with living Health and
`alive=true` may explicitly invoke `AIController.reactivate()`. Damage is independently checked by the
gun's **first world-muzzle ray**. An opaque collider always blocks that ray;
a solid actor can receive damage only through its own live Hurtbox and
Health. An AI attack is not a separate damage path.

D03 move requests queue **IDs**, while the final actor move intent is read
at physics time. Multiple move requests are resolved by the existing
priority/ID arbitration. D05 attack requests snapshot an explicit world
heading at request time; an already pending attack rejects a competing
request. Neither contract depends on rendering or camera state.

## Manual acceptance

Run `make check`; request Full E2E with a `[full-e2e]` commit, then
`make run` for the normal D06 game and
`godot --path . res://demo/ai/encounter.tscn` for the separate D07 arena.
Use WASD and number keys 1–5 in the D07 arena. Watch both enemies route
around the center, approach within configured range, aim and attack.
Check death/target loss, physical wall obstruction, player focus gating,
ammo/reload, weapon teardown and native/WebGL2 visuals against issue #15.
Previous isolated head passed 995 Godot assertions and native/WebGL2 Full E2E.
The additional P1/P2 regression commit requires fresh CI verification and
owner native/WebGL2 visual acceptance before merge. No new third-party assets are used.
