# Agent Instructions — ACTION-5

Read `PLAN.md` completely before implementing anything. Follow D01–D12 and their explicit exit gates. **D01–D09-02 are implemented:** D06 supplies Bat/Shovel/Gun equipment, D07 supplies camera-independent NPC AI, D08 supplies the persistent world and physical gate/portals, and D09-01 supplies the playable EXIT reference, HUD and view-local controls. **D09-03 HUD is ready for review on PR #38; pending manual visual acceptance, then D10 opt-in diagnostics and validators.** Keep D08 world/scene policy outside reusable Actor, Movement, Combat, Equipment, AI and Camera core components. Standalone move examples remain optional and independently testable.

## Product invariant

There is exactly one 3D game world and one authoritative player actor. Camera switching changes input mapping, aim policy, presentation, camera projection/transform and view-specific UI **only**. It must never recreate, reset, teleport or replace the game actor, reload the scene, or duplicate damage. Use camera3D and normal Godot rendering, not a custom renderer.

## Baseline

- Pin Godot **4.7.2 stable** and matching export templates.
- GDScript, Compatibility renderer, 60 Hz physics, `.glb`/glTF characters.
- Browser (WebAssembly/WebGL 2) and native Linux/Windows/macOS are required release targets.
- Godot 4 C# runtime is excluded. Prefer standard Godot nodes over third-party runtime dependencies.
- X = horizontal, Y = vertical/gravity, Z = depth.
- Five view profiles: F1 Side, F2 Beat'em up, F3 combined tilted Isometric / close over-the-shoulder (one orthographic resource, zoom-dependent), F4 First person, F5 true-overhead Top-Down (NES Commando/Zelda).
- Both native and Web use number row **1–5 as primary**; optional F1–F5 secondary, with mandatory five-mode selector in Web. Ctrl+number is browser-reserved, not a safe fallback.
- All shipped code/content must be license-compatible and sourced.

## Local development and CI

**The supported workflow is import-first using GNU Make**:

- `make import` regenerates the local Godot registry/resource imports.
- `make run` imports, then launches the game; `make editor` opens the editor.
- `make test` imports, runs Godot headless tests and checks parser/runtime logs.
- `make check` also verifies reproducible GLB fixtures; it is the local equivalent of the quick PR CI checks.
- The `ACTION-5 CI` workflow uses stable jobs `CI / Checks` (always) and `CI / Full E2E` (conditionally skipped on ordinary PRs). Full native/WebGL2 E2E runs on pushes to `master` or when the latest PR commit has `[full-e2e]`. Request full E2E before merging a visual-sensitive feature; both checks are required on `master`.
- `CI / Deploy Pages` publishes only the successfully E2E-tested `build/web/` export on pushes to `master`. Never deploy from PRs, workflow_dispatch or failing tests; don't add the deploy job to required PR status checks.
- `make web`, `make linux`, and `make build` import before exporting.
- The Makefile must fail closed on Godot errors and retain `.godot/` as a generated, ignored cache.
- CI must exercise Makefile targets rather than maintaining a conflicting implementation of the import/build steps. Do not add a requirement to commit the generated class registry.
- Use Node.js 24-native GitHub Actions for checkout, artifacts and Pages (including roadmap sync). Full E2E uses Playwright's headless Chromium shell to avoid downloading a headed browser. Do not shorten gameplay/render waits solely to reduce CI minutes; preserve genuine WebGL2 regressions.

## Working cycle

1. Check current repository and existing completion records; identify next incomplete DXX.
2. Make a small implementation checklist; do not overbuild or skip ahead.
3. Add automated tests and a runnable scene demonstrating the feature.
4. Run actual pinned Godot headless import/test and real native/web smoke where possible.
5. Document exact results, manual visual checks, limitations and blockers. If not run, state NOT VERIFIED.
6. Keep `addons/action5/` demo-independent; update API and ADR docs for design changes.
7. Make a coherent commit/PR with the DXX prefix and the required handoff template from PLAN.md.
8. Do not mark the deliverable finished until all its acceptance criteria pass.

## Prohibited shortcuts

- Don't replace real tests with TODOs or hardcoded pass output.
- Don't claim that headless test execution proves rendered correctness.
- Don't use detailed mesh collision to decide punching/kicking/weapon damage.
- Don't reset attack/weapon/AI state on view changes.
- Don't read raw keyboard input in Combat, Actor or Weapon classes.
- **Player moves are plug-in nodes:** adding a move must not require new `is_x` flags, per-move branches or concrete imports in `Action5Actor`, `Action5Locomotion`, `Action5MovementController`, `Action5ActorInputAdapter`, `Action5AnimationPresenter` or `Action5CameraRig`. Follow **[`docs/adding-moves.md`](docs/adding-moves.md)** for the complete extension contract. Only Locomotion writes physical velocity and calls `move_and_slide()`.
- Preserve distinct grounded/airborne fallback and verify custom moves register through their own script and InputMap defaults without modifying core code.
- **Move authoring checklist:** implement `Action5Move` hooks; install unique stable IDs under `Moves`; use `Action5MoveContext` X/Z commands, not body velocity writes; submit edge-triggered requests; respect priority and one arbitration winner per tick; restore colliders/resources in `exit()`; map authored clips using `SkeletonProfile.clip_map`; configure optional F4 eye height in `EyeHeightPresenter.move_offsets`, not camera branches; cover runtime registration/removal, disable/death cleanup, view switching and native/WebGL2 rendering.
- **Animation/attack separation:** the existing animation presenter selects custom movement clips by registered move ID; authored looping clips must be imported as loops. Attack timing/damage/weapon logic belongs to separate components, not movement or animation state checks. No view switch may reset the actor or gameplay.
- Don't assume F1/F5 or Ctrl+number shortcuts can be caught in web browsers; the visible five-button selector is required.
- F1 is a genuine Mario/Altered Beast side-scrolling projection: camera screen plane is world X/Y (zero pitch, fixed world -Z view). Do not confuse F1 with the elevated X/Z beat'em-up view F2 or rotate F1 toward the actor during follow.
- F3 is the **one combined isometric/third-person shoulder profile**: wide and close zoom share a resource and Camera3D. Do not bring back a separate F4 third-person profile, and do not turn F3 into a perspective camera on zoom.
- Do not collapse F3 tilted isometric and F5 true vertical overhead into one view profile.
- Do not project camera-forward onto X/Z for F5; it is zero at 90-degree downward pitch. Use projected camera-right/up or explicit world axes.
- Do not hardcode facing quantization into the combat core: F5 supports optional Zelda-style 4-way sword attacks, Commando-style 8-way shooting and independent aim.
- Don't claim deterministic rollback support from using a fixed physics tick.
- Don't introduce proprietary assets, unverified packages, or unnecessary engine plugins.

## Camera-local combat visuals

**Do not map third-person joint translations directly into camera space.**
Godot bone global poses are skeleton-local, and the character's rest pose
was never meant to be a first-person camera rig. The old approach created
huge cylinder caps and off-screen knees.

The actor/world rig and physics always exist. `FirstPersonPresenter`
owns culling and shadows (layers 20 and 19); it never branches on
attacks. `CombatVisualState` adapts the authoritative combat timeline
to a generic `{key, progress}` snapshot. `FirstPersonCombatLimbs`
consumes that snapshot and displays independently authored camera-space
`Action5FirstPersonLimbProfile` + `Action5FirstPersonPoseKey` resources.
The replaceable `Action5FirstPersonLimbGeometry` is **visual only**.
Do not introduce attack IDs in shared movement, camera, animation or
combat components. Third-person clips are still D04 imported-world
animations; F4 viewmodel clips have their own camera-local framing.
To add an action, configure definitions and visual profile; no core edits.

Test F4 idle arm, chamber/contact/recoil, lower-third knee/foot framing,
action cancellation, F3↔F4 continuity, custom third-attack registration,
world rig/culling/shadows, all 5 views, near-wall and crouch/jump,
native screenshots and WebGL2 rendering.
See [docs/first-person-presentation.md](docs/first-person-presentation.md)
and ADR-0004.

## D05 Health integration boundary

`Action5Health` must never depend on a concrete Actor or Locomotion node,
relative tree position, physics controller or renderer. It owns HP,
invulnerability, block/stagger and emits knockback/death events only.
`HealthActorAdapter` owns the optional wiring to `set_alive(false)` and
`apply_external_impulse()` and must be safely detachable. Test with a
standalone Health under a plain Node and without any actor or movement node.
Other receivers may implement their own subscriber; never add
actor/movement-specific branches to Health.

## D05 visual adapter boundary

`CombatController` never imports or calls AnimationPresenter and owns
no hit/death clip names. An optional `CombatAnimationAdapter` subscribes
to combat and health signals, converts definitions into generic full- or
upper-body animation calls and owns reaction visual lifetimes. The adapter
can be omitted or replaced without touching gameplay, camera or core
animation classes. Test cancellation, stagger expiry, death and late
visual attachment using a recording substitute. See docs/combat.md.

## D05 action input context boundary

`Action5ActorInputAdapter.get_action_input_context()` is the only
bridge exposing current world aim/facing, camera/view mode and control
availability as an `Action5ActionInputContext` snapshot. Combat input
consumes a duck-typed `context_source_path` provider of this method;
it MUST NOT import ActorInputAdapter or ViewManager or traverse
`actor.locomotion.desired`, `actor.facing`, or other private actor
hierarchy. Unknown/missing providers fail closed. A test-only provider
with no actor reference must support real attack requests; swapping
providers during runtime must not replay blocked commands. No
combat-specific branch is allowed in the core input adapter.

## D05 mouse combat input

Punch/Kick default to left/right mouse buttons alongside J/K and gamepad.
Attack resources declare `default_mouse_button`; CombatInputAdapter
registers a generic InputEventMouseButton if the action is not user-mapped.
Mouse presses must reach unhandled input before triggering combat so
clicking view/settings buttons does not also attack. The view/camera and
movement cores never branch on specific attack names or buttons.

## Shared skeletal animation defaults

`Action5SkeletonProfile` is independent of weapons, attacks and reactions:
its default `clip_map` contains only idle/walk/run, and the sole required
clip is Idle. Combat clips and their validation requirements belong in the
actor's configured profile, e.g. `demo/assets/crouch_skeleton_profile.tres`
requires its authored Punch/Kick/Hit/Death animations. Never add action or
weapon IDs to shared profile defaults; custom moves and actions extend
`clip_map` via data and use the generic animation presentation ports.
`tests/d04_suite.gd` covers both generic and demo-specific validation.

## D05 heading fallback and merge verification

CombatController never inspects a child named `Visual` or reads an animation,
camera, facing or movement component to infer attack direction.
`request_attack(id, world_xz_direction)` uses a finite supplied direction;
an omitted/zero direction retains the controller's last resolved attack heading
(initially X/Z = (0, -1)). Input/AI providers are responsible for resolving
view-appropriate aim before requesting an attack. A standalone
CharacterBody3D with a CombatController must pass the same behavior without
any `Visual`, Facing, Locomotion, Health or camera nodes.

D05 merge review includes `make check`, a third attack via resources, standalone
Health, optional HealthActorAdapter and CombatAnimationAdapter lifecycle,
a replaceable ActionInputContext provider, resource-only clip requirements,
mouse click/UI suppression, bounded knockback and native/WebGL2 limb evidence.
Use the current `CI / Checks` and `CI / Full E2E` jobs; request the latter
with `[full-e2e]` in the latest PR commit. Passing automated rendering tests
does not replace a human visual assessment where required by PLAN.md.
Do not mark D05 complete or merge it on the strength of earlier commit CI.

## D05 attack authoring

Follow [docs/combat.md](docs/combat.md) and ADR-0003. New attacks use an AttackDefinition and the existing CombatController/CombatInputAdapter request contract: never add attack-name branches to Actor, Locomotion, MovementController, ActorInputAdapter, AnimationPresenter or CameraRig. Combat owns physics-tick startup/active/recovery, mutable hit history, and Health/Hurtbox filtering. The only generic locomotion integration is apply_external_impulse; no combat code writes CharacterBody3D.velocity. Input edges must release-to-rearm through focus/settings interruption. Tests must prove new third-attack configuration and dedup across multiple hurtboxes before D05 is accepted.

## D06-01 weapon and equipment extension contract (implemented and verified)

Read [docs/equipment.md](docs/equipment.md) and ADR-0005 before modifying D06.
An equipped world weapon is one `Action5Weapon` instance. An immutable
`Action5WeaponDefinition` describes its socket, independent attacks,
world appearance and optional F4 scene; no ammo or mutable state in Resources.
`Action5EquipmentController` handles only inventory/selection/lifecycle.
`EquipmentVisualAdapter` resolves the generic `get_mount(socket_id)`
port, tracks world-mesh/shadow registrations and creates at most one
render-only F4 viewmodel. Weapons and the equipment controller must never
inspect view modes, camera/FPS render layers, named specific weapon types,
AnimationPresenter or FirstPersonPresenter internals.

D05's generic `register_attack` / `unregister_attack` pair supports
equipment lifecycle; unequip must cancel an active or buffered weapon
attack before removing it. `AttackDefinition.use_melee_hit_query`
defaults to true for D05/Bat/Shovel; set it false on an externally
resolved action such as Gun fire, then observe the existing active-phase
signal for physical muzzle tracing. No type-specific hit branches. Equipped weapons
provide attack definitions to D05 and request action IDs; they do not
execute a second attack timer, own hit queries or read raw inputs.
Attack input is resolved by the optional, duck-typed
`EquipmentAttackSelector.get_attack_for_input(action, fallback)` policy.
Each equipped attack explicitly sets `AttackDefinition.input_action` to
claim its corresponding InputMap action; `Action5Weapon.get_attack_for_input`
provides the configured match. **Missing assignments retain the original
unarmed Punch/Kick, even when equipment is held.** There is no positional
action replication or hardcoded LMB/RMB index mapping. One equipment action
may claim `actor_punch`; a different one may claim `actor_kick`.
Duplicate nonempty bindings within a definition are invalid.
Do not add an F-only swing key or equipment-specific branches to
CombatInputAdapter; it sees only this optional selection port.

An equipped F4 viewmodel must include an authored **gripping arm and
weapon** that move together. `AttackDefinition.visual_action_key`
optionally identifies the F4 pose independently of the world
`animation_key`; if blank it falls back to the original D05 action key.
Bat configures two independent attack definitions and visual keys:
LMB/J vertical `bat_swing` and RMB/K horizontal `bat_horizontal`.
Shovel keeps one attack on LMB/J, leaving RMB/K as Kick.
The viewmodel may export `action_profiles` to choose alternate authored
`Action5FirstPersonLimbProfile` poses using the visual action key,
while reusing a single hand and Grip. The same generic visual bridge
routes keys/progress; no weapon-specific presenter or second clock.
The demo rig now includes dedicated skinned world clips
`bat_vertical`, `bat_horizontal` and `shovel_overhead` mapped by
`SkeletonProfile`; F1/F2/F3/F5 must use those clips (with animated
right-hand sockets), not substitute the unarmed Punch/Kick visual.
To add a new weapon, author/import its world clip, map the logical key
in the actor's SkeletonProfile and configure its attack resource.
The alternate rig fixture must map/retarget the same logical key.
The F4 profiles remain camera-local and consume the same D05 clock. Suppress the original
resting/unassigned fist using the optional action-aware limb-visibility
policy while equipped; an unassigned Kick must still show its F4 leg.
Use the optional `get_visual_action().action_id` for exact ownership
when equipment shares an unarmed world animation key; preserve
backwards compatibility with `{key, progress}`-only visual sources.
Do not rotate a floating entire tool independently or use skinned
world-bone positions to place the local hand.

**Pickup event atomicity:** on a failed initial auto-equip, roll back inventory and emit neither `weapon_picked_up` nor `weapon_equipped`. On a successful first pickup emit each signal exactly once, in **pickup → equip** order. A failed swap cannot produce unequip/equip events. This protects HUD and AI listeners from phantom state; extend `tests/d06_hardening_suite.gd` for every new failure path.

Stowed and equipped weapon instances retain exclusive equipment ownership:
another actor cannot claim a stowed world-group node. A successful drop
releases it. **Equip/swap MUST stage every candidate attack registration
before stowing the previous weapon; partial failure rolls back staged IDs
without unequip/equip signals.** IDs must be unique across carried
weapons, so a collision rejects the swap without cancelling an
existing timeline. Unregister only the matching active/buffered attack;
never cancel an unrelated action just because an equipped attack was queued.
Observe independent `tree_exiting` only for actual destruction, never
for internal reparenting; cleanup must remove inventory, attack IDs, F4
meshes and world shadows. Actor removal destroys carried weapons;
drop first if they should persist as world pickups. Do not reparent
children synchronously during `_exit_tree()`.
If a weapon lacks a usable F4 viewmodel, keep its actual world meshes and
the default F4 hand visible; only cull world meshes after a valid visual
replacement is installed. Prove all three invariants with two-actor and
mid-action regression tests, not weapon-ID branches.

Test Bat, Shovel and a third fixture with different attack data, all five
views, F3/F4 mid action, click routing, return to unarmed on drop,
gripped F4 weapon contact pose, teardown/shadows and an NPC without
local first-person presentation. VT-08 must test fast actor AND
receiver crossings using authoritative physics hurtboxes, not the
world or first-person mesh. Use the separate D06 hardening fixture to
inject a partially rejecting registration port and free equipped/stowed
items while recording signals. Test live Run/Jump/Crouch with
F3→F4→F5 during an actual swing; keyboard and mouse for Bat's two
attacks and Shovel's swing/Kick in F2 and F4. Human review includes
wide/narrow F4, near-wall poses, grip and ground shadows. Do not
remove browser scene-readability assertions merely to pass CI.

**D06-02 handoff:** reuse this controller with a Gun instance owning ammo,
reload, cooldown, a per-weapon ranged effect and a physical world-muzzle
obstruction query. Send reload through a small **optional weapon-command
input adapter**, not a Gun branch in `CombatInputAdapter`, the Actor, or
generic Equipment. Use existing equip/unequip signals to bind/unbind
per-instance effects to D05 active-phase events and test a second configured
gun. **Never** infer a valid shot solely from a clear camera ray, and never
add `is_gun` or weapon-ID switches. F5-only 4/8-way aiming belongs in a
view-specific aim policy: `AttackDefinition.facing_sectors` currently also
quantizes direction in D05 for **every** view, so do not assign retro-only
sectors to a weapon expecting continuous F1–F4 aim. See issue #14, #18 and
ADR-0005.

**D06-01 completion record (2026-11-09):** D06-01 is approved, latest-head
`CI / Checks` passed **908 assertions / 0 failures**, `CI / Full E2E`
passed native/Linux and real WebGL2 smoke (run #42668808972), and owner
visual acceptance passed. The release tests are
`tests/d06_equipment_suite.gd`, `tests/d06_hardening_suite.gd`,
`tests/d06_fast_swing_suite.gd`, `tests/d06_movement_view_suite.gd`,
`tests/capture_scene.gd` and `ci/browser-smoke.mjs`. D06-01 and its D06-01 implementation are merged; D06-02 (#14) and
D07 (#15) were completed as separate subsequent deliverables.

## Starting task

**D01–D09-02 are implemented; D10 tooling is the next development focus.** For a new movement, read [`docs/adding-moves.md`](docs/adding-moves.md) and use `addons/action5/actor/moves/crouch.gd` with `demo/player.tscn` as the reference. For a new weapon, follow [docs/equipment.md](docs/equipment.md) and ADR-0005: configure its `WeaponDefinition` and independently authored `AttackDefinition`/world clips, optional F4 viewmodel and input claims; extend the D06 tests without changing generic Actor, MovementController, AnimationPresenter, CombatController or EquipmentController. D06-02 Gun (#14) and D07 AI (#15) are merged via D06-02/D07-01 using those same established ports.
## D06-02 gun extension (merged via D06-02)

A Gun is an Action5Weapon with its own ammunition, reload and world muzzle;
D05's active attack phase is the only firing moment. The gun uses
ViewAimTargetProvider.get_world_target(), then traces from its world Muzzle,
never the F4 viewmodel; a camera-visible target must not bypass a wall.
Optional WeaponCommandInputAdapter routes per-instance reload input without
touching CombatInputAdapter or movement. The Gun first-person model uses
a generic set_visual_source() handoff from EquipmentVisualAdapter for its
render-only reload pose. A second gun config must need no shared core edits.
An equipped shot blocked by geometry still spends one round; cancelled
startup/empty magazine does not. Stowing cancels reload, preserves ammo.
Pinned Godot 4.7.2 Checks and native/WebGL2 Full E2E passed on
[CI #42809417312](https://github.com/bravado/ACTION-5/actions/runs/42809417312):
**974 assertions, zero failures**. Owner F1–F5 visual testing passed
on 2026-11-10. D06-02 is merged. Consult docs/equipment.md and ADR-0006.

## Add a projectile/tracer without affecting hit authority

Use the optional `Action5GunProjectilePresenter` child and a
`ProjectileVisual` PackedScene, configured per gun. The ONLY source is
`Gun.fired(impact, hit_receiver)`, which happens AFTER D05 has resolved
the real world-muzzle hit. Trace the visual from the actual world Muzzle
to the returned impact; no extra physics ray, hurtbox, HP, damage, ammo,
combat clock or view-mode branch belongs in presentation. An animated
bright tip/trail is intentionally not a ballistic gameplay projectile.
Never parent a tracer to the F4 viewmodel: all five views observe one
world-shot trajectory. Its top-level world scene parent must not follow or die with the gun
after firing. The gun may be reparented multiple times in its lifetime:
subscribe to `fired` in `_enter_tree()`, disconnect in `_exit_tree()`,
not `_ready()` alone. Verify no visuals for dry/cancelled shots, no
colliders, one effect per shot, automatic cleanup, physical near-wall
endpoint, and optional per-gun scene/color. See docs/equipment.md.

## Merged D06-02 architecture and D07–D12 extension handoff (ADR-0006)

Read [ADR-0006](docs/adr/0006-authoritative-gun-and-projectile-visuals.md).
A new gun needs only scene/resources and a world muzzle; no edits to Actor,
Locomotion, MovementController, AnimationPresenter, EquipmentController,
CombatController or camera classes. Gun receives a replaceable actor-local
`get_world_target(origin, range, exclude)` port, **not** a camera. The
shipped `Action5ActorTargetAimProvider` demonstrates an AI world-target
source; D07 provides the decision/nav target producer, NOT another gun
or damage clock. The optional projectile presenter always attaches visual
effects to the world scene, never the weapon, with no collider or hits.
An independent reload adapter may clear ONLY the overlay it successfully
set. D08 world props use existing physics masks, D09's F5-only 4-/8-way aim
remains a view policy, D10 validations are optional, D11 reuses the existing
runner, and D12 requires addon-only runtime installation.

**Review gates:** latest-head Godot headless checks, Linux native rendered
captures and real WebGL2 smoke must all pass (the extended in-flight
projectile scenario is required), followed by owner F1–F5 visual sign-off
and final PR review. Merely having a passing earlier-head test or a
successful screenshot capture does not constitute merge approval.


## F4 gun tracer origin contract

When a gun fires in first person, do not visually launch the tracer from
the animated full-body socket: F4 displays a distinct camera-local gun.
The optional GunProjectilePresenter obtains the start point through
an actor-local, duck-typed `get_projectile_visual_origin(weapon, fallback)`
port. It uses the local F4 `Grip/VisualMuzzle` marker only if the
matching viewmodel is active. All other modes/actors fall back to
the world Muzzle. **Never** change Gun._on_attack_phase_changed,
the world physics Muzzle or Health/hit resolution to align the visual
tracer; it must still terminate at the original world hit point. Test
both normal and alternative gun F4 markers, NPC fallback, world F1–F3/F5
fallback and native F4 emitted `from_world` equality at firing time.


## D06-02 projectile gradient authoring

The shared `Action5ProjectileVisual` uses an independent
`projectile_trail.gdshader` for the visible CylinderMesh only. Local
-Y (muzzle-side tail) has higher emission/opacity; local +Y (toward the
impact) fades; lifetime transparency is a separate presentation
uniform. Preserve the existing noncolliding world-owned visual, F4
camera-local visual origin, all other view/AI world origin fallbacks and
unchanged authoritative hitscan. For another gun, configure exported
trail brightness/opacity and `projectile_color` on its scene. Do not
modify Gun, Combat, equipment or camera logic for visual styling.


## D06-02 physical ray receiver

A hit from the physical world Muzzle always stops at the first collider.
With ray layers 1+2 the collider may be the actor's solid
`PhysicsBody3D` rather than its own Hurtbox Area. Resolve this as an
authorized receiver only through an active `Action5Hurtbox` descendant
that explicitly maps to the same body's `Action5Health`. Never retry
the ray past unrelated wall geometry, accept any bare Health child as
damageable, or change camera-local projectile origin/hit authority.
Maintain the real `CharacterBody3D` receiver integration regression
covering body-first collision, solid wall obstruction, ally filtering
and disabled Hurtbox before merge.


## D06-02 verified/merged baseline (2026-11-10)

D06-02 has 974/974 pinned Godot assertions, passed native and WebGL2
Full E2E ([run #42809417312](https://github.com/bravado/ACTION-5/actions/runs/42809417312)),
and owner-confirmed F1–F5 manual visuals. The P1 physical-body ray
receiver regression is fixed; its review thread is resolved. D06-02 is merged. Do not reintroduce stale
"draft", "visual pending" or 941/958/967 latest-count statements.

**Simplification verdict:** keep the existing small actor-local world
target interface and optional visual/input adapters. A second gun and a
camera-free NPC already demonstrate extension without core edits. Do
not add a projectile manager, generic ammo state service, AI-specific
Gun, camera-aware hit resolution or global per-weapon flags. Only
refactor `Gun._resolve_hit_health()`'s on-hit descendant lookup if
profiling demonstrates a real cost with many NPCs; introducing a cache
or hit registry solely for D06-02 adds unnecessary lifecycle coupling.
D07 implements only the AI decision/nav/target producer and reuses
Combat, Equipment, Health/Hurtbox and the current aim port. D08 must
preserve these ports without moving interaction logic into the actor core.
See ADR-0006 for the original gun architecture review.


## D07 enemy intent/decision extension

D07 AI is camera-free and actor-local. Compose `Action5AIController` with
`Action5AITargetSensor`, `Action5AINavigation` (a normal Godot
`NavigationAgent3D`) and `Action5AIAttackPolicy`. The AI submits
`Action5MoveIntent` to the existing Actor and attack requests to D05
Combat/actor-local Equipment. Never add AI branches to Actor, Locomotion,
MovementController, AnimationPresenter, Gun or the camera. An equipped Gun
uses `Action5ActorTargetAimProvider`; a physical wall remains authoritative.

Movement move IDs are queued and the latest intent is used at the next
physics tick. Combat heading is snapshotted at request time; a second
concurrent request is rejected. Add a third enemy by scene inheritance and
a configured attack policy, not new core conditionals. Test real
`demo/world/encounter_sector.tscn` physics with `tests/d07_suite.gd`.
The suite instantiates `demo/main.tscn`, activates the existing dungeon
via WorldSession, and uses that same scene's Player/ViewManager/CombatInput.
Run `make check` and native/WebGL2 Full E2E. Never recreate a second
standalone enemy-map/Player scene just for tests.


## D07 AI hardening contract (D07-01)

The four D07 AI components are only an actor-local decision/intent layer.
AI selects equipped actions by `attack_id`, uses explicit optional
`reload_command`, and tracks the target of each accepted AI-owned attack.
Guard that same target's configured range and physical LoS every physics tick
(including startup/active); cancel only AI-owned action requests when invalid.
Never teach shared Combat, Actor, Equipment or MovementController about AI
or weapon names. Rejected actions and reload are not successful attacks.
Death stops AI physics processing; use `reactivate()` only after restoring
Health and the actor's alive state. Regression coverage must include real
AI-driven damage without direct Combat requests, startup target loss/cover,
autoreload, weapon cleanup and F1–F5 switching. D08 transitions and scene
persistence belong in D08-01, not this D07 component milestone.

D07 input rule: compose `CombatInputAdapter` with the player's
`EquipmentAttackSelector` in every playable world; locomotion-only
`ActorInputAdapter` does not dispatch punch/kick. Regress both actions in
the shared dungeon through normal InputMap events and real Health damage,
not direct Combat calls.


D07 enemy presentation: `demo/ai/enemy.tscn` composes the existing
`AnimationPresenter`, `CombatAnimationAdapter`, and optional
`GunReloadVisualAdapter` with the shared training rig; AI itself must
never choose or play clips. New enemies supply attack animation keys
and a rig-specific `SkeletonProfile`. The current NPC-only
`gun_fire` key maps to an existing forward-arm animation; player
profiles are not altered. Equipped meshes should follow the animated
`right_hand` socket when present, with the static socket fallback
retained for unanimated actors. Preserve regressions for Bat and Gun
clip begin/end, reload/death, independent model instances and no-render
combat. For any new NPC locomotion speeds, configure its
`AnimationPresenter.run_speed_threshold` between authored walk and run
speeds; do not assume the player's default threshold is correct.
Never move attack authority into the animation layer.


## D07 merged baseline → D08 implementation handoff

Merged D07-01 supplies D07 NPC AI/physical encounter and optional visual
composition. Player `CombatInputAdapter` is shared by all room instances;
E interaction, scene doors, restart UI, snapshots and persistent-world
handoff belong to D08 issue #16 and D08-01. The retired D08 prototype
`change_scene_to_packed()` was removed; the current single-world demo
opens one physical two-sided gate and changes active sectors only when the
player actually walks across its threshold. D08 must use
an input-independent Interactor, separate Door/Pickup/RoofVisibility nodes,
collision/nav updates and the existing Health/Combat/Equipment/AI ports.
Keep visual-only roofs and projectile tracers out of physics authority.
The arena floor ends at world X=14 and the instanced dungeon begins at
X=14 (dungeon origin X=26); both use the same world X/Z orientation.
The shared gateway is at X=14, Z=0 (the default side-view lane), between two collidable east-wall
segments and across an overlapping PassageFloor slab. Only one
`EncounterDoor` exists in the world, parented to `demo/main.tscn`,
with a permanent two-sided frame and a separately hidden opening panel.
The dungeon has NO second `ReturnDoor` instance. E toggles its physical
gate and navigation link; player movement across the boundary calls
`WorldSession`'s passive sector detection, **never a door teleport**.
Preload nearby dungeon physics before crossing and only pause it once
the player is well back inside the arena. Continue using the same
Actor/Equipment/Combat/Health and AI ports.
In the D08 dungeon, keep the Roof as a **physics-only collider**:
a world-space transparent box at Y=4 intersects the side/arcade camera
frustum and produces a distracting tint over only the upper half of
the screen. `demo/interactions/roof_visibility.gd` now owns a
**full-viewport, non-interactive ColorRect** in a scene-local
CanvasLayer (layer 0, below the HUD in layer 1). It displays the tint
only inside the dungeon in views 1/2/3/5; first person (view 4) and
the arena are clear. Do not reintroduce a 3D roof mesh, disable its
physical ceiling collider or tie rendering to combat/navigation.
Regress full-viewport anchors, view/sector changes, no mouse blocking
and physical collision in `tests/d08_world_suite.gd`. Keep local
fill lights subtle so the scene isn't washed out.
D08–D09-02 are part of the implemented scene-composition baseline.
Future D10 diagnostics must inspect, not rewrite, the shared movement,
combat, camera, equipment or animation cores.

The D07 merged baseline passed 1,018/1,018 pinned Godot assertions and
native/Linux plus real WebGL2 Full E2E on GitHub Actions run
#42871200034. The existing automated visual capture renders the main
demo, but may not travel into the dungeon: when changing NPC
animation/weapon geometry, run `demo/main.tscn`, enter the dungeon via E,
and inspect all five camera modes. The D07 suite uses that same dungeon.
For D08, keep its session/restart state separate from AI and combat
and add independent persistent-world traversal acceptance tests.


### D08 camera orientation across persistent sectors

`demo/world/encounter_sector.tscn` is an instanced room in the same
world as `demo/main.tscn`, translated on global +X **without rotation**.
F1, F2 and F5 camera profiles have world-space target clamps.
`demo/world/sector_camera_bounds.gd` now creates one continuous
arena+dungeon bounds rectangle from instance-local copies of the D02
profiles. Do **not** shift camera clamps or snap the camera at each
sector crossing: both rooms are on the same plane and camera space. Never patch shared `.tres` profiles, rotate
a map's movement axes, or add map-specific D08 conditions to
MovementPolicy, ActorInputAdapter or CameraRig for room-specific
heading changes. F5's bounded overhead heading stays invariant even at
map edges; F2 may use the **generic configurable** lateral-peek
presenter (`ViewProfile.lateral_peek_degrees`) to reveal X-facing
walls as the actor walks along world X, and holds its last angle at rest.
That F2 yaw is NEVER used to remap beat'em-up world-axis WASD.
Preserve F3/F4 yaw and user camera settings. Run `tests/d08_camera_sector_suite.gd` through
`make check` for every new room, and validate WASD in all five views
both before and after a doorway. There is no standalone D07 encounter scene; `tests/d07_suite.gd`
activates the dungeon inside `demo/main.tscn`. The obsolete scene-reload
transition suites and one-use handoff adapters were retired with the
duplicate scene. New scenarios must use the shared-world fixture.

D08 door visualization contract: physical open state disables the
CollisionShape3D and enables NavigationLink3D. The **one** shared door
uses `WorldDoor.keep_visual_when_open = true` to preserve its
two-sided DoorMesh frame, and `barrier_visual_path` to hide the solid
BarrierMesh when opened. Normal independent doors keep the default
hide-on-open visual behavior. Do not duplicate a return portal in the
dungeon. Verify entry from both sides, closed/open collision, continuous
player movement and persistent inventory in `tests/d08_world_suite.gd`.
Neither door rendering nor entrance state is a camera/actor concern.
**Adjacent connected doors have no destination Label3D** (avoid mirrored
overlapping text). Keep an opaque BarrierMesh co-located EXACTLY with
the door's CollisionShape3D and expose distinct physical handles on
both faces matching `get_interaction_point(actor)`; do not move a
visual-only marker away from the actual interaction point just to
make F2 appear usable. `LocationPortal` is different: its optional
`show_label` and `label_path` control destination text independently
of `can_interact` and travel. No label node is required for a portal.
A small direction-sensitive F2 camera yaw (profile-configurable,
12° default) reveals wall faces. Check geometry and E handle reach
from both sides in F1–F5; do NOT rotate world geometry or remap WASD.

### D08 connection contract: physical gate versus remote portal

The reusable `WorldDoor` is **only** for adjacent geometry. E toggles
`BarrierMesh`, the real CollisionShape3D and NavigationLink3D;
the frame remains visible. `get_interaction_point(actor)` returns
a near-side handle on either face. `Action5Interactor` uses this
optional port without knowing it is a door. Do not make an adjacent
door call `WorldSession.travel_to()`.

Closed physical doors must be **opaque** to players and enemy discovery.
The scene-local `RoomVisibility` component separately hides the
other room's visuals in every camera while keeping floor collision
and NPC state; proximity-driven physics preloading is NOT permission
to render the other room or acquire targets. `DoorAcquisitionFilter`
is composed into the two enemies' `Action5AITargetSensor` by
WorldSession. This is an optional `allows_acquisition(actor, target)`
port applied **only on first discovery**; never clear an acquired
target on closure. The existing Health, Combat, Navigation, Movement
and line-of-sight systems continue to enforce attacks and walls.
A key nuance: a D07 enemy may WALK across the open doorway,
and the player can close it behind the enemy. Never hide the whole
`EncounterSector` root for a closed door: that would hide or suspend
an already crossed enemy. `RoomVisibility` toggles the static dungeon
visual subtrees separately and evaluates each moving NPC and dropped
weapon by its **current** world X side. `WorldSession` keeps alerted
or crossed enemies processing even beyond the ordinary dungeon preload
range. This must not revive dead actors or bypass an actual closed
door's physical collision. E sight rays may skip intervening moving
`CharacterBody3D` actors (with the query exclusion assigned back each
retry); rays must NEVER skip StaticBody3D walls, gates or props.

The arena and dungeon now have separate NavigationRegion3D meshes
linked solely when the shared gate opens; D08's simple arena quad is
an example, not a replacement for baked obstacle-aware navigation.

`LocationPortal` is a **different component** for deliberate
nonadjacent travel: marker mode repositions the actor within a world;
PackedScene mode asks `LocationManager` to instantiate/cache a
detached environment and reuse the SAME Player/Equipment/Combat/
ViewManager. The remote chamber lives in
`demo/world/remote_chamber.tscn` with a separate marker-return
portal. `WorldSession` suspends automatic room crossing only while
remote; room rendering and camera reframe are separate adapters.
A remote location cannot introduce a duplicate Player or call
`SceneTree.change_scene_to_packed()` behind a normal door.

Tests: extend `tests/d08_connections_suite.gd` for actual viewport
E input, opaque rendering both ways, initial acquisition denial,
post-opening latched aggro, door/navlink physics and remote cached
scene/marker returns. Keep D07 enemy tests and D08 world/camera tests
passing. Do not disable strict LoS or add conditionals to movement,
combat, camera core or animation code for any of these connections.

### D08 interaction and drop contracts

All demo weapon prefabs install a lightweight optional
`PickupInteraction` child; the only E path for static, new or dropped
weapons is `Action5Interactor` with distance and physical LoS.
Never reintroduce a direct Equipment pickup fallback in main.gd:
nearby items behind real walls would be collectable. The scene-local `PickupSpawns` adapter registers authored pickup paths,
captures availability per spawn, and resets only available world instances;
never delete equipped items or weapons moved to other cached environments.
The reusable Equipment and Interactor components must not know about spawn state.
`Action5Interactor` skips inactive scene descendants, and
`LocationPortal` also refuses direct interactions while paused.

`EquipmentController.drop_parent_provider_path` is a replaceable
`get_drop_parent(actor)` port; the demo connects it to
`LocationManager`, which returns the live connected root or active
detached PackedScene. Do not infer a drop destination from the weapon
type or an original parent destroyed by Start fresh. NPC equipment
still works without a drop provider, using its existing parent where
available. D08 tests should cover blocked E pickups, dropped gear
after a destroyed spawn parent, remote retained gear and two
overlapping return portals with distinct destinations.

### D08 room lifecycle and visibility authority

Inactive detached PackedScenes must disable their real physics:
LocationManager enforces CollisionObject3D.DISABLE_MODE_REMOVE so
Godot removes/re-adds cached physics with the disabled/enabled scene.
Do not snapshot/mutate collision layer/mask values; they retain their
authored state. NavigationRegion3D/NavigationLink3D enabled flags
still require explicit snapshot/restore. Merely hiding a mesh does
not isolate physics. No detached scene owns the permanent Player,
Equipment, Health or Camera; invalid Marker3D destinations leave no
orphan nodes. Tag each cached remote scene with
`action5_detached_location` so connected-world RoomVisibility skips its
loose pickups. Extend `tests/d08_connections_suite.gd` with a second
overlapping cached scene whenever travel lifecycle changes.

RoomVisibility owns only scene-composed room rendering, enemy/loose
pickup occlusion and the original-visibility cache. It observes
Equipment pickup/drop signals plus SceneTree **pickup-group** node
additions. Filter before deferring, so unrelated camera/actor/effect
nodes incur no pickup registration work. Only tracked loose pickups
are checked for boundary movement; never scan all pickup groups each
physics tick. Equipment owns picked-up weapon
visuals, and wall/door collision is independent of visibility.
Prune WeakRef visibility/material entries after fresh scene resets,
and restore original flags when removing the adapter.

Only OuterWallFader owns F1 foreground-wall mesh hiding, F2/F3 fade
and F4/F5 opaque rendering. Both `action5_outer_wall` and
`action5_side_hidden_wall` must tag camera-facing foreground walls
in the arena, dungeon and detached rooms. The group is on the
StaticBody3D, but only direct MeshInstance3D children are hidden;
colliders, opaque door panels and room-root visibility stay authoritative.
View switches and fresh sector replacement must apply the new policy,
and original mesh visibility/material/shadows return on teardown.
Do not reintroduce a wall visibility writer in demo/main.gd.
SectorCameraBounds handles any number of configured, rotated connected
sector transforms by merging world-space bounds; never add room names
or specific movements to the core camera, Actor, AI or Combat. The
two-room visibility adapter is deliberately a demo-level composition,
not a new speculative generic framework.

### D08 proximity transparency: only outer walls

`demo/world/outer_wall_fader.gd` fades **only explicitly tagged**
`action5_outer_wall` StaticBody3D nodes, using the physical
CollisionShape3D footprint rather than distance to a long wall's
center. Arena/dungeon/remote chamber perimeter walls opt into the
group, including camera-front `SouthWall`. The interior
`PillarA`/`PillarB`, obstacle, east shared partition sections,
visible door frame, BarrierMesh and any NavigationLink3D are never
tagged. Fade starts 3.8 units from the wall and reaches 20% material
opacity at 1.1 units; original surface override and cast shadows
are restored at full distance and when the presenter exits. F1
hides only camera-foreground meshes tagged `action5_side_hidden_wall`
while preserving their collision; F4 and F5 keep all exterior
walls opaque. The F2 direction-sensitive peek remains configurable
and defaults to 6°.

**Web compatibility:** NEVER substitute
`GeometryInstance3D.transparency` for this effect. That property is
ignored by Godot's Compatibility/WebGL2 renderer. Duplicate
`StandardMaterial3D` once per wall mesh, use
`BaseMaterial3D.TRANSPARENCY_ALPHA` only when close, and reuse the
cached material to avoid repeated shader/resource allocation. Do
not alter room-root visibility owned by RoomVisibility, physical
collision, enemy discovery/LoS, navigation, or any shared material
resource. The single opt-in front mesh belongs to OuterWallFader. Extend D08 camera integration tests for proximity
alpha, F1 arena/dungeon/remote foreground hiding, restored materials,
nonfading interior walls, opaque F4/F5 and detached scene path.


### D08 F1 actor plane

`demo/world/side_lane_controller.gd` is the opt-in scene composer
for F1 shared Player/enemy world-Z alignment. It reads the selected
view, active remote scene and enemy group; it uses existing Locomotion
lane ports and collision-tested movement only. Do NOT move actors
inside the camera rig or add camera/door IDs to AI/Combat/Actor.
All living active enemies must join the same lane when F1 is selected,
including newly spawned or recreated dungeon NPCs. Releasing F1
unlocks their native 3D movement; keep temporary enemy/enemy
collision exceptions until separated, so the D07 navigation-through-
door regression still passes. No exception may remove player/world/
door physics. Cover F1/F2 switches, AI/HP persistence, and optional
detached-location behavior in D08 suites.


## D09-01 delivered architecture and extension rules

- `demo/ui/hud_adapter.gd` is the only owner of demo help/status
  formatting. Subscribe to gameplay signals; do not reproduce HUD
  polling/refresh handlers in `demo/main.gd`, nor move HUD logic into
  the addon. Display bindings from the active control profile and
  InputMap, actions from AttackDefinitions and optional ammo/command
  data from the equipped weapon (including the unarmed fallback).
- `addons/action5/input/view_control_profile.gd` maps InputMap
  action names to view-local roles. F2/F3/F5 use default.tres;
  F1 and F4 each have an override. Add per-view controls by authoring
  another resource, not hardcoding keys/view cases in Actor, Combat,
  MovementController or CameraRig. F1 W/Up jumps, S/Down holds crouch
  (with crouch-walk); Space jumps, Ctrl toggles. F4 arrow Left/Right
  turns, while A/D remains strafe. Focus loss/disabled UI must clear
  held input and require neutral rearming.
- `Action5ViewAimTargetProvider` alone owns the camera/view-to-world
  target policy. In orthographic F1, literal screen-center camera ray
  points through Z, so select an upper-torso-height horizontal sightline
  (default `side_center_height = 1.25`) along the combat lane.
  F4 still uses the camera-center ray; camera-free NPCs use their own
  target provider. **Never** bypass Gun's authoritative world-muzzle
  obstruction, damage resolution, or the visual-only projectile origin.
- `demo/interactions/reference_exit.gd` is a scene-specific
  Interactor target gated by existing NPC Health; the EXIT at dungeon
  local (9, 0, 0) is physically reachable on F1 Z=0, outside the
  SteepFace traversal obstacle. Victory overlay only observes the
  completion signal and reloads the current scene. D09-02 retro
  encounter policy is an optional resource-based view/weapon integration.

**Regression contract:** Run pinned `make check` and the real
Linux/WebGL2 E2E workflow for changes touching camera, controls,
combat sightlines, equipment or overlays. `tests/d09_reference_suite.gd`
covers inputs, HUD, completion, view switches and focus rearming;
`tests/d09_side_aim_suite.gd` covers physical F1 gun hits both ways,
muzzle visuals and wall obstruction. Final D09-01 baseline:
[CI / Checks, 1,275/1,275](https://github.com/bravado/ACTION-5/actions/runs/43135267448)
and [Full E2E](https://github.com/bravado/ACTION-5/actions/runs/43135511963).
Owner accepted the F1 trajectory. Do not falsely claim the separate
20-minute exploratory test based solely on automated smoke evidence.


## D09-02 retro combat integration (implemented)

D09-02 now authors a Sword using the existing `WeaponDefinition`, `AttackDefinition`, world mount and optional F4 grip. Direction quantization is a configurable `Action5ViewFacingPolicy` on the weapon definition; `Action5EquippedViewFacing` is one actor-local lookup shared by ActorInputAdapter (visible facing), CombatInputAdapter (melee request direction), and ViewAimTargetProvider (Gun target selection). This is not a second combat engine. Use `facing_sectors = 0` for F5-only quantization; it is not safe to set attack-global sectors. The starting arena uses the generic PickupSpawns reset adapter for Sword and other authored pickups; the D08 connected dungeon retains its own sector lifecycle. F5 demo assigns `demo/input/top_down.tres` in `demo/main.tscn`, with WASD movement, arrow-key independent aim and right-stick support; the generic ActorInputAdapter consumes optional extra aim actions. The HUD shows equipped Sword 4-WAY versus Gun 8-WAY and the current heading. The arena light switch is separated from the detached portal by more than twice the Interactor radius to prevent near-portal E selection conflicts; `tests/d09_top_down_suite.gd` validates physical pickup, same Sword F3/F5 behavior, eight-way Gun F5 target, free F3 target, and a replaceable 16-way policy. Keep world muzzle obstruction, D05 hit windows, gamepad independent aim, F4 visual-only muzzle, actor identity and scrolling profile bounds intact. Pinned CI/Full E2E validate the implementation; the complete owner exploratory playthrough remains a separate manual acceptance gate.

- D09-02 top-down Gun correction: **do not start projectiles at the actor's center**. Both demo Guns reuse the existing `EquipmentVisualAdapter` origin (physical weapon muzzle except optional F4 barrel-tip). Only the actor-local `Action5ViewAimTargetProvider` selects F5 target along the player's X/Z center-forward line. It first resolves a reachable target/obstacle on that line, then `Action5Gun` still casts the authoritative ray from the real muzzle to that point. Do not give `Action5Gun`, `CombatController`, `ProjectileVisual` or the projectile presenter new view branches. `tests/d09_top_down_suite.gd` verifies centerline target selection, real muzzle-origin emitted tracer, physical hit, ammo and F3/F4 fallbacks.

- **D09-02 F4 reload regression:** `demo/equipment/gun_reload_grip.tres` must pass `Action5FirstPersonLimbProfile.valid()`—especially the last pose at exactly `time = 1.0`, not 0.8. Its first/last grip geometry must return to the idle pose; otherwise `sample()` returns `{}` and F4 appears frozen despite Gun `reload_left` counting down. Both first-person Gun viewmodels reuse the profile and receive `get_visual_action()` through `set_visual_source` + EquipmentVisualAdapter. Do not introduce a second reload timer or put weapon-specific branches into CombatController/FirstPersonPresenter. `tests/d06_gun_suite.gd` now checks real mid-reload arm/grip movement, successful completion returning to idle, alternate Gun reload and abort on unequip.

**D09-02 performance contract:** Reuse the resolved Action5ViewControlProfile within an ActorInputAdapter physics tick; callers of get_movement_axes() may omit it and use the active profile. The demo F5 HUD needs its direction readout only at physics cadence while F5 is active; never bind gameplay clocks to the HUD or allocate a context every rendered frame. Direction policy lookups deliberately remain on demand (including runtime resource swaps); do not add an equipment/aim cache requiring explicit invalidation. View-facing resources accept sector_count = 0 (free) or 2..32, rejecting 1/out-of-range script assignments.

**D09-02 demo geometry accessibility:** Keep the arena Gun aligned with the Bat/Shovel pickup row at `Z = 1.0`, within the connected side-lane's `Z = 0` interaction range. In `demo/world/encounter_sector.tscn`, the central `Obstacle` uses matched 1.1 m tall BoxMesh/BoxShape with center `Y = 0.55` so its bottom stays on the floor and the existing side-scroller jump can clear it. Preserve the full collision (do not disable barriers, change jump speed or teleport past it). `tests/d09_reference_suite.gd` verifies a real F1 E pickup and a physically simulated F1 jump/run over the obstacle to the unlocked EXIT. Keep these adjustments scene-local, never in addon locomotion or equipment.


## D09-03 HUD contract (PR #38, ready for review)

- Render one stable, fixed HUD across all five camera modes. The authored layout in `demo/ui/hud.tscn` places Vitality top-left, Objective bottom-left and Equipment bottom-right. Its presentation script never owns gameplay state; `hud_adapter.gd` adapts authoritative Health, CombatController, Equipment, Interactor, ViewManager, session and InputMap state.
- Objective and equipment panels leave a clear bottom-center gap; no bottom full-width bar. Optional `Action5WeaponDefinition.hud_icon` textures never affect combat. The smaller item label reads `EquipmentController.get_next_weapon()` (the same policy as `swap_next()`) and the live `demo_swap` binding (default Q).
- `hud_toggle` (default H) hides gameplay HUD/notifications/prompts but never changes actor input, health, aiming, equipment, world state or death/victory UI. `hud_help` (default F6) opens the help overlay and uses existing demo input gating; keep it independent of HUD visibility. The old Status/Help/RetroDirection and ModeButtons UI nodes were removed; F6 help and the real HUD replace them.
- Any optional interaction prompt must query `Action5Interactor.get_target()`, the **same selection algorithm** as `try_interact()`. Interactable labels are optional demo-local display ports, not arbitrary type checks in the Interactor or HUD. Keep selection/line-of-sight authoritative.
- Provide real headless test coverage for HUD view/layout/visibility stability, equipment/Q swap, missing icon data, and interaction parity. Use the pinned Godot 4.7.2 checks and explicit native/Web visual verification before review.


### Camera shortcut mapping update (D09-03 / PR #38)

Use numeric **1 First-Person, 2 Beat 'em Up, 3 Isometric / Third-Person,
4 Side-Scroller, 5 Top-Down** in all user-facing UI and help. The
ViewManager's stable internal indices remain side=0, beat=1, iso=2,
first=3, top=4; do not reorder them or migrate saved camera overrides.
The `ViewInput.shortcut_profile_indices` map (`[3,1,2,0,4]` in the
demo scene) is the *sole* shortcut-order authority. The HUD queries it
for its compact active-view label and F6 button order. Keep default
identity mapping for users embedding Action5ViewInput without this array.
The resource is now named `addons/action5/views/top_down.tres`.
Use `ViewProfile.Mode.TOP_DOWN`, `ViewProfile.Mode.BEAT_EM_UP`,
and schema-3 sections `profile_top_down` and `profile_beat_em_up`.
Existing schema-2 preferences are migrated automatically when loaded.
The visible mode remains **Top-Down**.

### D09-03 UI layout refinement

The owner requested a **position swap**: Vitality/health is now **top-left**, Objective is **bottom-left**, and Equipment stays **bottom-right**. Keep all three panels fixed across view modes and preserve the bottom-center gap, HP/equipment/interaction ownership and H visibility toggle. Test anchors explicitly; do not change the HUD's gameplay adapter or input mapping to implement layout adjustments.


### D09-03 architectural refactor (PR #38)

Keep `Action5EquipmentController.get_next_weapon()` as the single source
for next-item preview and Q swap, and `can_pickup(weapon)` as the
side-effect-free eligibility query that both pickup() and world interaction
advertising call. Revalidate on the actual pickup transaction.

Static HUD panel nodes, positions, text defaults, styleboxes and
help/notification timers now live in `demo/ui/hud.tscn`; its
GDScript merely projects values. Do not restore invisible legacy
`Hud/Status`, `Hud/Help`, `Hud/ModeButtons` or `Hud/RetroDirection`
compatibility nodes. Update tests to operate on the real HUD presenter.
The presenter is the sole owner of gameplay HUD visibility; the adapter
may read, not mirror, its state. Refreshed help/shortcut data is generated
only on relevant events, explicit refresh and help opening; HP, movement
and ammunition updates have narrow handlers. Short H/F6 prompts must
reflect actual remapped InputMap actions.

### Resource filename conventions

New scenes, scripts, resources and visual assets **must use short, plain,
descriptive lowercase snake_case names** that describe their role, not a
branding concept, art direction or milestone. For the current UI:
`demo/ui/hud.tscn` is the reusable scene, `demo/ui/hud.gd` its presenter,
`demo/ui/hud_adapter.gd` the demo-only gameplay observer and
`demo/ui/panel_frame.tres` the shared panel style. The scene instance node is
`Hud/Display`; outcome overlays keep functional names such as
`death_overlay.tscn` and `victory_overlay.tscn`. Prefer the same conventions
for future resources (e.g. `inventory.tscn`, `health_bar.tscn`) rather than
inventing named UI themes. When a resource path must be renamed, migrate **all scenes, scripts,
tests and documentation atomically**, and verify the new paths load while
the old paths no longer exist. Enum members and InputMap actions should also use plain identifiers:
`TOP_DOWN`, `BEAT_EM_UP`, and `top_down_*`. Saved camera sections use
`profile_top_down` and `profile_beat_em_up` with a schema-2 reader
for old preferences. External integrations loading old resource paths,
enum member names, exported properties or action names must update their
references; preserve only the settings-file migration.
