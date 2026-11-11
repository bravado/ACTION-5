extends Node
## Presentation adapter for one connected world and any number of added
## sectors. Author per-profile local bounds once; transform all four X/Z
## corners for each sector, including rotated sectors, into world-space AABBs.
## Only explicit detached travel temporarily reframes the same camera.

const ProfileScript = preload("res://addons/action5/camera/view_profile.gd")

@export var view_manager_path: NodePath = ^"../ViewManager"
## Scene composition supplies connected roots; the parent is always sector 0.
## No assumption that the extra levels have the same world rotation.
@export var connected_sector_paths: Array[NodePath] = [^"../EncounterSector"]
@export var location_manager_path: NodePath = ^"../LocationManager"
@export var detached_half_size: Vector2 = Vector2(9.0, 6.0)

var _connected_bounds: Array[Dictionary] = []
@onready var views: Node = get_node_or_null(view_manager_path)


func _ready() -> void:
    if views == null:
        push_error("ACTION5: SectorCameraBounds needs ViewManager")
        return
    var originals: Array = views.get("profiles")
    if originals.is_empty():
        push_error("ACTION5: SectorCameraBounds needs initialized profiles")
        return
    var sectors: Array[Node3D] = [get_parent() as Node3D]
    for path in connected_sector_paths:
        var sector: Node3D = get_node_or_null(path) as Node3D
        if not is_instance_valid(sector):
            push_error("ACTION5: Invalid connected sector path: " + str(path))
            return
        sectors.append(sector)
    for i in range(originals.size()):
        var profile := originals[i] as ProfileScript
        if profile == null:
            push_error("ACTION5: SectorCameraBounds received invalid profile")
            return
        var local_profile := profile.duplicate(true) as ProfileScript
        var union: Dictionary = _bounds_for_sectors(profile.bounds_min,
            profile.bounds_max, sectors)
        local_profile.bounds_min = union["min"]
        local_profile.bounds_max = union["max"]
        originals[i] = local_profile
        _connected_bounds.append(union)
    views.set("profiles", originals)
    var active: int = int(views.get("active_index"))
    if active >= 0 and active < originals.size():
        views.set("current_profile", originals[active])
        views.get_node("CameraRig").set("profile", originals[active])
    # A physical gateway does not reframe or alter movement axes.
    var locations: Node = get_node_or_null(location_manager_path)
    if locations != null:
        locations.location_changed.connect(_on_location_changed)


## Four transformed footprint corners per sector. Called only at setup,
## not every frame. Also supports an arbitrary number of rotated sectors.
func _bounds_for_sectors(local_min: Vector2, local_max: Vector2,
        sectors: Array[Node3D]) -> Dictionary:
    var low := Vector2(INF, INF)
    var high := Vector2(-INF, -INF)
    for sector in sectors:
        for x in [local_min.x, local_max.x]:
            for z in [local_min.y, local_max.y]:
                var global: Vector3 = sector.to_global(Vector3(x, 0.0, z))
                var point := Vector2(global.x, global.z)
                low = Vector2(minf(low.x, point.x), minf(low.y, point.y))
                high = Vector2(maxf(high.x, point.x), maxf(high.y, point.y))
    return {"min": low, "max": high}


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
            var center := Vector2(location_root.global_position.x,
                location_root.global_position.z)
            p.bounds_min = center - detached_half_size
            p.bounds_max = center + detached_half_size
    var rig: Node = views.get_node_or_null("CameraRig")
    if rig != null and rig.has_method("refresh_settings"):
        rig.call("refresh_settings")
