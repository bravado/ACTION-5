extends Area3D
class_name Action5Hurtbox
## Non-damaging collision receiver. Multiple areas may point to one Health.
## Collision layer 2 is reserved for D05 hurtboxes; the body remains on 1.

const HealthScript = preload("res://addons/action5/combat/health.gd")

@export var health_path: NodePath = ^"../Health"


func _ready() -> void:
    collision_layer = 2
    collision_mask = 0
    monitoring = false
    monitorable = true


func get_health() -> HealthScript:
    return get_node_or_null(health_path) as HealthScript
