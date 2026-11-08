# D05 — Unarmed combat, health and hit resolution

One world, one actor and one action clock regardless of camera. Combat is
**not a movement state** and never owns `CharacterBody3D.velocity`. The
D05 demo offers **left mouse / J / gamepad X = Punch** and
**right mouse / K / gamepad Y = Kick**.
Both can be performed while walking, running or jumping. The nearby training
targets have a body hurtbox and an overlapping head hurtbox for hit dedup tests.

## Components

- `Action5CombatController` (a child of an actor) registers arbitrary
  `Action5AttackDefinition` resources. It owns the active attack, its
  physics-tick counter, a one-command buffer, and per-swing hit history.
  Actions can also be requested from AI with `request_attack(id, direction)`.
  An explicit finite world-X/Z direction sets the attack heading; a zero
  or omitted direction reuses the controller's previous attack heading
  (initially world north, X/Z = `(0, -1)`). No Visual/Facing child,
  presenter or camera lookup is involved. AI should pass a direction
  whenever it intends to change aim. The controller emits gameplay
  events; it does not reference any renderer.
- `Action5CombatAnimationAdapter` optionally subscribes to combat lifecycle
  and Health damaged/died events. Only this adapter invokes the generic
  animation set/clear API. It selects upper/full-body channels from the
  attack definition and owns configurable hit/death visuals. Removing or
  replacing it does not interrupt gameplay.
- `Action5Health` stores HP, team, block, immunity, post-hit invulnerability,
  stagger and death. `can_receive_hit(source, attack)` is an overridable hook.
  `take_hit()` emits `knockback_requested(world_velocity, duration_ticks)`
  for a nonlethal pushed hit, or `died(source)` on a lethal hit. It never
  finds a parent actor, accesses `Locomotion`, or changes body motion.
- `Action5HealthActorAdapter` is an **optional actor-local signal subscriber**
  connecting the Health event stream to the existing generic
  `Locomotion.apply_external_impulse()` and `Actor.set_alive(false)` ports.
  It has configurable NodePaths and no attack-specific branches. Remove it
  for a stationary target, or replace it for another type of receiver;
  Health remains fully functional without it. Removing the adapter
  disconnects both signals.
- `Action5Hurtbox` is an `Area3D` with a collision shape; multiple areas
  can reference **the same** Health, without duplicating damage.
- `Action5AimProvider` resolves a finite X/Z melee facing vector, preserving
  independent right-stick aim and F5 4-/8-way quantization. It also offers a
  full **3D** `camera_ray()` and `camera_target()` for future ranged
  equipment. Muzzle-to-target obstruction checking belongs to D06.
- `Action5ActionInputContext` is a typed, view-independent-by-convention
  **read-only snapshot** containing current world aim, facing, view mode,
  active camera and whether action input is allowed. The existing
  `ActorInputAdapter.get_action_input_context()` constructs it from its
  *own* actor/input state; consumers never traverse Locomotion/Facing nodes.
- `Action5CombatInputAdapter` reads raw combat button edges and consumes
  `get_action_input_context()` from a configurable `context_source_path`
  (default: `../ActorInput`). It knows only the method and snapshot type,
  not the concrete ActorInputAdapter, ViewManager, actor, locomotion or
  facing classes. Substitute a different provider implementing the same
  method without changing combat. Missing/disabled providers fail closed
  and require **release-to-rearm** to prevent deferred attacks.
  Attack definitions configure default keyboard, gamepad and optional mouse
  bindings, preserving user InputMap overrides. Mouse clicks must reach
  `_unhandled_input()`, so GUI-consumed clicks cannot attack.
  AI can request actions directly and does not require this adapter.
- `Action5Locomotion.apply_external_impulse(world_xz_velocity, duration_ticks)`
  is a generic, decaying knockback/wind/push command. Only the locomotion
  solver writes the physical velocity and calls `move_and_slide()`.
  The impulse contributes a bounded, linearly decaying planar velocity
  once per physics tick; it is removed from the following tick's locomotion
  input rather than accumulating across ticks. Wall collision normals
  remove blocked impulse components to prevent an artificial rebound.
  Side-view lane Z is projected out; stop/death clears it. View changes
  do not clear it.

## Timeline and collision contract

Attack duration is **physics ticks, not animation frames**. For
`startup_ticks = S`, `active_ticks = A`, `recovery_ticks = R`:

| Zero-based tick indices | Phase |
|---|---|
| `0 .. S-1` | Startup, no hit queries |
| `S .. S+A-1` | Active, query authored box hit shape each physics tick |
| `S+A .. S+A+R-1` | Recovery, no hit queries |
| `S+A+R` | Attack is already finished; the next buffered action may start |

Press **B** in the demo to toggle a translucent 3D hitbox: **blue** during startup/recovery and **red** during active ticks. The on-screen HUD reports the actor's HP, current attack ID, phase and elapsed physics tick. Rendering is debug-only and has no effect on collision or damage.

Hitboxes are configured world-space shapes, never animated mesh collisions.
`intersect_shape()` queries only layer **2** monitorable Area3D hurtboxes.
The hit shape is placed by an actor-local attack heading, independent of
camera and animation. A single attack keeps a set of **Health instance IDs**:
two hurtboxes for the same victim still produce **one** damage application.
Target filters reject the source's Health, same nonzero team (unless the
definition opts into friendly fire), immune/blocked targets, and targets in
invulnerability. Successful hits may stagger the victim and request an
external impulse through a Health signal. When an actor bridge is installed,
it forwards that request to locomotion. Lethal hits emit `died`, which the
bridge turns into `set_alive(false)`; the combat controller independently
cancels current and buffered attacks from the same Health signal. Targets
without locomotion or an actor bridge still take damage and can die.

The original training model's **faster, articulated** clips are now 0.25 s
for Punch (15 physics ticks) and 0.333 s for Kick (20 physics ticks).
Both use independently skinned elbow/forearm bones; the kick additionally
chambers its knee before foot extension, and the action-resource timing
matches the seven keyed animation poses. An imported replacement model may
remap its clips without changing the combat controller.

The optional `CombatAnimationAdapter` listens to
`attack_started`, `attack_finished`, `attack_cancelled`, `damaged`
and `died` signals. It selects existing D04
`set_upper_body_action()` / `set_full_body_action()` and clears them
on completion/cancellation. Punch uses the upper body to allow Run+Punch;
Kick uses the full body. Reaction clips default to `hit` and `death`
but are configured on the adapter, not the combat controller.
**Visuals never control damage timing** and neither CombatController nor
the generic AnimationPresenter has per-attack branches.

## First-person authored viewmodels (F4)

D05 F4 is now **a separate, data-driven presentation**, not a scaled
third-person Skeleton3D limb. The old approach produced oversized circular
end caps and unstable framing. The existing `FirstPersonPresenter` still
owns world-body culling and shadows; a different component
(`FirstPersonCombatLimbs`) registers camera-local viewmodel visuals on
layer 19. No new gameplay state or attack clock is created.

`CombatVisualState` implements one tiny visual snapshot interface:

```gdscript
get_visual_action() -> Dictionary
# {} when idle; otherwise {"key": StringName, "progress": float 0..1}
```

The adapter converts CombatController's authoritative physics ticks to
normalized progress. The viewmodel presenter depends **only** on the
snapshot interface and the generic first-person registration port;
it never imports CombatController, Actor, Skeleton3D or any move class.

- `first_person_punch.tres`: right arm/fist **visible throughout F4**.
  Five camera-space poses: rest → chamber → extension → recoil → rest.
  The upper arm begins **off the lower-right screen edge**, so there is
  no floating shoulder cap: elbow and fist remain in view throughout
  the animation, including at wider FOV settings.
- `first_person_kick.tres`: right thigh/knee/shin/boot visible **only
  while kicking**, six poses with a knee-first chamber and forward
  extension. The knee and foot remain in the lower part of the image.
- `Action5FirstPersonPoseKey`: normalized time, shoulder/hip, elbow/knee,
  wrist/foot and optional end rotation in local **metres**, not
  imported bone offsets or camera-relative scale multipliers.
- `Action5FirstPersonLimbGeometry`: **replaceable demonstration renderer**
  using slim, rounded CapsuleMesh pieces and one end mesh. Replace with
  an authored skinned viewmodel scene by assigning a `viewmodel_scene`
  implementing `configure(profile)` and `apply_pose(progress)`.
  It owns **no** combat rules and casts no additional shadows.

F4 hides the world body mesh but does not hide the world rig, socket
equipment, animated shadow casters or NPCs. The legacy camera-local
fake forearm/tool asset was removed; the world training prop remains
attached for other views. View changes never reset the actor, its
animation clocks, hitboxes or action state. The viewmodel only reappears
at the current progress when F4 is re-entered.

**Add an attack:** create a new `Action5AttackDefinition` + normal D04
clip mapping, then create a matching `Action5FirstPersonLimbProfile`
and a handful of `Action5FirstPersonPoseKey` subresources.
Add the profile to `FirstPersonCombatLimbs.profiles`. No switch cases,
bone-name assumptions, changes to movement/camera/animation/combat cores,
or duplicate gameplay animation controller. Other view types continue
rendering the full imported world character. See
[first-person architecture and research](first-person-presentation.md).

## Add a new attack without editing core classes

1. Duplicate `demo/combat/punch.tres`, choose a **unique**
   `attack_id`, author startup/active/recovery ticks, damage, `hitbox_size`,
   `hitbox_forward`, `hitbox_height`, knockback and stagger.
2. Choose `animation_key` (and `animation_channel`: upper = 0, full = 1).
   For custom clips, configure `SkeletonProfile.clip_map` and import the
   animation. The shared profile requires only Idle; configure combat
   mappings and `required_clips` in the game's own profile when they
   must be present. Missing optional clips fall back gracefully. The
   optional animation adapter automatically reads the same definition.
3. Set an optional `input_action`, `default_key`,
   `default_mouse_button` and gamepad button.
   Add the resource to the actor's `CombatController.attacks` list. The
   standalone CombatInputAdapter registers its InputMap default only if
   the user has not already bound the action.
4. Or call `register_attack(definition)` at runtime from any component;
   the `attack_registered` signal registers optional input defaults. AI or
   gameplay code calls `request_attack(id, Vector2(world_x, world_z))`.
5. Give targets one or more `Action5Hurtbox` Areas on collision layer 2
   with shapes and a `health_path` pointing at their Health component.
6. Add a real-physics test with a third, independently authored definition:
   prove precise active-frame hits, miss by range, multi-hurtbox dedup,
   camera-switch continuity, cancellation and the focus release gate.
   Run `make test` and `make build`; inspect a native and Web rendered
   animation (headless assertions alone are not visual verification).

**Extension invariant:** adding an attack must not edit
`Action5Actor`, `Action5Locomotion`, `Action5MovementController`,
`Action5ActorInputAdapter`, `Action5AnimationPresenter` or
`Action5CameraRig`. The one D05 locomotion change adds the **generic
external impulse port**, not an attack-specific branch. The combat
controller knows only definitions and shared Health/Hurtbox interfaces.

## D06 handoff

D06 weapons should own their per-instance ammo/reload/equipment state and
supply attack definitions to the existing combat runner. Equipment
presentation uses D04 animated hand sockets and FPS world-visual
registration. Ranged fire resolves a 3D camera target and separately
traces from the muzzle; a camera-clear ray alone never authorizes damage.
No Bat/Shovel/Gun ID dispatch belongs in these shared D05 classes.

## Verification

`tests/d05_combat_animation_suite.gd` exercises a replaceable recording
renderer, combat with no animation adapter, late attachment and removal,
cancellation, hit stagger and death. `tests/d05_suite.gd` also exercises
standalone Health without an Actor/Locomotion hierarchy, typed knockback and
death events, adapter detachment/reattachment, and actor death forwarding.
It exercises replaceable aim-context sources, denied/missing source
handling, and no stale buffered inputs after restoration, plus
exact phase-boundary signal ticks,
independent Punch/Kick/third action registration, all five views, 3D aim,
F5 directional choice, near/far hit geometry, overlapping hurtbox dedup,
teams, blocking, immunity, external impulse lifetime, focus release gate,
active-view switching and death. The existing import-first CI additionally
runs native and Web exports and WebGL2 view smoke. See PR #28 for
run-specific results and limitations.
