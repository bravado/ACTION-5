# Adding a player movement without core changes

This is the canonical authoring guide for new movement abilities in ACTION-5.
**Reference implementation:** [`Action5CrouchMove`](../addons/action5/actor/moves/crouch.gd)
installed as `Crouch` and `CrouchWalk` in
[`demo/player.tscn`](../demo/player.tscn). See also
[locomotion](locomotion.md), [animation](animation.md),
[cameras](cameras.md), and [development/testing](development.md).

**Non-negotiable architecture:** Add a component and data, **not a per-move
branch** in `Action5Actor`, `Action5Locomotion`,
`Action5MovementController`, `Action5ActorInputAdapter`,
`Action5AnimationPresenter`, or `Action5CameraRig`. No global
`is_sliding`/`is_crouching` booleans, duplicate actor, second movement
solver, or special-case camera view.

## Choose the correct owner

| Concern | Extension point |
|---|---|
| Eligibility, duration, direction, speed, collision/stance changes, interruption, cleanup | A new `Action5Move` subclass |
| Exclusive movement states and arbitration | Existing `Action5MovementController`, automatically registering `Moves` child nodes |
| Keyboard/gamepad actions | Component's `action_name` and default binding, InputMap; optional view-local role via `Action5ViewControlProfile` |
| Physical motion, gravity, jumping, sliding against the world | `Action5MoveContext` commands applied by existing `Action5Locomotion` |
| Visible movement clip(s) | Authored `AnimationPlayer` clips plus `SkeletonProfile.clip_map` |
| F4 camera eye height for a stance | Optional `EyeHeightPresenter.move_offsets` configuration and actor-local `EyeOffset` |
| Attacks, hits, weapon timing, damage, ammo | Separate combat/weapon components in D05/D06, **not** movement or animation |

## 1. Write the move component

For example, `addons/action5/actor/moves/dash.gd`:

```gdscript
extends "res://addons/action5/actor/moves/move.gd"
class_name Action5DashMove

@export_range(0.1, 20.0, 0.1) var dash_speed: float = 9.0
@export_range(0.01, 1.0, 0.01) var duration: float = 0.15

var _time_left: float = 0.0
var _direction: Vector2 = Vector2.ZERO


func _init() -> void:
    move_id = &"dash"
    action_name = &"actor_dash"
    default_key = KEY_V
    priority = 35


func can_enter(ctx: ContextScript) -> bool:
    return ctx.intent != null and ctx.intent.world_move.length_squared() > 0.01


func enter(ctx: ContextScript) -> void:
    _time_left = duration
    _direction = ctx.intent.world_move.normalized()
    if bool(ctx.locomotion.get("side_lane_locked")):
        _direction.y = 0.0
        _direction = _direction.normalized()


func physics_update(ctx: ContextScript, delta: float) -> void:
    ctx.request_horizontal_velocity(_direction * dash_speed)
    _time_left -= delta
    if _time_left <= 0.0:
        ctx.finish_move()


func exit(_ctx: ContextScript) -> void:
    _time_left = 0.0
    _direction = Vector2.ZERO
```

`ContextScript` is available through the `Action5Move` base.
Override only the hooks you need: `can_enter(ctx)`, `enter(ctx)`,
`physics_update(ctx, delta)`, `can_exit(ctx)` and `exit(ctx)`.
Capture the direction in `enter` for a committed dash, or read the
current intent each tick for steerable movements. Reset temporary state
and resources in `exit` whether the move completes normally, is
interrupted, or is removed.

### Context and physics contract

`ctx.intent` is an `Action5MoveIntent` with `world_move`,
`face_world`, `aim_world`, `jump_pressed`, `running`, and
`requested_moves`. `world_move` is **`Vector2(world X, world Z)`**,
never vertical Y. `ctx.body` is the authoritative `CharacterBody3D`;
use it for floor and clearance queries, **not to write velocity or
transform**. `ctx.delta` is physics delta and `ctx.horizontal_speed()`
reports actual X/Z speed.

Submit one-tick commands via
`ctx.request_horizontal_velocity(Vector2)`,
`ctx.request_vertical_velocity(float)`, and
`ctx.request_gravity_scale(float)` (scale clamped 0–4).
The context resets commands every physics tick. Only
`Action5Locomotion` assigns the body's velocity and calls
`move_and_slide()`. Call `ctx.finish_move()` to resolve a normal
grounded/airborne fallback. Do not make collision, gravity, combat
damage or attack timing dependent on animation callbacks.

For stances, duplicate mutable collision shapes per actor, keep the
capsule bottom aligned with the ground, test headroom before restoring
standing height, and restore the **original** shape and transform in
`exit`. The crouch component demonstrates these rules, including
temporary floor-contact grace during walking.

## 2. Install it and bind input

Create an ordinary `Node` with the new script beneath
`Player/Locomotion/MovementController/Moves` in the player scene.
`MovementController` discovers immediate `Action5Move` children
automatically. Every installed move needs a unique, stable `move_id`.
At runtime use `actor.locomotion.move_controller.add_move(move)`;
removing/freeing the child auto-unregisters it and runs `exit` for
an active move. `unregister_move(id)` leaves the Node attached, and
`register_move(move)` re-registers an attached node explicitly.

The input adapter discovers `action_name` from registered moves,
installs `default_key` and optional `default_gamepad_button` only
if the existing `InputMap` action has **no** bindings, and uses
`Input.is_action_just_pressed`. User remappings take precedence. View-specific keys belong in an
`Action5ViewControlProfile` resource, not a branch in the movement
component. For example, F1 maps S/Down to a held `crouch` request
without changing `Action5CrouchMove` or its Ctrl toggle.
Never read raw input from the move. To make a move internal/state-only,
configure `action_name = &""`, `default_key = 0` and
`default_gamepad_button = -1`. For example, `CrouchWalk` is another
instance of `Action5CrouchMove`, with `move_id = &"crouch_walk"`
and `walking_variant = true`; it has no separate input key.

For AI or tests, request any registered ID through the intent, rather
than calling a move hook directly:

```gdscript
var intent := Action5MoveIntent.new(Vector2.RIGHT)
intent.request_move(&"dash")
actor.apply_move_intent(intent)
```

From a cold-loaded script, preload
`res://addons/action5/actor/move_intent.gd` rather than requiring the
generated class registry. A request is **edge-triggered**: send it for
one physics tick only, or a toggle could immediately undo itself.

The controller batches requests at the next physics tick. It filters
with `can_enter`, excludes interruptions with lower priority than
the active move, selects the highest eligible priority (ties:
lexicographically smallest ID), and checks the active `can_exit`.
Losing/ineligible requests are consumed. An active move may call
`ctx.locomotion.move_controller.request_move(other_id)`: this queues
the transition for **the following tick** and does not add special
FSM transitions. One winning requested transition occurs per tick.
Only the standard grounded and airborne states auto-transition;
special moves persist until interrupted or `finish_move()` resolves
fallback. `actor.clear_motion()` or disabled/dead controls cancel
active moves and pending requests.

## 3. Add skeletal animation through data

Author a clip on the imported model's `AnimationPlayer` and add its
logical ID to the scene's `Action5SkeletonProfile.clip_map` resource.
The demo uses `demo/assets/crouch_skeleton_profile.tres`, with
`"crouch": "crouch"` and
`"crouch_walk": "crouch_walk"`. A new authored `dash` clip
would use `"dash": "dash"` (or map to a differently named imported
clip). The `AnimationPresenter` observes the active move ID and
resolves the key **without code changes**; missing optional move clips
fall back to idle. For ordinary grounded/airborne states it resolves
idle/walk/run and optional jump/fall based on speed and floor contact.

For a custom **looping** movement, author/import its clip to loop.
The demo generator uses glTF animation names `crouch-loop` and
`crouch_walk-loop` (imported as `crouch` and `crouch_walk`
with `Animation.LOOP_LINEAR`). Do **not** assume the animation
presenter's explicit idle/walk/run timeline overrides apply to
arbitrary move IDs. One-shot move duration is decided by gameplay,
not animation length.

Regenerate edited demo assets with
`node tools/generate_training_character.mjs` and
`node tools/generate_alternate_training_character.mjs`, then
`make import`. Map alternative rigs through their own
`SkeletonProfile`; preserve compatible bone/socket data and
record provenance/licenses in `docs/assets/LICENSES.md`.
Use `AnimationPresenter.set_upper_body_action` or
`set_full_body_action` only for separate **presentation-only**
action channels, and clear those overlays from the owning action.
See [animation.md](animation.md).

## 4. Optional first-person eye offset

For a movement that changes player height, **do not move the camera
from the movement component**. The actor can contain
`EyeOffset: Node3D` and `EyeHeightPresenter`
(`addons/action5/camera/eye_height_presenter.gd`), configured with
an ID-to-offset dictionary:

```text
move_offsets = {
  "crouch": -0.45,
  "crouch_walk": -0.45,
  "crawl": -0.85
}
```

`EyeHeightPresenter` observes `MovementController.move_changed`,
smoothly interpolates the local `EyeOffset.position.y`, and
disconnects/restores it when removed. Both crouch states share a
value to avoid vertical popping. The **optional** camera rig
`eye_offset_path` is resolved relative to the followed actor
(default `EyeOffset`), not relative to the Camera3D. In **F4
only**, effective eye height is the user-editable first-person
`ViewProfile.eye_height` plus the additive offset. Other views do
not use it. A blocked stand-up retains the crouch move ID and eye
target. See [cameras.md](cameras.md).

The eye offset affects **presentation**, not physical clearance.
The move still owns collision-shape resizing and obstruction checks.
Adding another move needs only an offset mapping, not a new camera
branch or a dependency from the move back to the camera.

## 5. Verification and review checklist

- [ ] New component registers under `Moves`, has a unique ID,
      action/key defaults respect existing remappings, and runtime
      registration/unregistration cleans up properly.
- [ ] Eligibility, arbitration/priority, `can_exit`, one-tick request
      edges, default grounded/airborne fallback and cancellation work.
- [ ] No direct `CharacterBody3D.velocity`, transform or
      `move_and_slide()` calls in a move; real collision, F1 lane lock,
      gravity, vertical override and slopes behave correctly.
- [ ] Collider changes use private shape instances and return to the
      original resource and position on interruption, disable and removal.
- [ ] Animation profile maps the move ID to a real imported clip, loops
      where required, and replacement rigs can use data-only mapping.
- [ ] Camera changes F1–F5 never recreate/reset actor or clip; any
      configured eye offset affects F4 alone, preserves camera settings,
      stays lowered while crouch-walking or blocked from standing,
      and resets when the presenter is removed.
- [ ] Real Godot regressions cover entry/exit, cancellation,
      dynamically installed moves and lifecycle; rendered native and
      browser screenshots cover visible poses and FPS height. **Headless
      pose tests alone do not prove visual correctness.**
- [ ] No changes to core actor, movement controller, locomotion solver,
      input adapter, animation presenter or camera's per-move behavior.

See `tests/d03_suite.gd` (generic runtime moves),
`tests/crouch_suite.gd` (multi-state stance, knees, clearance, camera
and teardown), `tests/d04_suite.gd` (view/model lifecycle) and
`tests/run_all.gd` (suite registration); do not hardcode an expected
fixed count of demo moves. Browser smoke lives in
`ci/browser-smoke.mjs`.

```bash
make import
make test
make run        # visually inspect the move in the relevant views
make build      # Linux and Web exports
make serve-web  # real browser/WebGL2 check
```

Document the exact CI run, screenshots, manual checks, failures and
limitations in the PR. Keep movement changes small and demo-independent.
