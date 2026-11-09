extends "res://addons/action5/equipment/weapon.gd"
class_name Action5Gun
## Per-instance hitscan behavior. The inherited Weapon supplies D06-01's
## inventory, registration and input-selection ports. No camera/viewmodel
## transforms or input events ever enter this component.

const HurtboxScript = preload("res://addons/action5/combat/hurtbox.gd")
const HealthScript = preload("res://addons/action5/combat/health.gd")

signal fired(impact: Vector3, hit_receiver: bool)
signal reload_started
signal reload_ended(completed: bool)

@export var fire_attack_id: StringName = &"gun_fire"
@export var muzzle_path: NodePath = ^"Muzzle"
@export var aim_provider_path: NodePath = ^"AimTargetProvider"
@export var reload_action: StringName = &"weapon_reload"
@export var reload_key: Key = KEY_R
@export_range(1, 200, 1) var magazine_size: int = 8
@export_range(0, 999, 1) var starting_reserve: int = 32
@export_range(1, 600, 1) var reload_ticks: int = 90
@export_range(0.1, 300.0, 0.5) var maximum_range: float = 60.0
@export_flags_3d_physics var ray_mask: int = 3

var magazine: int = 0
var reserve: int = 0
var reload_left: int = 0
var shots_fired: int = 0
var hits_landed: int = 0

var _bound_equipment: Node
var _combat: Node
var _aim: Node


func _ready() -> void:
    magazine = magazine_size
    reserve = starting_reserve
    # Attach before D05's priority -20 tick so its active transition is
    # observed exactly once without a second action/fire clock.
    process_physics_priority = -21


func get_command_bindings() -> Array[Dictionary]:
    return [{"action": reload_action, "key": reload_key}]


func request_weapon_command(action: StringName) -> bool:
    if action != reload_action or not is_equipped or not is_instance_valid(_combat):
        return false
    if reload_left > 0 or magazine >= magazine_size or reserve <= 0:
        return false
    if _combat.get("current_attack") != null or _combat.get("_pending_id") != &"":
        return false
    reload_left = reload_ticks
    reload_started.emit()
    return true


func get_ammo_status() -> Dictionary:
    return {"magazine": magazine, "reserve": reserve, "reloading": reload_left > 0,
        "reload_left": reload_left}


func get_visual_action() -> Dictionary:
    if reload_left > 0:
        return {"key": &"gun_reload", "progress": 1.0 - float(reload_left) / float(reload_ticks)}
    return {}


func _physics_process(_delta: float) -> void:
    _sync_equipment()
    if not is_equipped or not is_instance_valid(_combat):
        return
    if reload_left > 0:
        var actor := _bound_equipment.get_parent() as Node3D
        var health := actor.get_node_or_null("Health") as HealthScript
        if health != null and health.current_health <= 0.0:
            _cancel_reload()
            return
        reload_left -= 1
        if reload_left == 0:
            var loaded: int = mini(magazine_size - magazine, reserve)
            magazine += loaded
            reserve -= loaded
            reload_ended.emit(true)


func _sync_equipment() -> void:
    var current: Node = equipment_owner if is_instance_valid(equipment_owner) else null
    if current == _bound_equipment:
        if is_equipped and _combat == null:
            _bind_combat()
        return
    _unbind_combat()
    if is_instance_valid(_bound_equipment):
        var previous_callback := Callable(self, "_on_equipped")
        var previous_unequip := Callable(self, "_on_unequipped")
        if _bound_equipment.weapon_equipped.is_connected(previous_callback):
            _bound_equipment.weapon_equipped.disconnect(previous_callback)
        if _bound_equipment.weapon_unequipped.is_connected(previous_unequip):
            _bound_equipment.weapon_unequipped.disconnect(previous_unequip)
    _bound_equipment = current
    if not is_instance_valid(current):
        return
    current.weapon_equipped.connect(_on_equipped)
    current.weapon_unequipped.connect(_on_unequipped)
    if is_equipped and current.get("current_weapon") == self:
        _bind_combat()


func _on_equipped(weapon: Node3D) -> void:
    if weapon == self:
        _bind_combat()


func _on_unequipped(weapon: Node3D) -> void:
    if weapon == self:
        _unbind_combat()


func _bind_combat() -> void:
    if not is_equipped or not is_instance_valid(_bound_equipment):
        return
    var candidate: Node = _bound_equipment.get("combat") as Node
    if not is_instance_valid(candidate):
        return
    if _combat != candidate:
        _unbind_combat()
        _combat = candidate
        _combat.attack_phase_changed.connect(_on_attack_phase_changed)
    var actor := _bound_equipment.get_parent() as Node
    _aim = actor.get_node_or_null(aim_provider_path) if actor != null else null


func _unbind_combat() -> void:
    _cancel_reload()
    if is_instance_valid(_combat) and _combat.attack_phase_changed.is_connected(_on_attack_phase_changed):
        _combat.attack_phase_changed.disconnect(_on_attack_phase_changed)
    _combat = null
    _aim = null


func _cancel_reload() -> void:
    if reload_left > 0:
        reload_left = 0
        reload_ended.emit(false)


func _on_attack_phase_changed(id: StringName, phase: StringName, _tick: int) -> void:
    if id != fire_attack_id or phase != &"active" or not is_equipped:
        return
    if magazine == 0 or reload_left > 0 or not is_instance_valid(_aim):
        return
    var muzzle := get_node_or_null(muzzle_path) as Node3D
    var actor := _bound_equipment.get_parent() as CharacterBody3D
    if muzzle == null or actor == null:
        return
    var exclude: Array[RID] = [actor.get_rid()]
    for node in actor.find_children("*", "CollisionObject3D", true, false):
        var collision := node as CollisionObject3D
        if collision != null:
            exclude.append(collision.get_rid())
    var origin: Vector3 = muzzle.global_position
    var target: Vector3 = _aim.call("get_world_target", origin, maximum_range, exclude)
    if not target.is_finite() or origin.distance_squared_to(target) < 0.0001:
        return
    # A blocked physical shot still costs one round. An invalid request,
    # cancelled startup, dry magazine or reload does not.
    magazine -= 1
    shots_fired += 1
    var end: Vector3 = origin + (target - origin).normalized() * maximum_range
    # Respect a nearer camera-selected target; otherwise don't extend
    # the muzzle ray *past* a target and accidentally strike behind it.
    if origin.distance_to(target) <= maximum_range:
        end = target + (target - origin).normalized() * 0.05
    var query := PhysicsRayQueryParameters3D.create(origin, end, ray_mask, exclude)
    query.collide_with_areas = true
    query.collide_with_bodies = true
    var hit: Dictionary = actor.get_world_3d().direct_space_state.intersect_ray(query)
    var impact: Vector3 = hit.get("position", end)
    var damage_applied: bool = _try_damage(hit.get("collider") as CollisionObject3D, actor, origin, impact)
    fired.emit(impact, damage_applied)


func _try_damage(collider: CollisionObject3D, actor: CharacterBody3D,
        from: Vector3, impact: Vector3) -> bool:
    if collider == null:
        return false
    var hurtbox := collider as HurtboxScript
    if hurtbox == null:
        return false
    var target := hurtbox.get_health()
    var source := actor.get_node_or_null("Health") as HealthScript
    if target == null or target == source:
        return false
    var definition: Resource = _combat.call("get_attack", fire_attack_id)
    if definition == null:
        return false
    if source != null and source.team_id != 0 and source.team_id == target.team_id             and not bool(definition.get("allow_friendly_fire")):
        return false
    var delta := impact - from
    var direction := Vector2(delta.x, delta.z).normalized()
    var accepted: bool = target.take_hit(
        float(definition.get("damage")), actor, definition, direction,
        float(definition.get("knockback_speed")), int(definition.get("knockback_ticks")),
        int(definition.get("stagger_ticks"))
    )
    if accepted:
        hits_landed += 1
        _combat.attack_hit.emit(fire_attack_id, target.get_parent())
    return accepted


func _exit_tree() -> void:
    _unbind_combat()
    if is_instance_valid(_bound_equipment):
        if _bound_equipment.weapon_equipped.is_connected(_on_equipped):
            _bound_equipment.weapon_equipped.disconnect(_on_equipped)
        if _bound_equipment.weapon_unequipped.is_connected(_on_unequipped):
            _bound_equipment.weapon_unequipped.disconnect(_on_unequipped)
    _bound_equipment = null
