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
optional camera-space render-only viewmodel. The viewmodel can use
`CombatVisualState.get_visual_action()` for visual swing motion; it
never drives hitbox position, damage, weapon inventory or aim.

NPCs omit FirstPersonPresenter and can use an alternative tiny
`get_mount()` provider. They keep regular world meshes and shadows.

## Demo controls

| Key | Command |
|---|---|
| E | Pick up nearest Bat/Shovel within reach |
| Q | Swap between carried weapons |
| G | Drop current weapon into the persistent world |
| F | Use equipped weapon's first configured attack |
| Left/right mouse or J/K | D05 Punch/Kick remain available |
| 1–5 | Switch perspective without changing equipment |

The current sample arena places both pickups near the starting point.
Weapon pickup is a proximity interaction (not a physics impact or
complex inventory system). Drop restores the same Node3D to the world.

## Add a melee weapon without changing core code

1. Create an `Action5AttackDefinition` with a unique ID, attack ticks,
   hitbox size/forward offset, damage, knockback and generic animation
   key/channel already present in the actor's SkeletonProfile.
2. Create a `WeaponDefinition` resource with a unique `weapon_id`,
   a socket and `attacks = [new_attack]`. An optional F4 PackedScene
   may contain any number of geometry meshes; authored grip and swing
   offsets are data.
3. Create a `Weapon` Node3D scene with this definition and independently
   authored world MeshInstance3D children. Put it in the world. You
   may add it to the demo's `action5_weapon_pickup` group to allow E.
4. Pickup invokes `EquipmentController.pickup(weapon)` and auto-equips
   the first item. Swap/drop operate on instances. To invoke a
   configured swing, call `EquipmentController.request_equipped_action(
   index, world_xz_direction)`.
5. Add a test-only third weapon with different attack parameters. Verify
   no edits to `Action5Actor`, `Action5Locomotion`, MovementController,
   AnimationPresenter, CameraRig, FirstPersonPresenter, CombatController
   or the generic equipment controller are needed **for that new weapon**.

## Lifecycle and D06-02 constraints

Unequipping a weapon cancels and unregisters that weapon's D05 attack IDs.
Definitions never store equip state. Dropped items restore normal world
render layers and shadows, and re-pickup uses the same original instance.

D06-02 should add a Gun instance with its own ammo, reserve, reload and
cooldown state. Gun must consume an already-resolved world aim target and
trace from its physical socket muzzle, excluding the shooter and blocking
shots through world geometry. A clear camera ray is never enough to damage
a target. Gun effects must not rely on the D05 melee box hit test.

## Verification

`tests/d06_equipment_suite.gd` exercises the live world: item distance,
pickup, equipped socket, registration, real melee hit, swap cancellation,
drop/re-pickup, optional F4 visuals, multi-mesh shadow cleanup,
third-weapon extensibility and a camera-free NPC mount provider. Final
E2E acceptance additionally needs F3/F4 while running/jumping/attacking,
real screenshots and WebGL2 interaction evidence. See issue #13 and
ADR-0005; keep the issue open until the PR is approved and merged.
