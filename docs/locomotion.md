# D03 — Movement, input abstraction, jumping and facing

ACTION-5 runs **one authoritative `CharacterBody3D`** for all five perspectives. The reusable locomotion system lives in `addons/action5/actor/`; raw keyboard/controller input lives only in `addons/action5/input/`. `demo/` provides an arena and UI, not a competing movement implementation.

## Demo controls

| Keyboard | Action |
|---|---|
| **WASD / arrows** | Move; view-relative in isometric/first-person/overhead, world-X/Z in brawler, X-only in side-scroller |
| **Space** | Jump (grounded, coyote time and buffered input) |
| **Shift** | Run while held |
| **Alt** | Short directional dodge (when enabled) |
| **1–5** | Switch camera modes |
| **C** | Open/close live camera settings |
| **Esc** | Release captured mouse |
| **Mouse move** | Orbit/look in camera modes 3 and 4 while captured |

Gamepad: left stick moves, right stick optionally aims/faces independently, A jumps, left-stick click runs, B dodges, shoulders cycle camera profiles. All actions are remappable in Godot's InputMap; default bindings are installed only for empty actions.

## Shared classes

- **`Action5MoveIntent`** — pure per-tick movement/aim/facing/action data, all ground-plane vectors in world X/Z.
- **`Action5MovementPolicy`** — stateless deadzone, direction projection and 4-/8-way facing quantization helpers.
- **`Action5ActorInputAdapter`** — samples `InputMap` at physics ticks, creates intents and dispatches them to the actor. Handles focus loss, controller disconnect and neutralization after disconnect.
- **`Action5Actor`** — one 3D player with alive/enabled state; receives intents but does not read raw keys.
- **`Action5Locomotion`** — movement/gravity/jump, walk/run acceleration/braking, optional dodge, floor snap and slope bounds. Its parent is a `CharacterBody3D`.
- **`Action5FacingPresenter`** — visual-only yaw, optional quantized facing and turn smoothing.

D02's `Action5ViewManager` still exclusively owns camera switching. The D03 input adapter observes `view_changed` and applies F1 lane lock/unlock without modifying the actor's world transform during the switch.

## Mode-specific movement

| Mode | Mapping |
|---|---|
| **1 — Side** | X input moves world X; horizontal movement cannot change the captured Z lane; jump moves in **world Y** |
| **2 — Beat'em up** | X/Z movement follows world stage axes; jumping uses Y |
| **3 — Isometric / shoulder** | Screen right/up map to ground-plane right/forward through the camera. Mode 3's zoom does not alter the authoritative actor or movement speed |
| **4 — First person** | Camera heading maps ground X/Z movement; looking up/down never introduces vertical velocity |
| **5 — Retro overhead** | Camera screen right/up project onto ground; never use projected forward at exact vertical pitch. Physical movement is continuous; optional facing can be 4-way Zelda-like or 8-way Commando-like |

All projections normalize diagonal inputs to prevent faster diagonal movement. Independent aiming with the right stick can change facing without changing the movement vector.

## Tuning and physical constraints

The Godot Inspector exposes walk/run speed, acceleration/braking, jump impulse, floor snap, maximum floor angle, optional dodge distance/time and input deadzones. D03 uses real `move_and_slide()` physical collisions, floor snapping on ramps and walls that block movement; it does not invent scene-specific collision bypasses.

View switches do not overwrite current velocity or change position; F1 stops future Z acceleration and retains the current lane. When the actor is disabled/dead, the adapter stops movement; when the app loses focus or a controller disconnects, input is cleared until safe resumption.

## Run and verify

```bash
make run    # auto-import, press Space to jump and 1–5 to change views
make test   # headless D01 + D02 + D03 regression suite
make build  # Linux + Web export
make serve-web
```

CI verifies the Godot import/test/negative-test matrix, exported Linux executable, browser WebGL2 runtime and rendered screenshots. D03 tests specifically exercise real physics walking, running, jumping/landing, side lane stability, wall collision, disabled actor, deadzones and camera projection vectors.

**Not D03:** animation clip mapping (D04), combat hitboxes (D05), weapon equipping (D06), or enemy AI (D07).
