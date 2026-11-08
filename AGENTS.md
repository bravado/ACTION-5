# Agent Instructions — ACTION-5

Read `PLAN.md` completely before implementing anything. Follow the D01–D12 deliverable sequence and the explicit exit gates. **D01–D05 are merged (D05 via squash PR #28). D06-01 equipment is in progress; D06-02 guns and D07 AI remain pending.** Standalone movement examples can have separate PRs without expanding combat scope. Do not generate the framework in one untested change.

## Product invariant

There is exactly one 3D game world and one authoritative player actor. Camera switching changes input mapping, aim policy, presentation, camera projection/transform and view-specific UI **only**. It must never recreate, reset, teleport or replace the game actor, reload the scene, or duplicate damage. Use camera3D and normal Godot rendering, not a custom renderer.

## Baseline

- Pin Godot **4.7.2 stable** and matching export templates.
- GDScript, Compatibility renderer, 60 Hz physics, `.glb`/glTF characters.
- Browser (WebAssembly/WebGL 2) and native Linux/Windows/macOS are required release targets.
- Godot 4 C# runtime is excluded. Prefer standard Godot nodes over third-party runtime dependencies.
- X = horizontal, Y = vertical/gravity, Z = depth.
- Five view profiles: F1 Side, F2 Beat'em up, F3 combined tilted Isometric / close over-the-shoulder (one orthographic resource, zoom-dependent), F4 First person, F5 true-overhead Retro Top-Down (NES Commando/Zelda).
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

## D06 weapon and equipment extension contract (in progress)

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

D05's generic `register_attack` / `unregister_attack` pair is the only
combat registry extension required for D06-01; unequip must cancel an
active or buffered weapon attack before removing it. Equipped weapons
provide attack definitions to D05 and request action IDs; they do not
execute a second attack timer, own hit queries or read raw inputs.
Test Bat, Shovel and a third fixture with different attack data, all five
views, F3/F4 mid action, drop/teardown/shadows and an NPC without local
first-person presentation. D06-02 must reuse this controller with a Gun
instance owning ammo/reload, a per-weapon ranged effect and a physical
world-muzzle obstruction query. **Never** infer a valid shot solely from
a clear camera ray, and never add `is_gun` or weapon-ID switches.

Status: D06-01 is in development. Do not mark issue #13 complete or
claim native/WebGL2 visual acceptance until the current branch has passed
its E2E gates. D06-02 (#14) and D07 (#15) remain separate deliveries.

## Starting task

**D01–D05 are merged.** For a new movement, read [`docs/adding-moves.md`](docs/adding-moves.md) and use `addons/action5/actor/moves/crouch.gd` with `demo/player.tscn` as the reference implementation. D05 is complete. For D06, follow the equipment adapter contract above; keep future gun effects and enemy AI separate from the reusable movement, animation and camera classes.