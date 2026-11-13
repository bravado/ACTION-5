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
    var objective_panel := display.get_node("ObjectivePanel") as PanelContainer
    var hp_bar := display.get("_health_bar") as ProgressBar
    var hp_text := display.get("_hp_text") as Label
    var objective := display.get("_objective") as Label
    var fallback := display.get("_weapon_fallback") as Label
    verify.call(objective.text.contains("east gate")
        and objective.size.x >= 290.0 and objective.size.y >= 30.0,
        "D09-03 objective value has visible space in fixed bottom-left panel")
    verify.call(hp_text.text.contains("100 / 100") and hp_text.size.x >= 80.0,
        "D09-03 numeric HP value is not compressed by the vitality title")
    verify.call(fallback.visible and fallback.size.x >= 30.0,
        "D09-03 unarmed icon fallback reserves a visible square")
    var main_label := display.get("_weapon_title") as Label
    var second_label := display.get("_secondary") as Label
    verify.call(not display.get_node("HelpPanel").visible
        and stage.get_node_or_null("Hud/Status") == null
        and stage.get_node_or_null("Hud/ModeButtons") == null
        and hp_panel.visible and equip_panel.visible,
        "D09-03 one gameplay HUD replaces visible diagnostic wall")
    verify.call((display.get("_ammo_text") as Label).text == "PUNCH · KICK",
        "D09-03 compact unarmed actions omit verbose gamepad control descriptions")
    var input_adapter: Node = stage.get_node("ViewInput")
    var selector := display.get("_view_selector") as HBoxContainer
    var expected_labels := ["1 · FIRST", "2 · BEAT",
        "3 · ISOMETRIC", "4 · SIDE", "5 · TOP-DOWN"]
    var expected_indices := [3, 1, 2, 0, 4]
    verify.call(selector.get_child_count() == 5,
        "D09-03 F6 help exposes exactly five input-mapped view choices")
    for slot in range(5):
        var button := selector.get_child(slot) as Button
        verify.call(button.text == expected_labels[slot]
            and int(input_adapter.call("profile_index_for_shortcut", slot)) ==
                expected_indices[slot],
            "D09-03 selector %d label matches input adapter mapping" % (slot + 1))
    var health_pos: Vector2 = hp_panel.position
    var objective_pos: Vector2 = objective_panel.position
    var equip_pos: Vector2 = equip_panel.position
    verify.call(hp_panel.anchor_left == 0.0 and hp_panel.anchor_top == 0.0
        and hp_panel.anchor_bottom == 0.0
        and objective_panel.anchor_left == 0.0
        and objective_panel.anchor_top == 1.0
        and objective_panel.anchor_bottom == 1.0
        and equip_panel.anchor_right == 1.0 and equip_panel.anchor_bottom == 1.0
        and hp_panel.position.y < objective_panel.position.y
        and objective_panel.position.y + objective_panel.size.y <= display.size.y
        and equip_panel.position.x > objective_panel.position.x + objective_panel.size.x + 80.0,
        "D09-03 vitality sits top-left, objective bottom-left and equipment bottom-right with clear gap")
    for i in range(5):
        views.call("switch_view", i)
        await _frames(tree, 2)
        verify.call(hp_panel.position.is_equal_approx(health_pos)
            and objective_panel.position.is_equal_approx(objective_pos)
            and equip_panel.position.is_equal_approx(equip_pos)
            and display.get("_view").text.begins_with("%d" % ([4, 2, 3, 1, 5][i])),
            "D09-03 view %d uses identical fixed HUD anchors" % (i + 1))
    # Changing Health must not rebuild stable help/InputMap metadata.
    var stable_help: Label = display.get("_help_text") as Label
    var saved_hud_keys: Array = InputMap.action_get_events(&"hud_toggle")
    var saved_help_keys: Array = InputMap.action_get_events(&"hud_help")
    InputMap.action_erase_events(&"hud_toggle")
    InputMap.action_erase_events(&"hud_help")
    var hud_key := InputEventKey.new()
    hud_key.keycode = KEY_J
    var help_key := InputEventKey.new()
    help_key.keycode = KEY_F7
    InputMap.action_add_event(&"hud_toggle", hud_key)
    InputMap.action_add_event(&"hud_help", help_key)
    var before_help: String = stable_help.text
    health.current_health = 74.0
    health.health_changed.emit(74.0, 100.0)
    verify.call(stable_help.text == before_help,
        "D09-03 health signal does not rebuild stable help metadata")
    hud.call("set_help_open", true)
    verify.call((display.get("_help_title") as Label).text.contains("F7")
        and (display.get("_health_footer") as Label).text.contains("J"),
        "D09-03 remapped HUD/help hints follow real InputMap actions")
    hud.call("set_help_open", false)
    InputMap.action_erase_events(&"hud_toggle")
    InputMap.action_erase_events(&"hud_help")
    for event in saved_hud_keys:
        InputMap.action_add_event(&"hud_toggle", event)
    for event in saved_help_keys:
        InputMap.action_add_event(&"hud_help", event)
    hud.call("refresh")
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
    verify.call(equipment.call("get_next_weapon") == gun,
        "D09-03 Equipment is authoritative for the next Q selection")
    verify.call(main_label.text == "Bat" and second_label.text.contains("Pistol")
        and second_label.text.contains("Q"), "D09-03 active Bat shows smaller Pistol/Q cue")
    var swap := InputEventKey.new()
    swap.keycode = KEY_Q
    swap.pressed = true
    stage.call("_unhandled_input", swap)
    verify.call(equipment.call("get_next_weapon") == bat
        and main_label.text == "Pistol" and second_label.text.contains("Bat"),
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
        and not objective_panel.visible,
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
    # Eligibility is shared between Equipment pickup and the preview's port.
    var third := (load("res://demo/equipment/shovel.tscn") as PackedScene).instantiate() as Node3D
    stage.add_child(third)
    third.global_position = player.global_position + Vector3(0.4, 0, 0)
    var third_interaction: Node = third.get_node("PickupInteraction")
    verify.call(not bool(equipment.call("can_pickup", third))
        and not bool(third_interaction.call("can_interact", player)),
        "D09-03 full inventory never advertises an impossible pickup")
    equipment.set("max_items", 3)
    verify.call(bool(equipment.call("can_pickup", third))
        and bool(third_interaction.call("can_interact", player)),
        "D09-03 optional third slot uses the same authoritative pickup preflight")
    verify.call(bool(equipment.call("pickup", third)), "D09-03 third item can be picked")
    verify.call(equipment.call("get_next_weapon") == bat
        and (display.get("_secondary") as Label).text.contains("Bat"),
        "D09-03 next weapon preview matches 3-item swap sequence")
    var fourth := (load("res://demo/equipment/bat.tscn") as PackedScene).instantiate() as Node3D
    stage.add_child(fourth)
    fourth.global_position = player.global_position + Vector3(2.55, 0, 0)
    equipment.set("max_items", 4)
    verify.call(not bool(equipment.call("can_pickup", fourth))
        and not bool(fourth.get_node("PickupInteraction").call("can_interact", player)),
        "D09-03 2.55m interaction range does not misreport 2.5m pickup reach")
    fourth.global_position = player.global_position + Vector3(0.7, 0, 0)
    verify.call(bool(equipment.call("can_pickup", fourth)),
        "D09-03 eligible nearby fourth weapon can be previewed")
    stage.queue_free()
    await _frames(tree, 2)
