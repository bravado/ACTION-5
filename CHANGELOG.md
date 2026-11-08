# Changelog

## Unreleased

### D04 — Animated humanoid and local FPS presentation (PR #25, in review)

- Import an original, MIT-licensed rigged GLB character with 11 skeletal bones, separately skinned body/head geometry and eight authored animations (idle/walk/run/punch/kick/hit/death/reload).
- Add resource-configurable SkeletonProfile mappings and non-destructive GLB validation with informative missing clip/bone diagnostics and safe fallback sockets.
- Compose three independent AnimationTree channels: authoritative locomotion, profile-filtered upper-body action overlays, and full-body visual overrides. Custom moves and actions select imported clips by ID without modifying the movement core; overlays preserve the base playhead and leave gameplay hit timing to D05.
- Add persistent BoneAttachment3D hand/head sockets and a demo training prop that follows animated hand bones.
- In first person, cull the full local skinned body through a dedicated camera layer while preserving Visual, Skeleton3D and equipment sockets through all five view changes; NPC bodies stay visible.
- Render a compact held F4 training tool with camera-local hand/forearm geometry while retaining the animated world equipment. Shadow-only skinned meshes and world-weapon copies restore the actor's real shadow despite first-person body culling; browser/native tests verify jumping and visible floor shadow.
- Validate imported assets after Godot's required import step, with cold-start script checking, physics and browser smoke coverage.


### D03 — Actor movement and view-independent input (PR #24)

- Extract authoritative 3D actor, reusable locomotion, visual facing, movement-intent data contracts and camera-specific input policy modules.
- Add 60 Hz acceleration/deceleration, walking/running, grounded jump with coyote/buffer support, gravity, optional dodge, floor snap and bounded physical low-step assist.
- Respect camera-specific movement in all five views; F1 locks its current Z lane without teleportation, and F5 uses stable up/right vectors at exact overhead pitch.
- Separate independent aim and 4-/8-way facing quantization from actual world-space movement.
- Add keyboard/controller actions, deadzones, input reset on focus loss and gamepad disconnect, dead/disabled actor state.
- Extend procedural demo arena with a ramp and step, runtime controls, Godot regression suite and browser walk/jump smoke.
- Add an extensible `Action5MovementController` with pluggable `Action5Move` nodes, priority-based transitions and grounded/airborne fallbacks. Dodge and Slide are independent moves with their own input declarations. Test-only custom dash and vertical climb moves validate extension, interruption, per-move input registration and gravity control without editing Actor, InputAdapter or Locomotion.
- Fix inverted first-person vertical mouse look by default (mouse down now looks down), with a per-profile **Invert Y-axis** checkbox in Camera Settings. The checkbox persists user preference and Reset restores non-inverted behavior.


### D02 — Five view profiles and camera settings (PR #23, merged)

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

> Camera and locomotion foundations are complete. D04 adds skeletal presentation; combat, equipment, AI and game content are subsequent milestones.
