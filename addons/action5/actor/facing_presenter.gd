extends Node3D
class_name Action5FacingPresenter
## Visual-only heading; no physics, collision, or camera rig updates.

@export_range(0.0, 40.0, 0.5) var turn_rate_radians: float = 16.0
var facing_world: Vector2 = Vector2(0.0, -1.0)


func set_facing(direction: Vector2) -> void:
    if direction.is_finite() and direction.length_squared() > 0.001:
        facing_world = direction.normalized()


func _process(delta: float) -> void:
    var target_rotation: float = atan2(-facing_world.x, -facing_world.y)
    var step: float = turn_rate_radians * maxf(delta, 0.0)
    rotation.y = rotate_toward(rotation.y, target_rotation, step)
