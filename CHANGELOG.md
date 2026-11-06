# Changelog

## Unreleased

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
