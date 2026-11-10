# D06 equipment authoring and implementation state

**Status (2026-11-09):** D05 is merged via PR #28. **D06-01 Bat/Shovel
and the reusable equipment contract are implemented and approved in PR #31.**
Latest-head CI passed 908 assertions (0 failures), native/Linux + WebGL2
Full E2E and owner visual checks passed ([CI #42668808972](https://github.com/bravado/ACTION-5/actions/runs/42668808972)).
D06-02 Gun is implemented in PR #32 (under review), while D07 AI remains
a separate future milestone. See [ADR-0006](adr/0006-authoritative-gun-and-projectile-visuals.md).

## D06-02 development branch: hitscan gun (automated validation passed; manual visuals pending)

D06-02 uses the accepted D06-01 equipment and D05 action clocks. The demo
adds a Pistol pickup, magazine/reserve display, R reload, physical WorldRecoil
mesh effect, and camera-local firing/reload grip poses. A Heavy Pistol fixture
demonstrates different 3-round capacity, T reload command, 135-tick reload,
fire recovery, muzzle placement, appearance and separate attack ID.

**Authoritative ownership:** Action5Gun derives from the existing
Action5Weapon instance. Per-instance magazine, reserve, reload ticks and
firing counters live on the instance only. The D05 active phase emits
one hitscan ray. Neither gun nor equipment touches movement intent, player
view mode, camera transforms, render layers or raw input. World Muzzle is
the physical origin; the F4 camera-anchored GunF4 is presentation only.

**Aim contract:** The optional ViewAimTargetProvider translates a D05
ActionInputContext into a world-space destination. F4 traces through the
center of Camera3D; the independent physical trace ALWAYS runs from the
world Muzzle to this target, excluding the owner body's collision objects.
Other views use world aim/facing, with retro F5 optionally quantized to
8 sectors by the aim policy alone. No gun-specific camera checks and no
retro quantization in its AttackDefinition. A nearer layer-1 wall takes
precedence over a layer-2 Hurtbox. A valid active shot consumes one bullet
even when a wall blocks its target; a dry/invalid/cancelled request does not.
Hurtbox/Health handle friendly-team rejection, damage and stagger; no mesh
has authority to hit.

**Visible projectile (optional, render-only):** Each gun scene can mount
an independent `Action5GunProjectilePresenter` child with
`gun_path = ..`, `muzzle_path = ../Muzzle` and a replaceable
`projectile_scene` (`Action5ProjectileVisual` script). The presenter listens
to the existing `Gun.fired(impact, hit_receiver)` event **after** the
authoritative D05 active-phase hitscan has resolved its collision and damage.
It snapshots the world muzzle position and the returned **actual impact
point** (wall, target, or maximum range), launches a non-colliding emissive
projectile tip with a short cylinder trail, and frees the effect at the
end of its render-only travel. Neither damage, ammo nor fire cadence waits
for this animation. Empty magazines, buffered/cancelled attacks and reloads
produce no projectile because they never emit `fired`.

The projectile's `top_level` world transform fixes its trajectory even if
the shooter runs, turns, drops, destroys the weapon or switches cameras during flight. Meshes
are created only when firing, **after** equipment registered world-weapon
meshes, and remain on normal world layer 1 so F4 sees them without a
second visual-only weapon or camera-type checks. The presenter reconnects
its event listener in `_enter_tree()` after any weapon reparent (world,
stowed, socket), because Godot does not invoke `_ready()` again on
reparent. Its `_exit_tree()` disconnects. Each spawned projectile is
attached to the **world scene**, not to the gun: an in-flight effect
survives weapon destruction, view switching or actor teardown and frees
itself after a bounded duration. No global effect manager is required.

To customize for another gun, author a separate PackedScene using the
`Action5ProjectileVisual` script, then assign it to that gun's
`ProjectilePresenter.projectile_scene`. Configure `projectile_color`,
`travel_speed`, `minimum_duration`, `maximum_duration`, `tip_radius`,
`trail_length`, and `trail_radius`; no shared weapon/combat/equipment/
camera logic changes are necessary. To disable the visible projectile,
remove the optional presenter node. The demo Pistol uses a warm gold
streak; the Heavy Pistol fixture uses a wider blue streak. These are
visible travel effects, **not simulated physical bullets**: instant
hitscan remains gameplay authority. A true ballistic projectile is a
separate future collision/attack behavior, not something inferred from
the visual effect.

**Reload:** A separate optional WeaponCommandInputAdapter reads the existing
action-permission snapshot and forwards the equipped weapon's configured
command. Gun owns its tick countdown, moves rounds on successful completion,
and cancels an incomplete reload when stowed, dropped or destroyed. Already
consumed rounds remain consumed. A view change, run or jump does not reset
the timer. A full magazine, empty reserve, active reload or busy attack
rejects a new reload request. Weapon switching does not construct a second
gun or a second gameplay clock. The GunReloadVisual adapter listens to
reload events for the world skinned reload clip (if authored). F4 selects a
camera-space reload grip; its visual pose cannot finish the reload.
The world reload adapter only clears an upper-body clip when it actually
owns that clip, preventing unintended cancellation of another action.

**Extension:** Copy the Gun scene/resource pair, author a new unique
AttackDefinition (use_melee_hit_query=false, facing_sectors=Free, own
visual_action_key), a separate world Muzzle Marker3D and separate optional
F4 render-only viewmodel. Set magazine_size, starting_reserve,
reload_ticks, fire_attack_id, reload_action, reload_key, maximum_range and
ray_mask on that **instance**. The external aim provider is a replaceable
actor-local Node implementing get_world_target(origin, range, exclude).
Choose clip profiles via authored F4 resources and an optional world
animation adapter. No actor/locomotion/movement/animation/combat/equipment
core branches are needed for another gun.

**Camera-free NPC example:** `Action5ActorTargetAimProvider` is a second
concrete implementation of that same aim port. An AI decision component
sets its target using `set_target(Node3D)`; assign the NPC gun's
`aim_provider_path = ^"WorldTarget"` to the actor-local node. Missing
or freed targets return the current muzzle origin (invalid shot), so no
ammo or effect is produced. The target provider does not reference the
player, camera, InputMap or navigation; the AI issues an ordinary D05
attack request and the physical muzzle enforces occlusion. Tested in
`tests/d06_gun_suite.gd` on a real camera-free CharacterBody3D with its
own Health, CombatController, Equipment and mount source.

**Shared visual adapter exception:** A tiny optional
set_visual_source(weapon) call was added to EquipmentVisualAdapter when
registering an F4 scene. This only supplies the existing world instance to
an independently authored render-only Gun viewmodel so its reload pose
can follow that instance. Existing melee models are unchanged and all
physical muzzle/damage/ammo logic remains world-authoritative. It does
not add a gun-type condition, and an alternative F4 model can omit the port.

**Demo compatibility:** the Pistol pickup is at (3.0, 0.45, 3.0),
outside the spawn E-key radius of Bat/Shovel. This preserves D06-01
browser regression's two-item pickup sequence. Walk southeast and press E
to pick up the Pistol; use LMB/J to fire and R to reload. Ammo appears
in the HUD. The Heavy Pistol is a separate packed scene fixture, not an
additional default arena pickup.

**E2E visual capture:** tests/capture_scene.gd must generate
native-d06-gun-view-{1,2,3,5}.png, native-d06-gun-f3-projectile.png,
native-d06-gun-f4-idle/fire/reload/near-wall.png, and
ACTION5_D06_GUN_NATIVE_OK with projectile=1. The WebGL2 browser smoke
restarts its arena after legacy equipment tests, approaches the Pistol
using real WASD/E (and Q to switch from a held Bat), checks that J fire emitted **exactly one** projectile
creation event, and captures F4 idle, J fire and R reload. These
are automated rendering smoke artifacts, **not** subjective manual
inspection of grip, aim alignment and obstruction.

**Automated acceptance:** earlier gun-only [CI #42680870885](https://github.com/bravado/ACTION-5/actions/runs/42680870885)
passed 941 assertions and native/WebGL2 Full E2E. Following the
optional projectile and architectural hardening, [checks run
#42729829975](https://github.com/bravado/ACTION-5/actions/runs/42729829975)
passed **958 assertions, 0 failures**, including a camera-free NPC,
reload overlay ownership and world-owned projectile teardown. An earlier
expanded browser run [#42728334557](https://github.com/bravado/ACTION-5/actions/runs/42728334557)
failed because its fixed-time WASD sequence selected the Bat rather
than reaching the distant pistol; the browser scenario now uses bounded
real-input movement/pickup attempts and requires latest-head Full E2E.
Manual review of F1–F5 visual gun alignment, F4 grip/reload/tracer,
near-wall obstruction and F5 directional aim remains required before merge.

**Testing and handoff:** tests/d06_gun_suite.gd is registered with
tests/run_all.gd and covers shots, body exclusions, obstruction, reload
across views, alternate gun scene and cleanup. The 958-assertion headless suite passed; the latest extended Full E2E
and real manual visual review remain separate acceptance gates. Do not
close issue #14 based on documentation or screenshots alone. No release approval or issue closure is implied.

---

## Component responsibilities

`Action5WeaponDefinition` (Resource) contains immutable weapon ID,
display name, socket ID (`right_hand` by default), grip offsets, a list
of existing D05 `AttackDefinition` resources and an optional
camera-local F4 scene. `Action5Weapon` (Node3D) is the physical instance
and holds any future per-item mutable state; its action port forwards
a configured attack to `CombatController.request_attack()`.

`Action5EquipmentController` (Node3D) owns a small inventory, distance
check, equipped selection, swap/drop and generic register/unregister of
that weapon's attacks. **Equip is transactional:** new registrations
are staged and all rejected/partial registrations rolled back before
any prior item, signal or F4 visual is changed. Distinct carried weapons
must have distinct `attack_id` values, preventing destructive active-ID
replacement. A failed first auto-equip publishes neither pickup nor equip;
a successful first pickup emits exactly one `weapon_picked_up` **before**
`weapon_equipped`, after committing. It asks a replaceable `get_mount(socket_id)`
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

The checked-in, MIT-licensed training rig has **three dedicated world-space
skeletal attack clips**: `bat_vertical` (an overhand downward chop),
`bat_horizontal` (a torso-driven lateral sweep) and `shovel_overhead`
(a deliberate two-arm overhead strike). Each has seven articulated
keyframes and moves the same right-hand socket and physical weapon used
by F1/F2/F3/F5. These clips play through the existing upper-body
AnimationTree channel, preserving locomotion in the legs and keeping D05
hit timing authoritative. F4 uses separate first-person grip profiles
for camera framing, not a second gameplay weapon. No attack reuses
the unarmed Punch/Kick clip. The demo also regenerates an alternate
skeleton with independently renamed copies of these clips.

To create another weapon, import/author its 3D world animation on the
character rig, map the stable action key to the actual clip in that
rig's `SkeletonProfile.clip_map`, then set the attack's
`animation_key` to the logical key and `animation_channel = 0`.
Author an optional separate `visual_action_key` and F4 grip profile.
No type-specific branches or runtime bone hacks are needed.

The current sample arena places both pickups near the starting point.
Weapon pickup is a proximity interaction (not a physics impact or
complex inventory system). Drop restores the same Node3D to the world.

## Add a melee weapon without changing core code

1. Create an `Action5AttackDefinition` with a unique ID, attack ticks,
   hitbox size/forward offset, damage, knockback and a **dedicated mapped
   world animation** key/channel present in the actor's SkeletonProfile.
   The clip must animate the mounted hand/socket; do not use `punch` or
   `kick` as a stand-in for weapon swings. Set its
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

**Destruction semantics:** equipped/stowed weapons have a narrowly scoped
`tree_exiting` listener. Intentional equip/stow reparent operations are
ignored; separately freed weapons promptly clear selection, combat IDs,
F4 visuals and inventory references. On actor/equipment destruction,
all still-owned items are destroyed with their owner, with no unsafe
reparent during Godot's tree-exit notification. **Drop a weapon before
removing its actor if the world item should survive.** NPCs use the same
lifecycle with no first-person presenter. The controller owns no
camera, movement, animation or weapon-type behavior.

D06-02 should add a Gun instance with its own ammo, reserve, reload and
cooldown state. Bind its per-instance effects to the existing equipment and
D05 action lifecycle signals; route reload via a small optional
**weapon-command input adapter**, not special cases in generic combat input
or equipment. Configure a D05 AttackDefinition with
`use_melee_hit_query = false` and subscribe to the existing
`attack_phase_changed(..., "active", ...)` signal to resolve its ranged
effect. Gun must consume an already-resolved world aim target and trace
from its physical socket muzzle, excluding the shooter and blocking
shots through world geometry. A clear camera ray is never enough to
damage a target. Gun effects must not rely on D05's melee box hit test.

## Verification

- `tests/d06_equipment_suite.gd` covers configured Bat/Shovel/third-weapon
  attacks, real hits, ownership, F4 profiles, static hit dedup, active
  cancellation, shadows and NPC mounting without CameraRig.
- `tests/d06_hardening_suite.gd` injects a rejecting registration port
  **after** a successful staged attack, asserts atomic rollback and signal
  stability (including failed first pickup and successful pickup → equip
  signal ordering), rejects colliding IDs, frees stowed/equipped items directly,
  tears down actor inventories and checks real F4 model/shadow cleanup.
- `tests/d06_fast_swing_suite.gd` uses D05's actual physics query with
  fast actor and target crossings, grazing active-window contacts,
  self-hit filtering and per-target hit deduplication. The physics
  `CombatController` interpolates moving hitboxes, while `Hurtbox`
  exposes its previous physics position to cover a target that traverses
  the box entirely between consecutive samples. Neither reads a
  weapon's visible mesh or camera pose.
- `tests/d06_movement_view_suite.gd` uses an independent real demo
  arena to test Run/Jump/Crouch, F3→F4→F5 mid-attack,
  socket/actor identity, swap cancellation and shadow teardown.
- `tests/capture_scene.gd` captures world clips in F1/F2/F3/F5 and
  authored F4 actions. `ci/browser-smoke.mjs` sends real LMB/RMB/J/K
  for **both** Bat and Shovel in F2/F4, captures the F4 poses and checks
  that pointer capture never leaves the arena dark.

Run `make check` for import, assets and headless tests, plus
`make run build RUN_ARGS="--headless --quit-after 20"` to check the
native/Web exports. The release matrix (native Xvfb screenshots and real
Playwright WebGL2 browser input) is implemented by
`.github/workflows/godot-ci.yml`: add `[full-e2e]` to the latest PR
commit to run it. Review native and WebGL2 screenshot/log artifacts,
including narrow/wide viewport and near-wall images. **PR #31 passed**
908 headless assertions, native/WebGL2 Full E2E and owner visual review
on 2026-11-09. Issue #13 closes upon squash merge of that tested PR.

**Projectile feature checks (draft PR #32):** the expanded
`tests/d06_gun_suite.gd` checks the true muzzle-to-impact endpoints,
wall-truncated rays, one spawned visual per real shot, 3D layer/collision
isolation, finite cleanup, alternate color/scene and dry/cancelled no-op.
Native and browser in-flight screenshots are part of the opt-in Full E2E
pipeline. Manual visual acceptance is still required.


### F4 projectile visual muzzle alignment (PR #32 correction)

The real world `Gun/Muzzle` remains authoritative for raycasts, health
damage, ammunition and wall blocking in **all** views. In F4 the weapon
model is camera-local, so using that skeleton-mounted world muzzle for
the visible tracer appeared to fire from behind the player. Each F4 gun
scene now authors a `Grip/VisualMuzzle` Marker3D at the rendered barrel tip,
moving with the articulated Grip. The optional
`EquipmentVisualAdapter.get_projectile_visual_origin(weapon, fallback)`
returns that point **only** while the matching local viewmodel is active
in first person. The optional `GunProjectilePresenter` gets the
actor-local provider through its configured
`visual_origin_provider_path`; every other view, camera-free NPC,
unequipped weapon or absent viewmodel uses the **physical** world muzzle.
The destination remains the real world-muzzle hit position. There is no
F4 aiming/collision/damage rewrite and no second gameplay gun. Both
Pistol and Heavy Pistol scenes include independently authored markers;
the reusable addon does not import either demo scene. See ADR-0006.
