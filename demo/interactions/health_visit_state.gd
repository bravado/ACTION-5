extends Node
## Reusable Health-only opt-in scene snapshot for a dummy, destructible prop,
## or any non-AI actor with Health. No changes to Health or scene manager.

@export var health_path: NodePath = ^"../Health"
@export var object_path: NodePath = ^".."

@onready var health: Node = get_node_or_null(health_path)
@onready var object: Node3D = get_node_or_null(object_path) as Node3D


func capture_state() -> Dictionary:
    if not is_instance_valid(health):
        return {}
    var result: Dictionary = {"hp": float(health.get("current_health"))}
    if is_instance_valid(object):
        result["transform"] = object.global_transform
    return result


func restore_state(snapshot: Dictionary) -> void:
    if not is_instance_valid(health) or not snapshot.has("hp"):
        return
    if is_instance_valid(object) and snapshot.has("transform") \
            and snapshot["transform"] is Transform3D:
        object.global_transform = snapshot["transform"]
    var previous: float = float(health.get("current_health"))
    var hp: float = clampf(float(snapshot["hp"]), 0.0, float(health.get("max_health")))
    health.set("current_health", hp)
    health.emit_signal("health_changed", hp, previous)
    if hp <= 0.0:
        health.emit_signal("died", null)
