extends Node
class_name Action5Interactor
## Actor-local interaction authority. Input, AI and scripted callers all use
## the same try_interact()/interact() port; no type-specific branching.

@export var world_path: NodePath = ^".."
@export var candidate_group: StringName = &"action5_interactable"
@export_range(0.1, 20.0, 0.1) var maximum_distance: float = 2.6
@export var require_line_of_sight: bool = true
@export_flags_3d_physics var obstruction_mask: int = 1

@onready var world: Node = get_node_or_null(world_path)
var _last_frame: int = -1


func try_interact(actor: Node3D) -> bool:
    if not _valid_actor(actor):
        return false
    var closest: Node3D
    var best: float = maximum_distance * maximum_distance
    for member in get_tree().get_nodes_in_group(candidate_group):
        var item := member as Node3D
        if item == null or not _eligible(actor, item):
            continue
        var squared: float = actor.global_position.distance_squared_to(item.global_position)
        if squared <= best:
            closest = item
            best = squared
    return interact(actor, closest) if closest != null else false


## The explicit target path is usable by an NPC/script without InputMap.
func interact(actor: Node3D, target: Node3D) -> bool:
    if not _eligible(actor, target) or _last_frame == Engine.get_physics_frames():
        return false
    if not target.has_method("interact"):
        return false
    if not bool(target.call("interact", actor)):
        return false
    _last_frame = Engine.get_physics_frames()
    return true


func _valid_actor(actor: Node3D) -> bool:
    return is_instance_valid(actor) and actor.is_inside_tree()         and is_instance_valid(world) and world.is_ancestor_of(actor)         and (not actor.has_method("set_alive") or bool(actor.get("alive")))


func _eligible(actor: Node3D, item: Node3D) -> bool:
    if not _valid_actor(actor) or not is_instance_valid(item) or not item.is_inside_tree()             or not world.is_ancestor_of(item) or item == actor             or not item.is_in_group(candidate_group)             or actor.global_position.distance_squared_to(item.global_position)                 > maximum_distance * maximum_distance             or not item.has_method("can_interact")             or not bool(item.call("can_interact", actor)):
        return false
    return not require_line_of_sight or _clear_sight(actor, item)


func _clear_sight(actor: Node3D, item: Node3D) -> bool:
    var excluded: Array[RID] = []
    if actor is CollisionObject3D:
        excluded.append((actor as CollisionObject3D).get_rid())
    for child in actor.find_children("*", "CollisionObject3D", true, false):
        excluded.append((child as CollisionObject3D).get_rid())
    var from: Vector3 = actor.global_position + Vector3(0, 1.0, 0)
    var to: Vector3 = item.global_position + Vector3(0, 1.0, 0)
    if from.distance_squared_to(to) < 0.001:
        return true
    var query := PhysicsRayQueryParameters3D.create(from, to, obstruction_mask, excluded)
    query.collide_with_areas = false
    var hit: Dictionary = actor.get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty():
        return true
    var collider := hit.get("collider") as Node
    return collider == item or (collider != null and item.is_ancestor_of(collider))
