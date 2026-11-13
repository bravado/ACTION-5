extends Node
## One scene-local snapshot/reset adapter for authored pickup spawns.
## Interactions and inventory stay in the pickup prefab and Equipment.

@export var pickup_paths: Array[NodePath] = []

# Authored path -> original parent, transform, prefab and current instance.
# Stable authored paths are snapshot keys; runtime instance IDs are not.
var _spawns: Dictionary = {}


func _ready() -> void:
    add_to_group(&"action5_scene_persistable")
    for path in pickup_paths:
        var key := str(path)
        if key.is_empty() or _spawns.has(key):
            push_warning("ACTION5: Missing or duplicated pickup spawn path: " + key)
            continue
        var pickup := get_node_or_null(path) as Node3D
        if not is_instance_valid(pickup) or not pickup.get_parent() is Node3D:
            push_warning("ACTION5: Pickup spawn path must resolve to a Node3D: " + key)
            continue
        var scene: PackedScene = null
        if not pickup.scene_file_path.is_empty():
            scene = load(pickup.scene_file_path) as PackedScene
        if scene == null:
            push_warning("ACTION5: Pickup must be an instanced PackedScene: " + key)
            continue
        _spawns[key] = {
            "parent": pickup.get_parent(),
            "transform": pickup.global_transform,
            "name": pickup.name,
            "scene": scene,
            "instance": pickup,
        }


func _available(spawn: Dictionary) -> bool:
    var pickup := spawn["instance"] as Node3D
    return is_instance_valid(pickup) and not pickup.is_queued_for_deletion() \
        and pickup.get_parent() == spawn["parent"] \
        and pickup.get("equipment_owner") == null


func capture_state() -> Dictionary:
    var snapshot: Dictionary = {}
    for path in _spawns:
        snapshot[path] = _available(_spawns[path])
    return snapshot


func restore_state(snapshot: Dictionary) -> void:
    for path in _spawns:
        if not snapshot.has(path):
            continue
        var spawn: Dictionary = _spawns[path]
        var available := _available(spawn)
        if bool(snapshot[path]) and not available:
            _respawn(spawn)
        elif not bool(snapshot[path]) and available:
            _remove_available(spawn)


## Fresh entry replaces each original world pickup, never a carried item.
## A carried instance may survive while a new instance occupies its spawn.
func reset_to_initial() -> void:
    for spawn in _spawns.values():
        _remove_available(spawn)
        _respawn(spawn)


func _remove_available(spawn: Dictionary) -> void:
    if not _available(spawn):
        return
    (spawn["instance"] as Node3D).free()
    spawn["instance"] = null


func _respawn(spawn: Dictionary) -> void:
    var parent := spawn["parent"] as Node3D
    var scene := spawn["scene"] as PackedScene
    if not is_instance_valid(parent) or scene == null:
        return
    var pickup := scene.instantiate() as Node3D
    if pickup == null:
        return
    pickup.name = spawn["name"]
    parent.add_child(pickup)
    pickup.global_transform = spawn["transform"]
    spawn["instance"] = pickup
