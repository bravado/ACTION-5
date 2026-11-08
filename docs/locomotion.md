# D03 — Movement, input abstraction, jumping and facing

ACTION-5 runs **one authoritative `CharacterBody3D`** for all five perspectives. The reusable locomotion system lives in `addons/action5/actor/`; raw keyboard/controller input lives only in `addons/action5/input/`. `demo/` provides an arena and UI, not a competing movement implementation.

## Demo controls

| Keyboard | Action |
|---|---|
| **WASD / arrows** | Move; view-relative in isometric/first-person/overhead, world-X/Z in brawler, X-only in side-scroller |
| **Space** | Jump (grounded, coyote time and buffered input) |
| **Shift** | Run while held |
| **Alt** | Dodge move component (directional burst) |
| **X** | Slide move component (requires ground speed) |
| **Ctrl** | Toggle crouch; moving while crouched plays crouch-walk |
| **1–5** | Switch camera modes |
| **C** | Open/close live camera settings |
| **Esc** | Release captured mouse |
| **Mouse move** | Orbit/look in camera modes 3 and 4 while captured |

Gamepad: left stick moves, right stick optionally aims/faces independently, A jumps, left-stick click runs, B dodges, Y slides, **right-stick click (R3) toggles crouch**, shoulders cycle camera profiles. All actions are remappable in Godot's InputMap; default bindings are installed only for empty actions.

## Shared classes

- **`Action5MoveIntent`** — camera-independent, world-space movement/aim/facing/action data, plus generic `requested_moves: Array[StringName]` (no `is_sliding`/`is_wall_running` flags), all ground-plane vectors in world X/Z. The active camera mode does not travel with the intent.
- **`Action5MovementPolicy`** — stateless direction projection and 4-/8-way facing quantization helpers. Godot's `Input.get_vector()` supplies the configured radial deadzone, so no second deadzone implementation is needed.
- **`Action5ActorInputAdapter`** — samples `InputMap` before the locomotion physics tick (`process_physics_priority = -100`), creates intents and dispatches them to the actor. It owns window-focus loss/recovery, controller disconnect and neutralization after disconnect. The demo only calls `set_enabled()` when the camera settings UI opens or closes; repeated calls with the same value do nothing, and disabled input is not cleared on every physics tick.
- **`Action5Actor`** — one 3D player with alive/enabled state; forwards intents to locomotion but does not cache duplicate movement state or read raw keys.
- **`Action5Locomotion`** — the **only physics solver and authoritative intent holder** (`desired`), applying `move_and_slide`, movement/gravity/jump, acceleration/braking, floor snap and slope bounds. Its parent is a `CharacterBody3D`. Disabling controls/focus clears this authoritative intent; move components never write the body's velocity directly.
- **`Action5MovementController`** — generic exclusive move registry/FSM, priority-based transitions, grounded/airborne fallback, and `move_changed`, `move_registered`, `move_unregistered(id)` signals. It discovers all child `Action5Move` scripts in `Locomotion/MovementController/Moves`.
- **`Action5Move` / `Action5MoveContext`** — extension API: each move owns eligibility, entry, physics commands, exit and optional input defaults; context exposes a one-tick `request_horizontal_velocity()` command and `finish_move()`.
- **`Action5FacingPresenter`** — visual-only yaw, optional quantized facing and turn smoothing.

D02's `Action5ViewManager` still exclusively owns camera switching. The D03 input adapter observes `view_changed` and applies F1 lane lock/unlock without modifying the actor's world transform during the switch.

## Add a new player move (no core changes)

**Canonical authoring guide:** [Adding a movement component](adding-moves.md).
It includes a working dash script, registration, input defaults and
user remapping, `MoveContext` commands, transition arbitration,
camera-independent animation and F4 eye height, runtime removal, tests,
and the complete review checklist.

The core contract is **one registered `Action5Move` active at a
time**, installed as an immediate child of
`Player/Locomotion/MovementController/Moves`. The move declares
`move_id`, optional `action_name` and default binding, priority,
and lifecycle hooks (`can_enter`, `enter`, `physics_update`,
`can_exit`, `exit`). The input adapter converts an edge-triggered
action into an `Action5MoveIntent` request; the controller arbitrates
it, and only `Action5Locomotion` applies physical velocity and calls
`move_and_slide()`. No new per-move branch is required in the core.

For moves with multiple visible states, configure **multiple move IDs
with matching animation clips**. The reference
`Action5CrouchMove` is installed twice as `crouch` and
`crouch_walk`; each maps to a looping clip through
`demo/assets/crouch_skeleton_profile.tres`. The optional
`EyeHeightPresenter` maps both IDs to the same additive `-0.45`
first-person eye offset. A blocked standing transition keeps the
crouch collider and F4 viewpoint lowered. This behavior needs no
camera or animation presenter branch.

For AI/code, call `intent.request_move(id)` and pass that intent
to `actor.apply_move_intent(intent)`. At runtime,
`move_controller.add_move(move)` registers an added child; removal
or unregistering an active move must run its `exit()` cleanup.
Moves can issue horizontal/vertical/gravity commands through
`Action5MoveContext`. See the [full guide](adding-moves.md)
before implementing or reviewing another movement.

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

The Godot Inspector exposes walk/run speed, acceleration/braking, jump impulse, floor snap, maximum floor angle, individual move component speeds/timing and input deadzones. D03 uses real `move_and_slide()` physical collisions, floor snapping on ramps and walls that block movement. Its optional low-step assist first checks vertical and forward clearance, then casts the body down at the destination to confirm a walkable floor within the configured step height. It raises the body only to that measured landing height; it never blindly lifts by the maximum allowance or climbs walls, ceilings, or unsupported ledges.

View switches do not overwrite current velocity or change position; F1 stops future Z acceleration and retains the current lane. The actor's alive/control setters stop movement when disabled, the input adapter clears player movement when its UI gate closes or window focus is lost, and controller disconnects require neutral input before resuming. Focus remains blocked even if the settings panel closes while the window is unfocused. AI-supplied movement intents are not repeatedly canceled by disabled raw-input polling.

## Run and verify

```bash
make run    # auto-import; WASD, Space, Ctrl crouch and 1–5 views
make test   # headless D01–D04 + crouch/movement regression suites
make build  # Linux + Web export
make serve-web
```

CI verifies the Godot import/test/negative-test matrix, exported Linux executable, browser WebGL2 runtime and rendered screenshots. The D03 test suite installs a **test-only custom move** to prove no actor/input/solver edits are necessary, as well as testing Slide and Dodge through the shared controller. D03 tests specifically exercise real physics walking, running, jumping/landing, side lane stability, wall collision, disabled actor, deadzones and camera projection vectors.

**Not D03:** animation clip mapping (D04), combat hitboxes (D05), weapon equipping (D06), or enemy AI (D07).

## Crouching as an independent movement example

The `Crouch` and `CrouchWalk` nodes under
`demo/player.tscn → Locomotion/MovementController/Moves` use the same
`Action5CrouchMove` script with two configured move IDs. Press **Ctrl**
(or gamepad **R3**) to toggle a crouched stance. Moving while crouched
walks at 2.2 world units/s and plays the separate looping `crouch_walk`
animation; releasing movement returns to `crouch` idle. Press again
to stand, provided there is headroom.

The component changes only its actor's duplicated capsule collider; the
bottom stays aligned with the ground. It submits a horizontal-velocity
request to `MoveContext`, rather than writing `CharacterBody3D.velocity`
or calling `move_and_slide()`. Its overhead probe prevents standing
through a ceiling. Canceling the active move restores the original shape.

The original, MIT-licensed rig generator now includes articulated knee
joints and distinct thigh/shin meshes so the knees can bend forward and the shins can fold back
underneath the hips, instead of rotating as straight planks into a seated pose. The generator
authors two additional `-loop` glTF clips. `demo/assets/crouch_skeleton_profile.tres` maps
their imported names to the move IDs. **No edits** to `Action5Actor`,
`Action5Locomotion`, `Action5MovementController`,
`Action5ActorInputAdapter` or `Action5AnimationPresenter` are needed.
For another move, install a new `Action5Move` child, configure its action,
and include the matching clip(s) in the skeleton profile.

### Independent first-person eye presentation

`EyeHeightPresenter` observes the existing `MovementController.move_changed`
signal and eases an actor-local `EyeOffset` Node3D toward a configurable
vertical offset. The demo configures `crouch` and `crouch_walk` to `-0.45`
world units. Both states share the same target, so switching from crouch idle
to crouch walk does not bob the viewport back to standing height. A failed
stand-up request leaves the movement state (and eye height) crouched.

The camera's generic `eye_offset_path` is optional and only contributes in
F4: its effective height is the current `ViewProfile.eye_height` plus the
actor-local Y offset. Other camera profiles remain unchanged. The additive
model preserves the existing camera settings UI, including user eye-height
preferences. Removing the presenter disconnects its movement listener and
restores the original eye-offset position.

Adding crawling, sliding, or another stance needs only an offset entry in
`move_offsets` and an installed movement component. No changes are required
to `Action5Actor`, `MovementController`, `AnimationPresenter`, the movement
component, or the camera's mode-specific logic.
