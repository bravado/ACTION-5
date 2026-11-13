extends RefCounted
## D09-03 HUD is a scene-local read-only projection, never an equipment owner.

func _frames(tree: SceneTree, count: int = 3) -> void:
    for i in range(count):
        await tree.process_frame


func run_tests(tree: SceneTree, verify: Callable) -> void:
    var packed := load("res://demo/main.tscn") as PackedScene
    verify.call(packed != null, "D09-03 playable scene loads")
    if packed == null:
        return
    var stage := packed.instantiate() as Node3D
    stage.position = Vector3(3900, 0, 3900)
    tree.root.add_child(stage)
    await _frames(tree, 5)
    var player := stage.get_node("Player") as CharacterBody3D
    var equipment: Node = player.get_node("Equipment")
    var views: Node = stage.get_node("ViewManager")
    var hud: Node = stage.get_node("Hud")
    var display := stage.get_node("Hud/Reliquary") as Control
    var health := player.get_node("Health")
    var hp_panel := display.get_node("HealthPanel") as PanelContainer
    var equip_panel := display.get_node("EquipmentPanel") as PanelContainer
    var hp_bar := display.get("_health_bar") as ProgressBar
    var hp_text := display.get("_hp_text") as Label
    var objective := display.get("_objective") as Label
    var fallback := display.get("_weapon_fallback") as Label
    verify.call(objective.text.contains("east gate")
        and objective.size.x >= 290.0 and objective.size.y >= 30.0,
        "D09-03 objective value has visible space in fixed top-left panel")
    verify.call(hp_text.text.contains("100 / 100") and hp_text.size.x >= 80.0,
        "D09-03 numeric HP value is not compressed by the vitality title")
    verify.call(fallback.visible and fallback.size.x >= 30.0,
        "D09-03 unarmed icon fallback reserves a visible square")
    var main_label := display.get("_weapon_title") as Label
    var second_label := display.get("_secondary") as Label
    verify.call(not stage.get_node("Hud/Help").visible
        and not stage.get_node("Hud/Status").visible
        and hp_panel.visible and equip_panel.visible,
        "D09-03 one gameplay HUD replaces visible diagnostic wall")
    verify.call((display.get("_ammo_text") as Label).text == "PUNCH · KICK",
        "D09-03 compact unarmed actions omit verbose gamepad control descriptions")
    var health_pos: Vector2 = hp_panel.position
    var equip_pos: Vector2 = equip_panel.position
    verify.call(hp_panel.anchor_left == 0.0 and equip_panel.anchor_right == 1.0
        and equip_panel.position.x > hp_panel.position.x + hp_panel.size.x + 80.0,
        "D09-03 bottom panels are compact with unobstructed center gap")
    for i in range(5):
        views.call("switch_view", i)
        await _frames(tree, 2)
        verify.call(hp_panel.position.is_equal_approx(health_pos)
            and equip_panel.position.is_equal_approx(equip_pos)
            and display.get("_view").text.begins_with("F%d" % (i + 1)),
            "D09-03 view %d uses identical fixed HUD anchors" % (i + 1))
    health.current_health = 74.0
    health.health_changed.emit(74.0, 100.0)
    verify.call(is_equal_approx(hp_bar.value, 74.0)
        and hp_bar.max_value == 100.0, "D09-03 HP bar projects current/max Health")
    var bat := (load("res://demo/equipment/bat.tscn") as PackedScene).instantiate() as Node3D
    stage.add_child(bat)
    bat.global_position = player.global_position + Vector3(0.4, 0, 0)
    verify.call(equipment.call("pickup", bat), "D09-03 Bat pickup uses normal equipment")
    verify.call(main_label.text == "Bat" and not second_label.visible,
        "D09-03 one equipped item omits disabled swap cue")
    var gun := (load("res://demo/equipment/gun.tscn") as PackedScene).instantiate() as Node3D
    stage.add_child(gun)
    gun.global_position = player.global_position + Vector3(0.45, 0, 0)
    verify.call(equipment.call("pickup", gun), "D09-03 Gun joins existing inventory")
    verify.call(main_label.text == "Bat" and second_label.text.contains("Pistol")
        and second_label.text.contains("Q"), "D09-03 active Bat shows smaller Pistol/Q cue")
    var swap := InputEventKey.new()
    swap.keycode = KEY_Q
    swap.pressed = true
    stage.call("_unhandled_input", swap)
    verify.call(main_label.text == "Pistol" and second_label.text.contains("Bat"),
        "D09-03 Q uses existing swap command and reverses labels")
    var q_bindings: Array = InputMap.action_get_events(&"demo_swap")
    InputMap.action_erase_events(&"demo_swap")
    var custom_key := InputEventKey.new()
    custom_key.keycode = KEY_P
    InputMap.action_add_event(&"demo_swap", custom_key)
    hud.call("refresh")
    verify.call(second_label.text.contains("P") and not second_label.text.contains("Q"),
        "D09-03 secondary weapon hint follows remapped InputMap")
    InputMap.action_erase_events(&"demo_swap")
    for event in q_bindings:
        InputMap.action_add_event(&"demo_swap", event)
    hud.call("refresh")
    verify.call(display.get("_weapon_icon").texture != null,
        "D09-03 weapon image uses optional definition icon")
    views.call("switch_view", 3)
    hud.call("refresh")
    verify.call(display.get_node("AimReticle").visible,
        "D09-03 first-person gun displays contextual centered reticle")
    views.call("switch_view", 1)
    verify.call(not display.get_node("AimReticle").visible,
        "D09-03 aim reticle does not obstruct beat-em-up melee")
    var hide_key := InputEventKey.new()
    hide_key.keycode = KEY_H
    hide_key.pressed = true
    hud.call("_unhandled_input", hide_key)
    verify.call(not hp_panel.visible and not equip_panel.visible
        and not display.get_node("ObjectivePanel").visible,
        "D09-03 H hidden mode removes gameplay chrome")
    for i in range(5):
        views.call("switch_view", i)
        verify.call(not hp_panel.visible and not equip_panel.visible,
            "D09-03 hidden HUD stays hidden on view %d" % (i + 1))
    health.current_health = 42.0
    health.health_changed.emit(42.0, 74.0)
    verify.call(is_equal_approx(hp_bar.value, 42.0),
        "D09-03 hidden HUD still observes authoritative health")
    hud.call("set_help_open", true)
    verify.call(display.get_node("HelpPanel").visible and not hp_panel.visible,
        "D09-03 help remains accessible while gameplay HUD hidden")
    hud.call("set_help_open", false)
    hud.call("_unhandled_input", hide_key)
    verify.call(hp_panel.visible and equip_panel.visible
        and is_equal_approx(hp_bar.value, 42.0),
        "D09-03 HUD returns with latest state")
    # Avoid a separate prompt target selector: use exactly Interactor.get_target.
    var interactor: Node = stage.get_node("Interactor")
    player.global_position = stage.global_position + Vector3(100, 2, 100)
    var switch_instance := Node3D.new()
    switch_instance.set_script(load("res://demo/interactions/world_switch.gd"))
    stage.add_child(switch_instance)
    switch_instance.global_position = player.global_position + Vector3(0.35, 0, 0)
    var door := Node3D.new()
    door.set_script(load("res://demo/interactions/world_door.gd"))
    stage.add_child(door)
    door.global_position = player.global_position + Vector3(1.5, 0, 0)
    verify.call(interactor.call("get_target", player) == switch_instance,
        "D09-03 preview uses same nearest eligible target as interaction")
    hud.call("_refresh_interaction")
    verify.call(display.get("_interaction").text.contains("Turn light on"),
        "D09-03 prompt names the target that E would interact with")
    verify.call(interactor.call("try_interact", player) and switch_instance.activated,
        "D09-03 selected prompt target receives real interaction")
    stage.queue_free()
    await _frames(tree, 2)
