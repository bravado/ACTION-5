extends Node
class_name Action5CombatController
## An actor-local, camera-agnostic combat timeline. Only physics ticks advance
## startup/active/recovery. Resource definitions have no mutable action state.

const AttackScript = preload("res://addons/action5/combat/attack_definition.gd")
const HurtboxScript = preload("res://addons/action5/combat/hurtbox.gd")
const HealthScript = preload("res://addons/action5/combat/health.gd")
const MovementPolicyScript = preload("res://addons/action5/actor/movement_policy.gd")

signal attack_registered(attack: Resource)
signal attack_cancelled(id: StringName)
signal attack_started(id: StringName)
signal attack_phase_changed(id: StringName, phase: StringName, tick: int)
signal attack_hit(id: StringName, target: Node)
signal attack_finished(id: StringName)

@export var attacks: Array[Resource] = []
@export var health_path: NodePath = ^"../Health"
@export_flags_3d_physics var hurtbox_mask: int = 2
@export var debug_hitboxes: bool = false

var body: CharacterBody3D
var health: HealthScript
var current_attack: AttackScript
var current_id: StringName = &""
var phase: StringName = &"idle"
var elapsed_ticks: int = 0
var hit_count: int = 0

var _registry: Dictionary = {}
var _pending_id: StringName = &""
var _pending_direction: Vector2 = Vector2.ZERO
var _active_direction: Vector2 = Vector2(0.0, -1.0)
var _hit_actor_ids: Dictionary = {}
var _hit_shape: BoxShape3D = BoxShape3D.new()
var _debug_mesh: MeshInstance3D


func _ready() -> void:
    process_physics_priority = -20
    body = get_parent() as CharacterBody3D
    health = get_node_or_null(health_path) as HealthScript
    if body == null:
        push_error("ACTION5: CombatController must be a CharacterBody3D child")
        set_physics_process(false)
        return
    for resource in attacks:
        if resource is AttackScript:
            register_attack(resource as AttackScript)
    if health != null:
        health.damaged.connect(_on_owner_damaged)
        health.died.connect(_on_owner_died)


func register_attack(attack: AttackScript) -> bool:
    if attack == null or not attack.valid() or _registry.has(attack.attack_id):
        return false
    _registry[attack.attack_id] = attack
    attack_registered.emit(attack)
    return true


func get_attack(id: StringName) -> AttackScript:
    return _registry.get(id, null) as AttackScript


func get_attacks() -> Array[AttackScript]:
    var result: Array[AttackScript] = []
    for id in _registry:
        result.append(_registry[id] as AttackScript)
    return result


## Attack requests come from a separate input adapter, AI or weapon component.
## A single request can buffer during an existing action. Never restart it.
func request_attack(id: StringName, direction: Vector2 = Vector2.ZERO) -> bool:
    if get_attack(id) == null or body == null or not is_instance_valid(body):
        return false
    if health != null and (health.current_health <= 0.0 or health.stagger_left > 0):
        return false
    if not direction.is_finite():
        return false
    if _pending_id != &"":
        return false
    _pending_id = id
    _pending_direction = direction.normalized() if direction.length_squared() > 0.001 else Vector2.ZERO
    return true


func _physics_process(_delta: float) -> void:
    if health != null and health.stagger_left > 0:
        return
    if current_attack == null:
        if _pending_id == &"":
            _update_debug()
            return
        _begin_attack()
    if current_attack == null:
        return
    var definition: AttackScript = current_attack
    var t: int = elapsed_ticks
    var next_phase: StringName = &"startup"
    if t >= definition.startup_ticks + definition.active_ticks:
        next_phase = &"recovery"
    elif t >= definition.startup_ticks:
        next_phase = &"active"
    if phase != next_phase:
        phase = next_phase
        attack_phase_changed.emit(current_id, phase, t)
    if phase == &"active":
        _resolve_hits()
    _update_debug()
    elapsed_ticks += 1
    if elapsed_ticks >= definition.total_ticks():
        _finish_attack()


func _begin_attack() -> void:
    var id: StringName = _pending_id
    var direction: Vector2 = _pending_direction
    _pending_id = &""
    _pending_direction = Vector2.ZERO
    current_attack = get_attack(id)
    if current_attack == null:
        return
    current_id = id
    elapsed_ticks = 0
    hit_count = 0
    _hit_actor_ids.clear()
    if direction.length_squared() < 0.001:
        var visual: Node = body.get_node_or_null("Visual")
        if visual != null:
            direction = visual.get("facing_world")
    if direction.length_squared() < 0.001:
        direction = Vector2(0.0, -1.0)
    var sector_count: int = 4 if current_attack.facing_sectors == 1 else (8 if current_attack.facing_sectors == 2 else 0)
    _active_direction = MovementPolicyScript.quantize_facing(direction, sector_count)
    phase = &"idle"
    attack_started.emit(current_id)


func _hit_transform() -> Transform3D:
    var yaw: float = atan2(-_active_direction.x, -_active_direction.y)
    var basis := Basis(Vector3.UP, yaw)
    var center: Vector3 = body.global_position + Vector3(
        _active_direction.x * current_attack.hitbox_forward,
        current_attack.hitbox_height,
        _active_direction.y * current_attack.hitbox_forward
    )
    return Transform3D(basis, center)


func _resolve_hits() -> void:
    _hit_shape.size = current_attack.hitbox_size
    var query := PhysicsShapeQueryParameters3D.new()
    query.shape = _hit_shape
    query.transform = _hit_transform()
    query.collision_mask = hurtbox_mask
    query.collide_with_areas = true
    query.collide_with_bodies = false
    for entry in body.get_world_3d().direct_space_state.intersect_shape(query, 64):
        var hurtbox: HurtboxScript = entry.get("collider") as HurtboxScript
        if hurtbox == null:
            continue
        var target: HealthScript = hurtbox.get_health()
        if target == null or target == health or _hit_actor_ids.has(target.get_instance_id()):
            continue
        if health != null and health.team_id != 0 and health.team_id == target.team_id \
            and not current_attack.allow_friendly_fire:
            continue
        if target.take_hit(
            current_attack.damage, body, current_attack, _active_direction,
            current_attack.knockback_speed, current_attack.knockback_ticks,
            current_attack.stagger_ticks
        ):
            _hit_actor_ids[target.get_instance_id()] = true
            hit_count += 1
            attack_hit.emit(current_id, target.get_parent())


func _finish_attack(was_cancelled: bool = false) -> void:
    var finished: StringName = current_id
    current_attack = null
    current_id = &""
    phase = &"idle"
    elapsed_ticks = 0
    _hit_actor_ids.clear()
    _update_debug()
    if was_cancelled:
        attack_cancelled.emit(finished)
    else:
        attack_finished.emit(finished)


func cancel() -> void:
    _pending_id = &""
    _pending_direction = Vector2.ZERO
    if current_attack != null:
        _finish_attack(true)


## Damage and death interrupt gameplay; presentation is an optional
## signal subscriber and never influences the attack timeline.
func _on_owner_damaged(_amount: float, _source: Node) -> void:
    cancel()


func _on_owner_died(_source: Node) -> void:
    cancel()


## Purely optional visual debug: its mesh has no physics or hit authority.
func _update_debug() -> void:
    if not debug_hitboxes or current_attack == null:
        if is_instance_valid(_debug_mesh):
            _debug_mesh.visible = false
        return
    if not is_instance_valid(_debug_mesh):
        _debug_mesh = MeshInstance3D.new()
        _debug_mesh.name = "CombatHitboxDebug"
        var material := StandardMaterial3D.new()
        material.albedo_color = Color(1.0, 0.15, 0.15, 0.25)
        material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        var box := BoxMesh.new()
        box.material = material
        _debug_mesh.mesh = box
        _debug_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        body.add_child(_debug_mesh)
    (_debug_mesh.mesh as BoxMesh).size = current_attack.hitbox_size
    _debug_mesh.global_transform = _hit_transform()
    var debug_material: StandardMaterial3D = (_debug_mesh.mesh as BoxMesh).material as StandardMaterial3D
    if debug_material != null:
        debug_material.albedo_color = Color(1.0, 0.15, 0.15, 0.25) if phase == &"active" else Color(0.25, 0.6, 1.0, 0.12)
    _debug_mesh.visible = true
