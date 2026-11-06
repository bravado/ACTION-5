extends Node
class_name Action5Locomotion
## One CharacterBody3D is authoritative. This component only applies intents.
## Uses a fixed physics tick, floor snapping and slope-compatible move_and_slide.

const IntentScript = preload("res://addons/action5/actor/move_intent.gd")

@export_range(0.1, 20.0, 0.1) var walk_speed: float = 4.5
@export_range(0.1, 30.0, 0.1) var run_speed: float = 7.5
@export_range(1.0, 100.0, 0.5) var acceleration: float = 24.0
@export_range(1.0, 100.0, 0.5) var deceleration: float = 31.0
@export_range(1.0, 20.0, 0.1) var jump_speed: float = 6.3
@export_range(0.0, 1.0, 0.01) var floor_snap_distance: float = 0.30
@export_range(0.0, 0.6, 0.01) var max_step_height: float = 0.35
@export_range(5.0, 65.0, 1.0) var floor_slope_max_degrees: float = 45.0
@export_range(0.0, 0.25, 0.01) var coyote_seconds: float = 0.10
@export_range(0.0, 0.25, 0.01) var jump_buffer_seconds: float = 0.12
@export_range(0.0, 12.0, 0.5) var dodge_speed_bonus: float = 4.0
@export_range(0.0, 0.6, 0.05) var dodge_seconds: float = 0.16

@onready var body: CharacterBody3D = get_parent() as CharacterBody3D

var desired: IntentScript = IntentScript.new()
var enabled: bool = true
var side_lane_locked: bool = false
var side_lane_z: float = 0.0
var _coyote_left: float = 0.0
var _jump_buffer_left: float = 0.0
var _dodge_left: float = 0.0
var _dodge_direction: Vector2 = Vector2.ZERO


func _ready() -> void:
    if body == null:
        push_error("ACTION5: Locomotion must be a child of CharacterBody3D")
        set_physics_process(false)
        return
    body.floor_snap_length = floor_snap_distance
    body.floor_max_angle = deg_to_rad(floor_slope_max_degrees)
    body.floor_constant_speed = true


func apply_intent(next: IntentScript) -> void:
    desired = next if next != null else IntentScript.new()
    if desired.jump_pressed:
        _jump_buffer_left = jump_buffer_seconds
    if desired.dodge_pressed and _dodge_left <= 0.0 and desired.world_move.length_squared() > 0.01:
        _dodge_left = dodge_seconds
        _dodge_direction = desired.world_move.normalized()


func lock_side_lane() -> void:
    if body != null:
        side_lane_z = body.global_position.z
    side_lane_locked = true


func unlock_side_lane() -> void:
    side_lane_locked = false


func stop() -> void:
    desired = IntentScript.new()
    _jump_buffer_left = 0.0
    _dodge_left = 0.0
    _dodge_direction = Vector2.ZERO
    if body != null:
        body.velocity.x = 0.0
        body.velocity.z = 0.0


func set_enabled(value: bool) -> void:
    enabled = value
    if not value:
        stop()


func _physics_process(delta: float) -> void:
    if body == null:
        return
    if not enabled:
        # Keep gravity active in disabled/dead states, but never move laterally.
        body.velocity.x = 0.0
        body.velocity.z = 0.0
        _apply_gravity(delta)
        body.move_and_slide()
        return

    _coyote_left = coyote_seconds if body.is_on_floor() else maxf(_coyote_left - delta, 0.0)
    _jump_buffer_left = maxf(_jump_buffer_left - delta, 0.0)
    _dodge_left = maxf(_dodge_left - delta, 0.0)

    var movement: Vector2 = desired.world_move.limit_length(1.0)
    if side_lane_locked:
        movement.y = 0.0
        # A view switch does not edit the actor's position or velocity.
        # Stop depth *acceleration* on the next physics tick.
        body.velocity.z = 0.0

    var speed: float = run_speed if desired.running else walk_speed
    if _dodge_left > 0.0:
        movement = _dodge_direction
        if side_lane_locked:
            movement.y = 0.0
        speed += dodge_speed_bonus

    var target_x: float = movement.x * speed
    var target_z: float = movement.y * speed
    var accel_x: float = acceleration if absf(target_x) > absf(body.velocity.x) else deceleration
    var accel_z: float = acceleration if absf(target_z) > absf(body.velocity.z) else deceleration
    body.velocity.x = move_toward(body.velocity.x, target_x, accel_x * delta)
    body.velocity.z = move_toward(body.velocity.z, target_z, accel_z * delta)

    if _jump_buffer_left > 0.0 and _coyote_left > 0.0:
        body.velocity.y = jump_speed
        _jump_buffer_left = 0.0
        _coyote_left = 0.0

    _attempt_step(delta)
    _apply_gravity(delta)
    body.move_and_slide()

    # The side lane is an X/Y plane, not a second 2D world. Prevent
    # collision-sliding Z drift without snapping to a different lane.
    if side_lane_locked and absf(body.global_position.z - side_lane_z) < 0.20:
        var fixed_position: Vector3 = body.global_position
        fixed_position.z = side_lane_z
        body.global_position = fixed_position
        body.velocity.z = 0.0


## Optional low-obstacle step assist; never bypasses collision.
## It checks rise clearance and an unblocked horizontal path before lifting.
func _attempt_step(delta: float) -> void:
    if max_step_height <= 0.0 or not body.is_on_floor():
        return
    var horizontal := Vector3(body.velocity.x, 0.0, body.velocity.z) * delta
    if horizontal.length_squared() < 0.000001:
        return
    var transform: Transform3D = body.global_transform
    if not body.test_move(transform, horizontal):
        return
    var rise := Vector3.UP * max_step_height
    if body.test_move(transform, rise):
        return
    if body.test_move(transform.translated(rise), horizontal):
        return
    body.global_position += rise


func _apply_gravity(delta: float) -> void:
    if not body.is_on_floor():
        body.velocity.y -= float(ProjectSettings.get_setting("physics/3d/default_gravity")) * delta
    elif body.velocity.y < 0.0:
        body.velocity.y = 0.0
