extends RefCounted
## D09-01 real scene and public-port regression: no UI-owned gameplay state.

func _frames(tree: SceneTree, count: int = 3) -> void:
    for i in range(count):
        await tree.process_frame


func _ticks(tree: SceneTree, count: int = 3) -> void:
    for i in range(count):
        await tree.physics_frame


func run_tests(tree: SceneTree, verify: Callable) -> void:
    var previous_scene: Node = tree.current_scene
    var packed := load("res://demo/main.tscn") as PackedScene
    verify.call(packed != null, "D09 reference scene resource loads")
    if packed == null:
        return
    var stage := packed.instantiate() as Node3D
    stage.position = Vector3(2200, 0, 2200)
    tree.root.add_child(stage)
    tree.current_scene = stage
    await _frames(tree, 8)
    var player := stage.get_node("Player") as CharacterBody3D
    var views: Node = stage.get_node("ViewManager")
    var hud: Node = stage.get_node("Hud")
    var display := stage.get_node("Hud/Display") as Control
    var hp_text := display.get("_hp_text") as Label
    var weapon_text := display.get("_weapon_title") as Label
    var ammo_text := display.get("_ammo_text") as Label
    var view_text := display.get("_view") as Label
    var help := display.get("_help_text") as Label
    var equipment: Node = player.get_node("Equipment")
    var health: Node = player.get_node("Health")
    var session: Node = stage.get_node("WorldSession")
    var exit_node := stage.get_node("EncounterSector/ExitTerminal") as Node3D
    var interactor: Node = stage.get_node("Interactor")
    var overlay: Node = stage.get_node("VictoryOverlay")
    verify.call(hp_text.text.contains("100 / 100") and weapon_text.text == "Unarmed",
        "D09 HUD reads real unarmed Health and Equipment state")
    verify.call(help.text.contains("Find the east gate") and help.text.contains("Actions:")
        and help.text.contains("Views:"), "D09 objective, views and help are visible")
    verify.call(not exit_node.call("is_unlocked")
        and not exit_node.call("can_interact", player),
        "D09 exit requires defeat of live encounter enemies")
    var actor_id: int = player.get_instance_id()
    var input_adapter: Node = stage.get_node("ActorInput")
    var key_left := InputEventKey.new()
    key_left.keycode = KEY_LEFT
    var key_right := InputEventKey.new()
    key_right.keycode = KEY_RIGHT
    verify.call(InputMap.event_is_action(key_left, &"actor_turn_left")
        and InputMap.event_is_action(key_right, &"actor_turn_right")
        and not InputMap.event_is_action(key_left, &"move_left")
        and not InputMap.event_is_action(key_right, &"move_right"),
        "D09 arrow turn InputMap actions do not overlap A/D strafe")
    views.switch_view(3)
    await _ticks(tree, 2)
    var rig: Node = views.get("camera_rig")
    var original_yaw: float = rig.get("orbit_yaw")
    var original_position: Vector3 = player.global_position
    Input.action_press(&"actor_turn_right")
    await _ticks(tree, 8)
    Input.action_release(&"actor_turn_right")
    verify.call(float(rig.get("orbit_yaw")) < original_yaw - 0.15
        and player.global_position.distance_to(original_position) < 0.15
        and (input_adapter.call("get_movement_axes") as Vector2).is_zero_approx(),
        "D09 F4 right-arrow turns player/camera without lateral translation")
    verify.call(help.text.contains("Turn:") and help.text.contains("Move left/right:"),
        "D09 HUD explains first-person turning and strafing")
    var yaw_after_turn: float = rig.get("orbit_yaw")
    var movement_before: Vector3 = player.global_position
    Input.action_press(&"move_left")
    await _ticks(tree, 6)
    Input.action_release(&"move_left")
    var strafe_delta: Vector3 = player.global_position - movement_before
    var camera_right: Vector3 = (views.get_active_camera() as Camera3D).global_basis.x
    verify.call(absf(float(rig.get("orbit_yaw")) - yaw_after_turn) < 0.001
        and Vector2(strafe_delta.x, strafe_delta.z).dot(
            Vector2(-camera_right.x, -camera_right.z)) > 0.015,
        "D09 F4 A moves sideways relative to camera without changing yaw")
    # Focus loss and regain with a held arrow never introduces delayed turning.
    Input.action_press(&"actor_turn_left")
    input_adapter._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
    await _ticks(tree, 2)
    input_adapter._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
    await _ticks(tree, 2)
    verify.call(absf(float(rig.get("orbit_yaw")) - yaw_after_turn) < 0.001,
        "D09 focus loss/re-entry blocks held turn input")
    Input.action_release(&"actor_turn_left")
    await _ticks(tree, 2)
    Input.action_press(&"actor_turn_left")
    await _ticks(tree, 2)
    Input.action_release(&"actor_turn_left")
    verify.call(float(rig.get("orbit_yaw")) > yaw_after_turn,
        "D09 new arrow press resumes F4 turn after neutral rearm")
    views.switch_view(1)
    var other_view_yaw: float = rig.get("orbit_yaw")
    Input.action_press(&"actor_turn_right")
    await _ticks(tree, 2)
    verify.call((input_adapter.call("get_movement_axes") as Vector2).x > 0.95
        and absf(float(rig.get("orbit_yaw")) - other_view_yaw) < 0.001,
        "D09 F2 right-arrow still moves right without rotating camera")
    Input.action_release(&"actor_turn_right")
    await _ticks(tree, 2)

    # Per-view input roles are data-defined; no change to Actor or Crouch.
    views.switch_view(0)
    await _ticks(tree, 6)
    var side_controls: Resource = input_adapter.call("get_active_controls") as Resource
    verify.call(not bool(side_controls.get("vertical_movement"))
        and side_controls.get("extra_jump_action") == &"move_up"
        and side_controls.get("held_move_action") == &"move_down",
        "D09 F1 control resource assigns W/Up to jump and S/Down to hold crouch")
    Input.action_press(&"move_up")
    verify.call((input_adapter.call("get_movement_axes") as Vector2).y == 0.0,
        "D09 F1 Up does not move world depth")
    await _ticks(tree, 3)
    verify.call(player.velocity.y > 0.01,
        "D09 F1 W/Up triggers jump through the existing actor intent")
    Input.action_release(&"move_up")
    await _ticks(tree, 85)
    Input.action_press(&"move_down")
    await _ticks(tree, 7)
    var controller: Node = player.get_node("Locomotion/MovementController")
    verify.call(controller.get("active_id") == &"crouch"
        and (input_adapter.call("get_movement_axes") as Vector2).y == 0.0,
        "D09 F1 S/Down holds crouch instead of moving in stage depth")
    Input.action_press(&"move_right")
    await _ticks(tree, 6)
    verify.call(controller.get("active_id") == &"crouch_walk"
        and (input_adapter.call("get_movement_axes") as Vector2).x > 0.9,
        "D09 holding S while pressing D uses crouch-walk at full horizontal input")
    Input.action_release(&"move_down")
    await _ticks(tree, 6)
    verify.call(controller.get("active_id") != &"crouch"
        and controller.get("active_id") != &"crouch_walk",
        "D09 releasing S/Down stands without toggling repeatedly")
    Input.action_release(&"move_right")
    await _ticks(tree, 4)
    views.switch_view(1)
    Input.action_press(&"move_down")
    verify.call((input_adapter.call("get_movement_axes") as Vector2).y > 0.9,
        "D09 F2 S/Down retains standard forward/backward input")
    await _ticks(tree, 3)
    verify.call(controller.get("active_id") != &"crouch"
        and controller.get("active_id") != &"crouch_walk",
        "D09 F2 S does not invoke F1 crouch")
    Input.action_release(&"move_down")
    await _ticks(tree, 2)
    for i in range(5):
        views.switch_view(i)
        hud.call("refresh")
        verify.call(view_text.text.begins_with("%d" % ([4, 2, 3, 1, 5][i]))
            and player.get_instance_id() == actor_id,
            "D09 view %d HUD never replaces the actor" % (i + 1))
    var old_jump: Array = InputMap.action_get_events(&"actor_jump")
    InputMap.action_erase_events(&"actor_jump")
    var jump_key := InputEventKey.new()
    jump_key.keycode = KEY_P
    InputMap.action_add_event(&"actor_jump", jump_key)
    hud.call("refresh")
    verify.call(help.text.contains("Jump: P"), "D09 help follows InputMap rebind")
    InputMap.action_erase_events(&"actor_jump")
    for event in old_jump:
        InputMap.action_add_event(&"actor_jump", event)
    hud.call("refresh")
    verify.call(not help.text.contains("Jump: P"), "D09 help clears stale binding")

    var gun := (load("res://demo/equipment/gun_alt.tscn") as PackedScene).instantiate() as Node3D
    stage.add_child(gun)
    gun.global_position = player.global_position + Vector3(1, 0, 0)
    verify.call(equipment.call("pickup", gun), "D09 alternate gun uses normal pickup")
    await _frames(tree, 2)
    verify.call(weapon_text.text.contains("Heavy Pistol") and ammo_text.text.contains("03 / 12")
        and help.text.contains("Weapon Alt Reload") and help.text.contains("T"),
        "D09 alternate gun ammo and configured command appear without HUD branches")
    verify.call(int((gun.call("get_ammo_status") as Dictionary).get("magazine")) == 3,
        "D09 HUD reading ammo does not mutate it")
    health.set("current_health", 71.0)
    health.health_changed.emit(71.0, 100.0)
    verify.call(hp_text.text.contains("71 / 100"), "D09 Health signal refreshes HUD")
    verify.call(equipment.call("drop_current"), "D09 normal controller drops equipment")
    await _frames(tree, 2)
    verify.call(weapon_text.text == "Unarmed", "D09 ammo fields vanish when unarmed")

    # F1 locks the player to Z=0. The authored arena Gun must be in the
    # same physical pickup row as the Bat/Shovel, not stranded at Z=3.
    views.switch_view(0)
    var arena_gun := stage.get_node("GunPickup") as Node3D
    var arena_bat := stage.get_node("BatPickup") as Node3D
    var arena_shovel := stage.get_node("ShovelPickup") as Node3D
    var lane_z: float = float(stage.get_node("SideLaneController").get("connected_lane_z"))
    verify.call(is_equal_approx(arena_gun.position.z, arena_bat.position.z)
        and is_equal_approx(arena_gun.position.z, arena_shovel.position.z)
        and absf(arena_gun.position.z - lane_z) <= 1.0,
        "D09 F1 Gun stays in the same physically reachable pickup row as Bat/Shovel")
    player.global_position = stage.to_global(Vector3(arena_gun.position.x, 0.15, lane_z))
    player.velocity = Vector3.ZERO
    await _ticks(tree, 5)
    var gun_interaction: Node3D = arena_gun.get_node("PickupInteraction") as Node3D
    verify.call(absf(player.global_position.z - stage.to_global(
        Vector3(0.0, 0.0, lane_z)).z) < 0.08
        and bool(interactor.call("_eligible", player, gun_interaction)),
        "D09 F1 Gun pickup is eligible from the locked side lane with real line of sight")
    var press_e := InputEventKey.new()
    press_e.keycode = KEY_E
    press_e.pressed = true
    stage.call("_unhandled_input", press_e)
    verify.call(equipment.get("current_weapon") == arena_gun,
        "D09 F1 E actually picks up arena Gun without leaving the side-scroller plane")
    verify.call(equipment.call("drop_current"),
        "D09 dropping the F1 Gun still uses the standard equipment lifecycle")

    verify.call(session.call("travel_to", player, &"encounter"),
        "D09 scripted entry retains the shared actor")
    await _ticks(tree, 5)
    var room := stage.get_node("EncounterSector") as Node3D
    exit_node = room.get_node("ExitTerminal") as Node3D
    verify.call(not exit_node.call("is_unlocked"), "D09 real NPCs guard exit on entry")
    for child in room.get_children():
        if child.is_in_group("action5_enemy"):
            var enemy_health: Node = child.get_node_or_null("Health")
            if is_instance_valid(enemy_health):
                enemy_health.current_health = 0.0
                enemy_health.died.emit(player)
    await _ticks(tree, 3)
    verify.call(exit_node.call("is_unlocked"), "D09 defeated NPCs unlock scene exit")

    # Traverse the real 2D X/Y dungeon lane, jumping over the central
    # obstacle rather than teleporting to the EXIT. The world geometry,
    # collision shape, jump speed, gravity and lane controller all participate.
    views.switch_view(0)
    var block := room.get_node("Obstacle") as StaticBody3D
    var block_shape := block.get_node("CollisionShape3D").shape as BoxShape3D
    var block_mesh := block.get_node("Mesh").mesh as BoxMesh
    var block_top: float = block.global_position.y + block_shape.size.y * 0.5
    var takeoff_height: float = player.global_position.y
    verify.call(block_shape.size.is_equal_approx(block_mesh.size)
        and block_top < 1.4 and block_top > 0.8,
        "D09 lowered dungeon block has matching visual and physical geometry")
    player.global_position = room.to_global(Vector3(-3.8, 0.15, 0.0))
    player.velocity = Vector3.ZERO
    await _ticks(tree, 8)
    takeoff_height = player.global_position.y
    verify.call(player.is_on_floor(), "D09 F1 player starts the obstacle jump grounded")
    Input.action_press(&"actor_run")
    Input.action_press(&"move_right")
    Input.action_press(&"move_up")
    await _ticks(tree, 2)
    Input.action_release(&"move_up")
    var peak_height: float = player.global_position.y
    var cleared_block: bool = false
    var stayed_in_lane: bool = true
    for frame in range(160):
        await tree.physics_frame
        peak_height = maxf(peak_height, player.global_position.y)
        var progress: Vector3 = room.to_local(player.global_position)
        stayed_in_lane = stayed_in_lane and absf(progress.z) < 0.12
        if progress.x > block.position.x + block_shape.size.x * 0.5 + 0.4:
            cleared_block = true
        if progress.x >= 8.0:
            break
    Input.action_release(&"move_right")
    Input.action_release(&"actor_run")
    await _ticks(tree, 18)
    var final_progress: Vector3 = room.to_local(player.global_position)
    verify.call(cleared_block and stayed_in_lane
        and peak_height - takeoff_height > block_top + 0.1
        and final_progress.x > 7.0 and final_progress.x < 10.5,
        "D09 real F1 jump clears central block and runs to the EXIT without teleporting")
    verify.call(bool(interactor.call("_eligible", player, exit_node)),
        "D09 EXIT remains in physical reach/line-of-sight on shared F1 lane")
    verify.call(bool(interactor.call("interact", player, exit_node)),
        "D09 exit uses normal physical interaction port")
    verify.call(bool(exit_node.get("complete")) and overlay.get_node("Screen").visible
        and help.text.contains("COMPLETE") and player.get_instance_id() == actor_id,
        "D09 completion screen observes same player and state")
    verify.call(not interactor.call("interact", player, exit_node),
        "D09 completion cannot fire twice")
    stage.queue_free()
    tree.current_scene = previous_scene
    await _frames(tree, 3)
