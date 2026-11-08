extends Node3D
class_name Action5EquipmentController
## Equipment inventory and lifecycle ONLY. No camera, animation or weapon IDs.
## A replaceable mount provider supplies world attachment sockets. D05 combat
## remains the authoritative action clock and hit resolver.

const WeaponScript = preload("res://addons/action5/equipment/weapon.gd")

signal weapon_picked_up(weapon: Node3D)
signal weapon_equipped(weapon: Node3D)
signal weapon_unequipped(weapon: Node3D)
signal weapon_dropped(weapon: Node3D)

@export_range(1, 8, 1) var max_items: int = 2
@export_range(0.1, 10.0, 0.1) var pickup_radius: float = 2.5
@export var combat_path: NodePath = ^"../CombatController"
@export var mount_source_path: NodePath = ^"../EquipmentVisualAdapter"

@onready var combat: Node = get_node_or_null(combat_path)
@onready var mount_source: Node = get_node_or_null(mount_source_path)

var inventory: Array[WeaponScript] = []
var current_weapon: WeaponScript
var _world_parents: Dictionary = {}


func pickup(weapon: WeaponScript) -> bool:
    var actor := get_parent() as Node3D
    if actor == null or not is_instance_valid(weapon) or weapon.definition == null:
        return false
    if not weapon.definition.valid() or weapon.is_equipped or inventory.has(weapon):
        return false
    if inventory.size() >= max_items or weapon.global_position.distance_to(actor.global_position) > pickup_radius:
        return false
    var origin := weapon.get_parent() as Node3D
    if origin == null or not _can_register(weapon):
        return false
    _world_parents[weapon] = origin
    weapon.reparent(self, false)
    weapon.visible = false
    inventory.append(weapon)
    weapon_picked_up.emit(weapon)
    if current_weapon == null and not equip(weapon):
        inventory.erase(weapon)
        weapon.reparent(origin, false)
        weapon.visible = true
        _world_parents.erase(weapon)
        return false
    return true


func equip(weapon: WeaponScript) -> bool:
    if not inventory.has(weapon) or not _can_register(weapon):
        return false
    if current_weapon == weapon:
        return true
    var mount: Node3D = null
    if is_instance_valid(mount_source) and mount_source.has_method("get_mount"):
        mount = mount_source.call("get_mount", weapon.definition.socket_id) as Node3D
    if mount == null:
        return false
    if current_weapon != null:
        _stow_current()
    if not _register_attacks(weapon):
        return false
    weapon.reparent(mount, false)
    weapon.position = weapon.definition.grip_position
    weapon.rotation_degrees = weapon.definition.grip_rotation_degrees
    weapon.visible = true
    weapon.is_equipped = true
    current_weapon = weapon
    weapon_equipped.emit(weapon)
    return true


func swap_next() -> bool:
    if inventory.size() < 2:
        return false
    var current_index: int = inventory.find(current_weapon)
    return equip(inventory[(current_index + 1) % inventory.size()])


func drop_current() -> bool:
    if current_weapon == null:
        return false
    var actor := get_parent() as Node3D
    var weapon: WeaponScript = current_weapon
    var destination: Node3D = _world_parents.get(weapon) as Node3D
    if actor == null or not is_instance_valid(destination):
        return false
    _stow_current()
    inventory.erase(weapon)
    _world_parents.erase(weapon)
    weapon.reparent(destination, false)
    weapon.global_transform = Transform3D(
        Basis.IDENTITY, actor.global_position + Vector3(1.3, 0.4, 0.5)
    )
    weapon.visible = true
    weapon.is_equipped = false
    weapon_dropped.emit(weapon)
    return true


func request_equipped_action(index: int, world_direction: Vector2) -> bool:
    if current_weapon == null:
        return false
    return current_weapon.request_action(index, world_direction, combat)


func _stow_current() -> void:
    if current_weapon == null:
        return
    var previous: WeaponScript = current_weapon
    current_weapon = null
    weapon_unequipped.emit(previous)
    _unregister_attacks(previous)
    previous.reparent(self, false)
    previous.visible = false
    previous.is_equipped = false


func _can_register(weapon: WeaponScript) -> bool:
    if not is_instance_valid(combat) or not combat.has_method("get_attack"):
        return false
    var existing_ids: Dictionary = {}
    if current_weapon != null:
        for old_attack in current_weapon.get_attack_definitions():
            existing_ids[old_attack.get("attack_id")] = true
    var seen_ids: Dictionary = {}
    for attack in weapon.get_attack_definitions():
        var id: StringName = attack.get("attack_id")
        if id == &"" or seen_ids.has(id):
            return false
        seen_ids[id] = true
        if combat.call("get_attack", id) != null and not existing_ids.has(id):
            return false
    return true


func _register_attacks(weapon: WeaponScript) -> bool:
    var registered: Array[StringName] = []
    for attack in weapon.get_attack_definitions():
        if not bool(combat.call("register_attack", attack)):
            for id in registered:
                combat.call("unregister_attack", id)
            return false
        registered.append(attack.get("attack_id"))
    return true


func _unregister_attacks(weapon: WeaponScript) -> void:
    if not is_instance_valid(combat):
        return
    for attack in weapon.get_attack_definitions():
        combat.call("unregister_attack", attack.get("attack_id"))
