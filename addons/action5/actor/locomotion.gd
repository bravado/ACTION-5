extends Node
class_name Action5Locomotion
## One CharacterBody3D is authoritative. This component only applies intents.
## Uses a fixed physics tick, floor snapping and slope-compatible move_and_slide.

const IntentScript = preload("res://addons/action5/actor/move_intent.gd")
const MoveControllerScript = preload("res://addons/action5/actor/moves/movement_controller.gd")
const ContextScript = preload("res://addons/action5/actor/moves/move_context.gd")

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

@onready var body: CharacterBody3D = get_parent() as CharacterBody3D
@onready var move_controller: MoveControllerScript = $MovementController

var desired: IntentScript = IntentScript.new()
var enabled: bool = true
var side_lane_locked: bool = false
var side_lane_z: float = 0.0
var _coyote_left: float = 0.0
var _jump_buffer_left: float = 0.0


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
    # Queue edge-triggered move requests. The controller evaluates them in
    # its physics tick, after the one-tick command context has been reset.
    for move_id in desired.requested_moves:
        move_controller.request_move(move_id)


func lock_side_lane() -> void:
    if body != null:
        side_lane_z = body.global_position.z
    side_lane_locked = true


func unlock_side_lane() -> void:
    side_lane_locked = false


func stop() -> void:
    desired = IntentScript.new()
    _jump_buffer_left = 0.0
    if is_instance_valid(move_controller):
        move_controller.cancel()
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

    # A move component may request a different X/Z velocity this tick,
    # but only this solver assigns velocity and calls move_and_slide().
    var ctx: ContextScript = move_controller.tick(desired, delta)
    var movement: Vector2 = desired.world_move.limit_length(1.0)
    if side_lane_locked:
        movement.y = 0.0
        # Never change the actor's position or velocity at view-switch time.
        # The new lane policy takes effect on the next physical tick.
        body.velocity.z = 0.0

    if ctx.has_horizontal_override:
        var override: Vector2 = ctx.horizontal_override
        if side_lane_locked:
            override.y = 0.0
        body.velocity.x = override.x
        body.velocity.z = override.y
    else:
        var speed: float = run_speed if desired.running else walk_speed
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

    # Generic move commands can change vertical motion/gravity too (e.g.
    # climbing or wall-running), without adding another move-specific branch.
    if ctx.has_vertical_override:
        body.velocity.y = ctx.vertical_override
    _attempt_step(delta)
    _apply_gravity(delta * ctx.gravity_scale)
    body.move_and_slide()

    # The side lane is an X/Y plane, not a second 2D world. Prevent
    # collision-sliding Z drift without snapping to a different lane.
    if side_lane_locked and absf(body.global_position.z - side_lane_z) < 0.20:
        var fixed_position: Vector3 = body.global_position
        fixed_position.z = side_lane_z
        body.global_position = fixed_position
        body.velocity.z = 0.0


## Optional step assist: only rise as far as a real walkable landing.
## All three sweeps are collision tests; the solver still owns move_and_slide().
func _attempt_step(delta: float) -> void:
    if max_step_height <= 0.0 or not body.is_on_floor() or body.velocity.y > 0.0:
        return
    var horizontal := Vector3(body.velocity.x, 0.0, body.velocity.z) * delta
    if horizontal.length_squared() < 0.000001:
        return
    var transform: Transform3D = body.global_transform
    if not body.test_move(transform, horizontal):
        return

    var rise := body.up_direction * max_step_height
    if body.test_move(transform, rise):
        return
    if body.test_move(transform.translated(rise), horizontal):
        return

    # Probe for support at the destination, not at the original position.
    # A blocked path alone does not imply there is anything safe to stand on.
    var landing := KinematicCollision3D.new()
    var landing_from: Transform3D = transform.translated(rise + horizontal)
    var drop: Vector3 = -body.up_direction * (max_step_height + floor_snap_distance)
    if not body.test_move(landing_from, drop, landing):
        return
    if landing.get_normal().dot(body.up_direction) < cos(body.floor_max_angle):
        return

    # Landing travel gives the actual step rise (usually less than the max).
    # Reject the original floor/unsupported ledges as well as oversized rises.
    var height: float = max_step_height + landing.get_travel().dot(body.up_direction)
    if height <= body.safe_margin or height > max_step_height + body.safe_margin:
        return
    body.global_position += body.up_direction * height


func _apply_gravity(delta: float) -> void:
    if not body.is_on_floor():
        body.velocity.y -= float(ProjectSettings.get_setting("physics/3d/default_gravity")) * delta
    elif body.velocity.y < 0.0:
        body.velocity.y = 0.0
