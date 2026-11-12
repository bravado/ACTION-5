extends RefCounted
## Real shared-world retro encounter + resource-driven direction policy proof.
const PolicyScript = preload("res://addons/action5/combat/view_facing_policy.gd")
const AimScript = preload("res://addons/action5/combat/aim_provider.gd")
const ContextScript = preload("res://addons/action5/input/action_input_context.gd")
const ContextSourceScript = preload("res://tests/fixtures/action_input_context_source.gd")
const ProfileScript = preload("res://addons/action5/camera/view_profile.gd")


func _ticks(tree: SceneTree, amount: int) -> void:
    for i in range(amount):
        await tree.physics_frame


func run_tests(tree: SceneTree, verify: Callable) -> void:
    var scene := load("res://demo/main.tscn") as PackedScene
    verify.call(scene != null, "D09-02 shared retro world loads")
    if scene == null:
        return
    var level := scene.instantiate() as Node3D
    level.position = Vector3(1350.0, 0.0, 1350.0)
    tree.root.add_child(level)
    await _ticks(tree, 6)
    var player := level.get_node("Player") as CharacterBody3D
    var views: Node = level.get_node("ViewManager")
    var equipment: Node = player.get_node("Equipment")
    var combat: Node = player.get_node("CombatController")
    var policy: Node = player.get_node("EquippedViewFacing")
    var sword := level.get_node("EncounterSector/SwordPickup") as Node3D
    var gun := level.get_node("GunPickup") as Node3D
    var aim: Node = player.get_node("AimTargetProvider")
    var actor_input: Node = level.get_node("ActorInput")
    actor_input.call("set_enabled", false)
    verify.call(sword != null and sword.get("definition").valid(),
        "D09-02 dungeon contains a configured physical Sword pickup")
    verify.call(policy != null and gun != null and aim != null,
        "D09-02 gun and sword share one optional input-facing policy")
    views.switch_view(4)
    var control_profile: Resource = actor_input.call("get_active_controls")
    verify.call(control_profile != null
        and str(control_profile.get("move_up_action")) == "retro_move_up"
        and str(control_profile.get("extra_aim_up_action")) == "retro_aim_up",
        "D09-02 F5 installs a demo-local WASD move + arrows aim profile")
    var arrow_up := InputEventKey.new()
    arrow_up.keycode = KEY_UP
    var arrow_right := InputEventKey.new()
    arrow_right.keycode = KEY_RIGHT
    var w_key := InputEventKey.new()
    w_key.keycode = KEY_W
    verify.call(InputMap.event_is_action(arrow_up, &"retro_aim_up")
        and InputMap.event_is_action(arrow_right, &"retro_aim_right")
        and InputMap.event_is_action(w_key, &"retro_move_up"),
        "D09-02 actual arrow/W keys are bound to the independent retro InputMap roles")
    Input.action_press(&"retro_aim_up")
    Input.action_press(&"retro_aim_right")
    var keyboard_aim: Vector2 = actor_input.call("get_aim_axes")
    var keyboard_movement: Vector2 = actor_input.call("get_movement_axes")
    print("ACTION5_RETRO_INPUT aim=", keyboard_aim, " move=", keyboard_movement)
    verify.call(keyboard_aim.distance_to(Vector2(1, -1).normalized()) < 0.01
        and keyboard_movement.length_squared() < 0.001,
        "D09-02 Up+Right aim actions resolve diagonally without moving")
    Input.action_release(&"retro_aim_up")
    Input.action_release(&"retro_aim_right")
    Input.action_press(&"retro_move_up")
    keyboard_aim = actor_input.call("get_aim_axes")
    keyboard_movement = actor_input.call("get_movement_axes")
    print("ACTION5_RETRO_INPUT_MOVE aim=", keyboard_aim, " move=", keyboard_movement)
    verify.call(keyboard_aim.length_squared() < 0.001 and keyboard_movement.y < -0.99,
        "D09-02 WASD move actions do not introduce an aim direction")
    Input.action_release(&"retro_move_up")
    verify.call(views.camera_rig.is_vertical_overhead(),
        "D09-02 top-down remains precisely vertical")
    var camera_id_before: int = views.get_active_camera().get_instance_id()
    var camera_before: Vector3 = views.get_active_camera().global_position
    var heading_before: Basis = views.get_active_camera().global_basis
    player.global_position = sword.global_position + Vector3(0.25, 0, 0)
    await _ticks(tree, 3)
    views.camera_rig._snap_next = true
    views.camera_rig._update_camera(1.0 / 60.0)
    verify.call(views.get_active_camera().global_position.x - camera_before.x > 15.0
        and views.get_active_camera().global_basis.is_equal_approx(heading_before)
        and views.get_active_camera().get_instance_id() == camera_id_before,
        "D09-02 vertical camera scrolls into connected dungeon without changing heading or identity")
    verify.call(equipment.call("pickup", sword),
        "D09-02 Sword uses existing world pickup/equipment protocol")
    verify.call(policy.call("get_sectors", ProfileScript.Mode.RETRO_TOPDOWN) == 4
        and policy.call("get_sectors", ProfileScript.Mode.ISOMETRIC) == 0,
        "D09-02 Sword policy restricts only F5 to four directions")
    var slash: Resource = sword.get("definition").attacks[0]
    verify.call(slash.facing_sectors == 0 and combat.call("get_attack", slash.attack_id) == slash,
        "D09-02 Sword registers an unquantized D05 melee attack")
    var retro_hint := level.get_node("Hud/RetroDirection") as Label
    level.get_node("Hud").call("_process", 0.0)
    print("ACTION5_RETRO_HUD_SWORD visible=", retro_hint.visible, " text=", retro_hint.text)
    verify.call(retro_hint.visible and retro_hint.text.contains("Sword")
        and retro_hint.text.contains("4-WAY"),
        "D09-02 live overhead HUD identifies the equipped four-way Sword")
    var diagonal := Vector2(1, -0.5).normalized()
    var f5_sword: Vector2 = AimScript.resolve_direction(diagonal, Vector2.LEFT,
        ProfileScript.Mode.RETRO_TOPDOWN, null,
        policy.call("get_sectors", ProfileScript.Mode.RETRO_TOPDOWN))
    var f3_sword: Vector2 = AimScript.resolve_direction(diagonal, Vector2.LEFT,
        ProfileScript.Mode.ISOMETRIC, null,
        policy.call("get_sectors", ProfileScript.Mode.ISOMETRIC))
    verify.call(f5_sword.distance_to(Vector2.RIGHT) < 0.001
        and f3_sword.distance_to(diagonal) < 0.001,
        "D09-02 same Sword is F5 cardinal and F3 freely aimed")
    verify.call(combat.call("request_attack", slash.attack_id, f5_sword),
        "D09-02 Sword attack enters existing single combat timeline")
    await _ticks(tree, 5)
    verify.call(combat.get("_active_direction").distance_to(Vector2.RIGHT) < 0.001,
        "D09-02 active Sword hitbox faces policy-selected cardinal direction")
    views.switch_view(2)
    verify.call(combat.get("current_id") == slash.attack_id,
        "D09-02 F5 to F3 does not cancel a running Sword swing")
    await _ticks(tree, 30)
    verify.call(equipment.call("drop_current"), "D09-02 Sword can drop through shared equipment")
    gun.global_position = player.global_position + Vector3(0.3, 0.35, 0.2)
    await _ticks(tree, 3)
    verify.call(equipment.call("pickup", gun), "D09-02 existing Gun equips after Sword")
    verify.call(policy.call("get_sectors", ProfileScript.Mode.RETRO_TOPDOWN) == 8,
        "D09-02 Gun has independent eight-way F5 configuration")
    views.switch_view(4)
    level.get_node("Hud").call("_process", 0.0)
    print("ACTION5_RETRO_HUD_GUN visible=", retro_hint.visible, " text=", retro_hint.text)
    verify.call(retro_hint.visible and retro_hint.text.contains("Pistol")
        and retro_hint.text.contains("8-WAY"),
        "D09-02 same HUD shows eight sectors with Gun without restarting actor")
    var f5_gun: Vector2 = AimScript.resolve_direction(diagonal, Vector2.LEFT,
        ProfileScript.Mode.RETRO_TOPDOWN, null,
        policy.call("get_sectors", ProfileScript.Mode.RETRO_TOPDOWN))
    verify.call(f5_gun.distance_to(Vector2(1, -1).normalized()) < 0.001,
        "D09-02 diagonal Gun aim quantizes to eight sectors")
    var source := ContextSourceScript.new()
    level.add_child(source)
    aim.context_source = source
    source.snapshot = ContextScript.new(true, diagonal, Vector2.LEFT,
        ProfileScript.Mode.RETRO_TOPDOWN, views.get_active_camera())
    var muzzle := gun.get_node("Muzzle") as Node3D
    var excludes: Array[RID] = []
    # With target collision excluded, the aim point must lie on the
    # player's centerline, not on the parallel line from the hand muzzle.
    var original_target_mask: int = int(aim.get("camera_target_mask"))
    aim.set("camera_target_mask", 0)
    var target: Vector3 = aim.call("get_world_target", muzzle.global_position, 40.0, excludes)
    var from_actor: Vector2 = Vector2(
        target.x - player.global_position.x, target.z - player.global_position.z
    )
    verify.call(from_actor.normalized().distance_to(f5_gun) < 0.001
        and is_equal_approx(target.y, muzzle.global_position.y)
        and absf(from_actor.length() - 40.0) < 0.001,
        "D09-02 Gun aim selects F5 forward player-center line at muzzle height")
    source.snapshot = ContextScript.new(true, diagonal, Vector2.LEFT,
        ProfileScript.Mode.ISOMETRIC, views.get_active_camera())
    target = aim.call("get_world_target", muzzle.global_position, 40.0, excludes)
    verify.call(Vector2(target.x - muzzle.global_position.x,
        target.z - muzzle.global_position.z).normalized().distance_to(diagonal) < 0.001,
        "D09-02 F3 Gun target remains continuous from the physical muzzle")
    aim.set("camera_target_mask", original_target_mask)
    verify.call(gun.get("magazine") == gun.get("magazine_size"),
        "D09-02 view policy never spends ammunition")

    # The tracer must originate at the physical gun, while the forward
    # sightline originates from the actor's horizontal center. Test both
    # through the real active-phase shot and the existing projectile visual.
    var presenter: Node = gun.get_node("ProjectilePresenter")
    var world_visual: Node = player.get_node("EquipmentVisualAdapter")
    verify.call(presenter.get("visual_origin_provider_path") == NodePath("EquipmentVisualAdapter"),
        "D09-02 tracer uses existing muzzle origin with optional F4 viewmodel")
    var world_muzzle: Vector3 = muzzle.global_position
    var actor_center: Vector3 = player.global_position
    verify.call(presenter.call("_visual_origin", world_muzzle).is_equal_approx(world_muzzle),
        "D09-02 F5 visually starts at real Gun muzzle, never player body center")

    views.switch_view(2)
    verify.call(presenter.call("_visual_origin", muzzle.global_position).is_equal_approx(
        muzzle.global_position),
        "D09-02 F3 still launches from the physical weapon muzzle")
    views.switch_view(3)
    var expected_f4: Vector3 = world_visual.call(
        "get_projectile_visual_origin", gun, muzzle.global_position
    )
    verify.call(presenter.call("_visual_origin", muzzle.global_position).is_equal_approx(expected_f4)
        and expected_f4.distance_to(muzzle.global_position) > 0.1,
        "D09-02 F4 still launches from its gripped first-person barrel")
    views.switch_view(4)

    # Isolate a target on the exact forward centerline using an opt-in layer.
    # Hitscan is still from the Gun muzzle and must select the target from
    # the actor-centered F5 sightline rather than the offset muzzle lane.
    var sight_target := StaticBody3D.new()
    sight_target.name = "RetroCenterlineTarget"
    sight_target.collision_layer = 4
    sight_target.collision_mask = 0
    var sight_shape := CollisionShape3D.new()
    var sight_box := BoxShape3D.new()
    sight_box.size = Vector3(1.0, 1.5, 1.0)
    sight_shape.shape = sight_box
    sight_target.add_child(sight_shape)
    level.add_child(sight_target)
    sight_target.global_position = Vector3(
        player.global_position.x + 5.0, muzzle.global_position.y, player.global_position.z
    )
    aim.set("camera_target_mask", 4)
    var original_ray_mask: int = int(gun.get("ray_mask"))
    gun.set("ray_mask", 4)
    await _ticks(tree, 3)
    source.snapshot = ContextScript.new(true, Vector2.RIGHT, Vector2.LEFT,
        ProfileScript.Mode.RETRO_TOPDOWN, views.get_active_camera())
    var chosen_center_target: Vector3 = aim.call(
        "get_world_target", muzzle.global_position, 40.0, excludes
    )
    verify.call(absf(chosen_center_target.z - player.global_position.z) < 0.01
        and chosen_center_target.x > player.global_position.x + 3.5,
        "D09-02 physical F5 aim picks target in front of player center")

    var recorded_shots: Array[Dictionary] = []
    var projectiles: Array[Node3D] = []
    gun.fired.connect(func(impact: Vector3, _did_damage: bool) -> void:
        recorded_shots.append({
            "impact": impact, "muzzle": muzzle.global_position
        })
    )
    presenter.projectile_spawned.connect(func(projectile: Node3D) -> void:
        projectiles.append(projectile)
    )
    var ammo_before: int = gun.magazine
    var shots_before: int = gun.shots_fired
    var requested: bool = combat.call("request_attack", &"gun_fire", Vector2.RIGHT)
    await _ticks(tree, 8)
    verify.call(requested and recorded_shots.size() == 1 and projectiles.size() == 1
        and gun.shots_fired == shots_before + 1 and gun.magazine == ammo_before - 1,
        "D09-02 real F5 fire still uses one hit ray, ammo cost and visible tracer")
    if recorded_shots.size() == 1 and projectiles.size() == 1:
        var shot: Dictionary = recorded_shots[0]
        var tracer: Node3D = projectiles[0]
        var visual_start: Vector3 = tracer.get("from_world")
        var physical_muzzle: Vector3 = shot["muzzle"]
        var impact: Vector3 = shot["impact"]
        verify.call(visual_start.distance_to(physical_muzzle) < 0.002
            and (tracer.get("to_world") as Vector3).is_equal_approx(impact)
            and absf(impact.z - sight_target.global_position.z) < 0.5
            and impact.x > player.global_position.x + 3.5,
            "D09-02 real F5 tracer leaves Gun muzzle and converges toward center-front hit")
    else:
        verify.call(false, "D09-02 real F5 tracer leaves Gun muzzle and converges toward center-front hit")
    gun.set("ray_mask", original_ray_mask)
    aim.set("camera_target_mask", original_target_mask)
    sight_target.queue_free()
    await _ticks(tree, 2)
    var extra := PolicyScript.new()
    extra.view_mode = ProfileScript.Mode.RETRO_TOPDOWN
    extra.sector_count = 16
    var gun_definition: Resource = gun.get("definition")
    var original_policies: Array = gun_definition.view_facing_policies.duplicate()
    var alternate_policies: Array[Resource] = [extra]
    gun_definition.view_facing_policies = alternate_policies
    verify.call(policy.call("get_sectors", ProfileScript.Mode.RETRO_TOPDOWN) == 16,
        "D09-02 third sector count installs through resource config only")
    gun_definition.view_facing_policies = original_policies
    verify.call(policy.call("get_sectors", ProfileScript.Mode.RETRO_TOPDOWN) == 8,
        "D09-02 restoring policy does not leave cached direction")
    var actor_id: int = player.get_instance_id()
    var camera_id: int = views.get_active_camera().get_instance_id()
    for mode in [4, 2, 3, 4]:
        views.switch_view(mode)
    verify.call(player.get_instance_id() == actor_id
        and views.get_active_camera().get_instance_id() == camera_id,
        "D09-02 retro transitions retain one world actor and camera")
    level.queue_free()
    await tree.process_frame
