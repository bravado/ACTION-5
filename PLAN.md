# ACTION-5 — Godot Action Framework
## Product specification, architecture, delivery plan and acceptance criteria

**Version:** 1.0 planning baseline  
**Date:** 2026-11-05  
**Status update (2026-11-12): D01–D08 and D09-01 delivered.** The D08 connected arena/dungeon baseline remains stable; D09-01 adds the reference HUD, view-local input profiles, completion/replay, F1/F4 controls and physically blocked side-view gun aiming. Pinned Godot tests passed **1,275 assertions with zero failures**, and native Linux/WebGL2 E2E passed. The owner accepted the updated F1 gun trajectory. **Next: D09-02 retro-specific aim/scrolling**; D10–D12 remain planned. The release and long-play acceptance gates below remain authoritative.
**Audience:** Autonomous coding agent(s), code reviewers, project owner  
**Primary goal:** Build an MIT-licensed reusable Godot addon and a playable reference game that supports five instant-switchable control/camera perspectives in the same persistent 3D world.

---

## 1. Executive brief

Build **one 3D gameplay simulation**, not five games and not five renderers. All five views use the same actor position, physics, animation state, AI, HP, equipment, active attacks, and world objects. Only the **view profile**, input-to-intent mapping, aim policy, camera rig, and local presentation change.

| Shortcut | View | Camera | Locomotion | Aim/facing |
|---|---|---|---|---|
| 1 (F1 alternate) | Side | Fixed orthographic, stage-facing | X only; lock current Z as lane | Left/right, optional lock-on |
| 2 (F2 alternate) | Beat'em up | Side/angled orthographic | X/Z, stage-relative | Directional or soft target |
| 3 (F3 alternate) | Isometric / shoulder | One orthographic profile, zoomable from wide tilted dungeon to close shoulder framing | X/Z, screen/camera-relative | Cursor target, lock-on or shoulder look-ahead |
| 4 (F4 alternate) | First person | Perspective eye camera | X/Z, yaw-relative | Crosshair ray/mouse look |
| 5 (F5 alternate) | Retro top-down (NES Commando / Zelda) | True vertical overhead orthographic | X/Z screen-aligned; optionally 4-/8-way | 4-way melee facing, 8-way ranged aiming; optional independent aim |

**Crucial constraint:** Browser/OS shortcuts can preempt function keys (notably F1/F4), and Ctrl+number normally switches browser tabs. **Both native and Web use number-row 1–5 as the primary mapping**; F1–F5 remain optional alternate mappings. Web additionally requires a five-option on-screen view selector, with controller cycling. Do not rely on Ctrl+number. Avoid number-row conflicts with game weapon/equipment bindings by making the mapping configurable.

**Non-negotiable artifacts:**
1. `addons/action5/` — reusable, self-contained framework with no dependency on the demo.
2. `demo/` — playable 3D demonstration, including at least one combat arena and one dungeon-like area.
3. `tests/` — automated logic/integration checks and manual cross-platform acceptance checklists.
4. `docs/` — installation, architecture, extension points, model import, weapon authoring, troubleshooting.
5. `export_presets.cfg`, CI workflows and reproducible browser/native release artifacts.

---

## 2. Scope and product definition

### 2.1 In scope for 1.0

- One continuous 3D world rendered using Godot `Camera3D` (no homegrown rendering backend).
- Five camera/control profiles, switchable during running, attacking, jumping, death, enemy AI, and weapon reloads.
- 3D `CharacterBody3D` locomotion, gravity, jumping, acceleration, slopes/steps and collision response.
- Animated skeletal characters from `.glb`/glTF (idle, locomotion, punch, kick, hit, death; equipped attack/reload when available).
- Configurable hitboxes/hurtboxes and deterministic **frame-scheduled** combat rules at a fixed physics tick. Note: fixed tick does **not** make the full simulation network-deterministic.
- Unarmed attacks plus three weapons: bat, shovel and gun, including attachment, swapping, drops/pickups, collision/aim, ammunition/reload and attack timing.
- Enemy AI: idle, patrol/guard, acquire, approach/strafe, attack, stagger, disengage, death; 3D navigation and line of sight.
- Basic interactables: door, pickup, trigger volume, destructible prop, cover/obstacle and occlusion-friendly dungeon room.
- Local HUD: health, weapon/ammo, crosshair/target marker as relevant, active view label.
- Debug tools: show collision layers, hitboxes/hurtboxes, attack timeline, target rays, camera bounds and active intent.
- Keyboard/mouse and controller support; configurable bindings.
- Browser and Linux/Windows/macOS desktop exports, demonstrated via CI or documented reproducible workflows.
- Demo content from openly licensed or self-authored placeholder assets, with an attribution inventory.

### 2.2 Explicitly out of scope for 1.0

Online multiplayer, rollback netcode, competitive fighting-game move lists, procedural dungeon generation, inventory/economy/quests, large-scale crowds, advanced ragdolls, VR, consoles, mobile touch controls, graphical asset editors and proprietary-asset downloads. Keep interfaces extensible, but do not implement these prematurely.

### 2.3 Success criteria

- User can switch with **1–5** (native and Web primary), optional F1–F5 and five-option UI selector **at any point**, with no scene reload, teleportation, HP reset, animation restart or lost equipped weapon.
- Movement and aiming make sense for each profile. F1 locks the actor to the **current** Z lane; leaving F1 restores X/Z freedom.
- Punch, kick, bat, shovel and gun hit the same target correctly regardless of view; perspective changes cannot damage a target by themselves.
- Player, AI and objects continue updating when the camera switches.
- One demo can be exported to and run in Chromium/Firefox plus Linux/Windows/macOS native builds.
- Framework can be copied into a new Godot project and used without the demo scenes.
- Project has zero unexplained parser errors or failing automated tests; explicit performance report and asset licenses exist.

---

## 3. Technical baseline and decisions

| Topic | Decision |
|---|---|
| Engine | Godot **4.7.2 stable**, pin exact editor/export-template version in CI; reconsider only via documented migration PR |
| Scripting | Typed **GDScript**; do not introduce C# to runtime due to Godot 4 web export limitation |
| Renderer | **Compatibility** (WebGL 2/browser target); do not use Forward+-only shaders/effects |
| Web threading | Start with **single-threaded** web export; avoid assumptions requiring SharedArrayBuffer/COOP/COEP |
| World axes | X = stage horizontal; Y = elevation/gravity; Z = stage depth |
| Physics | Built-in Godot 3D physics, `CharacterBody3D`, `Area3D`, collision masks, explicit shape/ray queries |
| Combat timing | Fixed physics tick default **60 Hz**, with move data in integer ticks; keep visible animation synced |
| Assets | `.glb` / glTF 2.0; meters, consistent skeleton scale, local +Z/-Z orientation convention documented |
| Animation | `AnimationPlayer` for clips, `AnimationTree` for blend/state; authoritative gameplay actions separate from visual blending |
| Architecture | Scene composition + Resources + small services; prefer signals and typed boundaries over giant singleton managers |
| License | Framework MIT; independently attribute assets; do not apply MIT to third-party content unless permitted |
| Testing | Built-in headless Godot test runner (self-hosted GDScript) as minimum; optional GUT only if proven compatible/pinned |
| Repository | Git, GitHub Actions (or equivalent); one independently reviewable PR per deliverable |

**Sources to verify while implementing:** [Godot 4.7.2 release](https://godotengine.org/download/archive/4.7.2-stable/), [web export](https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_web.html), [AnimationTree](https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html), [glTF formats](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html), [EditorPlugin](https://docs.godotengine.org/en/stable/tutorials/plugins/editor/making_plugins.html), [Godot CLI](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html). Prefer 4.7-specific docs where available and verify API against pinned editor.

### 3.1 Important design constraints

- **Never** drive combat hits directly from mesh-to-mesh collisions or animation contact. Use capsule/box/sphere shapes and attack metadata.
- No hardcoded `Input.is_action_pressed()` inside Actor/Combat/Weapon classes. Only the input adapter reads raw input.
- Do not couple enemy behavior to the player's camera angle.
- No movement in Y caused by forward/back directional input, except through grounded physics/navigation; Y is gravity/jump/elevation.
- F5 is not sprite rendering, a separate 2D world, or a replacement for F3 isometric. Reuse 3D animations, collision, combat and world state.
- Don't reparent actors on view change. No instantiate/free of player or gameplay state during a camera transition.
- The first-person arms/head visibility is **local rendering**, not a new authoritative actor or collider.
- UI input must not also trigger attack; mouse capture must be restored/unlocked correctly on view switch, focus loss and pause.
- All action events and collision damage must remain correct at 30/60/120+ rendered frames per second.

---

## 4. System architecture

### 4.1 Responsibility boundaries

```text
GameWorld (one World3D; unchanged by view switch)
├── StageGeometry / Collision / NavigationRegion3D / Interactables
├── Actors
│   ├── ActorBody : CharacterBody3D        [authoritative transform/velocity]
│   ├── LocomotionComponent               [intent -> physics]
│   ├── CombatComponent                   [actions, hit resolution]
│   ├── HealthComponent                   [HP, damage, death]
│   ├── EquipmentComponent                [weapon instances / sockets]
│   ├── AnimationPresenter                [animation tree + visual events]
│   ├── HurtboxRegistry                   [damageable shapes]
│   └── AIController OR PlayerInputAdapter
└── LocalPlayerServices
    ├── ViewManager                      [profile selection / state]
    ├── CameraRig                        [fixed/chase/eye rigs, occlusion]
    ├── PlayerInputAdapter               [keyboard/controller -> intents]
    ├── AimResolver                      [mode policy -> aim intent]
    ├── FirstPersonPresenter             [head visibility / arms]
    └── HUD                              [view-dependent UI]
```

`ViewManager` MUST NOT own gameplay state. It issues `view_changed(profile, previous_profile)`; camera, input/aim and presentation consume the event independently. No multiple render backends; all views are `Camera3D` configurations.

### 4.2 Stable APIs/contracts

Proposed typed `Resource`/`RefCounted` data contracts (names can evolve only with an ADR and migration):

- `ViewProfile`: `id`, `name`, `movement_policy`, `aim_policy`, `facing_policy`, `direction_quantization` (`FREE`, `FOUR_WAY`, `EIGHT_WAY`), `independent_aim`, `projection`, `camera_pitch`, `camera_yaw`, `distance`, `offset`, `fov`, `ortho_size`, `camera_collision`, `first_person`, `hide_local_head`, `lock_depth`, `smoothing`, `crosshair_mode`, `camera_bounds_group`.
- `MoveIntent`: normalized planar `Vector2`, `jump_requested`, `sprint_held`, `dodge_requested`, `timestamp/tick` (no camera references).
- `AimIntent`: world-space aim origin/direction, optional target point and target actor; author/source and expiry/tick.
- `ActionRequest`: command ID (`light_attack`, `heavy_attack`, `interact`, `reload`, `equip`, `block`, etc.) and tick; buffered independently of animation.
- `AttackDefinition`: stable ID, animation key, category, startup/active/recovery ticks, hit volume definitions by tick, damage, stagger, knockback, range, allowed cancels, movement lock, hit-once policy, targeting policy, VFX/SFX event IDs.
- `WeaponDefinition` (**D06-01 implemented contract**): immutable ID, socket/grip, configured attack definitions, optional F4 visual scene. A new weapon's **instance-local behavior** (for D06-02 Gun) owns mutable ammo, magazine, reserve, reload/cooldown, muzzle/effect behavior. View-dependent aim conversion belongs to an aim provider; the physical world muzzle and its obstruction ray remain authoritative.
- `DamageEvent`: attacker, target, weapon/move IDs, impact location/normal, damage, knockback, tick and optional damage type.

Explicit signals:

```text
ViewManager.view_changed(current_profile, previous_profile)
LocomotionComponent.movement_state_changed(state)
CombatComponent.attack_started(attack_id, tick)
CombatComponent.attack_finished(attack_id, tick)
CombatComponent.hit_confirmed(damage_event)
HealthComponent.damage_received(damage_event)
HealthComponent.died(source)
EquipmentComponent.weapon_equipped(weapon_id)
```

### 4.3 View policy behavior

**F1 Side (Mario / Altered Beast):** a *true horizontal side-on* orthographic camera, viewing the world strictly along -Z. Screen-right is world +X, screen-up is world +Y; no elevation, downward tilt, yaw-follow or perspective skew, including during follow smoothing and view transitions. Keep X movement; when entering F1, record the current Z anchor; prevent user-input Z changes, *do not teleport*. Physics knockback may be restricted per game rule, configurable. Side facing maps to signed X. Jump still uses Y. Enemies/world continue fully 3D.

**F2 Beat'em up:** fixed stage-facing camera with mild elevation; X/Z movement in stage axes. Facing follows last meaningful input, current target, or configured soft lock. Stage bounds are independent of camera.

**F3 Isometric / shoulder:** **one orthographic view profile**, not a separate third-person mode. Wide zoom (default size 17) gives a tilted, screen-relative dungeon camera with visible wall depth. As zoom approaches 4, smoothly blend yaw, pitch, distance, shoulder offset, shoulder lift and look-ahead into a close above-shoulder camera. Stay orthographic in both framings, reuse the same actor/camera/profile, and allow mouse orbit, bounded pitch and wall avoidance. Provide live per-profile UI editing, reset, persistent user overrides and migration from the original six-slot preferences. True overhead is a separate F5 mode.

**F4 First person:** perspective eye/character anchor; mouse yaw/pitch with vertical limits; camera forward projected onto X/Z for locomotion; world-space crosshair ray target; locally hide head and optionally use an arms/weapon viewmodel. Maintain shared combat timing and authoritative muzzle/projectile trajectory.

**F5 Retro top-down:** use a true 90-degree downward orthographic camera, centered/following X/Z with configurable zoom, follow dead zone, level bounds and scrolling. Keep the same 3D world, character models, hitboxes, weapon attachments and combat. Map screen movement to X/Z via projected camera-right and camera-up axes, or explicit world axes. **Do not use a projected camera-forward vector** at vertical pitch: it becomes zero. Quantize facing/attacks to 4 directions (Zelda-style sword) or 8 directions (Commando-style gun), selected by profile/weapon rather than hardcoded in the combat core; optionally allow free analog movement and right-stick/mouse independent aim. Retain the last valid facing when aim input is zero. Resolve mouse aim from ray-to-ground/target, ensuring no NaN or invalid vector. Logical collision/damage and muzzle-world occlusion remain shared across all modes. Optional directional animation variants, overhead mesh/weapon visibility adjustments and retro pixel styling are presentation only. Apply roof/ceiling occlusion, camera bounds and overhead readability in the demo.

**Camera transitions:** Move target camera transform smoothly when possible. For orthographic <-> perspective projection changes, allow an instantaneous projection cut with short optional fade; do not promise seamless mathematical projection interpolation. Camera must avoid geometry intersections; expensive dual-viewport blending is NOT required for 1.0.

### 4.4 Input routing, including browser keys

- Define actions `view_1` ... `view_6`, `view_next`, `view_previous`, `move_*`, `jump`, `attack_light`, `attack_heavy`, `interact`, `reload`, `pause`, `lock_target`, `debug_overlay`.
- Native and Web: number-row 1–5 is primary. F1–F5 is optional secondary; Web must offer an always-visible five-view selector. Gamepad view next/previous. Preserve input rebinding when numbers also serve as equipment shortcuts.
- Web: do not rely on reserved browser/OS function keys or Ctrl+number tab shortcuts. Provide discoverable view selector and instructions, and test number-row binding in Chromium and Firefox.
- Focus loss: release capture, pause or clear held movement/attack buttons; no stuck inputs. Gamepad disconnected: gracefully fall back.
- UI dialogs consume input before player actions. InputAdapter emits intent; movement and combat are unaware of physical key codes.

### 4.5 Combat and collision policy

Default named 3D layers (adjust mask bits in one central configuration):

| Layer | Meaning | Examples |
|---|---|---|
| 1 | WorldSolid | floor, walls, props |
| 2 | ActorBody | player/enemy blocking capsules |
| 3 | Hurtbox | torso, head, limb damage areas |
| 4 | AttackQuery | melee strike/weapon sweep area |
| 5 | Projectile | physical bullets/throwables |
| 6 | Interactable | door/pickup proximity |
| 7 | CameraBlocker | geometry to avoid/fade |
| 8 | Trigger | volume entrances and events |

- Bodies resolve movement against world and optionally other actor bodies. Hitboxes overlap hurtboxes but do not physically push actors.
- Attack volumes use `Area3D` for sustained windows or direct physics queries at the authoritative tick. Swept shape tests/substeps handle fast bat/shovel swings; avoid tunneling from one tick to the next.
- Hit validation occurs **once per distinct target per activation** unless move explicitly supports multihit. A hurtbox registry maps multiple hurtbox shapes to one actor.
- Resolve attacks in stable order: collect contacts -> filter masks/owner/team/target -> deduplicate -> determine block/invulnerability -> apply damage/stagger/knockback -> emit results.
- Ranged: camera crosshair resolves intended point; muzzle-to-target ray checks intervening world geometry. Never spawn bullets from the camera or allow shooting through walls. Use physics-space queries during physics processing.
- Hit timing is defined in integer 60 Hz ticks; animation visuals can blend/interpolate and should never change the logical active window inadvertently.
- Avoid claiming network/replay determinism from engine physics. Optional deterministic combat core can be a future major milestone.

### 4.6 Animation and assets

- Accept `.glb` with standard humanoid skeleton, consistent scale and named clips (`idle`, `run`, `punch`, `kick`, `hit`, `death`, `reload` when applicable).
- Wrap imported assets in a Godot actor scene; never edit imported scenes as the only source of local overrides.
- F5 renders existing 3D models from above by default. Optional overhead-optimized animation/facing and cosmetic visual adjustments must not move authoritative hitboxes or colliders.
- Use `AnimationTree` for locomotion/attack blending; in-place locomotion is the 1.0 default. Explicit combat-driven movement/knockback, not accidental root-motion displacement.
- Document canonical forward axis, mesh pivot at feet, retarget assumptions, socket names (`right_hand`, `left_hand`, `muzzle`, `head`), units and texture budget.
- `BoneAttachment3D` / socket mapping attaches bat, gun and shovel. Different rigs can map local socket names in a `SkeletonProfile` resource.
- FPS visual layer can hide head from *local view only* or optionally attach hands-only viewmodel. The 3D full-body model remains rendered for other observers and remains the damageable actor.
- No requirement to ship third-party copyrighted characters or unlicensed motion-capture clips.

### 4.7 AI and level design

- Enemy FSM/behavior tree equivalent, intentionally simple for 1.0. NavigationAgent3D moves on navmesh where appropriate; melee attack choice checks distance, facing, line of sight, cooldown and combat state.
- The camera does not determine AI decisions or damage. F1 lock only modifies player controls; AI still needs sensible rules for engaging the player's current depth lane.
- Author level geometry as actual 3D: complete walls/ceilings and unobstructed routes for first person; distinct roof fade/ceiling controls for F3 isometric and F5 overhead; camera bounds for side and scrolling overhead views; world collision/navmesh shared.
- Include at least one room-to-room dungeon corridor, one open beat'em-up arena, and a transition between them in the same demo (no mandatory scene reload).

---

## 5. Repository layout

```text
/
├── project.godot
├── export_presets.cfg
├── README.md
├── LICENSE
├── AGENTS.md
├── CHANGELOG.md
├── addons/action5/
│   ├── plugin.cfg                    # EditorPlugin only for editor-facing tools
│   ├── plugin.gd
│   ├── core/{actor,health,events}/
│   ├── input/{input_adapter,intents}/
│   ├── view/{view_manager,view_profile,camera_rig}/
│   ├── locomotion/
│   ├── targeting/
│   ├── combat/{definitions,hitboxes,damage}/
│   ├── equipment/{weapons,sockets,projectiles}/
│   ├── animation/
│   ├── ai/
│   ├── interaction/
│   ├── ui/
│   └── debug/
├── demo/
│   ├── main.tscn
│   ├── levels/{arena,dungeon}/
│   ├── actors/{player,enemies}/
│   ├── weapons/
│   ├── profiles/{side,beatemup,top,third_person,first_person}.tres
│   └── ui/
├── tests/{unit,integration,scenarios,fixtures}/
├── docs/{architecture,api,assets,authoring,export,testing,adr}/
├── tools/{run_tests,validate_assets,export}/
└── .github/workflows/{validate,export,release}.yml
```

Runtime library code should not reference paths under `res://demo/`. `EditorPlugin` is optional for the addon runtime; do not force editor-only classes into exported games. Make plugin registration idempotent and reversible.

---

## 6. Deliverable schedule and gates

Every deliverable is an independently reviewable PR/commit set with: scope, code, tests, docs, evidence (test output/screenshots or short video), a known-limitations note and a manual test recipe. No phase can be declared complete until its exit gates pass.

### Release 0.1 — Foundation

#### D01 — Repository, engine baseline, CI, smoke exports
**Depends on:** none. **Recommended effort:** 1–2 focused agent work sessions.

**Tasks**
- Create pinned Godot 4.7.2 project with Compatibility renderer, 60 Hz physics and correct X/Y/Z convention.
- Initialize MIT license, `.gitignore`, formatting/naming policy, README, AGENTS.md, ADR template, changelog and license inventory.
- Add minimal 3D scene with floor, actor placeholder and world boundary.
- Implement test runner, `godot --headless --path . --import` preflight and parse/error checking.
- Add export presets and sample Linux + Web debug/smoke export; pin templates, upload CI logs/artifacts.
- Configure CI to run on PR; fail on parser errors, missing resource imports or failed smoke runs.

**Acceptance**
- Clone -> import -> run demo works without manual scene creation.
- Headless validator exits 0, and intentionally broken test fails CI.
- Web exports to local HTTP-served build and displays a moving/static actor; one native executable runs.
- No proprietary art or uncited third-party code.

#### D02 — Five view profiles and combined isometric/shoulder camera switching
**Depends on:** D01. **Effort:** 3–4 sessions.

**Tasks**
- Implement `ViewProfile`, `ViewManager`, `CameraRig` and five `.tres` resources: `side`, `beatemup`, `isometric`, `first_person`, `retro_topdown`; no separate third-person resource.
- Use primary number-row **1–5 in native and Web**, optional F1–F5, a five-option on-screen selector, InputMap rebinding and controller cycling.
- F1 horizontal side-scroller, F2 close arcade brawler, F3 wide isometric to close shoulder as *one* adjustable orthographic camera, F4 eye-level first person, F5 true vertical overhead.
- Expose applicable per-profile settings in-game, persist only changed values using stable profile IDs, support reset, and migrate legacy six-slot settings.
- Implement camera follow, offsets, bounds, spring-arm/obstacle avoidance, pitch clamps and basic transition smoothing.
- Handle input focus/mouse capture, pause and projection change transitions.
- Add visible view name and state-preservation instrumentation.

**Acceptance**
- Cycling all five profiles 20 times preserves actor identity, position, physics and world state.
- F3 provides tilted wide and close shoulder compositions with the same profile; zoom, shoulder framing, persistence, reset and migration work without actor movement.
- F1 remains horizontal, F2 close arcade, F4 first person and F5 truly overhead with correct screen axes and distinct framing.
- Near-wall collision/avoidance is verified for F3 close view; mouse look and focus handling work for F3 and F4.
- Browser 1–5 and every selector button work without reserved browser shortcuts.
- Resource camera settings are editable in the Inspector and runtime UI; native and Web exports, tests and visual evidence pass.

#### D03 — Character locomotion and input abstraction
**Depends on:** D02. **Effort:** 2–4 sessions.

**Tasks**
- Create reusable `ActionActor`, locomotion component, input adapter and intent data types.
- Build an extensible movement state controller: a new player move is installed as its own `Action5Move` node, with eligibility, priority, enter/tick/exit hooks and input defaults; no player-wide `is_my_move` flag or central branching. Grounded/airborne fallbacks and a shared physics solver keep one authoritative `CharacterBody3D`.
- Implement acceleration/deceleration, configurable speed, run/walk, grounded jump/gravity, optional dodge and simple slope/step behavior.
- Implement movement policies for F1 X-only, F2 stage-X/Z, combined F3 camera/screen relative, F4 first-person yaw relative, and F5 vertical-camera screen-relative X/Z with 4-/8-way facing and optional independent aiming.
- Entering F1 records current Z lane; leaving does not teleport. Prevent Y movement from planar inputs.
- Separate facing policy from locomotion and prevent camera jitter on abrupt turns.
- Handle dead/disabled actor, focus loss and gamepad disconnect without stuck movement.

**Acceptance**
- Same player can navigate sample obstacles across F1–F5; collision with walls remains correct.
- Holding an input while switching views does not cause a one-frame teleport or sudden excessive velocity.
- At fixed positions, F1 Z remains within tolerance while moving; F2–F5 support X/Z.
- F5 screen-up/right/down/left map to correct planar directions at exact vertical pitch without NaN/zero-vector, and facing quantization does not affect physical X/Z position.
- Unit tests cover world-plane vector projection, input dead zones, profile changes and state retention.
- An independently authored custom move can be added to the player and triggered by `MoveIntent.request_move()` and a declared InputMap binding without editing the existing Actor, Locomotion or InputAdapter implementations. Shipped Dodge and Slide are plug-in moves; exclusive transitions and cancellation are tested.

**Release 0.1 gate:** playable walking/jumping actor in one world, all view modes, browser + at least one native smoke build, documentation and tests.

### Release 0.2 — Animation, combat, weapons and enemy AI

#### D04 — Skeletal model and animation integration
**Depends on:** D03. **Effort:** 2–4 sessions.

**Tasks**
- Import a legally distributable test `.glb` model with idle/run/punch/kick/hit/death and optional reload animations.
- Build `AnimationPresenter` with `AnimationTree` and configurable clip mapping.
- Implement skeleton/socket mapping and right-/left-hand attachments; validate animation names and missing-bone fallbacks.
- Implement same actor third-person visuals and F4 local-head visibility or first-person viewmodel.
- Ensure visible animation follows authoritative action state; it must not rewrite combat timing.

**Acceptance**
- All required clips play in all views, no animation reset on view change.
- Attached placeholder item follows the hand through punch/run rotations.
- F4 camera is not obscured by the head; F3 full body remains visible.
- Replacing the model with another compatible skeleton requires data changes, not core engine code.

#### D05 — Unarmed combat, health and hit resolution
**Depends on:** D04. **Effort:** 3–5 sessions.

**Tasks**
- Implement `AttackDefinition`, attack state runner (startup/active/recovery), buffered commands and safe cancellation rules.
- Build capsule/box hurtboxes, active hitboxes and collision filtering; implement single-hit-per-target-per-swing deduplication.
- Implement punches and kicks, damage, stun/hit reactions, knockback, invulnerability windows as configurable data, death.
- Add aim/facing providers: side direction, movement/soft target, cursor target, camera/crosshair target, and F5 quantized 4-way melee/8-way ranged aim with optional independent right-stick/mouse aim.
- Debug draw active vs inactive attack volumes with tick/frame readout.

**Acceptance**
- Punch and kick consistently hit a nearby target and miss out-of-range targets in every view.
- A single swing does not accidentally damage a multi-hurtbox actor more than once.
- Startup/active/recovery phases advance by physics ticks independent of rendering FPS.
- View switches in mid-attack preserve attack phase and exactly-once hit behavior.
- Tests cover friendly fire filters, no self-hit, immunity/block hooks, knockback, death, edge-frame hits.

**D05 component contract and extension gate (D05, supplement to the above):**
- `CombatController` owns one authoritative physics-tick attack clock, buffer, hit shapes, target dedup and gameplay signals. It does not import or discover `AnimationPresenter`, `Visual`, a view profile or a movement controller. `request_attack(id, world_xz_direction)` accepts finite explicit world-space aim; when omitted, it reuses the last resolved attack heading (initially world north).
- `Health` owns damage, invulnerability, stagger and death. It emits `knockback_requested` / `died`; the **optional** `HealthActorAdapter` translates these events into generic actor lifecycle and locomotion impulse ports. Static targets must work without Actor, Locomotion, or the adapter.
- An **optional** `CombatAnimationAdapter` listens to combat/health signals and owns upper/full-body animations, cancellation, hit and death visuals. `CombatVisualState` exposes only a read-only `{key, progress}` snapshot; `FirstPersonCombatLimbs` presents authored camera-space profiles in F4 via the existing first-person visual registration port. Neither rendering component owns damage or action ticks.
- `ActionInputContext` is a typed snapshot of aim, facing, view, active camera and permission. `CombatInputAdapter` consumes a replaceable context provider, never traversing `ActorInputAdapter.actor.locomotion` or `actor.facing`. The resource-driven bindings are left-click/J/gamepad X = Punch and right-click/K/gamepad Y = Kick; GUI-consumed presses never attack. Attack defaults do not override user bindings.
- The shared `SkeletonProfile` defaults to idle/walk/run with **Idle only** required. The demo profile explicitly opts into Punch/Kick/Hit/Death. `Locomotion.apply_external_impulse()` is a generic bounded, decaying external-velocity port; no combat code writes body velocity.
- **No central edits for extensions:** installing a third attack uses a new `AttackDefinition`, configured clip/profile and optional InputMap defaults; no modifications to Actor, MovementController, Locomotion, ActorInputAdapter, AnimationPresenter or CameraRig. Regression fixtures include a bare CombatController without Visual/locomotion, standalone Health, an interchangeable action-context source and renderer, collision-safe impulse decay, all five views and F4 camera-local rendering.
- **D05 release verification:** `make check` / real Godot tests must pass, as must `CI / Full E2E` Linux/Web exports, native screenshots and actual WebGL2 browser smoke on the latest PR head. Put `[full-e2e]` in that commit message. Record concrete run URLs/results and any remaining manual visual limitations in the PR before changing draft status.

#### D06 — Weapons and equipment: bat, shovel, gun
**Depends on:** D05. **Effort:** 3–5 sessions.

**Tasks**
- Implement `WeaponDefinition`, equipment slots, equip/unequip/pickup/drop, sockets and in-world weapon models.
- Bat and shovel: distinct attack definitions, range, damage, impact and sweep shapes, animation key mapping.
- Gun: magazine, spare ammo, reload, fire rate, recoil visuals, muzzle VFX, world-obstructed camera-to-muzzle aiming, hitscan by default.
- Add optional projectile interface (can ship with one basic projectile weapon test fixture, not full ballistics).
- Separate game damage from weapon mesh physics; prevent wall penetration and shooter self-hit.

**Acceptance**
- Pick up, swap and drop all three weapons without glitches across F1–F5.
- A gun behind a wall cannot hit an enemy solely because the camera crosshair can see it.
- F4 fires toward intended camera target from muzzle; F1/F2/F3/F5 use respective aim policy. F5 supports 4-way sword strikes and 8-way gun aiming with shared muzzle obstruction rules.
- Ammo and reload state survive a view change; invalid shots do not use ammunition unless intended by rule.
- Automated tests cover weapon life cycle, cooldowns, ammo limits and hit filtering.

**D06 execution sequence and no-coupling gate (updated 2026-11-09):**
- **D06-01 / #13 (completed and accepted, D06-01):** `WeaponDefinition` is immutable configuration (ID, socket, attack definitions, world/F4 asset and grip); each `Weapon` instance owns its equipped state and future mutable properties. `EquipmentController` handles inventory, pickup radius, selection, mount and drop. A *separate* optional `EquipmentVisualAdapter` resolves animated sockets via `AnimationPresenter.get_socket()`, registers **each** world mesh through `FirstPersonPresenter.register_world_visual()`, and creates at most one render-only F4 viewmodel. Neither equipment controller nor weapon reads camera mode, manipulates layers, or writes movement velocity.
- **D05 integration:** one generic `CombatController.unregister_attack(id)` complements `register_attack()` for equipment teardown and cancels any current/buffered action before removal. It knows no specific weapon type. Weapon definitions register their attacks only when equipped; the weapon requests D05 action IDs through the single authoritative combat timeline. Test a third independently authored weapon and a camera-free NPC with an alternative mount provider.
- **D06-01 attack input and equipped F4 visual acceptance:** Equipment attacks explicitly claim each InputMap action through their `AttackDefinition.input_action` property and the **replaceable selection provider**; missing bindings keep regular Punch/Kick, even while equipped. No positional replication of one swing onto both LMB/RMB and J/K; Bat now has distinct vertical LMB/J and horizontal RMB/K attack resources, while Shovel claims only LMB/J so RMB/K remains Kick. Any other weapon can configure only right, both with distinct actions, or neither; duplicate claims are invalid. Neither CombatInputAdapter nor the actor checks weapon types. Equipment presentation gates the resting F4 arm and only the replaced action's limb; the **unassigned Kick** still animates its normal F4 leg. The separate viewmodel has one authored gripping arm and optional per-action `action_profiles`, so Bat changes from vertical to lateral F4 sweeps without another hand or clock; weapon meshes follow the hand through chamber/contact/recovery. `AttackDefinition.visual_action_key` separates the authored F4 action from the new dedicated world `animation_key` (`bat_vertical`, `bat_horizontal`, `shovel_overhead`). The original 15-joint MIT training GLB and the renamed alternate-rig fixture generate true weapon-specific skeletal clips, preserving upper-body/locomotion layering across all five cameras. Visuals do not own damage or ticks.
- **D06-01 hardening:** equipment registration stages all candidate attack IDs before replacing the old item; rejected second registrations roll back without altering the current selection. Distinct carried weapons must have unique attack IDs. An equipped/stowed weapon independently freed in the tree unregisters its attacks and F4 visuals; actor teardown destroys its items, and explicitly dropped items survive. VT-08 now uses D05 actor-volume substep sweeps and previous-frame hurtbox motion to detect fast crossings while preserving dedup, self/team filtering and active phases. Separate regressions test both motion directions and edge contacts, Run/Jump/Crouch with F3→F4→F5 active attacks, actor/viewmodel/socket continuity and camera-free NPC teardown. Browser E2E tests Bat and Shovel LMB/RMB/J/K across F2/F4 and rejects dark frames after pointer capture. A rejected initial pickup also leaves **no phantom pickup/equip signals**; a successful auto-equip emits **pickup then equip** once. **Acceptance passed:** latest-head CI / Checks (908 assertions, 0 failures), native screenshot matrix, Linux/WebGL2 Full E2E ([run #42668808972](https://github.com/bravado/ACTION-5/actions/runs/42668808972)), and owner manual visuals. D06-01 is merged.
- **D06-02 / #14 (merged via D06-02; 974 Godot assertions, Full E2E and owner visuals passed):** gun ammo/reload and hitscan must reside in a dedicated per-instance weapon behavior, using the existing generic equipment slot lifecycle. A separate optional weapon-command input adapter sends reload requests without adding gun-specific logic to `CombatInputAdapter` or EquipmentController; test a second configured Gun with unchanged core. A view-specific aim provider chooses a world target, while a **separate ray from the world muzzle** controls obstruction and hit eligibility. `AttackDefinition.use_melee_hit_query = false` opts external hit actions out of the default D05 melee box query while retaining the same timeline and active-phase signal. Never route gun hits solely through D05's melee box sweep; do not add gun type branches to EquipmentController, CombatController, camera, actor, or animation core.
- **D07 / #15 (merged via D07-01):** NPC equipment uses ordinary world meshes without private F4 registration. AI supplies movement intents and action requests independently of player input or camera state. Use the same weapon instances/controller rather than another AI-only combat engine.

#### D07 — Enemy actor and basic combat AI
**Depends on:** D05/D06. **Effort:** 2–4 sessions.

**Tasks**
- Reuse same Actor/Health/Combat/Weapon architecture for NPCs.
- Create enemy FSM: idle, acquire, chase/pathfind, maintain range, attack, hurt, dead; team/aggro configuration.
- Navigation mesh/`NavigationAgent3D`, obstacle steering as needed, line-of-sight/range checks, attack cooldowns.
- Add one melee NPC and one gun/ranged NPC; ensure side-lane engagement is playable.
- Define reaction to attack interruption and loss of target, with no behavior dependent on current camera.

**Acceptance**
- Two enemy types can find/engage player around obstacles and transition through death.
- Pressing F1–F5 repeatedly does not reset enemy decisions, navigation or HP.
- No enemy attacks from outside configured range or through opaque walls (unless explicitly designed).
- AI cannot repeatedly hit a dead actor; tests cover engagement state transitions.

**Release 0.2 gate:** animated character + 2 enemy types + punch/kick + 3 weapons operating in every view, browser and native regression demo.

### Release 0.3 — Gameplay integration and tooling

#### D08 — World interactions and dual-style level design
**Depends on:** D07. **Effort:** 2–3 sessions.

**Tasks**
- Implement proximity interaction contracts and example door, health pickup, weapon pickup, trigger volume and destructible prop.
- Build a continuous arena + dungeon corridor environment using shared world physics/navmesh; separate physical adjacent gates from remote portals, and isolate colliders/navigation of inactive cached remote locations while preserving the original player/equipment.
- Add per-zone camera bounds, side-view stage lane constraints (if enabled), and separate tilted-isometric F3 / true-overhead F5 roof/wall occlusion and camera scrolling behavior.
- Add simple respawn/checkpoint and pause/restart of demo (not generalized persistence framework).

**Acceptance**
- Player moves from arena to dungeon without a mandatory scene reload; enemies retain their state.
- Doors and pickups work from all views; side mode does not teleport across depth.
- Roof visibility changes do not alter collision or AI navigation.
- World props obstruct movement/projectiles correctly.

#### D09 — Playable reference game / vertical slice
**Depends on:** D08. **Effort:** 3–5 sessions.

**Tasks**
- Assemble 10–15 minute demo with intro/help overlay, short arena fight, corridor fight, one ranged encounter and final target/exit.
- Use one animated player, two NPC archetypes, bat, shovel, gun; health and simple ammo HUD.
- Add appropriate camera mode hints and controls screen, target indicators, local SFX and lightweight particles.
- Include an F5 retro encounter demonstrating Zelda-style 4-way melee, Commando-style 8-way shooting, scrolling and different visibility from F3.
- Add keyboard/gamepad accessibility basics: remappable keys, sensitivity, gamepad deadzone and reduced camera motion option.
- Smoke-test missing-asset handling and no input capture after pause/focus loss.

**Acceptance**
- Demo start-to-exit completable in native and web builds.
- Every mode is useful in at least one encounter; all five can be used throughout without blocking progress.
- No hard-crash, stuck input, permanent camera clipping or game-breaking attack state in a 20-minute manual exploratory run.
- Player can understand control switching via in-game UI.

#### D10 — Debug and editor-facing tooling
**Depends on:** D05–D09. **Effort:** 2–4 sessions.

**Tasks**
- Add toggleable debug HUD with FPS, tick, view, movement policy, actor velocity, aim target, AI state and current attack frame.
- Render hurtboxes/hitboxes, collision layer colors, muzzle ray, aim ray, camera rig position and world bounds (debug builds only).
- Implement read-only inspectors/validators for `ViewProfile`, `AttackDefinition`, `WeaponDefinition`, `SkeletonProfile`.
- If valuable, add optional `EditorPlugin` panel to create a default profile set and validate asset/socket/animation mappings; do not make a custom editor a blocker.
- Maintain docs and sample resource presets showing how a new game integrates the addon.

**Acceptance**
- Debug overlays can be enabled independently, impose no meaningful cost when disabled, and are excluded/disabled by default in release builds.
- Misconfigured collision masks/missing clips/sockets produce helpful warnings, not obscure runtime errors.
- New blank Godot project can enable/install addon and run a minimal example with documented steps.

**Release 0.3 gate:** representative game experience with interactions + demo progression + debugging tools, web/native verified.

### Release 1.0 — Quality and distribution

#### D11 — Automated regressions, optimization and full export matrix
**Depends on:** D01–D10. **Effort:** 3–5 sessions.

**Tasks**
- Run headless logic/integration tests for view switch, intent conversion, hit dedup, frame windows, weapons, AI FSM and resource validation.
- Add scripted gameplay smoke scene with assertions for state preservation when switching views during movement/attack/reload.
- Add native desktop export CI for Linux, Windows and macOS; validate export artifact structure and runnable smoke wherever CI runners permit.
- Add Web export CI with actual browser Playwright-style smoke checking startup, errors and selector; keep browser test harness separate from Godot runtime code.
- Benchmark Compatibility renderer on documented native/web machines, limit textures/polygons/draw calls, optimize initial download.
- Verify five-view UI and remappable number-row controls in Chromium and Firefox; confirm that F4/Ctrl+number browser shortcuts are not required; manually check macOS browser if available.

**Acceptance**
- All automated tests pass and release artifacts are produced by CI on a tagged build.
- Exported Web app starts under local HTTP (not `file://`), view selector works and no uncaught browser exceptions occur.
- No platform-specific hard blockers in tested matrix; document remaining limitations by browser/OS.
- Provisional targets (adjust with measured hardware): native 1080p 60 FPS and web 720p >=30 FPS in representative low-complexity demo scenes; initial compressed web payload target <= 50 MB, hard review threshold 100 MB. Report actual hardware/configuration and measurements, not ungrounded guarantees.
- All use of browser-incompatible APIs/dependencies is documented and eliminated from shipped runtime.

#### D12 — Packaging, documentation and 1.0 release
**Depends on:** D11. **Effort:** 2–3 sessions.

**Tasks**
- Extract runtime addon into clean installable folder with stable public classes, defaults, example templates and no `demo/` dependency.
- Write Getting Started (15-minute integration), architecture overview, API/events, movement/aim profile authoring, import/skeleton mapping, combat move authoring, weapons, enemy AI, web/native exporting and troubleshooting.
- Produce docs for collision masks, data schemas, view switches during attacks, browser hotkey limitations, asset license provenance.
- Publish versioned zip/addon package, demo native builds and hosted/downloadable HTML5 build; add checksums and change log.
- Tag `v1.0.0` only after final acceptance review; maintain issue backlog for post-1.0 improvements.

**Acceptance**
- A clean Godot project can copy `addons/action5/`, create an Actor with one ViewManager, and run without any `demo/` resource.
- README contains complete run/test/export commands, version requirements and links to demonstration.
- Release archives match CI build, licenses are complete, documented known limitations are specific, and core acceptance tests are green.

**Release 1.0 gate:** project owner can independently install, run, test, author a simple attack, and export a web/native example without reading framework source code.

---

## 7. Cross-deliverable acceptance test matrix

| Test ID | Scenario | Expected result | Primary deliverables |
|---|---|---|---|
| VT-01 | Press number row 1–5 native | Correct view, uninterrupted world | D02/D03 |
| VT-02 | Web number-row 1–5 / on-screen five-mode selector | All views usable; no reserved shortcut required | D02/D11 |
| VT-03 | Switch from F3 to F1 at nonzero Z | Position unchanged; lane anchors to current Z | D03 |
| VT-04 | Switch from F1 to F3 | Free X/Z resumes, no teleport | D03 |
| VT-05 | Switch during jump/knockback | Trajectory/state stays coherent | D03/D05 |
| VT-06 | Switch during attack active ticks | No duplicated hit or animation reset | D05 |
| VT-07 | Punch/kick adjacent enemy in each view | Correct hit, timing, feedback | D05 |
| VT-08 | Bat/shovel fast swing | No self-hit, duplicates or obvious tunneling | D06 |
| VT-09 | Shoot target with obstacle between muzzle/target | World blocks shot | D06 |
| VT-10 | Reload during repeated camera switch | Same ammo/timer state | D06 |
| VT-11 | NPC chasing while changing view | Navigation/aggro persists | D07 |
| VT-12 | First-person perspective near wall | Camera/head/weapon do not permanently obstruct play | D04/D11 |
| VT-13 | Top-down view beneath ceiling | Occlusion handled without changing physical wall | D08 |
| VT-14 | Lose/regain browser focus | No stuck input or unintended attacks | D03/D09 |
| VT-15 | Full demo browser + desktop | Completes without crash/blocker | D09/D11 |
| VT-16 | Install addon in empty project | Runs with no demo dependency | D10/D12 |
| VT-17 | Change viewport FPS 30/60/120 | Attack tick lengths unchanged | D05/D11 |
| VT-18 | Reopen project after fresh clone/reimport | No missing .uid/resource/plugin import errors | D01/D11 |
| VT-19 | Zoom F3 wide/close; switch F3 to F5 | Isometric/shoulder/vertical distinct; same actor and world state | D02 |
| VT-20 | F5 cardinal input and 4-way sword swing | Correct screen-aligned X/Z, facing and hit arc; no projected-forward degeneracy | D03/D05 |
| VT-21 | F5 8-way gun, optional independent aiming | Directional shot and obstacle/muzzle occlusion correct even while moving separately | D03/D06 |
| VT-22 | F5 camera scroll/zoom and roof | Bounds and occlusion correct, navigation/collisions preserved | D02/D08 |
| VT-23 | Switch F3/F5 during active attack/reload | No duplicated hit, reload reset or state loss | D05/D06/D11 |

### 7.1 Automated test strategy

**Unit:** pure math conversions, policy selection, attack windows, hit dedup, ammo rules, resource validation.  
**Integration:** Actor in an isolated scene with fake input / target and mock hit query; switch profiles while combat and AI run.  
**Scenario:** actual 3D scene, fixed-tick scripted sequence and expected transform/HP/ammo assertions.  
**Browser smoke:** exported app via HTTP, inspect browser console, trigger visible mode selector and verify a scene/HUD state change.  
**Manual:** collision feel, camera feel, animations, occlusion and performance by platform.

Use Godot headless commands for preflight and tests; the repository must contain a functional runner script, not just example commands:

```bash
godot --headless --path . --import
godot --headless --path . --script res://tests/run_all.gd
# Exact export preset names are defined in export_presets.cfg.
godot --headless --path . --export-release "Web" build/web/index.html
godot --headless --path . --export-release "Linux" build/linux/action5-demo
```

Create output directories first; pin matching export templates. Ensure the test script exits nonzero on failure. CI should preserve screenshots/logs from failures.

---

## 8. Definition of done and agent working agreement

### 8.1 General definition of done (every PR)

- [ ] Feature implemented and exercised in an actual Godot scene, not only pseudocode.
- [ ] Relevant headless tests added/passing; no red tests hidden by disabling checks.
- [ ] Code typed where practical, small classes, consistent resource naming and signal usage.
- [ ] No demo-specific references inside `addons/action5/`.
- [ ] Native + web compatibility considered; browser smoke repeated for changed camera/input/combat/render logic.
- [ ] Player state preserved on view switch; test added for new edge cases.
- [ ] Docs, controls screen, and export/asset attribution updated where applicable.
- [ ] One short test transcript and evidence artifact (logs + screenshot/video when visual).
- [ ] PR includes scope, design decisions, dependency changes, test commands/results, known limitations and next deliverable.

### 8.2 Autonomous agent protocol

1. Read this PLAN.md and AGENTS.md before touching code. Check pinned editor availability and run baseline tests.
2. Select the lowest numbered incomplete deliverable with satisfied dependencies; write a brief task checklist and work only within its scope.
3. If task is too large, split into sub-PRs while preserving the same acceptance criteria; prefer individually functional changes.
4. Add tests before or alongside code, and use real Godot execution to verify.
5. Make the smallest compatible architectural change. Write `docs/adr/NNN-*.md` for any public API, axis convention, physics policy or view behavior change.
6. Never silently skip browser/native validation or claim success without running a check; mark a step **not verified** and provide instructions if test environment is unavailable.
7. Do not invent or download proprietary assets. Use procedural meshes, self-created animations or properly licensed assets with provenance.
8. Commit coherent changes with a meaningful message, include files/commands/results in PR description, and stop at a working checkpoint.
9. Do not begin subsequent deliverables until the current PR's exit gates are met or the blocker is documented with explicit owner decision.
10. When blocked on an unimportant aesthetic decision, pick minimal defaults; when blocked on critical source assets, licenses or platform support, use a lawful fallback and document it rather than fabricating evidence.

### 8.3 Review gates

- **Architecture reviewer:** boundaries are respected and reusability preserved.
- **Gameplay reviewer:** feel and correctness of each view, aiming and combat.
- **Platform reviewer:** Web builds and desktop exports behave as documented.
- **Release reviewer:** licenses, docs, tests, performance and reproducibility.

An agent may run all roles sequentially, but evidence must remain independently inspectable. Do not self-certify manual visual quality without actual run/screenshot/video.

---

## 9. Risk register

| Risk | Probability / impact | Mitigation |
|---|---|---|
| Function keys and Ctrl+number shortcuts preempted by browser/OS | High / Medium | remappable number-row 1–5, mandatory five-view selector, controller cycling |
| Animation skeleton names vary across models | High / Medium | `SkeletonProfile`, clip/socket validator, documented import profile |
| First-person model clips camera/head | High / High | local-head hide/arms viewmodel, camera collision and close-wall tests |
| Mouse aim differs from projectile origin | High / High | camera-to-target then muzzle-to-target occlusion validation |
| Fast melee weapon misses targets | Medium / High | swept query/substeps and stable hit dedup by tick/target |
| Isometric/overhead roof occludes player | High / Medium | separate F3/F5 roof fade or toggle, physical collisions unchanged |
| True overhead 3D character/weapon is hard to read | Medium / Medium | directional animations and local presentation only; test weapon and character visibility |
| Vertical camera projected forward yields zero planar vector | High / High | use projected camera right/up (or world axes); assert valid cardinal movement |
| Switching to F1 creates unfair z-depth behavior | Medium / Medium | lock current lane, explicit game rule, UI feedback, test lane invariants |
| Render feature incompatible with web | Medium / High | Compatibility renderer from D01, frequent Web export, simple materials |
| AI/navmesh cannot engage in thin side lane | Medium / Medium | combat approach tolerances, AI lane adjustment, dedicated test arena |
| Fixed-tick logic mistaken for deterministic netcode | Medium / Medium | explicitly defer network determinism; no rollback claims |
| Agent implements overbuilt plugin instead of game | Medium / High | deliverable gates require playable scenes from D01 onward |
| Asset licensing contaminates release | Medium / High | attribution manifest and openly licensed/self-generated assets only |
| Camera smoothing causes motion sickness | Medium / Medium | configurable speed, reduced-motion toggle, instantaneous switch option |

---

## 10. Work estimates, dependencies and future roadmap

**Estimates are rough agent work sessions, not contractual calendar promises.** A work session assumes an experienced developer with Godot access, ability to run tests and no need to author commercial-quality 3D art. Iteration/debug time can substantially exceed these estimates.

| Deliverable | Sessions | Depends on |
|---|---:|---|
| D01 | 1–2 | — |
| D02 | 3–4 | D01 |
| D03 | 2–4 | D02 |
| D04 | 2–4 | D03 |
| D05 | 3–5 | D04 |
| D06 | 3–5 | D05 |
| D07 | 2–4 | D05, D06 |
| D08 | 2–3 | D07 |
| D09 | 3–5 | D08 |
| D10 | 2–4 | D05–D09 |
| D11 | 3–5 | D01–D10 |
| D12 | 2–3 | D11 |
| **Total** | **28–48** | Scope estimate only |

**Optional 1.1+:** animation retarget wizard, advanced ledge/platform traversal, richer combat data editor, local split-screen, dynamic camera split, more equipment types, ranged projectiles, abilities/magic, inventory/loot, procedural dungeon rooms, training-mode frame graphs. **Major separate roadmap:** competitive deterministic simulation/rollback networking, replay serialization, multiplayer authoritative state, advanced third-person locomotion. Do not merge these into 1.0 by default.

---

## 11. Initial backlog / recommended PR sequence

**GitHub tracking contract:** Release milestones are **0.1 Foundation (D01–D03)**, **0.2 Combat (D04–D07)**, **0.3 Gameplay & Tools (D08–D10)**, and **1.0 Distribution (D11–D12)**. Create one actionable GitHub issue per DXX-YY backlog item and assign it to the corresponding release milestone. The issue title begins with its immutable DXX-YY ID; include scope, acceptance, dependencies, test evidence and a link to this plan. Issue closure requires verified results and is not implied by plan text. Keep release milestone descriptions aligned with their release gates. Updates must not duplicate existing issues or milestones.

- `D01-01` Bootstrap pinned project, scripts, asset license policy.
- `D01-02` Headless test runner, CI import smoke, Web/Linux export smoke.
- `D02-01` Five fixed profiles (F1–F5), shared isometric/shoulder zoom, distinct retro-overhead camera.
- `D02-02` Third/first person camera, projection transitions and collision.
- `D02-03` Primary keys 1–5 native/Web, optional F keys, five-view selector, settings UI and controller cycling.
- `D03-01` Actor locomotion and intent contracts.
- `D03-02` View-specific ground-plane mapping, depth lock and jumping.
- `D03-03` Vertical-camera F5 mapping, 4-/8-way facing and independent-aim tests.
- `D04-01` Model import validator, clip/skeleton profile.
- `D04-02` Animation presenter, sockets and FPS local presentation.
- `D05-01` Combat timeline/actions, health and hurtboxes.
- `D05-02` Active hitbox windows, punch/kick, aim providers and debug.
- `D06-01` Equipment, bat/shovel and pickup/drop.
- `D06-02` Gun, camera-to-muzzle aiming, ammo/reload.
- `D07-01` AI states/navigation, melee/ranged enemies.
- `D08-01` Interactables and arena/dungeon integration.
- `D09-01` Playable reference scenario, HUD, input help.
- `D09-02` Retro overhead encounter: 4-way sword, 8-way gun and scrolling.
- `D10-01` Debug overlays, validators, addon setup.
- `D11-01` Matrix tests, browser E2E smoke, perf report.
- `D12-01` Packaging, final documentation, v1 release.

Each PR may be subdivided further if build/test evidence remains independently useful. Prioritize **D01–D03** as the first demonstrable milestone before expanding combat or editor tooling.

---

## 12. Minimum handoff format after each deliverable

```markdown
# DXX — Name
Status: Complete / Blocked / Partially complete
Commit/PR: <identifier>
Scope delivered: <files and behaviors>
Tests executed: <exact commands, results>
Native/Web evidence: <build names and screenshot/video links>
Acceptance criteria: <pass/fail per item>
Known limitations: <specific items, no vague 'works locally'>
Architecture decisions: <ADR links>
Follow-up issues: <IDs and severity>
Next: <lowest numbered unblocked deliverable>
```

**Final product rule:** A feature does not count as delivered merely because code compiles. It must be demonstrably usable, testable and compatible with the framework's shared-world/five-view architecture.
### D06-02 merged baseline — D06-02 (2026-11-10)

**Status: merged into `master` via squash commit `c2c4b9c7`.**
The `feat/d06-02-gun` branch implements an instance-local Gun using D06-01
inventory/mount registration and the existing D05 active-phase attack clock.
The separate actor-local aim providers resolve a world-space target from
player view/input or a camera-free NPC. The physical world Muzzle ray
decides hit/obstruction; a nearby wall wins even if F4 sees the target.
The Gun consumes a round only for a valid active shot, including blocked
shots, and owns magazine/reserve/reload state. A second configured gun,
independent optional reload input, world recoil, F4 visual gun, and
world-owned noncolliding projectile tracer exercise the same interfaces.

F4 may use its own camera-local `Grip/VisualMuzzle` for the **tracer's
visible start**, but never for hit authority. The shader fades the
procedural trail from the bright muzzle-side tail toward the impact-side
tip. Solid `CharacterBody3D` receivers now resolve their enabled owned
Hurtbox/Health without passing through the first collider. A physical
receiver integration regression confirms actual damage, team filtering,
wall blocking and disabled Hurtbox behavior.

**Evidence:** [GitHub Actions #42809417312](https://github.com/bravado/ACTION-5/actions/runs/42809417312) — `CI / Checks` **974/974 assertions, 0 failures** and `CI / Full E2E` **passed**, including native five-view gun/projectile screenshots,
first-person visual-muzzle validation, Linux/Web builds and real WebGL2
pickup/swap/fire/reload with one projectile per actual shot. **Owner
manual visual test passed on 2026-11-10**, as reported in the project
conversation. The previous P1 physical-body hit finding was corrected
and its review thread resolved. Docs and ADR-0006 are synchronized.

**Architecture outcome:** No changes to Actor, Locomotion,
MovementController, CombatController, EquipmentController, CameraRig or
AnimationPresenter for D06-02. The single change to the existing shared
EquipmentVisualAdapter is an optional render-only source/visual-origin
port; no weapon-ID or camera-mode branches enter gameplay. Existing
targeting, effect and command interfaces are sufficient for two guns
and both player/NPC aim providers; no general projectile manager, new
combat clock, generic ammo registry, or AI-specific gun is needed.
Details and deferred simplifications are in ADR-0006.

**D07–D12 handoff:** D07 adds a small independent target/decision/
navigation intent producer using the shipped camera-free aim provider
and existing actor-local movement/Combat/Equipment. Extend physical
body/hurtbox and multi-NPC regression tests, rather than creating an
AI-specific damage layer. D08 uses world collision masks for doors and
obstacles. D09 keeps F5 quantization in view policy and HUD read-only.
D10 opt-in authoring validators, D11 the existing test runner/matrix,
and D12 demo-independent addon packaging remain separate milestones.

**D06 and D07 handoff complete:** D07 reuses the camera-free aim port
and the existing combat/equipment interfaces. D08 subsequently delivered the connected world; do not reopen D06/D07 or introduce a new
combat/animation core for level interactions.


## D07-01 merged baseline — D07-01 (issue #15)

**Release target:** v0.2 Combat. **Implementation scope:** actor-local AI,
physical melee/ranged enemies and an independent playable encounter. D07
delivers the following merged, stable composition. D08 builds on this
baseline without changing the shared actor, movement or combat cores.

- `Action5AITargetSensor`: live targets, bounded acquisition/forgetting,
  target death/free/reacquisition and physical line of sight.
- `Action5AINavigation`: world-owned Godot navigation waypoints; no direct
  steering through unloaded navigation regions or opaque obstacles.
- `Action5AIAttackPolicy`: D05/D06 attacks chosen by configured
  `attack_id` and optional explicit `reload_command`; no weapon-index or
  weapon-type branches in the reusable combat engine.
- `Action5AIController`: camera-free intent producer, separate from
  locomotion's movement FSM and CombatController's physics timeline.
  Cancels only AI-owned attack requests upon lost range/LoS/target; rejected
  requests never publish attack state. Dead actors stop AI processing and
  may opt into reactivation after their authoritative health/alive state
  has been restored.

**Reference scenes:** `demo/ai/melee_enemy.tscn`,
`demo/ai/ranged_enemy.tscn` and their only authored shared-world room
`demo/world/encounter_sector.tscn`, instanced in `demo/main.tscn`.
The former standalone `demo/ai/encounter.tscn` was removed in D08.
Both NPCs own
independent Health, Combat, Equipment, world aim, navigation and action
decisions. They reuse the existing imported training rig and the optional
D04/D05/D06 presentation adapters for Bat swing, Gun firing/reload,
reaction/death and animated bone-socket equipment. The fallback static
socket keeps presentation optional. The **single shared Player** under
`demo/main.tscn` installs the normal CombatInputAdapter, so Punch/Kick
work in all five views and both world sectors.

**Verification contract:** `tests/d07_suite.gd` covers navigation around
opaque geometry, camera switches, concurrent NPC ownership, real
autonomous Bat/Gun damage, player input attacks, exact attack heading,
same-tick arbitration, changing cover/range during startup, ammo/reload,
target death/free/reacquisition, optional skeletal presentation and
unanimated fallback, NPC death, and equipment teardown.
GitHub Actions `CI / Checks` runs pinned Godot headless validation;
`CI / Full E2E` validates Linux/Web exports, native startup and
real WebGL2 browser startup. Final D07 CI evidence: [run #42871200034](https://github.com/bravado/ACTION-5/actions/runs/42871200034), with **1,018/1,018 Godot assertions**, Linux and Web exports, native rendering and real WebGL2 Full E2E. The automated browser/native screenshot harness targets the main demo.
The native/browser screenshot harness primarily exercises
`demo/main.tscn`, not the two-enemy encounter. For future visual changes,
review the encounter's animation, weapon alignment and F1–F5 behavior
manually; never treat a screenshot of the main demo as proof of encounter visuals.

**Architecture:** No new AI-specific Actor, movement controller, attack
clock, equipment owner, global target registry, projectile manager or
animation engine. The addon imports no `demo/` assets. NPC-only material
tints, starter equipment and skeleton clip mapping remain in `demo/`.
See `docs/ai.md`, AGENTS and the D07 implementation for recipes and evidence.

## D08-01 delivered architecture — persistent world and interactables

**F1 combat-lane follow-up:** A scene-owned `SideLaneController`
uses the existing Locomotion lock for the player and living enemies
on entry to F1, including late-spawned, fresh-dungeon and cached-remote
NPCs. Collision-tested movement aligns them to configurable local
Z=0 without bypassing solid gates. Enemy/enemy crowd exceptions
prevent one stacked NPC from blocking another's pursuit through the
door when switching back to F2–F5; they are removed after separation.
This adds no camera-, AI-, or combat-core conditional.


D08 extends the existing D07-equipped NPCs without changing the reusable actor, combat, locomotion or equipment cores. The playable scene `demo/main.tscn` hosts one persistent Player, Camera/ViewManager, inventory and the embedded `demo/world/encounter_sector.tscn` dungeon. The arena and dungeon meet on world X=14 at the same elevation, with a bridging floor and a single two-sided `WorldDoor` whose frame remains visible; E toggles an actual collision panel and navigation link, while the player walks through without being teleported.

`WorldSession` detects physical sector transitions, preloads nearby NPC physics, preserves live enemy state on ordinary revisits and supports an explicit destination-only fresh/restore policy. The `Action5Interactor` handles doors, switches, portals and prefab-local weapon pickups with real range and line-of-sight validation. An optional `LocationPortal` loads a cached environment PackedScene without duplicating Player, equipment or camera. Disabled remote locations are isolated by Godot `DISABLE_MODE_REMOVE` for collision objects and explicit navigation state handling. A location-owned drop-parent provider resolves the active world at drop time.

`RoomVisibility` independently handles connected-room occlusion, NPC and loose-item presentation, while `OuterWallFader` owns F1 foreground hiding and proximity transparency. The roof tint is a full-viewport presentation-only overlay; its separate physics ceiling remains authoritative. `SectorCameraBounds` merges transformed bounds of connected sectors without adding room names or movement transforms to the camera core. F2 lateral peek defaults to configurable 6°. All five views retain consistent facing and WASD semantics.

**D08 verification:** Godot integration tests cover physical doors, retained AI awareness, two overlapping cached remote environments, pickup/drop/restoration, non-default physics disabling, F1/F2 wall rendering and camera continuity. Latest pre-merge checks: **1,212 assertions, zero failures**, with owner F1–F5 visual acceptance on November 11, 2026. Native/WebGL2 exports remain under automated CI; a failing installation of browser dependencies is infrastructure evidence, not proof of a gameplay regression. D09 should build a playable reference scenario and view-specific retro aim/scrolling on these existing ports, without a new scene/persistence framework.

### D08 outer-wall visibility and F2 camera comfort

- [x] Reduce F2 lateral camera peek from 20° to a configurable
  **6° default**; preserve the 0° disable option and world-aligned
  beat'em-up WASD.
- [x] Reuse the **presentation-only** `OuterWallFader` to own
  both F1's front-wall mesh hide and near-wall fade, removing the
  competing main-scene writer. Its material fade is activated via
  `action5_outer_wall` groups on outer arena,
  dungeon and remote-room walls. Only these near-player perimeter
  meshes fade; shared/interior wall geometry, equipment props and
  the closed dungeon door remain fully opaque.
- [x] Use per-mesh duplicated/cached alpha StandardMaterial3D for
  **Compatibility/WebGL2** and restore original overrides when far.
  Keep collider, attacks, AI visibility/navigation and
  RoomVisibility's sector occlusion independent of fade.
- [x] Owner verified F1/F2/F3/F5 near-wall rendering and F4 opaque
  walls on November 11, 2026; maintain automated native/WebGL2
  screenshot and startup gates for subsequent changes.


## D09-01 delivered baseline — playable reference and view-local input

D09-01 composes the existing D08 arena and dungeon into a playable
start-to-EXIT flow. The physical east gate, enemy Health events and
Interactor ports remain authoritative; the demo-local `reference_exit`
and victory overlay only present objective and completion. Player,
weapons, scene state and camera are not duplicated.

`demo/ui/reference_hud.gd` observes the public ViewManager, Health,
Combat, Equipment, MovementController, weapon and InputMap ports.
`Action5ViewControlProfile` resources assign remappable InputMap
action names to per-view roles; F1 W/Up jumps, S/Down holds crouch
and side movement stays horizontal. F4 Left/Right arrows turn at
135°/s by default, and A/D strafe. F2/F3/F5 retain normal 2D
directional input. Movement core, FSM, camera and combat continue
to consume generic intent or look deltas; HUD does not own game state.

Gun targeting stays outside Gun: F4 resolves a true center-camera ray,
while F1 chooses a horizontal line along the 2D combat lane at
configurable 1.25-unit upper-torso height. All actual shots still
trace from their world muzzle to the selected world point, preserving
wall obstruction, damage and projectile origin. Camera-free AI
retains its independent target provider.

**Verification:** Pinned Godot 4.7.2 headless tests
(`tests/d09_reference_suite.gd`, `tests/d09_side_aim_suite.gd`
and existing D01–D08 suites) passed **1,275 assertions, 0 failures**:
[CI / Checks](https://github.com/bravado/ACTION-5/actions/runs/43135267448).
Linux export and native render capture, Web export and real WebGL2
browser startup passed [CI / Full E2E](https://github.com/bravado/ACTION-5/actions/runs/43135511963).
The project owner visually accepted the corrected F1 trajectory.
Do not confuse automated screenshots with completion of the separately
specified 20-minute exploratory native/Web run.

**Next work:** D09-02 retro 4/8-way encounter behavior and scrolling,
then D10 diagnostics/authoring, D11–D12 packaging and distribution.
