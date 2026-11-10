extends RefCounted
## D07: scene-entry policy controls only visited WORLD state. Player equipment
## and HP still persist across doors. Tests real scene loads and actor signals.

func _frames(tree: SceneTree, n: int = 5) -> void:
    for i in range(n):
        await tree.process_frame


func _travel_main(tree: SceneTree, main: Node3D, mode: int = 0) -> void:
    var door := main.get_node("EncounterDoor") as Node3D
    door.set("entry_policy", mode)
    (main.get_node("Player") as Node3D).global_position = door.global_position + Vector3(-0.8, 0.12, 0)
    var key := InputEventKey.new()
    key.keycode = KEY_E
    key.pressed = true
    main.call("_unhandled_input", key)
    await _frames(tree)


func _travel_encounter(tree: SceneTree, stage: Node3D) -> void:
    var door := stage.get_node("ReturnDoor") as Node3D
    (stage.get_node("Player") as Node3D).global_position = door.global_position + Vector3(-0.8, 0.12, 0)
    var key := InputEventKey.new()
    key.keycode = KEY_E
    key.pressed = true
    stage.get_node("InteractionInput").call("_unhandled_input", key)
    await _frames(tree)


func run_tests(tree: SceneTree, verify: Callable) -> void:
    var original_scene: Node = tree.current_scene
    var main := (load("res://demo/main.tscn") as PackedScene).instantiate() as Node3D
    tree.root.add_child(main)
    tree.current_scene = main
    await _frames(tree)
    verify.call(int(main.get_node("EncounterDoor").get("entry_policy")) == 0,
        "Default doorway policy restores prior scene state")
    var initial_player := main.get_node("Player") as Node3D
    var equipment := initial_player.get_node("Equipment")
    var bat := main.get_node("BatPickup") as Node3D
    initial_player.global_position = bat.global_position
    var key := InputEventKey.new()
    key.keycode = KEY_E
    key.pressed = true
    main.call("_unhandled_input", key)
    verify.call(equipment.inventory.size() == 1,
        "Test player picks up a real Bat through the ordinary input adapter")
    var player_health := initial_player.get_node("Health")
    player_health.set("current_health", 61.0)
    var dummy_health := main.get_node("NearDummy/Health")
    dummy_health.take_hit(66.0, initial_player, null, Vector2.RIGHT, 0.0, 0)
    verify.call(dummy_health.current_health == 34.0,
        "A main-scene training dummy is damaged using its existing Health")
    await _travel_main(tree, main)
    var encounter := tree.current_scene as Node3D
    verify.call(is_instance_valid(encounter)
        and encounter.scene_file_path == "res://demo/ai/encounter.tscn",
        "Fresh encounter loads with normal two NPCs")
    if encounter == null or encounter.scene_file_path != "res://demo/ai/encounter.tscn":
        tree.current_scene = original_scene
        return
    await _frames(tree, 4)
    var melee := encounter.get_node("Melee") as CharacterBody3D
    var ranged := encounter.get_node("Ranged") as CharacterBody3D
    var melee_health := melee.get_node("Health")
    var ranged_health := ranged.get_node("Health")
    var ranged_gun := ranged.get_node("Equipment").get("current_weapon") as Node3D
    verify.call(is_instance_valid(ranged_gun)
        and melee_health.current_health > 0 and ranged_health.current_health > 0,
        "Initial NPC state has two living independent enemies and equipped Gun")
    if not is_instance_valid(ranged_gun):
        tree.current_scene = original_scene
        return
    var moved_to: Vector3 = encounter.global_position + Vector3(-8, 0.15, 5.0)
    ranged.global_position = moved_to
    ranged_health.set("current_health", 19.0)
    ranged_gun.set("magazine", 2)
    ranged_gun.set("reserve", 7)
    melee_health.take_hit(1000.0, encounter.get_node("Player"), null, Vector2.RIGHT, 0.0, 0)
    verify.call(melee_health.current_health == 0.0 and not melee.alive
        and melee.get_node("AIController").state == &"dead",
        "Real Health death event disables one NPC before capture")
    await _travel_encounter(tree, encounter)
    var returned := tree.current_scene as Node3D
    verify.call(is_instance_valid(returned)
        and returned.scene_file_path == "res://demo/main.tscn",
        "Return door unloads encounter without keeping a live enemy scene")
    if returned == null or returned.scene_file_path != "res://demo/main.tscn":
        tree.current_scene = original_scene
        return
    verify.call(returned.get_node("Player/Equipment").inventory.size() == 1
        and returned.get_node("Player/Health").current_health == 61.0,
        "Player inventory and HP are independent of persistent NPC state")
    verify.call(returned.get_node("NearDummy/Health").current_health == 34.0
        and returned.get_node("NearDummy/HealthLabel").text == "34 HP",
        "Scene-agnostic Health snapshot restores damaged main-arena training dummy")
    verify.call(returned.get_node("SceneVisitState").capture_state().has(
        "res://demo/ai/encounter.tscn"),
        "Visited-scene history retains compact encounter snapshots while unloaded")
    await _travel_main(tree, returned)
    encounter = tree.current_scene as Node3D
    if encounter == null or encounter.scene_file_path != "res://demo/ai/encounter.tscn":
        verify.call(false, "Revisiting encounter under Restore succeeds")
        tree.current_scene = original_scene
        return
    melee = encounter.get_node("Melee") as CharacterBody3D
    ranged = encounter.get_node("Ranged") as CharacterBody3D
    melee_health = melee.get_node("Health")
    ranged_health = ranged.get_node("Health")
    ranged_gun = ranged.get_node("Equipment").current_weapon as Node3D
    verify.call(melee_health.current_health == 0.0 and not melee.alive
        and melee.get_node("AIController").state == &"dead"
        and melee.get_node("CombatController").current_attack == null,
        "Restore policy keeps defeated enemy dead, without combat authority")
    verify.call(ranged_health.current_health == 19.0 and ranged.alive
        and ranged.global_position.distance_to(moved_to) < 1.5,
        "Restore policy keeps surviving enemy HP and prior world position")
    verify.call(is_instance_valid(ranged_gun)
        and int(ranged_gun.get("magazine")) == 2 and int(ranged_gun.get("reserve")) == 7,
        "Restore policy keeps surviving NPC equipment ammunition")
    verify.call(encounter.get_node("Player/Equipment").inventory.size() == 1
        and encounter.get_node("Player/Health").current_health == 61.0,
        "Restoring NPCs never resets or duplicates the player's inventory")
    # Configurable other behavior: the same doorway can discard the saved
    # encounter snapshot on entry, while player inventory/HP still travel.
    await _travel_encounter(tree, encounter)
    returned = tree.current_scene as Node3D
    if returned == null or returned.scene_file_path != "res://demo/main.tscn":
        verify.call(false, "Return for Start fresh policy succeeds")
        tree.current_scene = original_scene
        return
    await _travel_main(tree, returned, 1)
    encounter = tree.current_scene as Node3D
    if encounter == null or encounter.scene_file_path != "res://demo/ai/encounter.tscn":
        verify.call(false, "Start fresh policy loads destination scene")
        tree.current_scene = original_scene
        return
    melee = encounter.get_node("Melee") as CharacterBody3D
    ranged = encounter.get_node("Ranged") as CharacterBody3D
    melee_health = melee.get_node("Health")
    ranged_health = ranged.get_node("Health")
    ranged_gun = ranged.get_node("Equipment").current_weapon as Node3D
    verify.call(melee.alive and melee_health.current_health == melee_health.max_health
        and ranged.alive and ranged_health.current_health == ranged_health.max_health,
        "Start fresh entry respawns both enemies with full HP")
    verify.call(is_instance_valid(ranged_gun)
        and int(ranged_gun.get("magazine")) == ranged_gun.get("magazine_size")
        and int(ranged_gun.get("reserve")) == ranged_gun.get("starting_reserve"),
        "Start fresh resets the NPC Gun's ammunition")
    verify.call(encounter.get_node("Player/Equipment").inventory.size() == 1
        and encounter.get_node("Player/Health").current_health == 61.0,
        "Start fresh affects the destination WORLD only, not carried player state")
    # A fresh entry becomes the new snapshot. Restart of this session must
    # not resurrect a previously defeated NPC from stale metadata.
    verify.call(not tree.has_meta(&"action5_demo_scene_handoff"),
        "One-shot handoff metadata is always consumed after scene entry")
    # The policy also applies to the MAIN arena, not just to the encounter.
    await _travel_encounter(tree, encounter)
    returned = tree.current_scene as Node3D
    verify.call(returned != null
        and returned.get_node("NearDummy/Health").current_health == 34.0,
        "Visited main-arena dummy still has prior damage after an encounter reset")
    if returned == null:
        tree.current_scene = original_scene
        return
    var return_player := returned.get_node("Player") as Node3D
    return_player.global_position = returned.get_node("EncounterDoor").global_position
    returned.get_node("NearDummy/Health").take_hit(
        100.0, return_player, null, Vector2.RIGHT, 0.0, 0)
    verify.call(returned.get_node("NearDummy/Health").current_health == 0.0,
        "Main-scene prop can remain defeated while transitioning elsewhere")
    await _travel_main(tree, returned)
    encounter = tree.current_scene as Node3D
    if encounter == null or encounter.scene_file_path != "res://demo/ai/encounter.tscn":
        verify.call(false, "Encounter entry before fresh main reset succeeds")
        tree.current_scene = original_scene
        return
    var exit := encounter.get_node("ReturnDoor") as Node3D
    exit.set("entry_policy", 1)
    await _travel_encounter(tree, encounter)
    var restarted_main := tree.current_scene as Node3D
    verify.call(restarted_main != null
        and restarted_main.scene_file_path == "res://demo/main.tscn"
        and restarted_main.get_node("NearDummy/Health").current_health == 100.0
        and restarted_main.get_node("NearDummy/HealthLabel").text == "100 HP",
        "A Start fresh return door resets main-arena props as configured")
    verify.call(restarted_main != null
        and restarted_main.get_node("Player/Equipment").inventory.size() == 1
        and restarted_main.get_node("Player/Health").current_health == 61.0,
        "Fresh main-arena entry still retains player HP and weapon inventory")
    tree.current_scene = original_scene
    if is_instance_valid(restarted_main):
        restarted_main.queue_free()
    await _frames(tree, 3)
