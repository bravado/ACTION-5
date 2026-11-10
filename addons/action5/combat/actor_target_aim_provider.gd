extends Node
class_name Action5ActorTargetAimProvider
## Camera-free target provider for NPCs, turrets and scripted actors.
## This is a concrete second consumer of the Gun's world-target port,
## not an AI decision FSM or a parallel combat/movement implementation.

@export var target_path: NodePath
@export var target_offset: Vector3 = Vector3(0.0, 0.8, 0.0)
var target: Node3D


func set_target(next_target: Node3D) -> void:
    target = next_target


func get_world_target(origin: Vector3, _maximum_range: float,
        _exclude: Array[RID]) -> Vector3:
    var receiver: Node3D = target if is_instance_valid(target) else (
        get_node_or_null(target_path) as Node3D
    )
    if not is_instance_valid(receiver) or not receiver.is_inside_tree():
        return origin
    var point: Vector3 = receiver.global_position + target_offset
    return point if point.is_finite() else origin
