extends "res://addons/action5/actor/moves/move.gd"
class_name Action5DodgeMove
## One-shot collision-respecting burst. No direct velocity/transform writes.

@export_range(0.0, 12.0, 0.5) var speed_bonus: float = 4.0
@export_range(0.01, 0.6, 0.01) var duration: float = 0.16

var _time_left: float = 0.0
var _direction: Vector2 = Vector2.ZERO


func can_enter(ctx: ContextScript) -> bool:
    return ctx.intent != null and ctx.intent.world_move.length_squared() > 0.01


func enter(ctx: ContextScript) -> void:
    _time_left = duration
    _direction = ctx.intent.world_move.normalized()
    if bool(ctx.locomotion.get("side_lane_locked")):
        _direction.y = 0.0
        _direction = _direction.normalized()


func physics_update(ctx: ContextScript, delta: float) -> void:
    var speed: float = float(ctx.locomotion.get("walk_speed")) + speed_bonus
    ctx.request_horizontal_velocity(_direction * speed)
    _time_left -= delta
    if _time_left <= 0.0:
        ctx.finish_move()


func exit(_ctx: ContextScript) -> void:
    _time_left = 0.0
