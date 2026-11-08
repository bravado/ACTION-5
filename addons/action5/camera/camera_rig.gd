extends Node3D

class_name Action5CameraRig

const ViewProfileScript = preload("res://addons/action5/camera/view_profile.gd")
## One persistent Camera3D for all five profiles; never owns gameplay state.

@onready var camera: Camera3D = $Camera3D
## Optional target-relative presentation offset (no movement dependencies).
@export var eye_offset_path: NodePath = ^"EyeOffset"

var profile: ViewProfileScript
var target: Node3D
var _eye_offset: Node3D
var orbit_yaw: float = 0.0
var orbit_pitch: float = 0.0
var transition_count: int = 0
var _snap_next: bool = true
# Preserve F4 mouse look while other modes borrow orbit_yaw/orbit_pitch.
var _first_person_orbit: Vector2 = Vector2.ZERO
var _first_person_orbit_initialized: bool = false


func apply_profile(next_profile: ViewProfileScript, next_target: Node3D) -> void:
    assert(next_profile != null)
    assert(next_target != null)
    var leaving_first_person: bool = (
        profile != null and profile.mode == ViewProfileScript.Mode.FIRST_PERSON
    )
    if leaving_first_person:
        _first_person_orbit = Vector2(orbit_yaw, orbit_pitch)
    profile = next_profile
    target = next_target
    _eye_offset = target.get_node_or_null(eye_offset_path) as Node3D
    # Isometric uses mouse offsets relative to the zoom-dependent angle.
    # F4 remembers its own direct yaw/pitch when switching to other views.
    if profile.mode == ViewProfileScript.Mode.FIRST_PERSON:
        if not _first_person_orbit_initialized:
            _first_person_orbit = Vector2(
                deg_to_rad(profile.default_yaw_degrees),
                deg_to_rad(profile.default_pitch_degrees)
            )
            _first_person_orbit_initialized = true
        orbit_yaw = _first_person_orbit.x
        orbit_pitch = clampf(
            _first_person_orbit.y,
            deg_to_rad(profile.min_pitch_degrees),
            deg_to_rad(profile.max_pitch_degrees)
        )
    else:
        orbit_yaw = 0.0
        orbit_pitch = 0.0
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL if profile.orthographic else Camera3D.PROJECTION_PERSPECTIVE
    camera.size = profile.orthographic_size
    camera.fov = profile.field_of_view
    camera.current = true
    # No temporary camera inside the player's head when changing projection.
    _snap_next = (
        leaving_first_person
        or profile.mode == ViewProfileScript.Mode.FIRST_PERSON
        or profile.mode == ViewProfileScript.Mode.RETRO_TOPDOWN
        # One isometric profile contains both high and close shoulder framing.
        or profile.mode == ViewProfileScript.Mode.ISOMETRIC
        # A platformer-style side view must be exactly horizontal immediately.
        or profile.mode == ViewProfileScript.Mode.SIDE
        or transition_count == 0
    )
    transition_count += 1
    _update_camera(1.0 / 60.0)


## Apply live UI tuning without resetting current mouse yaw or the player.
func refresh_settings(update_pitch: bool = false) -> void:
    if profile == null or target == null:
        return
    camera.size = profile.orthographic_size
    camera.fov = profile.field_of_view
    # ISO pitch is defined by the far/close profile settings plus the
    # user's orbit offset, so changing a slider does not reset mouse input.
    _snap_next = true
    _update_camera(1.0 / 60.0)


func apply_mouse_motion(relative: Vector2) -> void:
    if profile == null or not profile.is_orbit_mode():
        return
    orbit_yaw -= relative.x * profile.mouse_sensitivity
    if profile.mode == ViewProfileScript.Mode.ISOMETRIC:
        orbit_pitch = clampf(
            orbit_pitch - relative.y * profile.mouse_sensitivity,
            deg_to_rad(-60.0),
            deg_to_rad(60.0)
        )
    else:
        # First-person camera uses X = -orbit_pitch in its rotation basis.
        # Positive mouse Y must therefore increase orbit_pitch for the
        # standard (non-inverted) "mouse down -> look down" behavior.
        var pitch_sign: float = -1.0 if profile.invert_y else 1.0
        orbit_pitch = clampf(
            orbit_pitch + relative.y * profile.mouse_sensitivity * pitch_sign,
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
    var look_target: Vector3 = focus
    var up_axis: Vector3 = Vector3.UP

    if profile.is_orbit_mode():
        if profile.mode == ViewProfileScript.Mode.FIRST_PERSON:
            # Additive data from the actor; neither this rig nor its
            # ViewProfile needs to know whether the move is crouch or crawl.
            var local_eye_y: float = (
                _eye_offset.position.y if is_instance_valid(_eye_offset) else 0.0
            )
            focus = actor_position + Vector3.UP * (profile.eye_height + local_eye_y)
            desired = focus
        else:
            # A SINGLE isometric profile blends between a wide, inclined
            # orthographic view and a short, behind-shoulder view as zoom
            # approaches 4.0. Camera projection remains orthographic.
            # No additional gameplay mode or player actor is created.
            var close_factor: float = get_isometric_close_factor()
            var yaw: float = lerp_angle(
                deg_to_rad(profile.default_yaw_degrees),
                deg_to_rad(profile.close_yaw_degrees),
                close_factor
            ) + orbit_yaw
            var pitch: float = clampf(
                lerpf(deg_to_rad(profile.default_pitch_degrees),
                    deg_to_rad(profile.close_pitch_degrees), close_factor) + orbit_pitch,
                deg_to_rad(profile.min_pitch_degrees),
                deg_to_rad(profile.max_pitch_degrees)
            )
            var distance: float = lerpf(profile.chase_distance, profile.close_chase_distance, close_factor)
            var cos_pitch: float = cos(pitch)
            var orbit_offset := Vector3(
                sin(yaw) * cos_pitch,
                sin(pitch),
                cos(yaw) * cos_pitch
            ) * distance
            desired = focus + orbit_offset
            var right_axis := Vector3(cos(yaw), 0.0, -sin(yaw))
            var facing_axis := Vector3(-sin(yaw), 0.0, -cos(yaw))
            desired += right_axis * profile.shoulder_offset * close_factor
            desired += Vector3.UP * profile.shoulder_lift * close_factor
            look_target += facing_axis * profile.aim_ahead * close_factor
    elif profile.bound_camera_target:
        focus.x = clampf(focus.x, profile.bounds_min.x, profile.bounds_max.x)
        focus.z = clampf(focus.z, profile.bounds_min.y, profile.bounds_max.y)
        desired = focus + profile.fixed_offset

    var collided_with_wall: bool = false
    if profile.camera_collision and profile.mode == ViewProfileScript.Mode.ISOMETRIC and get_isometric_close_factor() > 0.35:
        var query := PhysicsRayQueryParameters3D.create(focus, desired, profile.camera_collision_mask)
        if target is CollisionObject3D:
            query.exclude = [(target as CollisionObject3D).get_rid()]
        var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
        if not hit.is_empty():
            collided_with_wall = true
            var collision_position: Vector3 = hit["position"]
            var approach: Vector3 = (desired - focus).normalized()
            desired = collision_position - approach * profile.wall_margin

    # A vertical camera cannot use world Y as "up": this would be collinear.
    if profile.is_overhead():
        up_axis = Vector3.FORWARD

    var alpha: float = 1.0
    # A blocked shoulder camera must not interpolate through the wall.
    if not _snap_next and profile.follow_speed > 0.0 and not collided_with_wall:
        alpha = 1.0 - exp(-profile.follow_speed * maxf(delta, 0.0))
    camera.global_position = camera.global_position.lerp(desired, alpha)
    _snap_next = false

    if profile.mode == ViewProfileScript.Mode.FIRST_PERSON:
        camera.global_basis = Basis.from_euler(Vector3(-orbit_pitch, orbit_yaw, 0.0))
    elif profile.mode == ViewProfileScript.Mode.SIDE:
        # Fixed side-on projection: -Z is always into the stage. NEVER look_at()
        # the actor here; smoothing would introduce yaw/pitch and ruin the XY view.
        camera.global_basis = Basis.IDENTITY
    else:
        camera.look_at(look_target, up_axis)


func get_isometric_close_factor() -> float:
    if profile == null or profile.mode != ViewProfileScript.Mode.ISOMETRIC:
        return 0.0
    # 14+ world units => traditional isometric; 4 or less => over-shoulder.
    return clampf((14.0 - profile.orthographic_size) / 10.0, 0.0, 1.0)


func is_vertical_overhead() -> bool:
    if profile == null or not profile.is_overhead():
        return false
    return camera.global_transform.basis.z.normalized().dot(Vector3.UP) > 0.999
