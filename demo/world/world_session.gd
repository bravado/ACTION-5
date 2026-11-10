extends Node
## A live-world demo coordinator: no change_scene, reloaded player, copied
## inventory or global scene metadata. The inactive sector is only paused;
## its NPCs, weapons, health and transforms remain the same instances.

signal sector_changed(previous: StringName, current: StringName)

@export var player_path: NodePath = ^"../Player"
@export var encounter_sector_path: NodePath = ^"../EncounterSector"
@export var arena_spawn_path: NodePath = ^"../ArenaSpawn"
@export var encounter_spawn_path: NodePath = ^"../EncounterSpawn"
@export var encounter_scene: PackedScene
@export var participant_group: StringName = &"action5_scene_persistable"

@onready var player: Node3D = get_node_or_null(player_path) as Node3D
@onready var encounter_sector: Node3D = get_node_or_null(encounter_sector_path) as Node3D
@onready var arena_spawn: Node3D = get_node_or_null(arena_spawn_path) as Node3D
@onready var encounter_spawn: Node3D = get_node_or_null(encounter_spawn_path) as Node3D

var current_sector: StringName = &"arena"
var _arena_initial: Dictionary = {}
var _loose_by_id: Dictionary = {}


func _ready() -> void:
    if is_instance_valid(player):
        var equipment := player.get_node_or_null("Equipment")
        if equipment != null:
            equipment.weapon_dropped.connect(_on_weapon_dropped)
            equipment.weapon_picked_up.connect(_on_weapon_picked_up)
    call_deferred("_capture_initial")


func _capture_initial() -> void:
    await get_tree().process_frame
    await get_tree().process_frame
    if not is_inside_tree():
        return
    var root: Node = get_parent()
    for member in get_tree().get_nodes_in_group(participant_group):
        var participant := member as Node
        if participant == null or not root.is_ancestor_of(participant)                 or participant == player or player.is_ancestor_of(participant)                 or (is_instance_valid(encounter_sector)                     and encounter_sector.is_ancestor_of(participant))                 or not participant.has_method("capture_state"):
            continue
        _arena_initial[str(root.get_path_to(participant))] = participant.call("capture_state")
    _set_encounter_active(false)


func travel_to(actor: Node3D, destination: StringName, start_fresh: bool = false) -> bool:
    if not is_inside_tree() or actor != player or not bool(actor.get("alive"))             or destination == current_sector             or (destination != &"arena" and destination != &"encounter"):
        return false
    if destination == &"encounter" and start_fresh:
        if not _reset_encounter():
            return false
    elif destination == &"arena" and start_fresh:
        _reset_arena()
    var spawn: Node3D = encounter_spawn if destination == &"encounter" else arena_spawn
    if not is_instance_valid(spawn):
        return false
    # Enable the receiving sector before teleporting. The same Player,
    # Health, Equipment, Combat and ViewManager continue running.
    if destination == &"encounter":
        _set_encounter_active(true)
    var locomotion := actor.get_node_or_null("Locomotion")
    if locomotion != null and locomotion.has_method("stop"):
        locomotion.call("stop")
    actor.global_position = spawn.global_position
    if actor is CharacterBody3D:
        (actor as CharacterBody3D).velocity = Vector3.ZERO
    var previous: StringName = current_sector
    current_sector = destination
    if destination == &"arena":
        _set_encounter_active(false)
    sector_changed.emit(previous, current_sector)
    return true


func _set_encounter_active(value: bool) -> void:
    if not is_instance_valid(encounter_sector):
        return
    encounter_sector.visible = value
    encounter_sector.process_mode = (
        Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED
    )


func _reset_encounter() -> bool:
    if encounter_scene == null or not is_instance_valid(encounter_sector):
        return false
    _clear_loose_in(&"encounter")
    var parent: Node = encounter_sector.get_parent()
    var index: int = encounter_sector.get_index()
    var name_before: String = encounter_sector.name
    var transform_before: Transform3D = encounter_sector.transform
    var replacement := encounter_scene.instantiate() as Node3D
    if replacement == null:
        return false
    encounter_sector.free()
    replacement.name = name_before
    replacement.transform = transform_before
    parent.add_child(replacement)
    parent.move_child(replacement, index)
    encounter_sector = replacement
    return true


func _reset_arena() -> void:
    _clear_loose_in(&"arena")
    var root: Node = get_parent()
    for path in _arena_initial:
        var participant := root.get_node_or_null(NodePath(str(path)))
        if participant == null:
            continue
        if participant.has_method("reset_to_initial"):
            participant.call("reset_to_initial")
        elif participant.has_method("restore_state"):
            participant.call("restore_state", (_arena_initial[path] as Dictionary).duplicate(true))


func _on_weapon_dropped(weapon: Node3D) -> void:
    if is_instance_valid(weapon):
        _loose_by_id[weapon.get_instance_id()] = {
            "sector": current_sector,
            "weapon": weakref(weapon)
        }


func _on_weapon_picked_up(weapon: Node3D) -> void:
    if is_instance_valid(weapon):
        _loose_by_id.erase(weapon.get_instance_id())


func _clear_loose_in(sector: StringName) -> void:
    for id in _loose_by_id.keys():
        var entry: Dictionary = _loose_by_id[id]
        var weapon: Node3D = (entry["weapon"] as WeakRef).get_ref() as Node3D
        if not is_instance_valid(weapon):
            _loose_by_id.erase(id)
            continue
        if entry["sector"] == sector:
            _loose_by_id.erase(id)
            if weapon.get("equipment_owner") == null:
                weapon.free()
