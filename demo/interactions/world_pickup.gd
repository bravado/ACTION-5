extends Node3D
## Authored weapon spawn/reset state. A prefab-local PickupInteraction
## handles interactions; this wrapper never bypasses the generic Interactor.

@export var weapon_path: NodePath
@export var pickup_scene: PackedScene

var _weapon: Node3D
var _spawn_parent: Node3D
var _spawn_transform: Transform3D


func _ready() -> void:
    add_to_group("action5_scene_persistable")
    _weapon = get_node_or_null(weapon_path) as Node3D
    if not is_instance_valid(_weapon):
        push_warning("ACTION5: WorldPickup needs an authored weapon")
        return
    _spawn_parent = _weapon.get_parent() as Node3D
    _spawn_transform = _weapon.global_transform
    global_position = _weapon.global_position
    if pickup_scene == null and not _weapon.scene_file_path.is_empty():
        pickup_scene = load(_weapon.scene_file_path) as PackedScene


func _available() -> bool:
    return is_instance_valid(_weapon) and not _weapon.is_queued_for_deletion()         and _weapon.get_parent() == _spawn_parent         and _weapon.get("equipment_owner") == null


func capture_state() -> Dictionary:
    return {"available": _available()}


func restore_state(snapshot: Dictionary) -> void:
    var available: bool = bool(snapshot.get("available", true))
    if not available and _available():
        _weapon.free()
        _weapon = null
    elif available and not _available()             and is_instance_valid(_spawn_parent) and pickup_scene != null:
        var instance := pickup_scene.instantiate() as Node3D
        if instance == null:
            return
        _spawn_parent.add_child(instance)
        instance.global_transform = _spawn_transform
        _weapon = instance


## Explicit fresh-entry reset. Never delete the player's owned original:
## the new pickup is a NEW world instance while inventory remains intact.
func reset_to_initial() -> void:
    # A gun dropped into a detached world is not owned by the arena
    # spawn wrapper and must survive an arena fresh-entry reset.
    if is_instance_valid(_weapon) and _weapon.get("equipment_owner") == null \
            and _weapon.get_parent() == _spawn_parent:
        _weapon.free()
    _weapon = null
    if pickup_scene == null or not is_instance_valid(_spawn_parent):
        return
    var fresh := pickup_scene.instantiate() as Node3D
    if fresh == null:
        return
    _spawn_parent.add_child(fresh)
    fresh.global_transform = _spawn_transform
    _weapon = fresh
    global_position = _spawn_transform.origin
