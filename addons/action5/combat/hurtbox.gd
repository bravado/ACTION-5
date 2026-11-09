extends Area3D
class_name Action5Hurtbox
## Camera/weapon-agnostic collision receiver. The previous physics-frame
## position lets D05 resolve a fast-moving target that crosses an active
## melee volume entirely between overlap samples (VT-08).
const HealthScript = preload("res://addons/action5/combat/health.gd")

@export var health_path: NodePath = ^"../Health"
var previous_physics_origin: Vector3 = Vector3.ZERO
var _last_physics_origin: Vector3 = Vector3.ZERO


func _ready() -> void:
    collision_layer = 2
    collision_mask = 0
    monitoring = false
    monitorable = true
    add_to_group("action5_hurtbox")
    # Record AFTER normal actor movement; Combat queries at priority -20.
    process_physics_priority = 80
    previous_physics_origin = global_position
    _last_physics_origin = global_position


func _physics_process(_delta: float) -> void:
    previous_physics_origin = _last_physics_origin
    _last_physics_origin = global_position


func get_health() -> HealthScript:
    return get_node_or_null(health_path) as HealthScript


## A conservative receiver bound, including local shape offsets. The
## authoritative hit is still subject to team/health/dedup filtering.
func motion_half_extents() -> Vector3:
    var bound := Vector3(0.2, 0.2, 0.2)
    for child in get_children():
        var collider := child as CollisionShape3D
        if collider == null or collider.disabled or collider.shape == null:
            continue
        var extents: Vector3 = Vector3(0.2, 0.2, 0.2)
        if collider.shape is BoxShape3D:
            extents = (collider.shape as BoxShape3D).size * 0.5
        elif collider.shape is SphereShape3D:
            var radius: float = (collider.shape as SphereShape3D).radius
            extents = Vector3.ONE * radius
        elif collider.shape is CapsuleShape3D:
            var capsule: CapsuleShape3D = collider.shape as CapsuleShape3D
            extents = Vector3(capsule.radius, capsule.height * 0.5, capsule.radius)
        bound = bound.max(extents + collider.position.abs())
    return bound
