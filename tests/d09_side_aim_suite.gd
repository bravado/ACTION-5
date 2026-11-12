extends RefCounted
## Side-scroller screen-plane gun aiming against REAL Godot collision objects.
## The camera selects a visible center-height target in the X/Y combat lane;
## the Gun remains authoritative for obstruction, ammo, hit and projectile.

const ContextSourceScript = preload("res://tests/fixtures/action_input_context_source.gd")
const ContextScript = preload("res://addons/action5/input/action_input_context.gd")
const ProfileScript = preload("res://addons/action5/camera/view_profile.gd")

func _ticks(tree: SceneTree, count: int) -> void:
    for i in range(count):
        await tree.physics_frame


func _fire(tree: SceneTree, combat: Node) -> bool:
    var accepted: bool = combat.call("request_attack", &"gun_fire", Vector2.RIGHT)
    await _ticks(tree, 4)
    return accepted


func run_tests(tree: SceneTree, verify: Callable) -> void:
    var scene := load("res://demo/main.tscn") as PackedScene
    verify.call(scene != null, "D09 side-gun real arena fixture loads")
    if scene == null:
        return
    var level := scene.instantiate() as Node3D
    level.position = Vector3(850.0, 0.0, 850.0)
    tree.root.add_child(level)
    await _ticks(tree, 6)
    var actor := level.get_node("Player") as CharacterBody3D
    var equipment: Node = actor.get_node("Equipment")
    var combat: Node = actor.get_node("CombatController")
    var views: Node = level.get_node("ViewManager")
    var aim: Node = actor.get_node("AimTargetProvider")
    var gun: Node3D = level.get_node("GunPickup") as Node3D
    var dummy := level.get_node("NearDummy") as Node3D
    var health: Node = dummy.get_node("Health")
    # Input polling is irrelevant to an authored damage/physics fixture.
    level.get_node("ActorInput").call("set_enabled", false)
    views.switch_view(0)
    dummy.position = Vector3(5.5, 0, 0)
    var source := ContextSourceScript.new()
    level.add_child(source)
    source.snapshot = ContextScript.new(
        true, Vector2.ZERO, Vector2.RIGHT,
        ProfileScript.Mode.SIDE, views.get_active_camera()
    )
    aim.context_source = source
    # The world pickup starts several metres away; scripted equipment
    # pickup enforces its ordinary range even in headless tests.
    gun.global_position = actor.global_position + Vector3(0.3, 0.4, 0.15)
    verify.call(equipment.call("pickup", gun),
        "D09 F1 equips the unchanged physical Gun")
    await _ticks(tree, 5)
    var muzzle := gun.get_node("Muzzle") as Node3D
    var excludes: Array[RID] = [actor.get_rid()]
    var center_target: Vector3 = aim.call("get_world_target",
        muzzle.global_position, 60.0, excludes)
    verify.call(center_target.distance_to(dummy.global_position + Vector3.UP * 1.25) < 0.9,
        "D09 F1 camera policy selects enemy body center on the shared 2D lane")
    verify.call(absf(center_target.y - 1.25) < 0.02,
        "D09 F1 target is upper-torso height instead of arm or floor height")
    var projectile_presenter: Node = gun.get_node("ProjectilePresenter")
    var projectiles: Array[Node3D] = []
    projectile_presenter.projectile_spawned.connect(
        func(effect: Node3D) -> void: projectiles.append(effect)
    )
    var muzzle_before: Vector3 = muzzle.global_position
    var old_hp: float = float(health.get("current_health"))
    verify.call(await _fire(tree, combat) and gun.get("shots_fired") == 1
        and gun.get("hits_landed") == 1 and float(health.get("current_health")) < old_hp,
        "D09 F1 side-facing gun hits same-lane enemy despite muzzle-height offset")
    verify.call(projectiles.size() == 1
        and projectiles[0].get("from_world").distance_to(muzzle_before) < 0.2,
        "D09 F1 tracer still starts at the real weapon muzzle")

    await _ticks(tree, 30)
    var wall := StaticBody3D.new()
    wall.collision_layer = 1
    wall.collision_mask = 0
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(0.45, 2.2, 2.0)
    shape.shape = box
    wall.add_child(shape)
    level.add_child(wall)
    wall.global_position = actor.global_position + Vector3(2.5, 1.1, 0.0)
    await _ticks(tree, 3)
    old_hp = float(health.get("current_health"))
    var ammo_before: int = gun.get("magazine")
    verify.call(await _fire(tree, combat)
        and int(gun.get("magazine")) == ammo_before - 1
        and float(health.get("current_health")) == old_hp
        and int(gun.get("hits_landed")) == 1,
        "D09 F1 solid world geometry still stops the center-aim muzzle shot")
    wall.queue_free()
    await _ticks(tree, 30)

    # The opposite direction uses the same policy and independent Gun port.
    dummy.position = Vector3(-5.5, 0.0, 0)
    health.set("invulnerability_left", 0)
    source.snapshot = ContextScript.new(
        true, Vector2.ZERO, Vector2.LEFT,
        ProfileScript.Mode.SIDE, views.get_active_camera()
    )
    var left_target: Vector3 = aim.call("get_world_target",
        muzzle.global_position, 60.0, excludes)
    verify.call(left_target.x < actor.global_position.x - 4.0
        and left_target.distance_to(dummy.global_position + Vector3.UP * 1.25) < 0.9,
        "D09 F1 center-height sightline respects left-facing aim too")
    old_hp = float(health.get("current_health"))
    verify.call(await _fire(tree, combat)
        and float(health.get("current_health")) < old_hp,
        "D09 F1 aiming left damages a real receiver through the muzzle")
    level.queue_free()
    await tree.process_frame
