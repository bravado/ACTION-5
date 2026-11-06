extends RefCounted
class_name Action5MoveIntent
## View-independent world-plane movement/aim command for one physics tick.
## This is a data contract, not an input poller or gameplay controller.

var world_move: Vector2 = Vector2.ZERO  # (world X, world Z), never world Y
var face_world: Vector2 = Vector2.ZERO
var aim_world: Vector2 = Vector2.ZERO
var jump_pressed: bool = false
var running: bool = false
var dodge_pressed: bool = false
var view_mode: int = 1


func _init(
    move: Vector2 = Vector2.ZERO,
    face: Vector2 = Vector2.ZERO,
    aim: Vector2 = Vector2.ZERO
) -> void:
    world_move = move.limit_length(1.0) if move.is_finite() else Vector2.ZERO
    face_world = face.normalized() if face.is_finite() else Vector2.ZERO
    aim_world = aim.normalized() if aim.is_finite() else Vector2.ZERO


func clear() -> void:
    world_move = Vector2.ZERO
    face_world = Vector2.ZERO
    aim_world = Vector2.ZERO
    jump_pressed = false
    running = false
    dodge_pressed = false
