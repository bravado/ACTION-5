extends Node
## Explicit non-adjacent travel. Keep the SAME player, ViewManager, combat,
## equipment and inventory while loading an independent environment scene.
## This is intentionally separate from the physical door/sector crossing.
## Loaded PackedScenes are cached and paused offscreen, not recreated on
## every visit; only an explicit fresh-session restart forgets them.

signal location_changed(previous: StringName, current: StringName, location_root: Node3D)

@export var actor_path: NodePath = ^"../Player"
@export var world_session_path: NodePath = ^"../WorldSession"
@export var detached_origin: Vector3 = Vector3(-80.0, 0, 0)

@onready var actor: Node3D = get_node_or_null(actor_path) as Node3D
@onready var session: Node = get_node_or_null(world_session_path)

var current_location: StringName = &"connected"
var active_scene: Node3D
var _loaded: Dictionary = {}


func can_travel(candidate: Node3D) -> bool:
    return is_instance_valid(actor) and candidate == actor \
        and bool(actor.get("alive")) and is_instance_valid(session)


func travel_to_scene(candidate: Node3D, packed: PackedScene, arrival_path: NodePath) -> bool:
    if not can_travel(candidate) or packed == null or packed.resource_path.is_empty() \
            or current_location != &"connected":
        return false
    var key: String = packed.resource_path
    var location: Node3D = _loaded.get(key) as Node3D
    if not is_instance_valid(location):
        location = packed.instantiate() as Node3D
        if location == null:
            return false
        location.position = detached_origin
        get_parent().add_child(location)
        _loaded[key] = location
    var arrival: Marker3D = location.get_node_or_null(arrival_path) as Marker3D
    if arrival == null:
        push_error("ACTION5: Detached scene needs a Marker3D arrival point")
        return false
    var previous: StringName = current_location
    current_location = StringName(key)
    active_scene = location
    active_scene.visible = true
    active_scene.process_mode = Node.PROCESS_MODE_INHERIT
    _move_actor(candidate, arrival.global_position)
    session.call("enter_detached")
    location_changed.emit(previous, current_location, active_scene)
    return true


func travel_to_marker(candidate: Node3D, marker: Marker3D) -> bool:
    if not can_travel(candidate) or not is_instance_valid(marker):
        return false
    var previous: StringName = current_location
    if is_instance_valid(active_scene):
        active_scene.visible = false
        active_scene.process_mode = Node.PROCESS_MODE_DISABLED
        active_scene = null
    current_location = &"connected"
    _move_actor(candidate, marker.global_position)
    if previous != &"connected":
        session.call("leave_detached")
    else:
        session.call("reconcile_actor_sector")
    location_changed.emit(previous, current_location, null)
    return true


func _move_actor(candidate: Node3D, arrival_position: Vector3) -> void:
    var locomotion: Node = candidate.get_node_or_null("Locomotion")
    if locomotion != null and locomotion.has_method("stop"):
        locomotion.call("stop")
    candidate.global_position = arrival_position
    if candidate is CharacterBody3D:
        (candidate as CharacterBody3D).velocity = Vector3.ZERO
