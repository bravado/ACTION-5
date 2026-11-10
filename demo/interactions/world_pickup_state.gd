extends Node
## Scene-owned history of *authored* world pickups consumed during this play
## session. No persistent global inventory: data crosses doors only through
## the existing one-use scene handoff.
##
## Track instance IDs at scene startup, before EquipmentController reparents
## picked weapons to inventory/sockets. The pickup signal fires after that
## reparent, so trying to derive its original NodePath at signal time fails.

@export var equipment_path: NodePath = ^"../Player/Equipment"
@export var pickup_group: StringName = &"action5_weapon_pickup"

var _initial_paths_by_id: Dictionary = {}
var _collected_by_scene: Dictionary = {}

@onready var _equipment: Node = get_node_or_null(equipment_path)
@onready var _stage: Node3D = get_parent() as Node3D


func _ready() -> void:
    if _stage == null or _equipment == null \
            or not _equipment.has_signal("weapon_picked_up"):
        push_warning("ACTION5: WorldPickupState requires a scene and Equipment")
        return
    # Only register pickups authored into THIS scene, not a group member
    # in another test arena, or a weapon spawned later by an NPC.
    for member in get_tree().get_nodes_in_group(pickup_group):
        var pickup := member as Node3D
        if is_instance_valid(pickup) and _stage.is_ancestor_of(pickup) \
                and pickup.owner == _stage:
            _initial_paths_by_id[pickup.get_instance_id()] = str(_stage.get_path_to(pickup))
    _equipment.weapon_picked_up.connect(_on_weapon_picked_up)


func _on_weapon_picked_up(weapon: Node3D) -> void:
    var id: int = weapon.get_instance_id()
    if not _initial_paths_by_id.has(id):
        return
    var stage_id: String = _stage.scene_file_path
    if stage_id.is_empty():
        return
    var path: String = _initial_paths_by_id[id]
    var consumed: Array = _collected_by_scene.get(stage_id, []).duplicate()
    if not consumed.has(path):
        consumed.append(path)
        _collected_by_scene[stage_id] = consumed


func capture_state() -> Dictionary:
    return _collected_by_scene.duplicate(true)


func restore_state(history: Dictionary, restart_destination: bool = false) -> void:
    if not is_instance_valid(_stage):
        return
    _collected_by_scene = history.duplicate(true)
    var stage_id: String = _stage.scene_file_path
    if restart_destination:
        # An explicit fresh-entry policy restarts this scene's map objects,
        # but keeps history for other scenes and the player's inventory.
        _collected_by_scene.erase(stage_id)
        return
    var consumed: Array = _collected_by_scene.get(stage_id, [])
    for path_variant in consumed:
        var path: String = str(path_variant)
        # Only remove nodes registered as an authored map pickup at startup.
        # Never remove the player's transferred, already-owned weapons.
        if not _initial_paths_by_id.values().has(path):
            continue
        var pickup := _stage.get_node_or_null(NodePath(path)) as Node3D
        if is_instance_valid(pickup):
            _initial_paths_by_id.erase(pickup.get_instance_id())
            # No visible one-frame ghost or E pickup before deferred free.
            pickup.free()


func _exit_tree() -> void:
    if is_instance_valid(_equipment) \
            and _equipment.weapon_picked_up.is_connected(_on_weapon_picked_up):
        _equipment.weapon_picked_up.disconnect(_on_weapon_picked_up)
