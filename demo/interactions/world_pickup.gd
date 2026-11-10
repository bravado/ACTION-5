extends Node3D
## Generic weapon-world interaction, not a special case inside main/Actor.
## The authored wrapper persists after Equipment reparents its weapon.

@export var weapon_path: NodePath
@export var pickup_scene: PackedScene

var _weapon: Node3D
var _spawn_parent: Node3D
var _spawn_transform: Transform3D


func _ready() -> void:
    add_to_group("action5_interactable")
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


func can_interact(actor: Node3D) -> bool:
    return _available() and is_instance_valid(actor)         and actor.get_node_or_null("Equipment") != null


func interact(actor: Node3D) -> bool:
    if not can_interact(actor):
        return false
    var equipment := actor.get_node("Equipment")
    return bool(equipment.call("pickup", _weapon))


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
