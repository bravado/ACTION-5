extends Node
## Presentation-only occlusion for adjacent room geometry, world pickups
## and mobile enemies. A physical gate can hide the OPPOSITE room, but
## may NOT hide an enemy that already walked to the player's side.
## Never modify collision, navigation, AI, Health or inventory state.

@export var session_path: NodePath = ^"../WorldSession"
@export var door_path: NodePath = ^"../EncounterDoor"
@export var dungeon_path: NodePath = ^"../EncounterSector"
@export var arena_visual_paths: Array[NodePath] = [
    ^"../Floor", ^"../NorthWall", ^"../SouthWall", ^"../WestWall",
    ^"../EastWall", ^"../PassageFloor", ^"../PillarA", ^"../PillarB",
    ^"../Ramp", ^"../LowStep", ^"../NearDummy", ^"../FarDummy",
    ^"../LightSwitch", ^"../RemotePortal"
]
@export var dungeon_visual_paths: Array[NodePath] = [
    ^"../EncounterSector/Floor",
    ^"../EncounterSector/Obstacle",
    ^"../EncounterSector/NorthWall",
    ^"../EncounterSector/SouthWall",
    ^"../EncounterSector/EastWall",
    ^"../EncounterSector/Roof",
    ^"../EncounterSector/TraversalFixture",
    ^"../EncounterSector/DungeonFillLight",
    ^"../EncounterSector/DungeonCombatLight"
]

@onready var session: Node = get_node_or_null(session_path)
@onready var door: Node3D = get_node_or_null(door_path) as Node3D
@onready var dungeon: Node3D = get_node_or_null(dungeon_path) as Node3D

var _original_visibility: Dictionary = {}
var _show_arena: bool = true
var _show_dungeon: bool = false


func _ready() -> void:
    if not is_instance_valid(session) or not is_instance_valid(door):
        push_error("ACTION5: RoomVisibility needs WorldSession and a physical door")
        return
    session.sector_changed.connect(_on_sector_changed)
    session.encounter_activation_changed.connect(_on_encounter_activation_changed)
    door.state_changed.connect(_on_door_changed)
    call_deferred("refresh")


func _physics_process(_delta: float) -> void:
    # An alerted enemy can physically cross a room boundary while the
    # player stays put. Only two demo enemies are considered; the expensive
    # static visual list is updated by signals, NOT on every physics tick.
    _refresh_mobile_enemies()


func _set_visual(piece: Node3D, show: bool) -> void:
    if not is_instance_valid(piece):
        return
    var key: int = piece.get_instance_id()
    if not _original_visibility.has(key):
        _original_visibility[key] = piece.visible
    piece.visible = bool(_original_visibility[key]) and show


func refresh() -> void:
    if not is_instance_valid(session) or not is_instance_valid(door):
        return
    if not is_instance_valid(dungeon):
        dungeon = get_node_or_null(dungeon_path) as Node3D
    var sector: StringName = session.get("current_sector")
    var opened: bool = bool(door.get("open"))
    var in_arena: bool = sector == &"arena"
    var in_dungeon: bool = sector == &"encounter"
    _show_arena = in_arena or (in_dungeon and opened)
    _show_dungeon = in_dungeon or (in_arena and opened
        and bool(session.get("_encounter_active")))
    # Leave the dungeon parent visible to preserve *independently
    # positioned* mobile actors. Hide only its static render subtree.
    if is_instance_valid(dungeon):
        dungeon.visible = true
    door.visible = in_arena or in_dungeon
    for path in arena_visual_paths:
        _set_visual(get_node_or_null(path) as Node3D, _show_arena)
    for path in dungeon_visual_paths:
        _set_visual(get_node_or_null(path) as Node3D, _show_dungeon)
    _refresh_mobile_enemies()
    _refresh_ground_weapons()


func _refresh_mobile_enemies() -> void:
    if not is_instance_valid(dungeon) or not is_instance_valid(session):
        return
    var root := get_parent() as Node3D
    var boundary: float = float(session.get("passage_boundary_x"))
    for child in dungeon.get_children():
        var actor := child as Node3D
        if actor == null or not actor.is_in_group("action5_enemy"):
            continue
        var in_dungeon: bool = root.to_local(actor.global_position).x > boundary
        _set_visual(actor, _show_dungeon if in_dungeon else _show_arena)


func _refresh_ground_weapons() -> void:
    var root := get_parent() as Node3D
    var boundary: float = float(session.get("passage_boundary_x"))
    for entry in get_tree().get_nodes_in_group("action5_weapon_pickup"):
        var weapon := entry as Node3D
        if not is_instance_valid(weapon) or not root.is_ancestor_of(weapon) \
                or weapon.get("equipment_owner") != null:
            continue
        var in_dungeon: bool = root.to_local(weapon.global_position).x > boundary
        _set_visual(weapon, _show_dungeon if in_dungeon else _show_arena)


func _on_sector_changed(_before: StringName, _after: StringName) -> void:
    refresh()


func _on_encounter_activation_changed(_active: bool) -> void:
    refresh()


func _on_door_changed(_open: bool, _locked: bool) -> void:
    refresh()


func _exit_tree() -> void:
    if is_instance_valid(session):
        if session.sector_changed.is_connected(_on_sector_changed):
            session.sector_changed.disconnect(_on_sector_changed)
        if session.encounter_activation_changed.is_connected(_on_encounter_activation_changed):
            session.encounter_activation_changed.disconnect(_on_encounter_activation_changed)
    if is_instance_valid(door) and door.state_changed.is_connected(_on_door_changed):
        door.state_changed.disconnect(_on_door_changed)
