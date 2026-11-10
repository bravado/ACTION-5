extends Node
## Continuous world-space camera clamps for physically connected sectors.
## Profiles are duplicated per game instance; arena and dungeon share the
## SAME camera axes and ONE union rectangle. Walking across the doorway
## never snaps the camera, rotates WASD, or resets orbit/first-person look.

const ProfileScript = preload("res://addons/action5/camera/view_profile.gd")

@export var view_manager_path: NodePath = ^"../ViewManager"
@export var dungeon_path: NodePath = ^"../EncounterSector"
@export var location_manager_path: NodePath = ^"../LocationManager"
@export var detached_half_size: Vector2 = Vector2(9.0, 6.0)

var _connected_bounds: Array[Dictionary] = []

@onready var views: Node = get_node_or_null(view_manager_path)
@onready var dungeon: Node3D = get_node_or_null(dungeon_path) as Node3D


func _ready() -> void:
    if views == null or dungeon == null:
        push_error("ACTION5: SectorCameraBounds needs ViewManager and the dungeon")
        return
    var originals: Array = views.get("profiles")
    if originals.is_empty():
        push_error("ACTION5: SectorCameraBounds needs initialized view profiles")
        return
    var root := get_parent() as Node3D
    # Both sectors have exactly the same world axes: only the dungeon
    # origin is translated. The union also admits every point in the
    # physical doorway, with no camera discontinuity at the boundary.
    var delta := Vector2(
        dungeon.global_position.x - root.global_position.x,
        dungeon.global_position.z - root.global_position.z
    )
    for i in range(originals.size()):
        var profile := originals[i] as ProfileScript
        if profile == null:
            push_error("ACTION5: SectorCameraBounds received invalid profile")
            return
        var local_profile := profile.duplicate(true) as ProfileScript
        var original_min: Vector2 = profile.bounds_min
        var original_max: Vector2 = profile.bounds_max
        local_profile.bounds_min = Vector2(
            minf(original_min.x, original_min.x + delta.x),
            minf(original_min.y, original_min.y + delta.y)
        )
        local_profile.bounds_max = Vector2(
            maxf(original_max.x, original_max.x + delta.x),
            maxf(original_max.y, original_max.y + delta.y)
        )
        originals[i] = local_profile
        _connected_bounds.append({
            "min": local_profile.bounds_min,
            "max": local_profile.bounds_max
        })
    views.set("profiles", originals)
    var active: int = int(views.get("active_index"))
    if active >= 0 and active < originals.size():
        views.set("current_profile", originals[active])
        views.get_node("CameraRig").set("profile", originals[active])
    # No sector_changed listener: ordinary connected doors never move
    # or reset a camera. Explicit REMOTE scene travel is different.
    var locations: Node = get_node_or_null(location_manager_path)
    if locations != null:
        locations.location_changed.connect(_on_location_changed)


func _on_location_changed(_previous: StringName, current: StringName,
        location_root: Node3D) -> void:
    if not is_instance_valid(views):
        return
    var profiles: Array = views.get("profiles")
    for i in range(mini(profiles.size(), _connected_bounds.size())):
        var p := profiles[i] as ProfileScript
        if p == null:
            continue
        if current == &"connected" or not is_instance_valid(location_root):
            p.bounds_min = _connected_bounds[i]["min"]
            p.bounds_max = _connected_bounds[i]["max"]
        else:
            # Only an explicit nonadjacent transition changes bounds.
            # Do not mutate a shared authored .tres or the actor's yaw.
            var center := Vector2(location_root.global_position.x,
                location_root.global_position.z)
            p.bounds_min = center - detached_half_size
            p.bounds_max = center + detached_half_size
    var rig: Node = views.get_node_or_null("CameraRig")
    if rig != null and rig.has_method("refresh_settings"):
        rig.call("refresh_settings")

