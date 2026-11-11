extends Node
## Optional acquisition-only visibility guard for adjacent rooms.
## The sensor depends solely on the allows_acquisition() protocol; it
## never imports or branches on a door, map, camera or world-session class.
##
## This guard rejects initial target discovery on opposite sides of a
## CLOSED physical doorway. An already-acquired target is intentionally
## not filtered here, so enemies retain aggro when the gate closes.

@export var door_path: NodePath = ^".."
@export_range(0.0, 1.0, 0.01) var plane_epsilon: float = 0.1
@onready var door: Node3D = get_node_or_null(door_path) as Node3D


func allows_acquisition(observer: Node3D, candidate: Node3D) -> bool:
    if not is_instance_valid(door) or not is_instance_valid(observer) \
            or not is_instance_valid(candidate):
        return false
    if bool(door.get("open")):
        return true
    var normal: Vector3 = door.global_basis.x.normalized()
    var observer_side: float = (observer.global_position - door.global_position).dot(normal)
    var candidate_side: float = (candidate.global_position - door.global_position).dot(normal)
    # Physical geometry and attack LoS remain separately authoritative.
    # Two actors in the same room can observe each other behind cover
    # (and pathfind around it); the gate only denies across-room discovery.
    return (observer_side >= -plane_epsilon and candidate_side >= -plane_epsilon) \
        or (observer_side <= plane_epsilon and candidate_side <= plane_epsilon)
