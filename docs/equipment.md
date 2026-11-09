# D06 equipment authoring and implementation state

**Status (2026-11-08):** D05 merged in PR #28. D06-01 Bat/Shovel and the
equipment contract are in development on `feat/d06-01-equipment`; do
not treat them as complete until current-head CI and native/WebGL2 evidence
pass. D06-02 Gun and D07 Enemy AI have not been implemented.

## Component responsibilities

`Action5WeaponDefinition` (Resource) contains immutable weapon ID,
display name, socket ID (`right_hand` by default), grip offsets, a list
of existing D05 `AttackDefinition` resources and an optional
camera-local F4 scene. `Action5Weapon` (Node3D) is the physical instance
and holds any future per-item mutable state; its action port forwards
a configured attack to `CombatController.request_attack()`.

`Action5EquipmentController` (Node3D) owns a small inventory, distance
check, equipped selection, swap/drop and generic register/unregister of
that weapon's attacks. It asks a replaceable `get_mount(socket_id)`
provider for a socket. It never imports `AnimationPresenter`, reads
camera keys/modes, or writes the actor's velocity.

`Action5EquipmentVisualAdapter` supplies that mount using
`AnimationPresenter.get_socket()`. For local players it registers
**every** world MeshInstance3D with FirstPersonPresenter so F4 hides
the mesh but preserves skinned world shadows, and attaches at most one
optional camera-space render-only viewmodel. The viewmodel uses
`CombatVisualState.get_visual_action()` for its authored swing motion; it
never drives hitbox position, damage, weapon inventory or aim. A separate
`EquipmentAttackSelector` resolves each incoming InputMap action through
the equipped instance's `get_attack_for_input(input_action)` port.
Each equipment `AttackDefinition.input_action` explicitly registers the
button/action it replaces; there is **no index-based default or automatic
duplication onto the other button**. The Bat demonstrates **two independent
actions**: `bat_swing` (`actor_punch`, LMB/J, vertical) and
`bat_horizontal` (`actor_kick`, RMB/K, wide lateral strike).
The Shovel claims only `actor_punch`, leaving RMB/K as regular Kick.
Other weapons may claim just one, both, another InputMap action, or none;
unassigned inputs retain the normal Punch/Kick behavior.
`CombatInputAdapter` consumes only the replaceable selection policy, not
equipment internals. Duplicate nonempty action assignments on one weapon
are invalid.

For F4, `FirstPersonCombatLimbs` uses an optional action-aware visibility
policy: an equipped F4 model hides the resting fist and its own substituted
attack limb, **but an unassigned Kick keeps its normal animated leg**.
When an item reuses an unarmed world animation key, the optional
`CombatVisualState.get_visual_action().action_id` distinguishes the
actual active equipped action from normal Punch/Kick, preventing false
limb suppression **and preventing an unassigned action from accidentally
driving the equipped weapon's swing** even with a shared clip.
The weapon's own
`Action5FirstPersonWeaponViewmodel` builds an arm from an authored
`FirstPersonLimbProfile` and attaches its weapon mesh to the actual
camera-space grip (fist transform). The arm, grip and weapon sweep
**together**, with no independent spinning item or extra attack timer.
For multiple actions, the viewmodel optionally exports
`action_profiles: Array[Resource]` of `FirstPersonLimbProfile` resources
keyed by `animation_key` (matching the attack's `visual_action_key`).
The same hand, grip and rendered Bat switch between vertical and horizontal
profiles; an unmatched/idle key returns to the base `grip_profile`.
The generic equipment renderer selects the pose from the existing visual
action snapshot, without weapon-ID cases or another gameplay clock.
`AttackDefinition.visual_action_key` optionally identifies the authored
camera-local sequence independently of `animation_key` (which still
selects the existing world skeleton clip). Bat and Shovel use unique
visual keys while D05 Punch/Kick keep their original defaults.
These poses are visual only: the socket-mounted world weapon stays
authoritative for shadow rendering and physics. **Optional F4 fallback:**
when `first_person_scene` is missing or unusable, the adapter leaves the
world weapon meshes on their normal visible layers and retains the default
F4 hand instead of hiding everything. This is an intentionally basic visual
fallback; author a proper gripped F4 scene for production-quality framing.
Only after a usable F4 viewmodel registers successfully are the real world
meshes locally culled and replaced by camera-space visuals.

NPCs omit FirstPersonPresenter and can use an alternative tiny
`get_mount()` provider. They keep regular world meshes and shadows.

## Demo controls

| Key | Command |
|---|---|
| E | Pick up nearest Bat/Shovel within reach |
| Q | Swap between carried weapons (or re-equip the last stowed item) |
| G | Drop current weapon into the persistent world |
| Left mouse / J | Bat vertical swing or Shovel swing; otherwise Punch |
| Right mouse / K | Bat horizontal strike; Shovel retains Kick; otherwise the equipped assignment or Kick |
| 1–5 | Switch perspective without changing equipment |

The demo rig has no dedicated Shovel or horizontal-Bat world clips.
Both Bat attacks and Shovel temporarily reuse the **upper-body Punch
clip**, never full-body Kick, in F1/F2/F3/F5. Their contact volumes,
damage and action timelines are already independent; F4 has distinct
authored grip/arm poses for each attack. A dedicated world horizontal
Bat animation remains an art/visual-acceptance follow-up, configurable
through the actor's SkeletonProfile and attack resource with no edits to
movement, combat or generic equipment.

The current sample arena places both pickups near the starting point.
Weapon pickup is a proximity interaction (not a physics impact or
complex inventory system). Drop restores the same Node3D to the world.

## Add a melee weapon without changing core code

1. Create an `Action5AttackDefinition` with a unique ID, attack ticks,
   hitbox size/forward offset, damage, knockback and generic animation
   key/channel already present in the actor's SkeletonProfile. Set its
   `input_action` to the action it should claim (e.g. `&"actor_punch"`
   for left mouse/J, `&"actor_kick"` for right mouse/K); leave empty to
   register an attack usable by other callers without overriding either
   button. Each nonempty input action may be claimed only once per weapon.
2. Create a `WeaponDefinition` resource with a unique `weapon_id`,
   a socket and `attacks = [new_attack]`. An optional F4 PackedScene
   may contain any number of geometry meshes; authored grip and swing
   offsets are data. For a coherent F4 swing, configure an authored
   `FirstPersonLimbProfile` on a `FirstPersonWeaponViewmodel` scene,
   with a `Grip` node holding all first-person tool meshes. `Grip`
   follows the extremity transform for each pose, including the rest
   pose, chamber, contact and recoil. For an alternate attack, create a
   second `FirstPersonLimbProfile` with `animation_key` equal to its
   `visual_action_key` and add it to the viewmodel's `action_profiles`;
   no additional equipment controller or separate viewmodel is needed.
3. Create a `Weapon` Node3D scene with this definition and independently
   authored world MeshInstance3D children. Put it in the world. You
   may add it to the demo's `action5_weapon_pickup` group to allow E.
4. Pickup invokes `EquipmentController.pickup(weapon)` and auto-equips
   the first item. Swap/drop operate on instances. To invoke a
   configured swing from gameplay/AI, call `EquipmentController.request_equipped_action(
   index, world_xz_direction)`. Player input uses its existing
   Punch/Kick actions and the replaceable selector. **Unassigned inputs
   automatically retain Punch/Kick** and no special swing key is required.
5. Add a test-only third weapon with different attack parameters. Verify
   no edits to `Action5Actor`, `Action5Locomotion`, MovementController,
   AnimationPresenter, CameraRig, FirstPersonPresenter, CombatController
   or the generic equipment controller are needed **for that new weapon**.

## Lifecycle and D06-02 constraints

Unequipping a weapon unregisters its D05 attack IDs and cancels only matching
active/buffered actions; unrelated active and pending actions keep their own
timelines. Stowed and equipped instances have exactly one `equipment_owner`,
so another actor cannot claim a still-owned item. A successful drop releases
ownership and returns it to the world for a different actor to pick up.
Definitions never store equip state. Dropped items restore normal world
render layers and shadows, and re-pickup uses the same original instance.

D06-02 should add a Gun instance with its own ammo, reserve, reload and
cooldown state. Configure a D05 AttackDefinition with
`use_melee_hit_query = false` and subscribe to the existing
`attack_phase_changed(..., "active", ...)` signal to resolve its ranged
effect. Gun must consume an already-resolved world aim target and trace
from its physical socket muzzle, excluding the shooter and blocking
shots through world geometry. A clear camera ray is never enough to
damage a target. Gun effects must not rely on D05's melee box hit test.

## Verification

`tests/d06_equipment_suite.gd` exercises the live world: item distance,
pickup, equipped socket, registration, real melee hit, swap cancellation,
drop/re-pickup, optional F4 visuals, multi-mesh shadow cleanup,
third-weapon extensibility, left/right attack selection, single gripped
F4 arm and a camera-free NPC mount provider. Final
E2E acceptance additionally needs F3/F4 while running/jumping/attacking,
real screenshots and WebGL2 interaction evidence. See issue #13 and
ADR-0005; keep the issue open until the PR is approved and merged.
