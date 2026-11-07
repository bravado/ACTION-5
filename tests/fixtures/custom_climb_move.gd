extends "res://addons/action5/actor/moves/move.gd"
## Vertical traversal fixture: movement physics supports new vertical abilities
## without new is_climbing checks or state-dependent branches in locomotion.

var ticks: int = 0
var enter_count: int = 0


func _init() -> void:
    move_id = &"test_climb"
    action_name = &"actor_test_climb"
    default_key = KEY_B
    priority = 55


func can_enter(_ctx: ContextScript) -> bool:
    return true


func enter(ctx: ContextScript) -> void:
    ticks = 0
    enter_count += 1
    # A command issued on entry must survive until the solver runs this tick.
    ctx.request_horizontal_velocity(Vector2(6.0, 0.0))


func physics_update(ctx: ContextScript, _delta: float) -> void:
    if ticks > 0:
        ctx.request_horizontal_velocity(Vector2.ZERO)
    ctx.request_vertical_velocity(3.0)
    ctx.request_gravity_scale(0.0)
    ticks += 1
    if ticks >= 12:
        ctx.finish_move()
