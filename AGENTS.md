# Agent Instructions — ACTION-5

Read `PLAN.md` completely before implementing anything. Follow the D01–D12 deliverable sequence and the explicit exit gates. **D01–D04 are merged; D05 combat is next in the main roadmap.** Standalone movement examples can have separate PRs without expanding combat scope. Do not generate the framework in one untested change.

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
- `make web`, `make linux`, and `make build` import before exporting.
- The Makefile must fail closed on Godot errors and retain `.godot/` as a generated, ignored cache.
- CI must exercise Makefile targets rather than maintaining a conflicting implementation of the import/build steps. Do not add a requirement to commit the generated class registry.

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

## Starting task

**D01–D04 are merged.** For a new movement, read [`docs/adding-moves.md`](docs/adding-moves.md) and use `addons/action5/actor/moves/crouch.gd` with `demo/player.tscn` as the reference implementation. D05 combat is separate: keep attacks and weapons decoupled from movement registration and reuse existing animation/camera interfaces.