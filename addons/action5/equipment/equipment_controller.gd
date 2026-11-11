extends Node3D
class_name Action5EquipmentController
## Equipment inventory and lifecycle only. Combat owns action timing; an
## injected mount provider owns socket lookup. No camera or weapon IDs here.

const WeaponScript = preload("res://addons/action5/equipment/weapon.gd")

signal weapon_picked_up(weapon: Node3D)
signal weapon_equipped(weapon: Node3D)
signal weapon_unequipped(weapon: Node3D)
signal weapon_dropped(weapon: Node3D)

@export_range(1, 8, 1) var max_items: int = 2
@export_range(0.1, 10.0, 0.1) var pickup_radius: float = 2.5
@export var combat_path: NodePath = ^"../CombatController"
@export var mount_source_path: NodePath = ^"../EquipmentVisualAdapter"
## Optional world-owned policy that resolves where to drop at the *current*
## location, rather than remembering a parent freed by a fresh-sector reset.
@export var drop_parent_provider_path: NodePath

@onready var combat: Node = get_node_or_null(combat_path)
@onready var mount_source: Node = get_node_or_null(mount_source_path)

var inventory: Array[WeaponScript] = []
var current_weapon: WeaponScript
var _world_parents: Dictionary = {}
## Reparenting normally emits tree_exiting. Only an *external* tree exit
## (free, node removal, actor teardown) should release inventory ownership.
var _relocating: Dictionary = {}


func pickup(weapon: WeaponScript) -> bool:
    var actor := get_parent() as Node3D
    if actor == null or not is_instance_valid(weapon) or weapon.is_queued_for_deletion() \
            or weapon.definition == null:
        return false
    if not weapon.definition.valid() or weapon.is_equipped or inventory.has(weapon):
        return false
    if weapon.equipment_owner != null:
        return false
    if inventory.size() >= max_items or weapon.global_position.distance_to(actor.global_position) > pickup_radius:
        return false
    var origin := weapon.get_parent() as Node3D
    if origin == null or not _can_register(weapon):
        return false
    _world_parents[weapon] = origin
    weapon.equipment_owner = self
    inventory.append(weapon)
    _watch_weapon(weapon)
    _move_weapon(weapon, self)
    weapon.visible = false
    var auto_equipped: bool = current_weapon == null
    if auto_equipped and not _equip_weapon(weapon, false):
        inventory.erase(weapon)
        _forget_weapon(weapon)
        _move_weapon(weapon, origin)
        weapon.visible = true
        weapon.equipment_owner = null
        return false
    # Publish a pickup only after the entire operation commits. In
    # particular, a rejected first auto-equip must not leave HUD/AI
    # observers with a phantom pickup that was rolled back.
    weapon_picked_up.emit(weapon)
    # Preserve the original successful pickup -> equip signal ordering
    # without publishing either event if the auto-equip had to roll back.
    if auto_equipped:
        weapon_equipped.emit(weapon)
    return true


func equip(weapon: WeaponScript) -> bool:
    return _equip_weapon(weapon, true)


func _equip_weapon(weapon: WeaponScript, notify: bool) -> bool:
    if not is_instance_valid(weapon) or weapon.is_queued_for_deletion() \
            or not inventory.has(weapon) or weapon.equipment_owner != self:
        return false
    if current_weapon == weapon:
        return true
    if not _can_register(weapon):
        return false
    var mount: Node3D = null
    if is_instance_valid(mount_source) and mount_source.has_method("get_mount"):
        mount = mount_source.call("get_mount", weapon.definition.socket_id) as Node3D
    if not is_instance_valid(mount) or mount.is_queued_for_deletion():
        return false
    # Transaction boundary: stage ALL new registrations while the old
    # weapon, attack clock, visual and signals remain untouched. Partial
    # rejections roll back only the staged IDs. Two inventory items with
    # overlapping attack IDs are invalid: swapping cannot replace an
    # active ID without cancelling its authoritative timeline.
    if not _register_attacks(weapon):
        return false
    if current_weapon != null:
        _stow_current()
    _move_weapon(weapon, mount)
    weapon.position = weapon.definition.grip_position
    weapon.rotation_degrees = weapon.definition.grip_rotation_degrees
    weapon.visible = true
    weapon.is_equipped = true
    current_weapon = weapon
    if notify:
        weapon_equipped.emit(weapon)
    return true


func swap_next() -> bool:
    if inventory.is_empty():
        return false
    if current_weapon == null:
        return equip(inventory[0])
    if inventory.size() < 2:
        return false
    var current_index: int = inventory.find(current_weapon)
    if current_index < 0:
        return false
    return equip(inventory[(current_index + 1) % inventory.size()])


func drop_current() -> bool:
    if current_weapon == null or not is_instance_valid(current_weapon) \
            or current_weapon.is_queued_for_deletion():
        return false
    var actor := get_parent() as Node3D
    var weapon: WeaponScript = current_weapon
    if actor == null:
        return false
    var destination: Node3D
    if not drop_parent_provider_path.is_empty():
        var provider: Node = get_node_or_null(drop_parent_provider_path)
        if not is_instance_valid(provider) or not provider.has_method("get_drop_parent"):
            return false
        destination = provider.call("get_drop_parent", actor) as Node3D
    else:
        destination = _world_parents.get(weapon) as Node3D
        # Bare NPC/actor fixtures may lack a provider and survive a
        # dynamically replaced parent: use the actor's live world instead.
        if not is_instance_valid(destination):
            destination = actor.get_parent() as Node3D
    if not is_instance_valid(destination) or destination.is_queued_for_deletion() \
            or not destination.is_inside_tree():
        return false
    _stow_current()
    inventory.erase(weapon)
    _forget_weapon(weapon)
    _move_weapon(weapon, destination)
    weapon.global_transform = Transform3D(
        Basis.IDENTITY, actor.global_position + Vector3(1.3, 0.4, 0.5)
    )
    weapon.visible = true
    weapon.is_equipped = false
    weapon.equipment_owner = null
    weapon_dropped.emit(weapon)
    return true


func request_equipped_action(index: int, world_direction: Vector2) -> bool:
    if not is_instance_valid(current_weapon) or current_weapon.is_queued_for_deletion():
        return false
    return current_weapon.request_action(index, world_direction, combat)


func _stow_current() -> void:
    if current_weapon == null:
        return
    var previous: WeaponScript = current_weapon
    current_weapon = null
    weapon_unequipped.emit(previous)
    _unregister_attacks(previous)
    _move_weapon(previous, self)
    previous.visible = false
    previous.is_equipped = false


func _can_register(weapon: WeaponScript) -> bool:
    if not is_instance_valid(combat) or not combat.has_method("get_attack") \
            or not combat.has_method("register_attack") \
            or not combat.has_method("unregister_attack"):
        return false
    var seen_ids: Dictionary = {}
    for attack in weapon.get_attack_definitions():
        var id: StringName = attack.get("attack_id")
        if id == &"" or seen_ids.has(id) or combat.call("get_attack", id) != null:
            return false
        seen_ids[id] = true
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


func _watch_weapon(weapon: WeaponScript) -> void:
    var callback: Callable = _on_owned_weapon_exiting.bind(weapon)
    if not weapon.tree_exiting.is_connected(callback):
        weapon.tree_exiting.connect(callback)


func _forget_weapon(weapon: WeaponScript) -> void:
    _world_parents.erase(weapon)
    if not is_instance_valid(weapon):
        return
    var callback: Callable = _on_owned_weapon_exiting.bind(weapon)
    if weapon.tree_exiting.is_connected(callback):
        weapon.tree_exiting.disconnect(callback)


func _move_weapon(weapon: WeaponScript, destination: Node3D) -> void:
    _relocating[weapon] = true
    weapon.reparent(destination, false)
    _relocating.erase(weapon)


func _on_owned_weapon_exiting(weapon: WeaponScript) -> void:
    # Called synchronously BEFORE Node.free() invalidates the Resource and
    # child meshes. An intentional equip/stow/drop reparent is not deletion.
    if _relocating.has(weapon) or not inventory.has(weapon):
        return
    if current_weapon == weapon:
        current_weapon = null
        weapon_unequipped.emit(weapon)
        _unregister_attacks(weapon)
    inventory.erase(weapon)
    _forget_weapon(weapon)
    weapon.is_equipped = false
    weapon.equipment_owner = null


func _exit_tree() -> void:
    # Godot forbids reparenting children while the actor hierarchy is
    # exiting the tree. A destroyed actor takes its carried items with it;
    # surviving equipment must be explicitly dropped BEFORE actor teardown.
    # An independently removed controller also discards its attached items
    # rather than orphaning an equipped (unregistered) mesh in the socket.
    for weapon in inventory.duplicate():
        if not is_instance_valid(weapon):
            continue
        if current_weapon == weapon:
            current_weapon = null
            weapon_unequipped.emit(weapon)
            _unregister_attacks(weapon)
        _forget_weapon(weapon)
        weapon.equipment_owner = null
        weapon.is_equipped = false
        if not weapon.is_queued_for_deletion():
            weapon.queue_free()
    inventory.clear()
    current_weapon = null
    _world_parents.clear()
    _relocating.clear()
