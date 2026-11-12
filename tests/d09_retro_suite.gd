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


func _keyboard(key: Key, pressed: bool) -> void:
    var event := InputEventKey.new()
    event.keycode = key
    event.pressed = pressed
    Input.parse_input_event(event)


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
    _keyboard(KEY_UP, true)
    _keyboard(KEY_RIGHT, true)
    var keyboard_aim: Vector2 = actor_input.call("get_aim_axes")
    var keyboard_movement: Vector2 = actor_input.call("get_movement_axes")
    verify.call(keyboard_aim.distance_to(Vector2(1, -1).normalized()) < 0.01
        and keyboard_movement.length_squared() < 0.001,
        "D09-02 actual Up+Right keyboard input aims diagonally without moving")
    _keyboard(KEY_UP, false)
    _keyboard(KEY_RIGHT, false)
    _keyboard(KEY_W, true)
    keyboard_aim = actor_input.call("get_aim_axes")
    keyboard_movement = actor_input.call("get_movement_axes")
    verify.call(keyboard_aim.length_squared() < 0.001 and keyboard_movement.y < -0.99,
        "D09-02 WASD movement does not introduce an aim direction")
    _keyboard(KEY_W, false)
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
    await tree.process_frame
    var retro_hint := level.get_node("Hud/RetroDirection") as Label
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
    await tree.process_frame
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
    var target: Vector3 = aim.call("get_world_target", muzzle.global_position, 40.0, excludes)
    verify.call(Vector2(target.x - muzzle.global_position.x,
        target.z - muzzle.global_position.z).normalized().distance_to(f5_gun) < 0.001,
        "D09-02 physical Gun aim uses the same F5 eight-way policy")
    source.snapshot = ContextScript.new(true, diagonal, Vector2.LEFT,
        ProfileScript.Mode.ISOMETRIC, views.get_active_camera())
    target = aim.call("get_world_target", muzzle.global_position, 40.0, excludes)
    verify.call(Vector2(target.x - muzzle.global_position.x,
        target.z - muzzle.global_position.z).normalized().distance_to(diagonal) < 0.001,
        "D09-02 F3 Gun target remains continuous without changing ammo")
    verify.call(gun.get("magazine") == gun.get("magazine_size"),
        "D09-02 view policy never spends ammunition")
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
