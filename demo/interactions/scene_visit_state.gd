extends Node
## Compact, session-only per-scene value snapshots. Inactive worlds are
## destroyed, so they consume no AI/physics/rendering CPU or live-node RAM.
## The SceneHandoff carries this small dictionary across each door.
##
## To persist a new kind of entity, give it a child component in
## "action5_scene_persistable" with capture_state()/restore_state().
## This manager never imports or branches on enemy/weapon/movement classes.

@export var participant_group: StringName = &"action5_scene_persistable"

var _history: Dictionary = {}
@onready var _stage: Node3D = get_parent() as Node3D


func capture_state() -> Dictionary:
    var all: Dictionary = _history.duplicate(true)
    if not is_instance_valid(_stage) or _stage.scene_file_path.is_empty():
        return all
    var entries: Dictionary = {}
    for part in get_tree().get_nodes_in_group(participant_group):
        if not is_instance_valid(part) or not _stage.is_ancestor_of(part) \
                or not part.has_method("capture_state"):
            continue
        var path: String = str(_stage.get_path_to(part))
        entries[path] = part.call("capture_state")
    all[_stage.scene_file_path] = entries
    return all


func restore_state(history: Dictionary, restart_destination: bool = false) -> void:
    _history = history.duplicate(true)
    if not is_instance_valid(_stage):
        return
    var scene_path: String = _stage.scene_file_path
    if restart_destination:
        # Delete only this destination's saved state. Other visited scenes
        # retain their snapshots and can later be entered with Restore.
        _history.erase(scene_path)
        return
    var entries: Dictionary = _history.get(scene_path, {})
    for path_variant in entries:
        var path: String = str(path_variant)
        var part := _stage.get_node_or_null(NodePath(path))
        if part == null or not part.is_in_group(participant_group) \
                or not part.has_method("restore_state"):
            continue
        part.call("restore_state", entries[path_variant])
