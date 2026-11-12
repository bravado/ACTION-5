# Changelog

## Unreleased

### D09-01 — Playable reference and per-view input (issue #17)

- Compose the shared arena, east physical door, dungeon enemies and gated EXIT into a playable objective with a victory/replay screen; preserve the same Player, weapon and scene authority.
- Introduce signal-driven, read-only HUD and dynamic InputMap/AttackDefinition control help, including generic ammo/reload and the alternate Gun.
- Add `Action5ViewControlProfile` resources: F1 W/Up jumps, S/Down holds crouch; F4 arrows turn, A/D strafes; F2/F3/F5 retain their directional controls.
- Select F1 upper-torso-height targets from a horizontal combat-lane ray while keeping the existing physical muzzle hitscan and wall obstruction. Retain F4 screen-center aim and independent camera-free AI aiming.
- Simplify HUD refresh ownership and held-input state; extend real-physics view/HUD/exit/aim regression suites. Pinned Godot checks: **1,275 assertions, zero failures**, and Linux/native plus real WebGL2 E2E passed. Owner visually accepted the corrected F1 trajectory.

### D08 — Persistent connected arena and dungeon (delivered)

- Reuse one Player, CameraRig, Equipment and world session across a physically connected arena/dungeon with a two-sided collidable door, NPC line-of-sight/nav gating, and retained enemy/pickup state.
- Add explicit remote cached location portals, configured fresh/restore entry policies, independent interaction/drop ownership, room visibility, per-sector camera bounds and view-local outer-wall transparency.
- Align actors collision-safely on the F1 stage lane; retain F2–F5 free 3D movement and physical collision.

### D07 — Camera-free NPC combat (delivered)

- Introduce actor-local AI sensing, navigation, pursuit and attack decisions on top of the existing Combat, Equipment and Health contracts. Equipped melee and ranged enemies share the world dungeon and world-muzzle obstruction.

### D06 — Equipment and ranged weapons (delivered)

- Add world-equipped/stowed Bat and Shovel actions with unarmed fallbacks; reusable pickup/swap/drop and input-claim contracts.
- Add independently configured Pistol and Heavy Pistol with physical muzzle hitscan, optional visual projectile trails and reloads, and separate render-only first-person grips.

### D05 — Independent combat and Health (delivered)

- Separate action timing, registered attacks, Hurtboxes, Health and combat input from locomotion and animation. Punch/kick resolve one authoritative attack timeline across the five views.


### D04 — Animated humanoid and local FPS presentation (delivered)

- Import an original, MIT-licensed skinned GLB character with 15 joints, separately skinned body/head geometry and authored idle, locomotion, crouch, combat, reload and weapon animations.
- Add resource-configurable SkeletonProfile mappings and non-destructive GLB validation with informative missing clip/bone diagnostics and safe fallback sockets.
- Compose three independent AnimationTree channels: authoritative locomotion, profile-filtered upper-body action overlays, and full-body visual overrides. Custom moves and actions select imported clips by ID without modifying the movement core; overlays preserve the base playhead and leave gameplay hit timing to D05.
- Add persistent BoneAttachment3D hand/head sockets and a demo training prop that follows animated hand bones.
- In first person, cull the full local skinned body through a dedicated camera layer while preserving Visual, Skeleton3D and equipment sockets through all five view changes; NPC bodies stay visible.
- Render a compact held F4 training tool with camera-local hand/forearm geometry while retaining the animated world equipment. Shadow-only skinned meshes and world-weapon copies restore the actor's real shadow despite first-person body culling; browser/native tests verify jumping and visible floor shadow.
- Validate imported assets after Godot's required import step, with cold-start script checking, physics and browser smoke coverage.


### D03 — Actor movement and view-independent input (delivered)

- Extract authoritative 3D actor, reusable locomotion, visual facing, movement-intent data contracts and camera-specific input policy modules.
- Add 60 Hz acceleration/deceleration, walking/running, grounded jump with coyote/buffer support, gravity, optional dodge, floor snap and bounded physical low-step assist.
- Respect camera-specific movement in all five views; F1 locks its current Z lane without teleportation, and F5 uses stable up/right vectors at exact overhead pitch.
- Separate independent aim and 4-/8-way facing quantization from actual world-space movement.
- Add keyboard/controller actions, deadzones, input reset on focus loss and gamepad disconnect, dead/disabled actor state.
- Extend procedural demo arena with a ramp and step, runtime controls, Godot regression suite and browser walk/jump smoke.
- Add an extensible `Action5MovementController` with pluggable `Action5Move` nodes, priority-based transitions and grounded/airborne fallbacks. Dodge and Slide are independent moves with their own input declarations. Test-only custom dash and vertical climb moves validate extension, interruption, per-move input registration and gravity control without editing Actor, InputAdapter or Locomotion.
- Fix inverted first-person vertical mouse look by default (mouse down now looks down), with a per-profile **Invert Y-axis** checkbox in Camera Settings. The checkbox persists user preference and Reset restores non-inverted behavior.


### D02 — Five view profiles and camera settings (delivered)

- Implement a persistent camera rig and five configurable views: true side-scroller, arcade beat'em up, unified isometric/over-the-shoulder, first person and retro top-down.
- Combine the former third-person preset into mode 3, with wide-to-close orthographic zoom, mouse orbit, pitch controls, shoulder offset, camera collision and aim look-ahead.
- Use number keys 1–5 in native/Web, optional F1–F5, five on-screen buttons and controller cycling.
- Add in-game camera settings panel, save/reset per-profile user overrides and migrate legacy six-slot preferences.
- Test camera/world-state preservation, close-shoulder occlusion, cardinal overhead movement, 5-mode selector, Linux/Web exports and visual browser smoke.
- Standardize local Godot import, test, run and export commands through an import-first Makefile.


### D01 — Godot foundation

- Pin Godot 4.7.2, GDScript and the Compatibility renderer.
- Add the D01 diagnostic 3D scene and keyboard-driven actor.
- Add MIT license, addon skeleton, test runner and export presets.
- Add GitHub Actions smoke builds and evidence artifacts.

> D01–D08 and D09-01 are delivered; D09-02 retro top-down encounter/scrolling, D10 tooling and D11–D12 distribution remain in the roadmap.
