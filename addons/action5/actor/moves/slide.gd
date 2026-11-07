extends "res://addons/action5/actor/moves/move.gd"
class_name Action5SlideMove
## Example installable move: only this component defines slide eligibility,
## speed, duration and termination. The locomotion solver is unchanged.

@export_range(0.0, 20.0, 0.1) var slide_speed: float = 8.5
@export_range(0.01, 2.0, 0.01) var duration: float = 0.45
@export_range(0.0, 15.0, 0.1) var minimum_entry_speed: float = 2.8

var _time_left: float = 0.0
var _direction: Vector2 = Vector2.ZERO


func _init() -> void:
    move_id = &"slide"
    action_name = &"actor_slide"
    default_key = KEY_X
    default_gamepad_button = JOY_BUTTON_Y
    priority = 40


func can_enter(ctx: ContextScript) -> bool:
    return (
        ctx.body.is_on_floor()
        and ctx.horizontal_speed() >= minimum_entry_speed
        and ctx.intent != null
        and ctx.intent.world_move.length_squared() > 0.01
    )


func enter(ctx: ContextScript) -> void:
    _time_left = duration
    _direction = ctx.intent.world_move.normalized()
    if bool(ctx.locomotion.get("side_lane_locked")):
        _direction.y = 0.0
        _direction = _direction.normalized()


func physics_update(ctx: ContextScript, delta: float) -> void:
    ctx.request_horizontal_velocity(_direction * slide_speed)
    _time_left -= delta
    if _time_left <= 0.0 or not ctx.body.is_on_floor():
        ctx.finish_move()


func exit(_ctx: ContextScript) -> void:
    _time_left = 0.0
