extends Node3D

class_name Action5CameraRig

const ViewProfileScript = preload("res://addons/action5/camera/view_profile.gd")
## One persistent Camera3D for all six profiles; never owns gameplay state.

@onready var camera: Camera3D = $Camera3D

var profile: ViewProfileScript
var target: Node3D
var orbit_yaw: float = 0.0
var orbit_pitch: float = 0.0
var transition_count: int = 0
var _snap_next: bool = true


func apply_profile(next_profile: ViewProfileScript, next_target: Node3D) -> void:
    assert(next_profile != null)
    assert(next_target != null)
    var leaving_first_person: bool = (
        profile != null and profile.mode == ViewProfileScript.Mode.FIRST_PERSON
    )
    profile = next_profile
    target = next_target
    orbit_yaw = deg_to_rad(profile.default_yaw_degrees)
    orbit_pitch = deg_to_rad(profile.default_pitch_degrees)
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL if profile.orthographic else Camera3D.PROJECTION_PERSPECTIVE
    camera.size = profile.orthographic_size
    camera.fov = profile.field_of_view
    camera.current = true
    # No temporary camera inside the player's head when changing projection.
    _snap_next = (
        leaving_first_person
        or profile.mode == ViewProfileScript.Mode.FIRST_PERSON
        or profile.mode == ViewProfileScript.Mode.RETRO_TOPDOWN
        or transition_count == 0
    )
    transition_count += 1
    _update_camera(1.0 / 60.0)


func apply_mouse_motion(relative: Vector2) -> void:
    if profile == null or not profile.is_orbit_mode():
        return
    orbit_yaw -= relative.x * profile.mouse_sensitivity
    orbit_pitch = clampf(
        orbit_pitch - relative.y * profile.mouse_sensitivity,
        deg_to_rad(profile.min_pitch_degrees),
        deg_to_rad(profile.max_pitch_degrees)
    )


func _process(delta: float) -> void:
    if profile != null and is_instance_valid(target):
        _update_camera(delta)


func _update_camera(delta: float) -> void:
    if profile == null or target == null:
        return
    var actor_position: Vector3 = target.global_position
    var focus: Vector3 = actor_position + Vector3.UP * profile.focus_height
    var desired: Vector3 = focus + profile.fixed_offset
    var up_axis: Vector3 = Vector3.UP

    if profile.is_orbit_mode():
        if profile.mode == ViewProfileScript.Mode.FIRST_PERSON:
            focus = actor_position + Vector3.UP * profile.eye_height
            desired = focus
        else:
            var cos_pitch: float = cos(orbit_pitch)
            var orbit_offset := Vector3(
                sin(orbit_yaw) * cos_pitch,
                sin(orbit_pitch),
                cos(orbit_yaw) * cos_pitch
            ) * profile.chase_distance
            desired = focus + orbit_offset
    elif profile.bound_camera_target:
        focus.x = clampf(focus.x, profile.bounds_min.x, profile.bounds_max.x)
        focus.z = clampf(focus.z, profile.bounds_min.y, profile.bounds_max.y)
        desired = focus + profile.fixed_offset

    if profile.camera_collision and profile.mode == ViewProfileScript.Mode.THIRD_PERSON:
        var query := PhysicsRayQueryParameters3D.create(focus, desired, profile.camera_collision_mask)
        if target is CollisionObject3D:
            query.exclude = [(target as CollisionObject3D).get_rid()]
        var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
        if not hit.is_empty():
            var collision_position: Vector3 = hit["position"]
            var approach: Vector3 = (desired - focus).normalized()
            desired = collision_position - approach * profile.wall_margin

    # A vertical camera cannot use world Y as "up": this would be collinear.
    if profile.is_overhead():
        up_axis = Vector3.FORWARD

    var alpha: float = 1.0
    if not _snap_next and profile.follow_speed > 0.0:
        alpha = 1.0 - exp(-profile.follow_speed * maxf(delta, 0.0))
    camera.global_position = camera.global_position.lerp(desired, alpha)
    _snap_next = false

    if profile.mode == ViewProfileScript.Mode.FIRST_PERSON:
        camera.global_basis = Basis.from_euler(Vector3(-orbit_pitch, orbit_yaw, 0.0))
    else:
        camera.look_at(focus, up_axis)


func is_vertical_overhead() -> bool:
    if profile == null or not profile.is_overhead():
        return false
    return camera.global_transform.basis.z.normalized().dot(Vector3.UP) > 0.999
