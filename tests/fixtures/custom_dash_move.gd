extends "res://addons/action5/actor/moves/move.gd"
## Regression fixture intentionally outside addon. Installing this move must
## require zero edits to the Actor, Locomotion or InputAdapter implementations.

var enter_count: int = 0
var exit_count: int = 0
var tick_count: int = 0


func _init() -> void:
    move_id = &"test_dash"
    action_name = &"actor_test_dash"
    default_key = KEY_V
    default_gamepad_button = -1
    priority = 30


func can_enter(ctx: ContextScript) -> bool:
    return ctx.intent != null and ctx.intent.world_move.length_squared() > 0.01


func enter(_ctx: ContextScript) -> void:
    enter_count += 1
    tick_count = 0


func physics_update(ctx: ContextScript, _delta: float) -> void:
    tick_count += 1
    ctx.request_horizontal_velocity(Vector2(6.0, 0.0))
    if tick_count >= 6:
        ctx.finish_move()


func exit(_ctx: ContextScript) -> void:
    exit_count += 1
