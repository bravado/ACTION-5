extends Node
## One live sector: save a compact baseline for optional Start fresh, or
## retain the actual actor/weapon objects for Restore previous. No scene
## changes, duplicated players, global managers or per-frame serialization.

@export var sector_root_path: NodePath = ^".."
@export var excluded_root_path: NodePath
@export var participant_group: StringName = &"action5_scene_persistable"

@onready var sector_root: Node = get_node_or_null(sector_root_path)
@onready var excluded_root: Node = get_node_or_null(excluded_root_path)

var initial: Dictionary = {}
var ready_for_reset: bool = false


func _ready() -> void:
    call_deferred("_save_initial_after_loadouts")


func _save_initial_after_loadouts() -> void:
    # EnemyLoadout equips on a deferred call. Let its normal D06 signal/
    # weapon initialization finish before capturing the optional baseline.
    await get_tree().process_frame
    await get_tree().process_frame
    if not is_inside_tree() or not is_instance_valid(sector_root):
        return
    for member in get_tree().get_nodes_in_group(participant_group):
        var part := member as Node
        if part == null or not sector_root.is_ancestor_of(part)                 or (is_instance_valid(excluded_root)                     and excluded_root.is_ancestor_of(part))                 or not part.has_method("capture_state"):
            continue
        initial[str(sector_root.get_path_to(part))] = part.call("capture_state")
    ready_for_reset = true


func restore_initial() -> bool:
    if not ready_for_reset or not is_instance_valid(sector_root):
        return false
    for path in initial:
        var part := sector_root.get_node_or_null(NodePath(str(path)))
        if is_instance_valid(part) and part.has_method("restore_state"):
            part.call("restore_state", (initial[path] as Dictionary).duplicate(true))
    return true
