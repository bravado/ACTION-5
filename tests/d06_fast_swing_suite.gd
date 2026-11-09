extends RefCounted
## VT-08: real physics-tick overlap and continuous fast-motion regressions.
## Uses D05 Combat/Hurtbox/Health, not camera meshes or test-only damage.
const CombatScript = preload("res://addons/action5/combat/combat_controller.gd")
const HealthScript = preload("res://addons/action5/combat/health.gd")
const HurtboxScript = preload("res://addons/action5/combat/hurtbox.gd")
const AttackScript = preload("res://addons/action5/combat/attack_definition.gd")


func _target(parent: Node3D, label: String, position: Vector3) -> Node3D:
    var host := Node3D.new()
    host.name = label
    parent.add_child(host)
    host.global_position = position
    var health: HealthScript = HealthScript.new()
    health.name = "Health"
    health.team_id = 2
    host.add_child(health)
    var hurtbox: HurtboxScript = HurtboxScript.new()
    hurtbox.name = "Hurtbox"
    hurtbox.position.y = 1.0
    host.add_child(hurtbox)
    var collider := CollisionShape3D.new()
    collider.name = "CollisionShape3D"
    var box := BoxShape3D.new()
    box.size = Vector3(0.44, 1.15, 0.48)
    collider.shape = box
    hurtbox.add_child(collider)
    return host


func _start_active(tree: SceneTree, combat: CombatScript, id: StringName) -> bool:
    if not combat.request_attack(id, Vector2(0, -1)):
        return false
    for tick in range(8):
        await tree.physics_frame
        if combat.phase == &"active":
            return true
    return false


func run_tests(tree: SceneTree, level: Node3D, verify: Callable) -> void:
    var fighter := CharacterBody3D.new()
    fighter.name = "D06FastSwingActor"
    level.add_child(fighter)
    fighter.global_position = Vector3(45.4, 0, 48)
    var health: HealthScript = HealthScript.new()
    health.name = "Health"
    health.team_id = 1
    fighter.add_child(health)
    var combat: CombatScript = CombatScript.new()
    combat.name = "CombatController"
    fighter.add_child(combat)
    var self_area: HurtboxScript = HurtboxScript.new()
    self_area.name = "SelfHurtbox"
    self_area.position.y = 1.0
    fighter.add_child(self_area)
    var self_col := CollisionShape3D.new()
    var self_shape := BoxShape3D.new()
    self_shape.size = Vector3(0.65, 1.2, 0.65)
    self_col.shape = self_shape
    self_area.add_child(self_col)

    var target: Node3D = _target(level, "D06FastSwingTarget", Vector3(48, 0, 47))
    var target_health: HealthScript = target.get_node("Health") as HealthScript
    var attack: AttackScript = AttackScript.new()
    attack.attack_id = &"d06_vt08_sweep"
    attack.startup_ticks = 2
    attack.active_ticks = 7
    attack.recovery_ticks = 3
    attack.hitbox_size = Vector3(1.1, 1.1, 0.95)
    attack.hitbox_forward = 1.0
    attack.hitbox_height = 1.0
    attack.damage = 15.0
    attack.knockback_speed = 0.0
    attack.stagger_ticks = 0
    verify.call(combat.register_attack(attack), "VT-08 registers a standard D05 physics hit volume")
    for tick in range(3):
        await tree.physics_frame

    # The attacker crosses an entire target in ONE simulation step.
    # Both endpoint overlap queries are empty; intermediate physics-shape
    # samples must find it, without using authored mesh/grip transforms.
    verify.call(await _start_active(tree, combat, attack.attack_id),
        "VT-08 starts actual active melee window before the fast crossing")
    fighter.global_position.x = 50.6
    for tick in range(2):
        await tree.physics_frame
    verify.call(is_equal_approx(target_health.current_health, target_health.max_health - 15.0)
        and combat.hit_count == 1 and health.current_health == health.max_health,
        "VT-08 fast actor crossing hits target exactly once and never hits self")
    for tick in range(3):
        await tree.physics_frame
    verify.call(combat.hit_count == 1, "VT-08 multiple swept samples do not duplicate target damage")
    combat.cancel()

    # Target movement can also cross the entire fixed strike volume before
    # the next sampled overlap. The receiver owns no weapon or camera port.
    fighter.global_position = Vector3(48, 0, 48)
    target.global_position = Vector3(45.4, 0, 47)
    target_health.current_health = target_health.max_health
    target_health.invulnerability_left = 0
    for tick in range(3):
        await tree.physics_frame
    verify.call(await _start_active(tree, combat, attack.attack_id),
        "VT-08 stationary fighter reaches the active window with target outside range")
    target.global_position.x = 50.6
    for tick in range(2):
        await tree.physics_frame
    verify.call(is_equal_approx(target_health.current_health, target_health.max_health - 15.0)
        and combat.hit_count == 1,
        "VT-08 fast target crossing is resolved despite missing both endpoint overlaps")
    combat.cancel()

    # Edge-frame strictness: startup is never damaging; an actual partial
    # target overlap during the first active tick is; recovery is not.
    target_health.current_health = target_health.max_health
    target.global_position = Vector3(48.70, 0, 47)
    fighter.global_position = Vector3(48, 0, 48)
    for tick in range(3):
        await tree.physics_frame
    verify.call(combat.request_attack(attack.attack_id, Vector2(0, -1)),
        "VT-08 edge-contact attack request")
    await tree.physics_frame
    verify.call(target_health.current_health == target_health.max_health,
        "VT-08 startup overlap never damages target before active window")
    for tick in range(8):
        await tree.physics_frame
    verify.call(is_equal_approx(target_health.current_health, target_health.max_health - 15.0)
        and combat.hit_count == 1,
        "VT-08 grazing volume makes one edge contact only in active phase")
    combat.cancel()

    # The continuous fallback is still a normal masked physics hit: do not
    # allow a fast trajectory to bypass the collision-layer opt-out.
    var receiver: HurtboxScript = target.get_node("Hurtbox") as HurtboxScript
    target_health.current_health = target_health.max_health
    receiver.collision_layer = 4  # D05 hit mask is layer 2 only.
    target.global_position = Vector3(45.4, 0, 47)
    for tick in range(3):
        await tree.physics_frame
    verify.call(await _start_active(tree, combat, attack.attack_id),
        "VT-08 begins receiver-layer filtering at the actual active window")
    target.global_position.x = 50.6
    for tick in range(2):
        await tree.physics_frame
    verify.call(target_health.current_health == target_health.max_health
        and combat.hit_count == 0,
        "VT-08 moving receiver on excluded collision layer cannot be hit")
    combat.cancel()
    receiver.collision_layer = 2
    var collider: CollisionShape3D = receiver.get_node("CollisionShape3D")
    collider.disabled = true
    verify.call(not receiver.has_active_shape(),
        "VT-08 continuous receiver motion rejects disabled physics shapes")
    collider.disabled = false

    fighter.queue_free()
    target.queue_free()
    await tree.process_frame
