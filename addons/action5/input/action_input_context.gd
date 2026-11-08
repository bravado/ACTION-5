extends RefCounted
class_name Action5ActionInputContext
## Read-only-by-contract snapshot for actions/abilities. The input source
## owns the actor, facing, view and focus details, not its consumers.
## Camera is a reference for aim resolution, never a gameplay clock.

var accepting_actions: bool = false
var world_aim: Vector2 = Vector2.ZERO
var facing_world: Vector2 = Vector2(0.0, -1.0)
var view_mode: int = 0
var camera: Camera3D


func _init(
    available: bool = false,
    aim: Vector2 = Vector2.ZERO,
    facing: Vector2 = Vector2(0.0, -1.0),
    mode: int = 0,
    active_camera: Camera3D = null
) -> void:
    accepting_actions = available
    world_aim = aim if aim.is_finite() else Vector2.ZERO
    facing_world = facing if facing.is_finite() else Vector2.ZERO
    view_mode = mode
    camera = active_camera
