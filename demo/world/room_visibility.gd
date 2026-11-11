extends Node
## Scene-specific visual composition, independent of physics/AI/camera.
## Connected room roots are configurable; mobile actor/item visibility uses
## the physical boundary and gate, not the currently selected camera.
## No global pickup scan per frame: creation/equipment events register items,
## and only tracked loose pickups are checked for boundary changes.

@export var session_path: NodePath = ^"../WorldSession"
@export var door_path: NodePath = ^"../EncounterDoor"
@export var dungeon_path: NodePath = ^"../EncounterSector"
@export var equipment_path: NodePath = ^"../Player/Equipment"
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
@onready var equipment: Node = get_node_or_null(equipment_path)

## Instance id => {node: WeakRef, visible: original bool}.
var _original_visibility: Dictionary = {}
## Instance id => WeakRef of CONNECTED-room loose pickup.
var _ground_weapons: Dictionary = {}
var _show_arena: bool = true
var _show_dungeon: bool = false


func _ready() -> void:
    if not is_instance_valid(session) or not is_instance_valid(door):
        push_error("ACTION5: RoomVisibility needs WorldSession and a physical door")
        return
    session.sector_changed.connect(_on_sector_changed)
    session.encounter_activation_changed.connect(_on_encounter_activation_changed)
    door.state_changed.connect(_on_door_changed)
    if is_instance_valid(equipment):
        equipment.weapon_dropped.connect(_on_weapon_dropped)
        equipment.weapon_picked_up.connect(_on_weapon_picked_up)
    get_tree().node_added.connect(_on_node_added)
    call_deferred("refresh")


func _physics_process(_delta: float) -> void:
    # Only actor children and previously registered loose weapons; there is
    # no get_nodes_in_group() scan in the hot path.
    _refresh_mobile_enemies()
    _update_ground_weapons()


func _set_visual(piece: Node3D, show: bool) -> void:
    if not is_instance_valid(piece):
        return
    var id: int = piece.get_instance_id()
    if not _original_visibility.has(id):
        _original_visibility[id] = {"node": weakref(piece), "visible": piece.visible}
    piece.visible = bool(_original_visibility[id]["visible"]) and show


func _prune_visibility() -> void:
    for id in _original_visibility.keys():
        var piece: Node = (_original_visibility[id]["node"] as WeakRef).get_ref()
        if not is_instance_valid(piece) or piece.is_queued_for_deletion():
            _original_visibility.erase(id)


func refresh() -> void:
    if not is_instance_valid(session) or not is_instance_valid(door):
        return
    _prune_visibility()
    if not is_instance_valid(dungeon):
        dungeon = get_node_or_null(dungeon_path) as Node3D
    var sector: StringName = session.get("current_sector")
    var opened: bool = bool(door.get("open"))
    var in_arena: bool = sector == &"arena"
    var in_dungeon: bool = sector == &"encounter"
    _show_arena = in_arena or (in_dungeon and opened)
    _show_dungeon = in_dungeon or (in_arena and opened
        and bool(session.get("_encounter_active")))
    # The parent remains active for NPCs that already walked into arena.
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


func _is_connected_pickup(weapon: Node3D) -> bool:
    var root: Node = get_parent()
    var ancestor: Node = weapon
    while is_instance_valid(ancestor) and ancestor != root:
        # Detached locations own their own visibility and loose items,
        # even though they are cached under the same SceneTree parent.
        if ancestor.is_in_group("action5_detached_location"):
            return false
        ancestor = ancestor.get_parent()
    return ancestor == root


func _track_pickup(weapon: Node3D) -> void:
    if not is_instance_valid(weapon) or not weapon.is_in_group("action5_weapon_pickup") \
            or weapon.get("equipment_owner") != null or not _is_connected_pickup(weapon):
        return
    _ground_weapons[weapon.get_instance_id()] = weakref(weapon)
    _update_pickup(weapon)


func _update_pickup(weapon: Node3D) -> void:
    if not is_instance_valid(weapon) or weapon.get("equipment_owner") != null:
        return
    var root := get_parent() as Node3D
    var boundary: float = float(session.get("passage_boundary_x"))
    var in_dungeon: bool = root.to_local(weapon.global_position).x > boundary
    _set_visual(weapon, _show_dungeon if in_dungeon else _show_arena)


func _update_ground_weapons() -> void:
    for id in _ground_weapons.keys():
        var weapon: Node3D = (_ground_weapons[id] as WeakRef).get_ref() as Node3D
        if not is_instance_valid(weapon) or weapon.is_queued_for_deletion():
            _ground_weapons.erase(id)
            _original_visibility.erase(id)
        elif weapon.get("equipment_owner") != null or not _is_connected_pickup(weapon):
            _ground_weapons.erase(id)
            _original_visibility.erase(id)
        else:
            _update_pickup(weapon)


func _refresh_ground_weapons() -> void:
    # Only on door/sector changes, not every frame. New objects and drops
    # are registered through node_added and equipment events.
    for candidate in get_tree().get_nodes_in_group("action5_weapon_pickup"):
        _track_pickup(candidate as Node3D)
    _update_ground_weapons()


func _on_node_added(candidate: Node) -> void:
    if candidate is Node3D:
        # Runtime weapons may join the pickup group in _ready, after
        # node_added fires; check on the following idle iteration.
        call_deferred("_track_new_pickup", weakref(candidate))


func _track_new_pickup(reference: WeakRef) -> void:
    var weapon: Node3D = reference.get_ref() as Node3D
    if is_instance_valid(weapon):
        _track_pickup(weapon)


func _on_weapon_dropped(weapon: Node3D) -> void:
    _track_pickup(weapon)


func _on_weapon_picked_up(weapon: Node3D) -> void:
    if is_instance_valid(weapon):
        var id: int = weapon.get_instance_id()
        _ground_weapons.erase(id)
        # Equipment now owns mesh visibility and reparenting.
        _original_visibility.erase(id)


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
    if is_instance_valid(equipment):
        if equipment.weapon_dropped.is_connected(_on_weapon_dropped):
            equipment.weapon_dropped.disconnect(_on_weapon_dropped)
        if equipment.weapon_picked_up.is_connected(_on_weapon_picked_up):
            equipment.weapon_picked_up.disconnect(_on_weapon_picked_up)
    if get_tree().node_added.is_connected(_on_node_added):
        get_tree().node_added.disconnect(_on_node_added)
    # Removing only the visual adapter must not leave hidden wall meshes.
    for entry in _original_visibility.values():
        var piece: Node3D = (entry["node"] as WeakRef).get_ref() as Node3D
        if is_instance_valid(piece):
            piece.visible = bool(entry["visible"])
    _original_visibility.clear()
    _ground_weapons.clear()
