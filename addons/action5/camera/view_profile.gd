extends Resource
class_name Action5ViewProfile
## D02 reusable camera/control policy. No demo/ dependencies.

enum Mode {
    SIDE,
    BEATEMUP,
    ISOMETRIC,
    THIRD_PERSON,
    FIRST_PERSON,
    RETRO_TOPDOWN,
}

@export var mode: Mode = Mode.BEATEMUP
@export var display_name: String = "Beat'em Up"
@export var fixed_offset: Vector3 = Vector3(0.0, 10.0, 13.0)
@export_range(0.0, 3.0, 0.05) var focus_height: float = 0.85
@export var orthographic: bool = true
@export_range(4.0, 45.0, 0.5) var orthographic_size: float = 17.0
@export_range(35.0, 105.0, 1.0) var field_of_view: float = 70.0
@export_range(0.0, 30.0, 0.1) var follow_speed: float = 9.0
@export var bound_camera_target: bool = true
@export var bounds_min: Vector2 = Vector2(-11.0, -6.0)
@export var bounds_max: Vector2 = Vector2(11.0, 6.0)
@export_range(1.0, 14.0, 0.25) var chase_distance: float = 4.5
@export_range(-70.0, 80.0, 1.0) var default_pitch_degrees: float = 18.0
@export_range(-180.0, 180.0, 1.0) var default_yaw_degrees: float = 0.0
@export_range(0.5, 2.3, 0.05) var eye_height: float = 1.55
@export var camera_collision: bool = false
@export_flags_3d_physics var camera_collision_mask: int = 1
@export_range(0.08, 1.0, 0.01) var wall_margin: float = 0.25
@export_range(0.001, 0.02, 0.001) var mouse_sensitivity: float = 0.003
@export_range(-80.0, 0.0, 1.0) var min_pitch_degrees: float = -65.0
@export_range(0.0, 85.0, 1.0) var max_pitch_degrees: float = 65.0


func is_orbit_mode() -> bool:
    return mode == Mode.THIRD_PERSON or mode == Mode.FIRST_PERSON


func is_overhead() -> bool:
    return mode == Mode.RETRO_TOPDOWN
