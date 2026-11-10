extends RefCounted
## D06-02: real world physics, per-instance ammo, reload, equipment and
## camera/muzzle occlusion. Does not replace physics with dummy pass flags.

const GunScript = preload("res://addons/action5/equipment/gun.gd")
const NPCHealthScript = preload("res://addons/action5/combat/health.gd")
const NPCCombatScript = preload("res://addons/action5/combat/combat_controller.gd")
const NPCEquipmentScript = preload("res://addons/action5/equipment/equipment_controller.gd")
const NPCMountScript = preload("res://tests/fixtures/equipment_mount_source.gd")
const TargetAimScript = preload("res://addons/action5/combat/actor_target_aim_provider.gd")
const ProjectileScript = preload("res://addons/action5/animation/projectile_visual.gd")
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

    var reload_visual: Node = actor.get_node("GunReloadVisual")
    var world_animator: Node = actor.get_node("AnimationPresenter")
    verify.call(world_animator.call("set_upper_body_action", &"punch"),
        "Regression fixture has a legitimate unrelated upper-body combat clip")
    reload_visual.call("_on_unequipped", null)
    verify.call(world_animator.get("upper_body_clip") == &"punch",
        "Gun reload adapter does not clear a clip it did not start")
    world_animator.call("clear_upper_body_action")

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
    var projectile_presenter: Node = gun.get_node("ProjectilePresenter")
    var projectile_visuals: Array[Node3D] = []
    projectile_presenter.projectile_spawned.connect(func(effect: Node3D) -> void:
        projectile_visuals.append(effect)
    )
    var impacts: Array[Vector3] = []
    gun.fired.connect(func(point: Vector3, _hit: bool) -> void:
        impacts.append(point)
    )
    verify.call(projectile_presenter != null
        and projectile_presenter.get("spawn_count") == 0,
        "No projectile visual is spawned before a real fired event")
    var fps_model: Node3D = world_visual.get("_viewmodel") as Node3D
    verify.call(is_instance_valid(fps_model) and gun._combat == combat
        and gun._aim == aim and combat.get_attack(&"gun_fire") != null,
        "One live gun binds D05 combat, a world aim port and the F4 render-only visual")

    target.global_position = Vector3(initial_muzzle.x, initial_muzzle.y - 0.8, initial_muzzle.z - 4.0)
    health.set("current_health", 100.0)
    var old_hp: float = health.get("current_health")
    var ammo_before: int = gun.magazine
    var requested: bool = await _fire(tree, combat, &"gun_fire", Vector2(0, -1))
    verify.call(requested and gun.shots_fired == 1 and gun.magazine == ammo_before - 1
        and health.get("current_health") < old_hp and gun.hits_landed == 1,
        "One active phase must fire, spend one round and damage the physical Hurtbox")

    # The already-authoritative shot creates a render-only tracer in the
    # SAME world space and along the ray's actual resolved impact endpoint.
    var first_visual: ProjectileScript = (
        projectile_visuals[0] as ProjectileScript
        if projectile_visuals.size() > 0 else null
    )
    var tip_mesh: MeshInstance3D = (
        first_visual.get_node_or_null("VisibleProjectile") as MeshInstance3D
        if first_visual != null else null
    )
    verify.call(first_visual != null and first_visual.top_level
        and first_visual.get_parent() != gun
        and first_visual.get_parent() != projectile_presenter
        and first_visual.from_world.distance_to(initial_muzzle) < 0.15
        and impacts.size() == 1
        and first_visual.to_world.is_equal_approx(impacts[0])
        and tip_mesh != null and tip_mesh.layers == 1
        and tip_mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
        "In-flight tracer uses the true world muzzle and hit point on ordinary camera layers")
    verify.call(first_visual != null
        and first_visual.find_children("*", "CollisionObject3D", true, false).is_empty(),
        "Projectile visuals cannot apply collision, health or additional damage")

    # The same request never fires twice during one active/recovery window.
    await _ticks(tree, 2)
    verify.call(gun.shots_fired == 1 and gun.hits_landed == 1,
        "One active/recovery window cannot duplicate a Gun shot")
    await _ticks(tree, 20)
    verify.call(not is_instance_valid(first_visual)
        and projectile_presenter.get("spawn_count") == 1,
        "Projectile expires automatically after the shot without leaving pooled collision objects")

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
        "Physical muzzle obstruction blocks damage and still spends one round")
    verify.call(projectile_presenter.get("spawn_count") == 2
        and projectile_visuals.size() == 2
        and is_instance_valid(projectile_visuals[1])
        and (projectile_visuals[1] as ProjectileScript).to_world.distance_to(
            wall.global_position) < 0.3,
        "Muzzle-blocked shots stop the visible tracer at the world obstacle")
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
    verify.call(camera_target.distance_to(target.global_position + Vector3(0, 0.8, 0)) < 1.1,
        "F4 resolves the camera-visible target independently of weapon muzzle")
    old_hp = health.get("current_health")
    requested = await _fire(tree, combat, &"gun_fire", Vector2(0, -1))
    verify.call(requested and health.get("current_health") == old_hp
        and projectile_presenter.get("spawn_count") == 3,
        "F4 crosshair visibility does not bypass muzzle obstruction but still shows projectile")
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

    # The actual F4 local viewmodel has a separate, visible muzzle on its
    # animated Grip. Only the transient projectile may start there.
    views.switch_view(3)
    await _ticks(tree, 3)
    var f4_model: Node3D = world_visual.get("_viewmodel") as Node3D
    var f4_tip: Node3D = (
        f4_model.get_node_or_null("Grip/VisualMuzzle") as Node3D
        if is_instance_valid(f4_model) else null
    )
    var world_origin_before_f4: Vector3 = muzzle.global_position
    var authored_origin: Vector3 = world_visual.call(
        "get_projectile_visual_origin", gun, world_origin_before_f4
    )
    verify.call(f4_tip != null
        and authored_origin.distance_to(f4_tip.global_position) < 0.002
        and authored_origin.distance_to(world_origin_before_f4) > 0.2,
        "F4 visual projectile origin uses the gripped barrel tip, not third-person body socket")
    var snapshot_at_shot: Array[Vector3] = []
    var capture_f4_start: Callable = func(_impact: Vector3, _did_hit: bool) -> void:
        if is_instance_valid(f4_tip):
            snapshot_at_shot.append(f4_tip.global_position)
    gun.fired.connect(capture_f4_start)
    source.snapshot = ContextScript.new(true, Vector2.ZERO, Vector2(0, -1),
        ProfileScript.Mode.FIRST_PERSON, views.get_active_camera())
    var f4_visual_count: int = projectile_visuals.size()
    var f4_ammo_before: int = gun.magazine
    var f4_requested: bool = await _fire(tree, combat, &"gun_fire", Vector2(0, -1))
    var f4_visual: ProjectileScript = (
        projectile_visuals[f4_visual_count] as ProjectileScript
        if projectile_visuals.size() > f4_visual_count else null
    )
    verify.call(f4_requested and gun.magazine == f4_ammo_before - 1
        and snapshot_at_shot.size() == 1 and f4_visual != null
        and f4_visual.from_world.distance_to(snapshot_at_shot[0]) < 0.002
        and f4_visual.to_world.is_equal_approx(impacts[impacts.size() - 1]),
        "F4 active shot uses camera-local visual muzzle but preserves world-physics impact and ammo")
    # This listener only applies to the F4 fixture. Do not keep a Callable
    # capturing a short-lived viewmodel attached to the persistent Gun.
    gun.fired.disconnect(capture_f4_start)
    var eye: Camera3D = views.get_active_camera()
    verify.call(f4_visual != null and not eye.is_position_behind(f4_visual.from_world),
        "F4 projectile originates visibly in front of the active first-person camera")
    await _ticks(tree, 20)
    # This additional F4 shot is a real shot and spends another round; use
    # the actual magazine state for the subsequent reload assertions.
    baseline_magazine = gun.magazine
    views.switch_view(2)
    source.snapshot = ContextScript.new(true, Vector2(0, -1),
        Vector2(0, -1), ProfileScript.Mode.BEATEMUP)
    verify.call(world_visual.call("get_projectile_visual_origin",
        gun, muzzle.global_position).is_equal_approx(muzzle.global_position),
        "F1–F3 and F5 never use the local F4 visual muzzle for projectile position")

    # Independent F5 right-stick aiming uses the view-specific policy, not
    # movement or gun branches; F1–F3 retain continuous directions.
    source.snapshot = ContextScript.new(true, Vector2(0.98, 0.18),
        Vector2(-1, 0), ProfileScript.Mode.RETRO_TOPDOWN)
    var retro_target: Vector3 = aim.call("get_world_target",
        muzzle.global_position, 20.0, camera_excludes)
    var retro_direction := Vector2(retro_target.x - muzzle.global_position.x,
        retro_target.z - muzzle.global_position.z).normalized()
    verify.call(retro_direction.dot(Vector2.RIGHT) > 0.99,
        "F5 independent 8-way aim follows right stick, not moving/facing left")
    for mode in [ProfileScript.Mode.SIDE, ProfileScript.Mode.BEATEMUP,
            ProfileScript.Mode.ISOMETRIC]:
        source.snapshot = ContextScript.new(true, Vector2(0.6, -0.8),
            Vector2(-1, 0), mode)
        var aim_target: Vector3 = aim.call("get_world_target",
            muzzle.global_position, 20.0, camera_excludes)
        var continuous_direction := Vector2(aim_target.x - muzzle.global_position.x,
            aim_target.z - muzzle.global_position.z).normalized()
        verify.call(continuous_direction.distance_to(Vector2(0.6, -0.8)) < 0.001,
            "View %d retains continuous gun heading without retro quantization" % mode)
    source.snapshot = ContextScript.new(true, Vector2(0, -1),
        Vector2(0, -1), ProfileScript.Mode.BEATEMUP)

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
    verify.call(requested and gun.magazine == ammo_before
        and projectile_presenter.get("spawn_count") == 4,
        "Cancelled startup/buffered gun attack cannot consume ammo or spawn a phantom tracer")

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
    var alternate_presenter: Node = variant.get_node("ProjectilePresenter")
    var alternate_visuals: Array[Node3D] = []
    alternate_presenter.projectile_spawned.connect(func(effect: Node3D) -> void:
        alternate_visuals.append(effect)
    )
    verify.call(alternate_presenter.get("projectile_scene") != projectile_presenter.get("projectile_scene"),
        "Second gun configures its own projectile scene without changing shared rendering code")
    var variant_muzzle := variant.get_node("Muzzle") as Node3D
    views.switch_view(3)
    await _ticks(tree, 2)
    var heavy_model: Node3D = world_visual.get("_viewmodel") as Node3D
    var heavy_tip: Node3D = (
        heavy_model.get_node_or_null("Grip/VisualMuzzle") as Node3D
        if is_instance_valid(heavy_model) else null
    )
    var heavy_start: Vector3 = world_visual.call(
        "get_projectile_visual_origin", variant, variant_muzzle.global_position
    )
    verify.call(heavy_tip != null
        and heavy_start.distance_to(heavy_tip.global_position) < 0.002,
        "Alternate gun supplies its own authored F4 muzzle without changes to shared logic")
    views.switch_view(1)

    verify.call(not variant_muzzle.position.is_equal_approx(muzzle.position),
        "Second gun authors a different physical muzzle socket")
    var initial_variant_magazine: int = variant.magazine
    requested = await _fire(tree, combat, &"gun_alt_fire", Vector2(0, -1))
    var heavy_visual: ProjectileScript = (
        alternate_visuals[0] as ProjectileScript
        if alternate_visuals.size() > 0 else null
    )
    verify.call(requested and variant.magazine == initial_variant_magazine - 1
        and heavy_visual != null and heavy_visual.projectile_color.b > heavy_visual.projectile_color.r,
        "Alternate gun fires its configured blue projectile without core conditionals")
    await _ticks(tree, 30)
    # Empty magazine must never create a phantom hit or negative ammo.
    for shot in range(variant.magazine):
        await _ticks(tree, 30)
        verify.call(await _fire(tree, combat, &"gun_alt_fire", Vector2(0, -1)),
            "Alternate gun can fire remaining configured rounds")
    await _ticks(tree, 30)
    var fired_before_dry: int = variant.shots_fired
    requested = await _fire(tree, combat, &"gun_alt_fire", Vector2(0, -1))
    var visuals_before_dry: int = int(alternate_presenter.get("spawn_count"))
    verify.call(requested and variant.magazine == 0
        and variant.shots_fired == fired_before_dry
        and visuals_before_dry == initial_variant_magazine,
        "Dry active attack cannot fire, damage or spawn a fake projectile")
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
    # Camera-free NPC consumes exactly the same gun/attack/equipment ports.
    # No ActorInputAdapter, ViewManager, FPS presenter or AI-only hit logic.
    var npc := CharacterBody3D.new()
    npc.name = "CameraFreeRangedActor"
    var npc_health := NPCHealthScript.new()
    npc_health.name = "Health"
    npc_health.team_id = 1
    npc.add_child(npc_health)
    var npc_combat := NPCCombatScript.new()
    npc_combat.name = "CombatController"
    npc.add_child(npc_combat)
    var npc_mount := NPCMountScript.new()
    npc_mount.name = "SocketSource"
    npc.add_child(npc_mount)
    var npc_socket := Node3D.new()
    npc_socket.name = "Socket"
    npc_mount.add_child(npc_socket)
    var npc_equipment := NPCEquipmentScript.new()
    npc_equipment.name = "Equipment"
    npc_equipment.mount_source_path = ^"../SocketSource"
    npc.add_child(npc_equipment)
    var npc_aim := TargetAimScript.new()
    npc_aim.name = "WorldTarget"
    npc.add_child(npc_aim)
    level.add_child(npc)
    npc.global_position = Vector3(115.0, 0.15, 0.0)
    npc_aim.set_target(target)
    var npc_gun := (load("res://demo/equipment/gun.tscn") as PackedScene).instantiate() as GunScript
    npc_gun.aim_provider_path = ^"WorldTarget"
    level.add_child(npc_gun)
    npc_gun.global_position = npc.global_position + Vector3(0.3, 0.4, 0.3)
    verify.call(npc_equipment.pickup(npc_gun)
        and npc_equipment.current_weapon == npc_gun,
        "Camera-free NPC equips identical Gun without an input adapter or F4 viewmodel")
    await _ticks(tree, 3)
    var npc_muzzle := npc_gun.get_node("Muzzle") as Node3D
    target.global_position = npc_muzzle.global_position + Vector3(0.0, -0.8, -3.0)
    health.set("current_health", 100.0)
    verify.call(npc_gun._aim == npc_aim and npc_aim.get_world_target(
        npc_muzzle.global_position, 60.0, camera_excludes) != npc_muzzle.global_position,
        "D07 target provider resolves a world point without consulting player view")
    var npc_projectiles: Array[Node3D] = []
    var npc_presenter: Node = npc_gun.get_node("ProjectilePresenter")
    npc_presenter.projectile_spawned.connect(func(effect: Node3D) -> void:
        npc_projectiles.append(effect)
    )
    var npc_muzzle_origin: Vector3 = npc_muzzle.global_position
    var npc_fired: bool = await _fire(tree, npc_combat, &"gun_fire", Vector2(0, -1))
    verify.call(npc_fired and npc_gun.magazine == 7
        and health.get("current_health") < 100.0 and npc_gun.hits_landed == 1,
        "Camera-free NPC hits a physical Hurtbox through normal D05 Gun/Health contracts")
    verify.call(npc_projectiles.size() == 1
        and (npc_projectiles[0] as ProjectileScript).from_world.distance_to(npc_muzzle_origin) < 0.15,
        "Camera-free NPC tracer starts from its own physical muzzle without an F4 provider")
    await _ticks(tree, 20)
    var npc_ammo: int = npc_gun.magazine
    views.switch_view(3)
    views.switch_view(4)
    verify.call(npc_gun.magazine == npc_ammo and npc_equipment.current_weapon == npc_gun,
        "Local camera switches never modify camera-free NPC gun and ammo")
    # Clearing the NPC target fails closed, never creates an infinite/invalid
    # world ray or spends ammunition.
    npc_aim.set_target(null)
    await _ticks(tree, 20)
    var dry_aim_shot: bool = await _fire(tree, npc_combat, &"gun_fire", Vector2(0, -1))
    verify.call(dry_aim_shot and npc_gun.magazine == npc_ammo,
        "Missing AI target does not consume ammo, spawn a projectile or use a camera fallback")
    npc.queue_free()
    await _ticks(tree, 2)
    verify.call(not is_instance_valid(npc_gun),
        "Camera-free actor teardown removes owned equipment without leaking a weapon")

    # World-owned projectile continues independently after weapon/actor
    # destruction, then expires without involving a global projectile FSM.
    verify.call(equipment.pickup(gun), "Reequip earlier gun for teardown-in-flight regression")
    await _ticks(tree, 3)
    var visuals_before_teardown: int = projectile_visuals.size()
    var last_shot: bool = await _fire(tree, combat, &"gun_fire", Vector2(0, -1))
    var in_flight: Node3D = (
        projectile_visuals[visuals_before_teardown]
        if projectile_visuals.size() > visuals_before_teardown else null
    )
    gun.queue_free()
    await _ticks(tree, 2)
    verify.call(last_shot and is_instance_valid(in_flight)
        and in_flight.get_parent() != gun,
        "Existing projectile survives disposal of its equipped gun")
    await _ticks(tree, 25)
    verify.call(not is_instance_valid(in_flight),
        "Orphan-free world projectile expires on its own after gun destruction")

    source.queue_free()
    level.queue_free()
    await tree.process_frame
