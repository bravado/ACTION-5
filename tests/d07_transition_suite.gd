extends RefCounted
## Real playable scene transition and Health/UI lifecycle. No fake scene
## router or mock Health; run after the D07 physical enemy suite.

func _frames(tree: SceneTree, count: int = 3) -> void:
    for i in range(count):
        await tree.process_frame


func run_tests(tree: SceneTree, verify: Callable) -> void:
    var original_scene: Node = tree.current_scene
    var main_scene := load("res://demo/main.tscn") as PackedScene
    var main := main_scene.instantiate() as Node3D
    tree.root.add_child(main)
    tree.current_scene = main
    await _frames(tree)
    var player := main.get_node("Player") as CharacterBody3D
    var door := main.get_node("EncounterDoor") as Node3D
    var input := main.get_node("InteractionInput")
    var overlay := main.get_node("DeathOverlay")
    var screen := overlay.get_node("Screen") as Control
    var restart := overlay.get_node("Screen/Center/Panel/Content/RestartButton") as Button

    verify.call(not screen.visible and not door.call("can_interact", player),
        "Main scene starts alive with hidden restart UI and a range-gated encounter door")
    var player_health := player.get_node("Health")
    # Trigger a genuine Health.died -> HealthActorAdapter -> UI observer.
    player_health.take_hit(200.0, door, null, Vector2.RIGHT, 0.0, 0)
    verify.call(screen.visible and not player.alive and restart.visible
        and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
        "Player death shows an interactive Restart button and releases F4 mouse capture")
    player.global_position = door.global_position
    verify.call(not door.call("can_interact", player) and not input.call("try_interact"),
        "A dead player cannot enter the encounter or bypass the death overlay")

    var old_main_id: int = main.get_instance_id()
    restart.pressed.emit()
    await _frames(tree)
    main = tree.current_scene as Node3D
    verify.call(is_instance_valid(main) and main.get_instance_id() != old_main_id
        and main.scene_file_path == "res://demo/main.tscn",
        "Restart button reloads a fresh main scene instead of reviving a stale actor")
    if not is_instance_valid(main) or main.scene_file_path != "res://demo/main.tscn":
        tree.current_scene = original_scene
        return
    player = main.get_node("Player") as CharacterBody3D
    player_health = player.get_node("Health")
    door = main.get_node("EncounterDoor") as Node3D
    input = main.get_node("InteractionInput")
    overlay = main.get_node("DeathOverlay")
    verify.call(player.alive and player_health.current_health == player_health.max_health
        and not (overlay.get_node("Screen") as Control).visible
        and not bool(door.get("transition_pending")),
        "Restart restores full HP and resets the door, UI and player instance")

    # Pick up two real weapon scene instances through the ordinary main E
    # input. A gun's mutable ammo and the selected inventory slot must survive
    # the door even though the old actor and inventory nodes are destroyed.
    var equipment := player.get_node("Equipment")
    var bat := main.get_node("BatPickup") as Node3D
    var gun := main.get_node("GunPickup") as Node3D
    var key := InputEventKey.new()
    key.keycode = KEY_E
    key.pressed = true
    player.global_position = bat.global_position
    main.call("_unhandled_input", key)
    player.global_position = gun.global_position
    main.call("_unhandled_input", key)
    verify.call(equipment.inventory.size() == 2
        and equipment.inventory[0] == bat and equipment.inventory[1] == gun
        and bat.scene_file_path == "res://demo/equipment/bat.tscn"
        and gun.scene_file_path == "res://demo/equipment/gun.tscn",
        "E pickup carries two authored weapon identities, even after reparenting")
    var visited: Dictionary = main.get_node("WorldPickupState").call("capture_state")
    var consumed: Array = visited.get("res://demo/main.tscn", [])
    verify.call(consumed.has("BatPickup") and consumed.has("GunPickup")
        and not consumed.has("ShovelPickup"),
        "Pickup history records the specific authored map locations, not weapon types")
    var swap_key := InputEventKey.new()
    swap_key.keycode = KEY_Q
    swap_key.pressed = true
    main.call("_unhandled_input", swap_key)
    verify.call(equipment.current_weapon == gun
        and player.get_node("CombatController").get_attack(&"gun_fire") != null,
        "Main actor equips the second inventory item via the standard Q binding")
    gun.set("magazine", 3)
    gun.set("reserve", 11)
    gun.set("shots_fired", 4)
    gun.set("hits_landed", 2)
    player_health.set("current_health", 77.0)

    # Test the same configured E-key boundary as actual input, not a direct
    # get_tree().change_scene_to_packed() shortcut.
    player.global_position = door.global_position + Vector3(-0.8, 0.1, 0.0)
    verify.call(door.call("can_interact", player),
        "Player can reach the east-side door in the real physical main scene")
    # A second instanced world may contain a door at the exact same world
    # coordinates. Its group membership must not steal this scene's E.
    var foreign_world := Node3D.new()
    var foreign_door := (load("res://demo/interactions/scene_door.gd") as GDScript).new() as Node3D
    foreign_door.name = "ForeignDoor"
    foreign_door.set("destination_scene", load("res://demo/ai/encounter.tscn"))
    foreign_world.add_child(foreign_door)
    foreign_door.position = door.global_position
    foreign_door.add_to_group("action5_interactable")
    tree.root.add_child(foreign_world)
    verify.call(not foreign_door.call("interact", player),
        "A door belonging to another instanced world cannot change this scene")
    main.call("_unhandled_input", key)
    verify.call(bool(door.get("transition_pending"))
        and not bool(foreign_door.get("transition_pending")),
        "One E press queues this scene's door, not a same-position foreign door")
    main.call("_unhandled_input", key)
    verify.call(bool(door.get("transition_pending")),
        "Repeated E cannot queue a second transition before the scene changes")

    foreign_world.queue_free()
    await _frames(tree, 4)
    var encounter := tree.current_scene as Node3D
    verify.call(is_instance_valid(encounter)
        and encounter.scene_file_path == "res://demo/ai/encounter.tscn",
        "Door loads the authored melee/ranged encounter as the active scene")
    if not is_instance_valid(encounter) or encounter.scene_file_path != "res://demo/ai/encounter.tscn":
        tree.current_scene = original_scene
        return

    var encounter_player := encounter.get_node("Player") as CharacterBody3D
    var encounter_health := encounter_player.get_node("Health")
    var encounter_equipment := encounter_player.get_node("Equipment")
    verify.call(encounter_equipment.inventory.size() == 2
        and encounter_equipment.inventory[0].definition.weapon_id == &"bat"
        and encounter_equipment.inventory[1].definition.weapon_id == &"gun",
        "Door restores both carried weapon scenes into the new actor-owned inventory")
    var carried_gun := encounter_equipment.current_weapon as Node3D
    verify.call(is_instance_valid(carried_gun) and carried_gun == encounter_equipment.inventory[1]
        and int(carried_gun.get("magazine")) == 3 and int(carried_gun.get("reserve")) == 11
        and int(carried_gun.get("shots_fired")) == 4
        and int(carried_gun.get("hits_landed")) == 2
        and encounter_player.get_node("CombatController").get_attack(&"gun_fire") != null,
        "Selected Gun, magazine, reserve, hit history and D05 registration survive scene load")
    verify.call(float(encounter_health.get("current_health")) == 77.0,
        "Door handoff preserves living player HP instead of resetting it to full")
    verify.call(not tree.has_meta(&"action5_demo_scene_handoff"),
        "One-time scene handoff is consumed before gameplay or Restart")

    verify.call(encounter_equipment.swap_next()
        and encounter_equipment.current_weapon == encounter_equipment.inventory[0]
        and encounter_player.get_node("CombatController").get_attack(&"bat_swing") != null
        and encounter_equipment.swap_next()
        and encounter_equipment.current_weapon == carried_gun
        and encounter_player.get_node("CombatController").get_attack(&"gun_fire") != null,
        "Switching the carried Bat/Gun re-registers only the correct weapon actions")

    # The return door provides the same one-shot state handoff in reverse.
    var exit_door := encounter.get_node("ReturnDoor") as Node3D
    encounter_player.global_position = exit_door.global_position + Vector3(-0.7, 0.12, 0)
    var encounter_input := encounter.get_node("InteractionInput")
    encounter_input.call("_unhandled_input", key)
    verify.call(bool(exit_door.get("transition_pending")),
        "Encounter E-key interaction opens the return door")
    await _frames(tree, 4)
    var returned_main := tree.current_scene as Node3D
    verify.call(is_instance_valid(returned_main)
        and returned_main.scene_file_path == "res://demo/main.tscn",
        "Return door loads the main arena again")
    if not is_instance_valid(returned_main) or returned_main.scene_file_path != "res://demo/main.tscn":
        tree.current_scene = original_scene
        return
    var return_player := returned_main.get_node("Player") as CharacterBody3D
    var return_equipment := return_player.get_node("Equipment")
    var return_gun := return_equipment.current_weapon as Node3D
    verify.call(return_equipment.inventory.size() == 2
        and is_instance_valid(return_gun) and return_gun.definition.weapon_id == &"gun"
        and int(return_gun.get("magazine")) == 3 and int(return_gun.get("reserve")) == 11
        and float(return_player.get_node("Health").get("current_health")) == 77.0,
        "Round-trip door traversal preserves inventory, selected gun, ammo and HP")
    verify.call(not returned_main.has_node("BatPickup")
        and not returned_main.has_node("GunPickup")
        and returned_main.has_node("ShovelPickup"),
        "Returning to the arena does not respawn collected Bat/Gun world pickups")
    var returned_history: Dictionary = returned_main.get_node("WorldPickupState").call("capture_state")
    verify.call(returned_history.get("res://demo/main.tscn", []).size() == 2
        and returned_history.get("res://demo/main.tscn", []).has("BatPickup")
        and returned_history.get("res://demo/main.tscn", []).has("GunPickup"),
        "A returned scene retains two consumed pickup locations for the next door")
    var return_door := returned_main.get_node("EncounterDoor") as Node3D
    return_player.global_position = return_door.global_position + Vector3(-0.8, 0.1, 0)
    returned_main.call("_unhandled_input", key)
    await _frames(tree, 4)
    encounter = tree.current_scene as Node3D
    verify.call(is_instance_valid(encounter)
        and encounter.scene_file_path == "res://demo/ai/encounter.tscn",
        "The same equipment can pass through multiple consecutive doors")
    if not is_instance_valid(encounter) or encounter.scene_file_path != "res://demo/ai/encounter.tscn":
        tree.current_scene = original_scene
        return
    encounter_player = encounter.get_node("Player") as CharacterBody3D
    encounter_health = encounter_player.get_node("Health")

    var encounter_overlay := encounter.get_node("DeathOverlay")
    var encounter_screen := encounter_overlay.get_node("Screen") as Control
    var encounter_restart := encounter_overlay.get_node(
        "Screen/Center/Panel/Content/RestartButton") as Button
    verify.call(encounter.has_node("Melee") and encounter.has_node("Ranged")
        and encounter.has_node("CombatInput") and encounter.has_node("ActorInput")
        and not encounter_screen.visible,
        "Encounter loads both NPC types, player combat input and hidden restart UI")
    var encounter_id: int = encounter.get_instance_id()
    encounter_health.take_hit(200.0, encounter.get_node("Melee"),
        null, Vector2.RIGHT, 0.0, 0)
    verify.call(encounter_screen.visible and not encounter_player.alive,
        "Death in the encounter presents the same reusable Restart overlay")
    encounter_restart.pressed.emit()
    await _frames(tree, 4)
    var restarted := tree.current_scene as Node3D
    verify.call(is_instance_valid(restarted)
        and restarted.get_instance_id() != encounter_id
        and restarted.scene_file_path == "res://demo/ai/encounter.tscn"
        and (restarted.get_node("Player/Health").get("current_health") as float) > 0
        and (restarted.get_node("Player/Equipment").get("inventory") as Array).is_empty()
        and not tree.has_meta(&"action5_demo_scene_handoff"),
        "Encounter Restart creates fresh health and inventory, not a replayed door snapshot")
    var fresh_exit := restarted.get_node("ReturnDoor") as Node3D
    var fresh_player := restarted.get_node("Player") as Node3D
    fresh_player.global_position = fresh_exit.global_position + Vector3(-0.8, 0.12, 0)
    restarted.get_node("InteractionInput").call("_unhandled_input", key)
    await _frames(tree, 4)
    var restarted_main := tree.current_scene as Node3D
    verify.call(is_instance_valid(restarted_main)
        and restarted_main.scene_file_path == "res://demo/main.tscn"
        and restarted_main.has_node("BatPickup") and restarted_main.has_node("GunPickup")
        and restarted_main.has_node("ShovelPickup"),
        "Death/Restart resets session pickup history; a new visit starts with full map loot")
    restarted = restarted_main
    tree.current_scene = original_scene
    if is_instance_valid(restarted):
        restarted.queue_free()
    await _frames(tree, 2)
