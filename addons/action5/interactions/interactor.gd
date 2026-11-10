extends Node
class_name Action5Interactor
## Actor-local interaction authority. Input, AI and scripted callers all use
## the same try_interact()/interact() port; no type-specific branching.

@export var world_path: NodePath = ^".."
@export var candidate_group: StringName = &"action5_interactable"
@export_range(0.1, 20.0, 0.1) var maximum_distance: float = 2.6
@export var require_line_of_sight: bool = true
@export_flags_3d_physics var obstruction_mask: int = 1
## World prop interactions should not fail merely because another moving
## character stands between the player and a nearby door handle.
## Static walls/closed door colliders continue to block the ray.
@export var ignore_character_occlusion: bool = true

@onready var world: Node = get_node_or_null(world_path)
var _last_frame: int = -1
var _last_target_id: int = 0


func try_interact(actor: Node3D) -> bool:
    if not _valid_actor(actor):
        return false
    var closest: Node3D
    var best: float = maximum_distance * maximum_distance
    for member in get_tree().get_nodes_in_group(candidate_group):
        var item := member as Node3D
        if item == null or not _eligible(actor, item):
            continue
        var squared: float = actor.global_position.distance_squared_to(_interaction_point(actor, item))
        if squared <= best:
            closest = item
            best = squared
    return interact(actor, closest) if closest != null else false


## The explicit target path is usable by an NPC/script without InputMap.
func interact(actor: Node3D, target: Node3D) -> bool:
    if not _eligible(actor, target):
        return false
    var frame: int = Engine.get_physics_frames()
    if _last_frame == frame and _last_target_id == target.get_instance_id():
        return false
    if not target.has_method("interact"):
        return false
    if not bool(target.call("interact", actor)):
        return false
    _last_frame = frame
    _last_target_id = target.get_instance_id()
    return true


func _valid_actor(actor: Node3D) -> bool:
    return is_instance_valid(actor) and actor.is_inside_tree()         and is_instance_valid(world) and world.is_ancestor_of(actor)         and (not actor.has_method("set_alive") or bool(actor.get("alive")))


func _interaction_point(actor: Node3D, item: Node3D) -> Vector3:
    if item.has_method("get_interaction_point"):
        var result: Variant = item.call("get_interaction_point", actor)
        if result is Vector3 and (result as Vector3).is_finite():
            return result
    return item.global_position


func _eligible(actor: Node3D, item: Node3D) -> bool:
    if not _valid_actor(actor) or not is_instance_valid(item) or not item.is_inside_tree()             or not world.is_ancestor_of(item) or item == actor             or not item.is_in_group(candidate_group)             or actor.global_position.distance_squared_to(_interaction_point(actor, item))                 > maximum_distance * maximum_distance             or not item.has_method("can_interact")             or not bool(item.call("can_interact", actor)):
        return false
    return not require_line_of_sight or _clear_sight(actor, item)


func _clear_sight(actor: Node3D, item: Node3D) -> bool:
    var excluded: Array[RID] = []
    if actor is CollisionObject3D:
        excluded.append((actor as CollisionObject3D).get_rid())
    for child in actor.find_children("*", "CollisionObject3D", true, false):
        excluded.append((child as CollisionObject3D).get_rid())
    var from: Vector3 = actor.global_position + Vector3(0, 1.0, 0)
    var to: Vector3 = (
        _interaction_point(actor, item)
        if item.has_method("get_interaction_point")
        else item.global_position + Vector3(0, 1.0, 0)
    )
    if from.distance_squared_to(to) < 0.001:
        return true
    var query := PhysicsRayQueryParameters3D.create(from, to, obstruction_mask, excluded)
    query.collide_with_areas = false
    var space: PhysicsDirectSpaceState3D = actor.get_world_3d().direct_space_state
    # Query repeatedly, excluding only intervening CharacterBody3D actors;
    # never skip StaticBody3D doors, walls, RigidBody obstacles or terrain.
    # This remains an optional generic interaction policy, not a door
    # special case. Cap retries to avoid pathological overlapping actors.
    for attempt in range(10):
        var hit: Dictionary = space.intersect_ray(query)
        if hit.is_empty():
            return true
        var collider := hit.get("collider") as Node
        if collider == item or (collider != null and item.is_ancestor_of(collider)):
            return true
        if ignore_character_occlusion and collider is CharacterBody3D:
            var next_excluded: Array[RID] = query.exclude
            next_excluded.append((collider as CollisionObject3D).get_rid())
            query.exclude = next_excluded
            continue
        if item.name == "EncounterDoor":
            print("ACTION5_INTERACT_LOS_FAIL collider=",
                collider.get_path() if collider != null else hit,
                " pos=", hit.get("position"), " from=", from, " to=", to,
                " attempt=", attempt, " excluded=", query.exclude.size())
        return false
    if item.name == "EncounterDoor":
        print("ACTION5_INTERACT_LOS_RETRY_EXHAUSTED from=", from,
            " to=", to, " exclude=", query.exclude.size())
    return false
