extends Node
class_name Action5ViewManager
## Owns only view selection and instrumentation. Never modifies actor physics or HP.

signal view_changed(current_profile: Action5ViewProfile, previous_profile: Action5ViewProfile)

@export var actor_path: NodePath = ^"../Player"
@export var initial_view_index: int = 1
@export var profiles: Array[Action5ViewProfile] = []

@onready var camera_rig: Action5CameraRig = $CameraRig

var actor: Node3D
var current_profile: Action5ViewProfile
var active_index: int = -1
var switch_count: int = 0
var last_position_delta: float = 0.0


func _ready() -> void:
    actor = get_node_or_null(actor_path) as Node3D
    if actor == null:
        push_error("ACTION5: ViewManager actor_path does not resolve to Node3D")
        return
    if profiles.is_empty():
        for path in [
            "res://addons/action5/views/side.tres",
            "res://addons/action5/views/beatemup.tres",
            "res://addons/action5/views/isometric.tres",
            "res://addons/action5/views/third_person.tres",
            "res://addons/action5/views/first_person.tres",
            "res://addons/action5/views/retro_topdown.tres",
        ]:
            profiles.append(load(path) as Action5ViewProfile)
    if profiles.size() != 6:
        push_error("ACTION5: ViewManager requires six ViewProfile resources")
        return
    for profile in profiles:
        if profile == null:
            push_error("ACTION5: ViewManager cannot use a null profile")
            return
    switch_view(clampi(initial_view_index, 0, profiles.size() - 1))


func switch_view(index: int) -> bool:
    if actor == null or index < 0 or index >= profiles.size():
        return false
    var next_profile: Action5ViewProfile = profiles[index]
    if next_profile == null:
        return false
    if active_index == index:
        return true

    var previous_profile: Action5ViewProfile = current_profile
    var position_before: Vector3 = actor.global_position
    var velocity_before: Vector3 = Vector3.ZERO
    if actor is CharacterBody3D:
        velocity_before = (actor as CharacterBody3D).velocity

    active_index = index
    current_profile = next_profile
    camera_rig.apply_profile(next_profile, actor)
    _apply_local_presentation()
    last_position_delta = actor.global_position.distance_to(position_before)
    # Detect inadvertent future coupling without making the view own movement.
    assert(last_position_delta < 0.0001, "Camera switching must not teleport an actor")
    if actor is CharacterBody3D:
        assert((actor as CharacterBody3D).velocity == velocity_before,
            "Camera switching must not modify actor velocity")
    switch_count += 1
    view_changed.emit(current_profile, previous_profile)
    print("ACTION5_VIEW_CHANGED index=", index + 1, " mode=", current_profile.display_name)
    return true


func cycle_view(direction: int) -> bool:
    if profiles.is_empty():
        return false
    return switch_view(posmod(active_index + direction, profiles.size()))


func get_active_camera() -> Camera3D:
    return camera_rig.camera


func _apply_local_presentation() -> void:
    var visuals: Node3D = actor.get_node_or_null("Visual") as Node3D
    if visuals != null:
        visuals.visible = current_profile.mode != Action5ViewProfile.Mode.FIRST_PERSON
