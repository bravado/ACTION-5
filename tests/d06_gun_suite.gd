extends RefCounted
## D06-02: real world physics, per-instance ammo, reload, equipment and
## camera/muzzle occlusion. Does not replace physics with dummy pass flags.

const GunScript = preload("res://addons/action5/equipment/gun.gd")
const ContextSourceScript = preload("res://tests/fixtures/action_input_context_source.gd")
const ContextScript = preload("res://addons/action5/input/action_input_context.gd")
const ProfileScript = preload("res://addons/action5/camera/view_profile.gd")


func _ticks(tree: SceneTree, count: int) -> void:
    for i in range(count):
        await tree.physics_frame


func _fire(tree: SceneTree, combat: Node, id: StringName, heading: Vector2) -> bool:
    var requested: bool = combat.call("request_attack", id, heading)
    # SceneTree.physics_frame is emitted before node _physics_process.
    # Include the active transition, not just the startup frame boundary.
    await _ticks(tree, 4)
    return requested


func run_tests(tree: SceneTree, verify: Callable) -> void:
    var scene := load("res://demo/main.tscn") as PackedScene
    verify.call(scene != null, "Gun regression arena loads the real D06 demo scene")
    if scene == null:
        return
    var level := scene.instantiate() as Node3D
    # The legacy D06 arena is still live in tests/run_all.gd. Keep this
    # second authoritative actor and its physics world far from that fixture;
    # overlapping CharacterBody3D capsules otherwise push one actor upward
    # during every move_and_slide tick without apparent vertical velocity.
    level.position = Vector3(100.0, 0.0, 0.0)
    tree.root.add_child(level)
    await _ticks(tree, 3)
    var actor := level.get_node("Player") as CharacterBody3D
    var equipment: Node = actor.get_node("Equipment")
    var combat: Node = actor.get_node("CombatController")
    var gun := level.get_node("GunPickup") as GunScript
    var target := level.get_node("NearDummy") as Node3D
    var health: Node = target.get_node("Health")
    var views: Node = level.get_node("ViewManager")
    var world_visual: Node = actor.get_node("EquipmentVisualAdapter")

    var source := ContextSourceScript.new()
    level.add_child(source)
    source.snapshot = ContextScript.new(true, Vector2(0, -1), Vector2(0, -1),
        ProfileScript.Mode.BEATEMUP)
    var aim: Node = actor.get_node("AimTargetProvider")
    aim.context_source = source

    # A picked up gun is still one physical, socket-mounted instance. The
    # authoritative muzzle is a child of it, not the F4 viewmodel.
    actor.global_position = Vector3(100.0, 0.15, 0.0)
    gun.global_position = actor.global_position + Vector3(0.3, 0.4, 0.3)
    verify.call(equipment.pickup(gun) and equipment.current_weapon == gun
        and gun.is_equipped and gun.get_parent() != level
        and gun.magazine == 8 and gun.reserve == 32,
        "Pistol equips through D06-01 and owns its own magazine and reserve")
    await _ticks(tree, 2)
    var muzzle := gun.get_node("Muzzle") as Node3D
    var initial_muzzle: Vector3 = muzzle.global_position
    var fps_model: Node3D = world_visual.get("_viewmodel") as Node3D
    verify.call(is_instance_valid(fps_model) and gun._combat == combat
        and gun._aim == aim and combat.get_attack(&"gun_fire") != null,
        "One live gun binds D05 combat, a world aim port and the F4 render-only visual")

    target.global_position = Vector3(initial_muzzle.x, initial_muzzle.y - 0.8, initial_muzzle.z - 4.0)
    health.set("current_health", 100.0)
    var trace_excludes: Array[RID] = []
    print("D06_GUN_TRACE before muzzle=", muzzle.global_position,
        " actor=", actor.global_position, " socket=", (gun.get_parent() as Node3D).global_position,
        " target=", target.global_position, " hurtbox=",
        (target.get_node("Hurtbox") as Area3D).global_position,
        " aim=", aim.call("get_world_target", muzzle.global_position, 60.0, trace_excludes))
    var old_hp: float = health.get("current_health")
    gun.fired.connect(func(point: Vector3, landed: bool) -> void:
        print("D06_GUN_FIRED impact=", point, " landed=", landed,
            " muzzle=", muzzle.global_position, " actor=", actor.global_position,
        " socket=", (gun.get_parent() as Node3D).global_position, " velocity=", actor.velocity,
        " gunlocal=", gun.position, " target=",
            (target.get_node("Hurtbox") as Area3D).global_position))
    var ammo_before: int = gun.magazine
    var requested: bool = await _fire(tree, combat, &"gun_fire", Vector2(0, -1))
    verify.call(requested and gun.shots_fired == 1 and gun.magazine == ammo_before - 1
        and health.get("current_health") < old_hp and gun.hits_landed == 1,
        "Active-phase hit: req=%s fired=%d mag=%d hp=%.1f hits=%d muzzle=%s" % [str(requested), gun.shots_fired, gun.magazine, float(health.get("current_health")), gun.hits_landed, str(muzzle.global_position)])

    # The same request never fires twice during one active/recovery window.
    await _ticks(tree, 2)
    verify.call(gun.shots_fired == 1 and gun.hits_landed == 1,
        "No duplicates: shots=%d hits=%d" % [gun.shots_fired, gun.hits_landed])
    await _ticks(tree, 20)

    # An opaque layer-1 obstacle must win over a layer-2 target, regardless
    # of clear camera line of sight. Camera sits above the near muzzle wall.
    var wall := StaticBody3D.new()
    wall.collision_layer = 1
    wall.collision_mask = 0
    level.add_child(wall)
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(1.6, 0.6, 0.25)
    shape.shape = box
    wall.add_child(shape)
    wall.global_position = muzzle.global_position + Vector3(0, 0, -1.2)
    await _ticks(tree, 2)
    old_hp = health.get("current_health")
    ammo_before = gun.magazine
    requested = await _fire(tree, combat, &"gun_fire", Vector2(0, -1))
    verify.call(requested and gun.magazine == ammo_before - 1
        and health.get("current_health") == old_hp and gun.hits_landed == 1,
        "Muzzle obstruction: req=%s shots=%d ammo=%d hp=%.1f hits=%d" % [str(requested), gun.shots_fired, gun.magazine, float(health.get("current_health")), gun.hits_landed])
    await _ticks(tree, 20)

    # Actual F4 view-specific camera ray sees the target above the short
    # muzzle wall; physical muzzle still hits the wall. No camera hit bypass.
    var camera := Camera3D.new()
    level.add_child(camera)
    camera.global_position = muzzle.global_position + Vector3(0, 2.0, 0.25)
    camera.look_at(target.global_position + Vector3(0, 0.8, 0), Vector3.UP)
    source.snapshot = ContextScript.new(true, Vector2.ZERO, Vector2(0, -1),
        ProfileScript.Mode.FIRST_PERSON, camera)
    var camera_excludes: Array[RID] = [actor.get_rid()]
    var camera_target: Vector3 = aim.call("get_world_target",
        muzzle.global_position, 60.0, camera_excludes)
    print("D06_F4_TARGET computed=", camera_target, " target=",
        target.global_position + Vector3(0, 0.8, 0), " camera=", camera.global_position)
    verify.call(camera_target.distance_to(target.global_position + Vector3(0, 0.8, 0)) < 1.1,
        "F4 resolves the camera-visible target independently of weapon muzzle")
    old_hp = health.get("current_health")
    requested = await _fire(tree, combat, &"gun_fire", Vector2(0, -1))
    verify.call(requested and health.get("current_health") == old_hp,
        "F4 crosshair visibility does not bypass opaque muzzle-to-target geometry")
    await _ticks(tree, 20)
    wall.queue_free()
    await _ticks(tree, 2)

    # Gun is allowed to fire while jumping/running: no locomotion switches
    # are made by Gun, and all views retain one physical instance.
    source.snapshot = ContextScript.new(true, Vector2(0, -1), Vector2(0, -1),
        ProfileScript.Mode.BEATEMUP)
    var baseline_weapon: Node = equipment.current_weapon
    var baseline_magazine: int = gun.magazine
    for view in range(5):
        views.switch_view(view)
        await _ticks(tree, 1)
    verify.call(equipment.current_weapon == baseline_weapon
        and muzzle.global_position.is_finite() and gun.magazine == baseline_magazine
        and gun.shots_fired == 3,
        "F1–F5 switches preserve the gun instance, physical muzzle and ammunition")

    # Reload has a separate weapon-command timeline, not a combat action.
    verify.call(gun.request_weapon_command(&"weapon_reload") and gun.reload_left > 0,
        "Reload uses per-weapon command rather than an attack ID")
    var reload_before: int = gun.reload_left
    for view in [2, 3, 4, 0, 1]:
        views.switch_view(view)
        await _ticks(tree, 4)
    verify.call(gun.reload_left < reload_before and gun.magazine == baseline_magazine
        and gun.reserve == 32 and equipment.current_weapon == gun,
        "Reload timer advances across F3/F4/F5 switches without moving ammo into the camera")
    verify.call(not gun.request_weapon_command(&"weapon_reload"),
        "Cannot restart an already active reload")
    await _ticks(tree, gun.reload_left + 1)
    verify.call(gun.magazine == 8 and gun.reserve == 32 - (8 - baseline_magazine)
        and gun.reload_left == 0, "Reload completes exactly once, up to magazine/reserve limits")
    verify.call(not gun.request_weapon_command(&"weapon_reload"),
        "Full magazine cannot reload or waste reserve")

    # A queued but cancelled fire never consumes ammo.
    await _ticks(tree, 20)
    ammo_before = gun.magazine
    requested = combat.request_attack(&"gun_fire", Vector2(0, -1))
    combat.cancel()
    await _ticks(tree, 4)
    verify.call(requested and gun.magazine == ammo_before,
        "Cancelled startup/buffered gun attack cannot consume ammunition")

    # Stowing cancels reload and active fire, but retains all stored rounds.
    await _ticks(tree, 20)
    verify.call(gun.request_weapon_command(&"weapon_reload") == false,
        "Full magazine remains a no-op before a weapon swap")
    var before_drop: Dictionary = gun.get_ammo_status()
    verify.call(equipment.drop_current() and not gun.is_equipped
        and gun._combat == null and combat.get_attack(&"gun_fire") == null
        and gun.magazine == before_drop["magazine"] and gun.reserve == before_drop["reserve"],
        "Dropping unbinds attack and visuals without losing the weapon's ammo")
    verify.call(not gun.request_weapon_command(&"weapon_reload"),
        "World pickup cannot reload when unequipped")

    # Fixture 2 changes only scene, attack data and gun instance properties.
    var variant := (load("res://demo/equipment/gun_alt.tscn") as PackedScene).instantiate() as GunScript
    level.add_child(variant)
    variant.global_position = actor.global_position + Vector3(0.3, 0.4, 0.3)
    verify.call(equipment.pickup(variant) and variant.magazine == 3
        and variant.reserve == 12 and variant.reload_ticks == 135
        and variant.reload_action == &"weapon_alt_reload"
        and variant.definition.first_person_scene != gun.definition.first_person_scene,
        "Second gun registers with different ammo, cadence, reload command, clip and model")
    await _ticks(tree, 2)
    verify.call(combat.get_attack(&"gun_alt_fire") != null
        and combat.get_attack(&"gun_fire") == null,
        "Second configured gun reuses generic equipment and D05 action registry")
    var variant_muzzle := variant.get_node("Muzzle") as Node3D
    verify.call(not variant_muzzle.position.is_equal_approx(muzzle.position),
        "Second gun authors a different physical muzzle socket")
    var initial_variant_magazine: int = variant.magazine
    requested = await _fire(tree, combat, &"gun_alt_fire", Vector2(0, -1))
    verify.call(requested and variant.magazine == initial_variant_magazine - 1,
        "Alternate cadence attack fires from the alternate gun without core conditionals")
    await _ticks(tree, 30)
    verify.call(variant.request_weapon_command(&"weapon_alt_reload"),
        "Alternate gun accepts its own configured reload command")
    var variant_ammo: int = variant.magazine
    equipment.drop_current()
    await _ticks(tree, 1)
    verify.call(variant.reload_left == 0 and variant.magazine == variant_ammo,
        "Unequip aborts incomplete reload without refunding or creating ammunition")
    verify.call(equipment.pickup(variant) and variant.magazine == variant_ammo,
        "Re-pickup preserves the same ammo state instead of constructing a new weapon")

    # Clean teardown should remove the attack ID and the F4 visual only once.
    variant.queue_free()
    await _ticks(tree, 2)
    verify.call(combat.get_attack(&"gun_alt_fire") == null
        and equipment.current_weapon == null
        and not is_instance_valid(world_visual.get("_viewmodel") as Node),
        "Freeing an armed gun cleans up its D05 registration and FPS visual")
    source.queue_free()
    level.queue_free()
    await tree.process_frame
