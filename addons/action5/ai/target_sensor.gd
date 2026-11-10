extends Node
class_name Action5AITargetSensor
## Actor-local acquisition and world-geometry visibility. No camera, input or
## damage authority. A target must own living Health to be attackable.

const HealthScript = preload("res://addons/action5/combat/health.gd")

@export var target_group: StringName = &"action5_player"
@export_range(1.0, 200.0, 0.5) var acquisition_range: float = 24.0
@export_range(1.0, 200.0, 0.5) var forget_range: float = 34.0
@export var source_height: float = 1.0
@export var target_height: float = 1.0
@export_flags_3d_physics var sight_mask: int = 3

var current_target: Node3D
var _preferred_target: Node3D


func set_target(candidate: Node3D) -> void:
    _preferred_target = candidate
    current_target = candidate if _is_viable(candidate) else null


func clear_target() -> void:
    current_target = null
    _preferred_target = null


func get_target(actor: Node3D) -> Node3D:
    if not is_instance_valid(actor) or not actor.is_inside_tree():
        current_target = null
        return null
    if _is_viable(current_target) and _distance(actor, current_target) <= forget_range:
        return current_target
    current_target = null
    if _is_viable(_preferred_target) and _distance(actor, _preferred_target) <= acquisition_range:
        current_target = _preferred_target
        return current_target
    var best: float = acquisition_range
    for candidate in get_tree().get_nodes_in_group(target_group):
        var target := candidate as Node3D
        if not _is_viable(target) or target == actor:
            continue
        var distance: float = _distance(actor, target)
        if distance < best:
            best = distance
            current_target = target
    return current_target


func is_target_alive(candidate: Node3D) -> bool:
    return _is_viable(candidate)


func has_line_of_sight(actor: CollisionObject3D, target: Node3D) -> bool:
    if not _is_viable(target) or not is_instance_valid(actor):
        return false
    var start: Vector3 = actor.global_position + Vector3.UP * source_height
    var end: Vector3 = target.global_position + Vector3.UP * target_height
    if start.distance_squared_to(end) <= 0.001:
        return true
    var excluded: Array[RID] = [actor.get_rid()]
    for child in actor.find_children("*", "CollisionObject3D", true, false):
        var collision := child as CollisionObject3D
        if collision != null:
            excluded.append(collision.get_rid())
    var query := PhysicsRayQueryParameters3D.create(start, end, sight_mask, excluded)
    query.collide_with_areas = true
    query.collide_with_bodies = true
    var hit: Dictionary = actor.get_world_3d().direct_space_state.intersect_ray(query)
    var collider := hit.get("collider") as Node
    return collider == target or (is_instance_valid(collider) and target.is_ancestor_of(collider))


func _distance(actor: Node3D, candidate: Node3D) -> float:
    var offset: Vector3 = candidate.global_position - actor.global_position
    return Vector2(offset.x, offset.z).length()


func _is_viable(candidate: Node3D) -> bool:
    if not is_instance_valid(candidate) or candidate.is_queued_for_deletion() \
            or not candidate.is_inside_tree():
        return false
    var health := candidate.get_node_or_null("Health") as HealthScript
    return health != null and health.current_health > 0.0
