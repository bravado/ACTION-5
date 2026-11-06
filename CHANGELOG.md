# Changelog

## Unreleased

### D03 — Actor movement and view-independent input (PR #24)

- Extract authoritative 3D actor, reusable locomotion, visual facing, movement-intent data contracts and camera-specific input policy modules.
- Add 60 Hz acceleration/deceleration, walking/running, grounded jump with coyote/buffer support, gravity, optional dodge, floor snap and bounded physical low-step assist.
- Respect camera-specific movement in all five views; F1 locks its current Z lane without teleportation, and F5 uses stable up/right vectors at exact overhead pitch.
- Separate independent aim and 4-/8-way facing quantization from actual world-space movement.
- Add keyboard/controller actions, deadzones, input reset on focus loss and gamepad disconnect, dead/disabled actor state.
- Extend procedural demo arena with a ramp and step, runtime controls, Godot regression suite and browser walk/jump smoke.
- Add an extensible `Action5MovementController` with pluggable `Action5Move` nodes, priority-based transitions and grounded/airborne fallbacks. Dodge and Slide are independent moves with their own input declarations. A test-only custom dash validates extension without edits to Actor, InputAdapter or Locomotion.


### D02 — Five view profiles and camera settings (PR #23, pending review)

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

> No production-ready camera, combat or weapon systems have been released. Those follow D02 onward.
