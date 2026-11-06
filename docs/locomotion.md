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
| **1–5** | Switch camera modes |
| **C** | Open/close live camera settings |
| **Esc** | Release captured mouse |
| **Mouse move** | Orbit/look in camera modes 3 and 4 while captured |

Gamepad: left stick moves, right stick optionally aims/faces independently, A jumps, left-stick click runs, B dodges, Y slides, shoulders cycle camera profiles. All actions are remappable in Godot's InputMap; default bindings are installed only for empty actions.

## Shared classes

- **`Action5MoveIntent`** — pure per-tick movement/aim/facing/action data, plus generic `requested_moves: Array[StringName]` (no `is_sliding`/`is_wall_running` flags), all ground-plane vectors in world X/Z.
- **`Action5MovementPolicy`** — stateless deadzone, direction projection and 4-/8-way facing quantization helpers.
- **`Action5ActorInputAdapter`** — samples `InputMap` at physics ticks, creates intents and dispatches them to the actor. Handles focus loss, controller disconnect and neutralization after disconnect.
- **`Action5Actor`** — one 3D player with alive/enabled state; receives intents but does not read raw keys.
- **`Action5Locomotion`** — the **only physics solver**, applying `move_and_slide`, movement/gravity/jump, acceleration/braking, floor snap and slope bounds. Its parent is a `CharacterBody3D`. Move components never write the body's velocity directly.
- **`Action5MovementController`** — generic exclusive move registry/FSM, priority-based transitions, grounded/airborne fallback, `move_changed` and `move_registered` signals. It discovers all child `Action5Move` scripts in `Locomotion/MovementController/Moves`.
- **`Action5Move` / `Action5MoveContext`** — extension API: each move owns eligibility, entry, physics commands, exit and optional input defaults; context exposes a one-tick `request_horizontal_velocity()` command and `finish_move()`.
- **`Action5FacingPresenter`** — visual-only yaw, optional quantized facing and turn smoothing.

D02's `Action5ViewManager` still exclusively owns camera switching. The D03 input adapter observes `view_changed` and applies F1 lane lock/unlock without modifying the actor's world transform during the switch.

## Add a new player move (no core changes)

**A move is an independent GDScript node**, not a branch in `ActionActor` or `Action5Locomotion`. The shipped `Grounded`, `Airborne`, `Dodge`, and `Slide` are ordinary components. Only one exclusive move is active at a time; the controller chooses the grounded/airborne fallback when a special move finishes. Walk/run/jump are physical capabilities of the underlying solver and do not require separate state-combination classes.

To add a custom dash or climb:

1. Create a script extending `res://addons/action5/actor/moves/move.gd`.
2. In its `_init()`, assign a unique `move_id`, an optional `action_name`, optional default keyboard/gamepad keys and a `priority`.
3. Implement `can_enter(ctx)`, `enter(ctx)`, `physics_update(ctx, delta)`, `can_exit(ctx)` and `exit(ctx)` as needed.
4. Add a Node with that script beneath **`Player/Locomotion/MovementController/Moves`**. The controller registers it and the input adapter registers its action automatically. Existing `InputMap` remappings are left unchanged.

Example minimal move:

```gdscript
extends "res://addons/action5/actor/moves/move.gd"

var ticks := 0

func _init() -> void:
    move_id = &"dash"
    action_name = &"actor_dash"
    default_key = KEY_V
    priority = 30

func can_enter(ctx: ContextScript) -> bool:
    return ctx.intent.world_move.length_squared() > 0.01

func enter(_ctx: ContextScript) -> void:
    ticks = 0

func physics_update(ctx: ContextScript, _delta: float) -> void:
    ctx.request_horizontal_velocity(ctx.intent.world_move * 9.0)
    ticks += 1
    if ticks >= 8:
        ctx.finish_move()
```

No edits to the actor, locomotion solver, input adapter, or other moves are required. You may also install a move at runtime with `actor.locomotion.move_controller.add_move(move)`. Trigger it from input via its declared action or from AI/code:

```gdscript
var command := Action5MoveIntent.new(Vector2.RIGHT)
command.request_move(&"dash")
actor.apply_move_intent(command)
```

The controller checks eligibility, interruption priority and `can_exit` before switching states. Components may **request** horizontal velocity, but only the solver touches `CharacterBody3D.velocity` and calls `move_and_slide()`, preserving physics, walls and the five-view invariants. Different action categories such as combat are intentionally reserved for later milestones and should use separate controllers rather than cross-product states like `RunningAndShooting`.

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

The Godot Inspector exposes walk/run speed, acceleration/braking, jump impulse, floor snap, maximum floor angle, individual move component speeds/timing and input deadzones. D03 uses real `move_and_slide()` physical collisions, floor snapping on ramps and walls that block movement; it does not invent scene-specific collision bypasses.

View switches do not overwrite current velocity or change position; F1 stops future Z acceleration and retains the current lane. When the actor is disabled/dead, the adapter stops movement; when the app loses focus or a controller disconnects, input is cleared until safe resumption.

## Run and verify

```bash
make run    # auto-import, press Space to jump and 1–5 to change views
make test   # headless D01 + D02 + D03 regression suite
make build  # Linux + Web export
make serve-web
```

CI verifies the Godot import/test/negative-test matrix, exported Linux executable, browser WebGL2 runtime and rendered screenshots. The D03 test suite installs a **test-only custom move** to prove no actor/input/solver edits are necessary, as well as testing Slide and Dodge through the shared controller. D03 tests specifically exercise real physics walking, running, jumping/landing, side lane stability, wall collision, disabled actor, deadzones and camera projection vectors.

**Not D03:** animation clip mapping (D04), combat hitboxes (D05), weapon equipping (D06), or enemy AI (D07).
