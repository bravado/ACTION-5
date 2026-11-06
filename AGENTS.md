# Agent Instructions — ACTION-5

Read `PLAN.md` completely before implementing anything. Follow the deliverable sequence D01–D12 and the explicit exit gates. **Start with D01 only.** Do not generate the entire framework in one untested change.

## Product invariant

There is exactly one 3D game world and one authoritative player actor. Camera switching changes input mapping, aim policy, presentation, camera projection/transform and view-specific UI **only**. It must never recreate, reset, teleport or replace the game actor, reload the scene, or duplicate damage. Use camera3D and normal Godot rendering, not a custom renderer.

## Baseline

- Pin Godot **4.7.2 stable** and matching export templates.
- GDScript, Compatibility renderer, 60 Hz physics, `.glb`/glTF characters.
- Browser (WebAssembly/WebGL 2) and native Linux/Windows/macOS are required release targets.
- Godot 4 C# runtime is excluded. Prefer standard Godot nodes over third-party runtime dependencies.
- X = horizontal, Y = vertical/gravity, Z = depth.
- Six view profiles: F1 Side, F2 Beat'em up, F3 tilted Isometric, F4 Third person, F5 First person, F6 true-overhead Retro Top-Down (NES Commando/Zelda).
- Both native and Web use number row **1–6 as primary**; optional F1–F6 secondary, with mandatory six-mode selector in Web. Ctrl+number is browser-reserved, not a safe fallback.
- All shipped code/content must be license-compatible and sourced.

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
- Don't assume F1/F5 or Ctrl+number shortcuts can be caught in web browsers.
- F1 is a genuine Mario/Altered Beast side-scrolling projection: camera screen plane is world X/Y (zero pitch, fixed world -Z view). Do not confuse F1 with the elevated X/Z beat'em-up view F2 or rotate F1 toward the actor during follow.
- Do not collapse F3 tilted isometric and F6 true vertical overhead into one view profile.
- Do not project camera-forward onto X/Z for F6; it is zero at 90-degree downward pitch. Use projected camera-right/up or explicit world axes.
- Do not hardcode facing quantization into the combat core: F6 supports optional Zelda-style 4-way sword attacks, Commando-style 8-way shooting and independent aim.
- Don't claim deterministic rollback support from using a fixed physics tick.
- Don't introduce proprietary assets, unverified packages, or unnecessary engine plugins.

## Starting task

**D01 is implemented and squash-merged. D02 is the current task:** six configurable view profiles, number keys 1–6, one persistent Camera3D, browser/native regression tests and a reviewed PR. Do not start D03 until D02's gate is accepted.