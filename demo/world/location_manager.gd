extends Node
## Explicit remote travel: one persistent Player, equipment and camera.
## Cached environment scenes remain in the SceneTree, but inactive scenes
## have no physical collisions or navigation. Disabled CollisionObject3D
## objects use DISABLE_MODE_REMOVE; navigation remains explicit.

signal location_changed(previous: StringName, current: StringName, location_root: Node3D)

@export var actor_path: NodePath = ^"../Player"
@export var world_session_path: NodePath = ^"../WorldSession"
@export var detached_origin: Vector3 = Vector3(-80.0, 0, 0)

@onready var actor: Node3D = get_node_or_null(actor_path) as Node3D
@onready var session: Node = get_node_or_null(world_session_path)

var active_scene: Node3D
## Read-only location identity derives from the one authoritative scene.
var current_location: StringName:
    get:
        return StringName(active_scene.scene_file_path) if is_instance_valid(active_scene) \
            else &"connected"
var _loaded: Dictionary = {}
var _inactive_navigation: Dictionary = {}


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
        # Validate BEFORE adding anything to the live world. Bad portals
        # must not leave orphan colliders, inventory, or cached scenes.
        if not (location.get_node_or_null(arrival_path) is Marker3D):
            location.free()
            push_warning("ACTION5: Detached scene needs a Marker3D arrival point")
            return false
        location.add_to_group("action5_detached_location")
        location.position = detached_origin
        get_parent().add_child(location)
        _loaded[key] = location
    var arrival: Marker3D = location.get_node_or_null(arrival_path) as Marker3D
    if arrival == null:
        push_warning("ACTION5: Detached scene needs a Marker3D arrival point")
        return false
    var previous: StringName = current_location
    active_scene = location
    _set_scene_active(location, true)
    _move_actor(candidate, arrival.global_position)
    session.call("enter_detached")
    location_changed.emit(previous, current_location, active_scene)
    return true


func travel_to_marker(candidate: Node3D, marker: Marker3D) -> bool:
    if not can_travel(candidate) or not is_instance_valid(marker):
        return false
    var previous: StringName = current_location
    if is_instance_valid(active_scene):
        _set_scene_active(active_scene, false)
        active_scene = null
    _move_actor(candidate, marker.global_position)
    if previous != &"connected":
        session.call("leave_detached")
    else:
        session.call("reconcile_actor_sector")
    location_changed.emit(previous, current_location, null)
    return true


## Cached environments never contain the shared actor or equipped items.
func _set_scene_active(location: Node3D, enabled: bool) -> void:
    var id: int = location.get_instance_id()
    if enabled:
        location.visible = true
        location.process_mode = Node.PROCESS_MODE_INHERIT
        for entry in _inactive_navigation.get(id, []):
            var node: Node = (entry["node"] as WeakRef).get_ref() as Node
            if is_instance_valid(node):
                node.set("enabled", entry["enabled"])
        _inactive_navigation.erase(id)
        return
    var navigation: Array = []
    var nodes: Array[Node] = [location]
    nodes.append_array(location.find_children("*", "", true, false))
    for node in nodes:
        if node is CollisionObject3D:
            # Godot restores collision objects automatically on reenable;
            # explicit REMOVE also overrides authored KEEP_ACTIVE variants.
            (node as CollisionObject3D).disable_mode = CollisionObject3D.DISABLE_MODE_REMOVE
        elif node is NavigationRegion3D or node is NavigationLink3D:
            navigation.append({"node": weakref(node), "enabled": node.get("enabled")})
            node.set("enabled", false)
    _inactive_navigation[id] = navigation
    location.visible = false
    location.process_mode = Node.PROCESS_MODE_DISABLED


## Optional duck-typed Equipment drop destination. Scene-owned state
## selects the current room, keeping Equipment free of remote portal IDs.
func get_drop_parent(candidate: Node3D) -> Node3D:
    if not is_instance_valid(candidate) or candidate != actor:
        return null
    if current_location != &"connected":
        return active_scene if is_instance_valid(active_scene) else null
    return get_parent() as Node3D


func _move_actor(candidate: Node3D, arrival_position: Vector3) -> void:
    var locomotion: Node = candidate.get_node_or_null("Locomotion")
    if locomotion != null and locomotion.has_method("stop"):
        locomotion.call("stop")
    candidate.global_position = arrival_position
    if candidate is CharacterBody3D:
        (candidate as CharacterBody3D).velocity = Vector3.ZERO
