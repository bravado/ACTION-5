extends RefCounted
## D07-01: real CharacterBody3D navigation, AI decisions, equipment and gun
## physical ray authority. No mock hit results or placeholder assertions.

const IntentScript = preload("res://addons/action5/actor/move_intent.gd")


func _ticks(tree: SceneTree, count: int) -> void:
    for i in range(count):
        await tree.physics_frame


func run_tests(tree: SceneTree, verify: Callable) -> void:
    var scene := load("res://demo/ai/encounter.tscn") as PackedScene
    verify.call(scene != null, "D07 physical enemy encounter scene loads")
    if scene == null:
        return
    var arena := scene.instantiate() as Node3D
    arena.position = Vector3(500, 0, 500)
    tree.root.add_child(arena)
    var player := arena.get_node("Player") as CharacterBody3D
    var views := arena.get_node("ViewManager")
    arena.get_node("ActorInput").set_enabled(false)
    var melee := arena.get_node("Melee") as CharacterBody3D
    var ranged := arena.get_node("Ranged") as CharacterBody3D
    var melee_ai := melee.get_node("AIController")
    var ranged_ai := ranged.get_node("AIController")
    var melee_combat := melee.get_node("CombatController")
    var ranged_combat := ranged.get_node("CombatController")
    var melee_equipment := melee.get_node("Equipment")
    var ranged_equipment := ranged.get_node("Equipment")
    var melee_health := melee.get_node("Health")
    var ranged_health := ranged.get_node("Health")
    var player_health := player.get_node("Health")
    # The arena targets a living player over many physics ticks. A high HP
    # allows navigation/combat evidence without depending on player survival.
    player_health.max_health = 10000.0
    player_health.current_health = 10000.0
    await _ticks(tree, 8)
    var bat := melee_equipment.current_weapon as Node3D
    var gun := ranged_equipment.current_weapon as Node3D
    verify.call(is_instance_valid(bat) and is_instance_valid(gun)
        and melee_combat.get_attack(&"bat_swing") != null
        and ranged_combat.get_attack(&"gun_fire") != null,
        "Independent NPC inventories register different configured combat actions")
    if not is_instance_valid(gun) or not is_instance_valid(bat):
        arena.queue_free()
        await tree.process_frame
        return
    verify.call(melee_health.team_id == ranged_health.team_id
        and melee_health != ranged_health
        and melee_combat != ranged_combat and bat.equipment_owner == melee_equipment
        and gun.equipment_owner == ranged_equipment,
        "Two NPCs have separate HP, combat clocks and exclusive weapon instances")
    verify.call(melee_ai.target == player and ranged_ai.target == player,
        "Both NPCs acquire the real living world-space player target")
    var sensor := ranged.get_node("TargetSensor")
    verify.call(not sensor.has_line_of_sight(ranged, player),
        "Opaque central obstacle actually blocks ranged acquisition sight")
    var start_melee: Vector3 = melee.global_position
    var start_ranged: Vector3 = ranged.global_position
    var positions_before_views: Array[Vector3] = [melee.global_position, ranged.global_position]
    for index in [0, 1, 2, 3, 4, 2, 3, 0, 4, 1]:
        views.switch_view(index)
        await _ticks(tree, 2)
    verify.call(melee_ai.target == player and ranged_ai.target == player
        and melee_health.current_health > 0 and ranged_health.current_health > 0
        and melee.global_position != positions_before_views[0]
        and ranged.global_position != positions_before_views[1],
        "F1-F5 camera switches leave both AI actors navigating with persistent HP")
    await _ticks(tree, 190)
    verify.call(melee.global_position.distance_to(start_melee) > 1.5
        and ranged.global_position.distance_to(start_ranged) > 0.5,
        "Both actors chase around the real obstacle with D03 movement physics")
    verify.call(melee_ai.target == player and ranged_ai.target == player
        and melee_health.current_health > 0 and ranged_health.current_health > 0,
        "Camera-free AI and independent health persist during pursuit")
    # Player input is not required for either AI intent producer. The player
    # adapter can be absent/unfocused while NPC movement still runs.
    var previous_position: Vector3 = melee.global_position
    player.set_controls_enabled(false)
    player.global_position = arena.global_position + Vector3(-7, 0.15, -5)
    await _ticks(tree, 55)
    verify.call(melee_ai.target == player and ranged_ai.target == player
        and melee.global_position.distance_to(previous_position) > 0.15,
        "Gating player controls does not stop enemy target decisions or movement")
    player.set_controls_enabled(true)
    var previous_hp: float = ranged_health.current_health
    var attack_before: int = gun.shots_fired
    # The real Gun must use its owning NPC's target provider, not a camera
    # direction or player input adapter.
    verify.call(gun._aim == ranged.get_node("AimTargetProvider")
        and ranged.get_node("AimTargetProvider").target == player,
        "Ranged target provider is local to its NPC, without view dependency")

    # D03 move IDs are arbitrated during physics; two pre-tick intents
    # carry only move IDs, and the final submitted direction wins.
    var move_controller := melee.get_node("Locomotion/MovementController")
    var first := IntentScript.new(Vector2.LEFT)
    first.request_move(&"grounded")
    var last := IntentScript.new(Vector2.RIGHT)
    last.request_move(&"grounded")
    melee_ai.set_physics_process(false)
    melee.apply_move_intent(first)
    melee.apply_move_intent(last)
    await tree.physics_frame
    verify.call(melee.get_node("Locomotion").desired.world_move == Vector2.RIGHT
        and move_controller.get("_pending_requests").is_empty(),
        "Two same-tick AI move intents resolve with the latest world direction")
    melee_ai.set_physics_process(true)
    # D05 requests snapshot a world heading. A second request in the same
    # tick is rejected rather than reversing the first queued attack.
    ranged_ai.set_physics_process(false)
    ranged_combat.cancel()
    var accepted: bool = ranged_combat.request_attack(&"gun_fire", Vector2.RIGHT)
    var rejected: bool = ranged_combat.request_attack(&"gun_fire", Vector2.LEFT)
    await _ticks(tree, 1)
    verify.call(accepted and not rejected and ranged_combat.get("_active_direction") == Vector2.RIGHT,
        "Queued D05 heading is snapshotted; same-tick conflicting attack is rejected")
    ranged_combat.cancel()
    ranged_ai.set_physics_process(true)

    # An NPC's death cancels action authority; the other NPC continues.
    melee_health.take_hit(1000.0, player, null, Vector2.RIGHT, 0.0, 0)
    await _ticks(tree, 2)
    verify.call(melee_ai.state == &"dead" and not melee.alive
        and melee_combat.current_attack == null
        and ranged_health.current_health == previous_hp
        and is_instance_valid(gun),
        "Melee death disables only its actor; ranged equipment remains independent")
    # Dead player targets cannot receive new attacks. Aim target is cleared
    # before the next decision tick, including during gun reload.
    player_health.take_hit(20000.0, ranged, null, Vector2.RIGHT, 0.0, 0)
    await _ticks(tree, 3)
    verify.call(ranged_ai.target == null and ranged_ai.state == &"idle"
        and ranged.get_node("AimTargetProvider").target == null,
        "Target death immediately releases AI decision and world aim ownership")
    player.queue_free()
    await _ticks(tree, 3)
    verify.call(ranged_ai.target == null and ranged_ai.state == &"idle",
        "Freed target cannot leave a stale AI or gun aim reference")
    arena.queue_free()
    await tree.process_frame
