extends RefCounted
## D06-01 release hardening: atomic registration, destroyed-instance cleanup
## and actor teardown. Uses only the public duck-typed combat/mount ports.

const WeaponScript = preload("res://addons/action5/equipment/weapon.gd")
const DefinitionScript = preload("res://addons/action5/equipment/weapon_definition.gd")
const EquipmentScript = preload("res://addons/action5/equipment/equipment_controller.gd")
const AttackScript = preload("res://addons/action5/combat/attack_definition.gd")
const MountScript = preload("res://tests/fixtures/equipment_mount_source.gd")
const RejectingPortScript = preload("res://tests/fixtures/rejecting_combat_port.gd")


func _make_actor(level: Node3D, label: String, where: Vector3) -> Node3D:
    var actor := Node3D.new()
    actor.name = label
    var port: Node = RejectingPortScript.new()
    port.name = "CombatController"
    actor.add_child(port)
    var provider: Node = MountScript.new()
    provider.name = "SocketProvider"
    actor.add_child(provider)
    var socket := Node3D.new()
    socket.name = "Socket"
    provider.add_child(socket)
    var equipment: EquipmentScript = EquipmentScript.new()
    equipment.name = "Equipment"
    equipment.mount_source_path = ^"../SocketProvider"
    actor.add_child(equipment)
    level.add_child(actor)
    actor.global_position = where
    return actor


func _make_weapon(level: Node3D, label: String, ids: Array[StringName], where: Vector3) -> WeaponScript:
    var definition: DefinitionScript = DefinitionScript.new()
    definition.weapon_id = StringName(label)
    for id in ids:
        var attack: AttackScript = AttackScript.new()
        attack.attack_id = id
        definition.attacks.append(attack)
    var weapon: WeaponScript = WeaponScript.new()
    weapon.name = label
    weapon.definition = definition
    level.add_child(weapon)
    weapon.global_position = where
    return weapon


func run_tests(tree: SceneTree, level: Node3D, verify: Callable) -> void:
    var actor: Node3D = _make_actor(level, "D06AtomicSwap", Vector3(24, 0.5, 24))
    var equipment: EquipmentScript = actor.get_node("Equipment")
    var port: Node = actor.get_node("CombatController")
    var socket: Node3D = actor.get_node("SocketProvider/Socket")
    var original: WeaponScript = _make_weapon(level, "D06Original",
        [&"d06_old"], actor.global_position + Vector3(0.3, 0, 0))
    var replacement: WeaponScript = _make_weapon(level, "D06Candidate",
        [&"d06_new_1", &"d06_new_2"], actor.global_position + Vector3(0.5, 0, 0))
    var unequipped: Array[Node3D] = []
    var equipped: Array[Node3D] = []
    equipment.weapon_unequipped.connect(func(w: Node3D) -> void: unequipped.append(w))
    equipment.weapon_equipped.connect(func(w: Node3D) -> void: equipped.append(w))
    verify.call(equipment.pickup(original) and equipment.pickup(replacement)
        and equipment.current_weapon == original and original.get_parent() == socket
        and equipment.inventory.size() == 2 and port.get_attack(&"d06_old") != null,
        "Atomic-swap fixture starts with one active registry and a stowed candidate")

    port.set("reject_id", &"d06_new_2")
    verify.call(not equipment.swap_next()
        and equipment.current_weapon == original and original.get_parent() == socket
        and original.is_equipped and original.visible
        and not replacement.is_equipped and not replacement.visible
        and port.get_attack(&"d06_old") == original.definition.attacks[0]
        and port.get_attack(&"d06_new_1") == null
        and port.get_attack(&"d06_new_2") == null
        and unequipped.is_empty() and equipped.size() == 1,
        "Rejected second registration rolls back staged IDs without stowing original or emitting signals")
    verify.call(port.get("registration_attempts").has(&"d06_new_1")
        and port.get("registration_attempts").has(&"d06_new_2"),
        "Failure was injected AFTER one new action had successfully registered")

    # Attack IDs must be unique across simultaneous inventories. Collisions
    # are rejected before touching the current action or visual state.
    var colliding: WeaponScript = _make_weapon(level, "D06Conflicting",
        [&"d06_old"], actor.global_position + Vector3(0.7, 0, 0))
    equipment.max_items = 3
    verify.call(not equipment.pickup(colliding)
        and equipment.current_weapon == original
        and port.get_attack(&"d06_old") == original.definition.attacks[0],
        "Overlapping weapon attack IDs reject transaction without altering the equipped registry")
    port.set("reject_id", &"")
    verify.call(equipment.swap_next()
        and equipment.current_weapon == replacement
        and replacement.get_parent() == socket
        and port.get_attack(&"d06_old") == null
        and port.get_attack(&"d06_new_1") == replacement.definition.attacks[0]
        and port.get_attack(&"d06_new_2") == replacement.definition.attacks[1]
        and unequipped.size() == 1 and equipped.size() == 2,
        "Successful swap commits both actions once, emits one unequip/equip and keeps socket ownership")

    # A stowed item may be independently freed, not only dropped through UI.
    original.queue_free()
    await tree.process_frame
    await tree.process_frame
    verify.call(not is_instance_valid(original)
        and equipment.inventory.size() == 1
        and equipment.current_weapon == replacement
        and equipment.inventory[0] == replacement
        and port.get_attack(&"d06_new_1") != null
        and port.get_attack(&"d06_new_2") != null,
        "Freeing a stowed weapon removes inventory and ownership without affecting active item")

    # Direct free() emits tree_exiting synchronously while definitions are
    # still valid. The controller must unregister before the node is gone.
    replacement.free()
    verify.call(not is_instance_valid(replacement)
        and equipment.current_weapon == null and equipment.inventory.is_empty()
        and port.get_attack(&"d06_new_1") == null
        and port.get_attack(&"d06_new_2") == null
        and unequipped.size() == 2,
        "Directly freeing an equipped weapon unregisters every action exactly once")
    verify.call(not equipment.swap_next() and not equipment.drop_current()
        and not equipment.request_equipped_action(0, Vector2.RIGHT),
        "No stale selection survives an independently destroyed weapon")

    # A dropped weapon is no longer observed by this inventory. Freeing it
    # must not trigger a phantom unequip or change another current item.
    var dropped: WeaponScript = _make_weapon(level, "D06Dropped",
        [&"d06_drop"], actor.global_position + Vector3(0.3, 0, 0))
    verify.call(equipment.pickup(dropped) and equipment.drop_current()
        and dropped.get_parent() == level and dropped.equipment_owner == null,
        "Explicit drop releases ownership and restores the world parent")
    var unequipped_before: int = unequipped.size()
    dropped.free()
    verify.call(unequipped.size() == unequipped_before and equipment.inventory.is_empty(),
        "Freeing a previously dropped item does not trigger stale ownership callbacks")
    colliding.queue_free()
    actor.queue_free()
    await tree.process_frame
    await tree.process_frame

    # Equipment/actor teardown must release valid objects from its inventory
    # to the world when the original world parent survives. No model/camera
    # dependency is necessary for a future D07 enemy actor.
    var doomed: Node3D = _make_actor(level, "D06DoomedActor", Vector3(26, 0.5, 26))
    var doomed_equipment: EquipmentScript = doomed.get_node("Equipment")
    var held: WeaponScript = _make_weapon(level, "D06HeldOnExit",
        [&"d06_held"], doomed.global_position + Vector3(0.25, 0, 0))
    var stowed: WeaponScript = _make_weapon(level, "D06StowedOnExit",
        [&"d06_stowed"], doomed.global_position + Vector3(0.4, 0, 0))
    verify.call(doomed_equipment.pickup(held) and doomed_equipment.pickup(stowed),
        "Independent actor carries an equipped and a stowed instance before removal")
    doomed.queue_free()
    await tree.process_frame
    await tree.process_frame
    verify.call(not is_instance_valid(doomed)
        and is_instance_valid(held) and held.get_parent() == level
        and is_instance_valid(stowed) and stowed.get_parent() == level
        and held.equipment_owner == null and not held.is_equipped
        and stowed.equipment_owner == null and not stowed.is_equipped
        and held.visible and stowed.visible,
        "Removing actor releases both weapons to the world without dangling owners")
    held.queue_free()
    stowed.queue_free()
    await tree.process_frame

    # Real local F4 adapter and renderer: externally freeing an equipped
    # multi-mesh Bat must release the camera viewmodel/shadow registrations.
    var player: Node3D = level.get_node("Player")
    var live_equipment: EquipmentScript = player.get_node("Equipment")
    var live_combat: Node = player.get_node("CombatController")
    var fps: Node = player.get_node("FirstPersonPresenter")
    var visual: Node = player.get_node("EquipmentVisualAdapter")
    var bat: WeaponScript = level.get_node("BatPickup")
    var shadows_before: int = fps.world_visual_shadows.size()
    verify.call(live_equipment.pickup(bat)
        and live_equipment.current_weapon == bat
        and visual.get("_viewmodel") != null
        and fps.world_visual_shadows.size() > shadows_before,
        "Local actor re-equips the same Bat for independent destruction cleanup")
    bat.queue_free()
    await tree.process_frame
    await tree.process_frame
    verify.call(not is_instance_valid(bat)
        and live_equipment.current_weapon == null
        and live_equipment.inventory.is_empty()
        and live_combat.get_attack(&"bat_swing") == null
        and live_combat.get_attack(&"bat_horizontal") == null
        and visual.get("_viewmodel") == null
        and visual.get("_registered_meshes").is_empty()
        and fps.world_visual_shadows.size() == shadows_before,
        "Freeing equipped local Bat releases attack IDs, F4 viewmodel and every world shadow")
