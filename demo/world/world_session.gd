extends Node
## Sector visibility and optional fresh/restore entry for ONE connected world.
## Actual gameplay walks through the physical two-sided gateway at X=14.
## No door-triggered teleport, cloned Player, serialized inventory or
## camera/movement dependencies. Warping is a separate optional script port.

signal sector_changed(previous: StringName, current: StringName)
signal encounter_activation_changed(active: bool)

@export var player_path: NodePath = ^"../Player"
@export var encounter_sector_path: NodePath = ^"../EncounterSector"
@export var arena_spawn_path: NodePath = ^"../ArenaSpawn"
@export var encounter_spawn_path: NodePath = ^"../EncounterSpawn"
@export var encounter_scene: PackedScene
@export var discovery_filter_path: NodePath = ^"../EncounterDoor/AcquisitionFilter"
@export var participant_group: StringName = &"action5_scene_persistable"

## Shared wall threshold, expressed in parent-world local coordinates.
@export var passage_boundary_x: float = 14.0
@export_range(0.0, 2.0, 0.05) var crossing_hysteresis: float = 0.3
## Activate dungeon physics before reaching the open gateway. This keeps
## floor, nav and actors available for continuous walking in both directions.
@export_range(1.0, 20.0, 0.5) var preload_distance: float = 6.0

@export_enum("Restore previous", "Start fresh") var dungeon_entry_policy: int = 0
@export_enum("Restore previous", "Start fresh") var arena_entry_policy: int = 0

@onready var player: Node3D = get_node_or_null(player_path) as Node3D
@onready var encounter_sector: Node3D = get_node_or_null(encounter_sector_path) as Node3D
@onready var arena_spawn: Node3D = get_node_or_null(arena_spawn_path) as Node3D
@onready var encounter_spawn: Node3D = get_node_or_null(encounter_spawn_path) as Node3D

var current_sector: StringName = &"arena"
var _arena_initial: Dictionary = {}
var _loose_by_id: Dictionary = {}
var _initial_ready: bool = false
var _encounter_active: bool = true


func _ready() -> void:
    if is_instance_valid(player):
        var equipment := player.get_node_or_null("Equipment")
        if equipment != null:
            equipment.weapon_dropped.connect(_on_weapon_dropped)
            equipment.weapon_picked_up.connect(_on_weapon_picked_up)
    _bind_enemy_discovery_filter()
    call_deferred("_capture_initial")


## Scene-composition port: all NPC TargetSensors receive the optional
## acquisition filter without the AI core knowing about a particular door.
func _bind_enemy_discovery_filter() -> void:
    var filter: Node = get_node_or_null(discovery_filter_path)
    if not is_instance_valid(filter) or not is_instance_valid(encounter_sector):
        return
    for child in encounter_sector.get_children():
        var actor := child as Node
        if actor == null:
            continue
        var sensor: Node = actor.get_node_or_null("TargetSensor")
        if sensor != null and sensor.has_method("set_acquisition_gate"):
            sensor.call("set_acquisition_gate", filter)


func _capture_initial() -> void:
    await get_tree().process_frame
    await get_tree().process_frame
    if not is_inside_tree():
        return
    var root: Node = get_parent()
    for member in get_tree().get_nodes_in_group(participant_group):
        var participant := member as Node
        if participant == null or not root.is_ancestor_of(participant) \
                or participant == player or player.is_ancestor_of(participant) \
                or (is_instance_valid(encounter_sector) \
                    and encounter_sector.is_ancestor_of(participant)) \
                or not participant.has_method("capture_state"):
            continue
        _arena_initial[str(root.get_path_to(participant))] = participant.call("capture_state")
    _initial_ready = true
    _update_encounter_activation()


func _physics_process(_delta: float) -> void:
    if not _initial_ready or not is_instance_valid(player) \
            or current_sector == &"remote":
        return
    var x: float = _player_world_x()
    var desired: StringName = current_sector
    if current_sector == &"arena" and x >= passage_boundary_x + crossing_hysteresis:
        desired = &"encounter"
    elif current_sector == &"encounter" and x <= passage_boundary_x - crossing_hysteresis:
        desired = &"arena"
    if desired != current_sector:
        _enter_sector(desired, _entry_starts_fresh(desired))
    _update_encounter_activation()


func _player_world_x() -> float:
    var root := get_parent() as Node3D
    return root.to_local(player.global_position).x


func _entry_starts_fresh(destination: StringName) -> bool:
    return (dungeon_entry_policy == 1 if destination == &"encounter"
        else arena_entry_policy == 1)


func _enter_sector(destination: StringName, start_fresh: bool) -> bool:
    if start_fresh:
        if destination == &"encounter":
            if not _reset_encounter():
                return false
        else:
            _reset_arena()
    if destination == &"encounter":
        _set_encounter_active(true)
    var previous: StringName = current_sector
    current_sector = destination
    sector_changed.emit(previous, destination)
    return true


func _update_encounter_activation() -> void:
    if not is_instance_valid(player):
        return
    var near: bool = current_sector != &"remote" \
        and _player_world_x() >= passage_boundary_x - preload_distance
    _set_encounter_active(near or current_sector == &"encounter")


func _set_encounter_active(value: bool) -> void:
    if not is_instance_valid(encounter_sector) or value == _encounter_active:
        return
    _encounter_active = value
    # Presentation is independent; a closed door may hide the dungeon
    # visually while its physical floor/collision is preloaded near us.
    encounter_sector.process_mode = (
        Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED
    )
    encounter_activation_changed.emit(value)


## Detached location entry is deliberate: never confused with simply
## crossing a wall. Only the explicit LocationPortal/LocationManager may
## place the actor there; other sectors keep their original live state.
func enter_detached() -> void:
    if current_sector == &"remote":
        return
    var previous: StringName = current_sector
    current_sector = &"remote"
    _update_encounter_activation()
    sector_changed.emit(previous, current_sector)


func leave_detached() -> void:
    if current_sector != &"remote":
        return
    var previous: StringName = current_sector
    current_sector = (
        &"encounter" if _player_world_x() > passage_boundary_x else &"arena"
    )
    _update_encounter_activation()
    sector_changed.emit(previous, current_sector)


func reconcile_actor_sector() -> void:
    if current_sector == &"remote":
        return
    var desired: StringName = (
        &"encounter" if _player_world_x() > passage_boundary_x else &"arena"
    )
    if desired != current_sector:
        _enter_sector(desired, false)
    _update_encounter_activation()


## Explicit scripted warp for cutscenes/CI only. The physical gateway does
## NOT call it: player walking, world coordinates and motion remain continuous.
func travel_to(actor: Node3D, destination: StringName, start_fresh: bool = false) -> bool:
    if not is_inside_tree() or actor != player or not bool(actor.get("alive")) \
            or destination == current_sector \
            or (destination != &"arena" and destination != &"encounter"):
        return false
    var spawn: Node3D = encounter_spawn if destination == &"encounter" else arena_spawn
    if not is_instance_valid(spawn):
        return false
    if not _enter_sector(destination, start_fresh or _entry_starts_fresh(destination)):
        return false
    var locomotion := actor.get_node_or_null("Locomotion")
    if locomotion != null and locomotion.has_method("stop"):
        locomotion.call("stop")
    actor.global_position = spawn.global_position
    if actor is CharacterBody3D:
        (actor as CharacterBody3D).velocity = Vector3.ZERO
    _update_encounter_activation()
    return true


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
    _encounter_active = true
    _bind_enemy_discovery_filter()
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
