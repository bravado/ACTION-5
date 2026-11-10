extends Node
## Presentation-only visibility for rooms joined by an opaque door.
## A closed connection hides the *other room's rendering* in all camera
## modes (including side views that look across wall geometry).
## Collision, navigation, NPC life/HP and the original player are untouched.
## WorldSession independently preloads physics and schedules AI.

@export var session_path: NodePath = ^"../WorldSession"
@export var door_path: NodePath = ^"../EncounterDoor"
@export var dungeon_path: NodePath = ^"../EncounterSector"
@export var arena_visual_paths: Array[NodePath] = [
    ^"../Floor", ^"../NorthWall", ^"../SouthWall", ^"../WestWall",
    ^"../EastWall", ^"../PassageFloor", ^"../PillarA", ^"../PillarB",
    ^"../Ramp", ^"../LowStep", ^"../NearDummy", ^"../FarDummy",
    ^"../LightSwitch"
]

@onready var session: Node = get_node_or_null(session_path)
@onready var door: Node3D = get_node_or_null(door_path) as Node3D
@onready var dungeon: Node3D = get_node_or_null(dungeon_path) as Node3D

var _original_visibility: Dictionary = {}


func _ready() -> void:
    if not is_instance_valid(session) or not is_instance_valid(door):
        push_error("ACTION5: RoomVisibility needs WorldSession and a physical door")
        return
    session.sector_changed.connect(_on_sector_changed)
    session.encounter_activation_changed.connect(_on_encounter_activation_changed)
    door.state_changed.connect(_on_door_changed)
    call_deferred("refresh")


func refresh() -> void:
    if not is_instance_valid(session) or not is_instance_valid(door):
        return
    var sector: StringName = session.get("current_sector")
    var opened: bool = bool(door.get("open"))
    var in_arena: bool = sector == &"arena"
    var in_dungeon: bool = sector == &"encounter"
    var show_arena: bool = in_arena or (in_dungeon and opened)
    var show_dungeon: bool = in_dungeon or (in_arena and opened
        and bool(session.get("_encounter_active")))
    if is_instance_valid(dungeon):
        dungeon.visible = show_dungeon
    door.visible = in_arena or in_dungeon
    for path in arena_visual_paths:
        var piece := get_node_or_null(path) as Node3D
        if not is_instance_valid(piece):
            continue
        var key: int = piece.get_instance_id()
        if not _original_visibility.has(key):
            _original_visibility[key] = piece.visible
        piece.visible = bool(_original_visibility[key]) and show_arena
    # Authored world pickups and dropped weapons can be reparented to
    # the *same* World root by Equipment. Classify visible ground items
    # by their CURRENT world coordinates, never their original node name;
    # a Bat dropped inside the dungeon must stay visible there.
    var root := get_parent() as Node3D
    var boundary: float = float(session.get("passage_boundary_x"))
    for entry in get_tree().get_nodes_in_group("action5_weapon_pickup"):
        var weapon := entry as Node3D
        if not is_instance_valid(weapon) or not root.is_ancestor_of(weapon) \
                or weapon.get("equipment_owner") != null:
            continue
        var key: int = weapon.get_instance_id()
        if not _original_visibility.has(key):
            _original_visibility[key] = weapon.visible
        var dungeon_side: bool = root.to_local(weapon.global_position).x > boundary
        weapon.visible = bool(_original_visibility[key]) and (
            show_dungeon if dungeon_side else show_arena
        )


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
