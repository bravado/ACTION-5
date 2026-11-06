extends CharacterBody3D
## D01 debug actor: deliberately small. D02 will replace input/policy selection.
## This actor receives a world-plane movement intent, never reads raw keys.

@export_range(0.1, 20.0, 0.1) var walk_speed: float = 4.5
@export_range(1.0, 60.0, 1.0) var acceleration: float = 19.0

var _planar_intent: Vector2 = Vector2.ZERO


func set_move_intent(intent: Vector2) -> void:
    _planar_intent = intent.limit_length(1.0)


func _physics_process(delta: float) -> void:
    velocity.x = move_toward(velocity.x, _planar_intent.x * walk_speed, acceleration * delta)
    velocity.z = move_toward(velocity.z, _planar_intent.y * walk_speed, acceleration * delta)
    if not is_on_floor():
        velocity.y -= float(ProjectSettings.get_setting("physics/3d/default_gravity")) * delta
    elif velocity.y < 0.0:
        velocity.y = 0.0

    move_and_slide()

    if _planar_intent.length_squared() > 0.02:
        $Visual.rotation.y = atan2(-_planar_intent.x, -_planar_intent.y)
