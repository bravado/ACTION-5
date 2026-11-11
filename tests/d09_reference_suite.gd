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
    var status := stage.get_node("Hud/Status") as Label
    var help := stage.get_node("Hud/Help") as Label
    var equipment: Node = player.get_node("Equipment")
    var health: Node = player.get_node("Health")
    var session: Node = stage.get_node("WorldSession")
    var exit_node := stage.get_node("EncounterSector/ExitTerminal") as Node3D
    var interactor: Node = stage.get_node("Interactor")
    var overlay: Node = stage.get_node("VictoryOverlay")
    verify.call(status.text.contains("HP") and status.text.contains("Unarmed"),
        "D09 HUD reads real unarmed Health and Equipment state")
    verify.call(help.text.contains("Find the east gate") and help.text.contains("Actions:")
        and help.text.contains("Views:"), "D09 objective, views and help are visible")
    verify.call(not exit_node.call("is_unlocked")
        and not exit_node.call("can_interact", player),
        "D09 exit requires defeat of live encounter enemies")
    var actor_id: int = player.get_instance_id()
    for i in range(5):
        views.switch_view(i)
        hud.call("refresh")
        verify.call(status.text.contains("VIEW %d / 5" % (i + 1))
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
    verify.call(status.text.contains("Heavy Pistol") and status.text.contains("Ammo 3/12")
        and help.text.contains("Weapon Alt Reload") and help.text.contains("T"),
        "D09 alternate gun ammo and configured command appear without HUD branches")
    verify.call(int((gun.call("get_ammo_status") as Dictionary).get("magazine")) == 3,
        "D09 HUD reading ammo does not mutate it")
    health.set("current_health", 71.0)
    health.health_changed.emit(71.0, 100.0)
    verify.call(status.text.contains("HP 71"), "D09 Health signal refreshes HUD")
    verify.call(equipment.call("drop_current"), "D09 normal controller drops equipment")
    await _frames(tree, 2)
    verify.call(status.text.contains("Unarmed"), "D09 ammo fields vanish when unarmed")

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
    player.global_position = exit_node.global_position + Vector3(-1, 0.15, 0)
    player.velocity = Vector3.ZERO
    await _ticks(tree, 4)
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
