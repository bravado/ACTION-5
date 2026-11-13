extends RefCounted
## D08 authoritative integration: two sectors of ONE live SceneTree with
## ONE player. A door must never replace actor/equipment or lose loose
## weapons. Tests real InputMap key boundaries, world collision and LoS.


func _frames(tree: SceneTree, count: int = 5) -> void:
    for i in range(count):
        await tree.process_frame


func _physics_frames(tree: SceneTree, count: int = 2) -> void:
    for i in range(count):
        await tree.physics_frame


func _key(code: int) -> InputEventKey:
    var key := InputEventKey.new()
    key.keycode = code
    key.pressed = true
    return key


func _press(scene: Node, code: int) -> void:
    scene.call("_unhandled_input", _key(code))


func run_tests(tree: SceneTree, verify: Callable) -> void:
    var original_scene: Node = tree.current_scene
    var stage := (load("res://demo/main.tscn") as PackedScene).instantiate() as Node3D
    # Other suites may retain an actor at the origin. Never let physical
    # rays in this fixture hit colliders from a different live test world.
    stage.position = Vector3(900, 0, 900)
    tree.root.add_child(stage)
    tree.current_scene = stage
    await _frames(tree, 9)
    var player := stage.get_node("Player") as CharacterBody3D
    var equipment := player.get_node("Equipment")
    var world := stage.get_node("WorldSession")
    var encounter := stage.get_node("EncounterSector") as Node3D
    var door := stage.get_node("EncounterDoor") as Node3D
    var arena_door_mesh := door.get_node("DoorMesh") as Node3D
    var barrier_mesh := door.get_node("BarrierMesh") as MeshInstance3D
    verify.call(door.get_node_or_null("DoorLabel") == null
        and door.get_node_or_null("ReturnLabel") == null,
        "Adjacent physical doors have no redundant destination labels")
    var left_handle := door.get_node("Handles/ArenaHandle") as MeshInstance3D
    var right_handle := door.get_node("Handles/DungeonHandle") as MeshInstance3D
    verify.call(left_handle.visible and right_handle.visible
        and (left_handle.global_position - right_handle.global_position).length() > 1.5,
        "One physical gate has distinct near-side visible handles instead of overlapping labels")
    var arena_door_id: int = door.get_instance_id()
    var player_id: int = player.get_instance_id()
    var stage_id: int = stage.get_instance_id()
    var enemy := encounter.get_node("Melee") as CharacterBody3D
    var enemy_id: int = enemy.get_instance_id()
    verify.call(world.current_sector == &"arena"
        and not encounter.get_node("Floor").visible
        and encounter.process_mode == Node.PROCESS_MODE_DISABLED
        and stage.get_node("Interactor") != null,
        "World boots with an inactive CPU-paused encounter and independent Interactor")
    verify.call(not (stage.get_node("DungeonRoofOverlay/Tint") as ColorRect).visible,
        "Full-screen dungeon tint is hidden in the main arena")

    # Default doors remain hide-on-open; only explicitly configured
    # travel portals keep a recognizable visible destination marker.
    var normal_door := Node3D.new()
    normal_door.name = "PlainDoorFixture"
    normal_door.set_script(load("res://demo/interactions/world_door.gd"))
    var normal_mesh := MeshInstance3D.new()
    normal_mesh.name = "DoorMesh"
    normal_door.add_child(normal_mesh)
    normal_door.position = Vector3(1000, 0, 1000)
    stage.add_child(normal_door)
    normal_door.call("set_open", true)
    verify.call(not normal_mesh.visible
        and not bool(normal_door.get("keep_visual_when_open")),
        "Ordinary door panels still hide when opened; persistent marker is opt-in")
    normal_door.call("set_open", false)
    verify.call(normal_mesh.visible,
        "Closing an ordinary door restores its panel visibility")
    normal_door.queue_free()

    # P1: the E fallback must never bypass the generic Interactor's
    # physical ray. A dynamically spawned weapon with an obstructed
    # pickup interaction cannot be collected simply because it is near.
    var blocked_weapon := (
        load("res://demo/equipment/gun_alt.tscn") as PackedScene
    ).instantiate() as Node3D
    blocked_weapon.position = Vector3(-8.3, 0.45, 4.0)
    stage.add_child(blocked_weapon)
    player.global_position = stage.to_global(Vector3(-10.0, 0.15, 4.0))
    var pickup_blocker := StaticBody3D.new()
    pickup_blocker.position = Vector3(-9.1, 1.0, 4.0)
    var blocker_shape := CollisionShape3D.new()
    blocker_shape.shape = BoxShape3D.new()
    (blocker_shape.shape as BoxShape3D).size = Vector3(0.35, 2.3, 2.0)
    pickup_blocker.add_child(blocker_shape)
    stage.add_child(pickup_blocker)
    await _physics_frames(tree, 3)
    _press(stage, KEY_E)
    verify.call(equipment.inventory.is_empty()
        and not bool(stage.get_node("Interactor").call("interact", player,
            blocked_weapon.get_node("PickupInteraction"))),
        "E cannot collect an otherwise visible nearby weapon through a solid wall")
    pickup_blocker.queue_free()
    await _physics_frames(tree, 3)
    _press(stage, KEY_E)
    verify.call(equipment.current_weapon == blocked_weapon
        and equipment.inventory.size() == 1,
        "Removing the wall lets the SAME dynamically spawned weapon be collected by E")
    if equipment.inventory.has(blocked_weapon):
        equipment.call("drop_current")
    blocked_weapon.free()

    player.global_position = stage.get_node("BatPickup").global_position
    _press(stage, KEY_E)
    var bat := equipment.get("current_weapon") as Node3D
    player.global_position = stage.get_node("GunPickup").global_position
    _press(stage, KEY_E)
    verify.call(equipment.inventory.size() == 2
        and is_instance_valid(bat)
        and equipment.inventory[0] == bat
        and equipment.inventory[1].definition.weapon_id == &"gun",
        "Both original arena weapons join the same actor-owned inventory using E")
    _press(stage, KEY_Q)
    var gun := equipment.get("current_weapon") as Node3D
    verify.call(is_instance_valid(gun) and gun.definition.weapon_id == &"gun",
        "Q swaps inventory selection without a weapon-specific core branch")
    _press(stage, KEY_G)
    var dropped_position: Vector3 = gun.global_position
    var loose_id: int = gun.get_instance_id()
    verify.call(equipment.inventory.size() == 1 and equipment.current_weapon == null
        and gun.get_parent() == stage and gun.visible
        and gun.equipment_owner == null,
        "G drops the selected Gun as a real independent world node")

    # The physical entrance is exactly at the shared wall. Pressing E
    # opens the barrier, but MUST NOT teleport the actor or change sector.
    player.global_position = door.global_position + Vector3(-1.5, 0.15, 0)
    await _physics_frames(tree, 2)
    verify.call((door.call("get_interaction_point", player) as Vector3).distance_to(
        left_handle.global_position) < 0.001,
        "Arena-side E interaction point aligns exactly with the visible door handle")
    # Real collision before/after opening, through the center of the
    # shared wall gap. Exclude only the player's own body.
    var exclude: Array[RID] = [player.get_rid()]
    for child in player.find_children("*", "CollisionObject3D", true, false):
        exclude.append((child as CollisionObject3D).get_rid())
    var gate_query := PhysicsRayQueryParameters3D.create(
        door.global_position + Vector3(-1.8, 2.2, 0),
        door.global_position + Vector3(1.8, 2.2, 0),
        1, exclude
    )
    var gate_space := stage.get_world_3d().direct_space_state
    var closed_hit: Dictionary = gate_space.intersect_ray(gate_query)
    verify.call(closed_hit.get("collider") == door.get_node("Body"),
        "Closed gate physically blocks the shared opening, not just its visual panel")
    var before_open: Vector3 = player.global_position
    _press(stage, KEY_E)
    await _physics_frames(tree, 2)
    verify.call(door.open and world.current_sector == &"arena"
        and player.global_position.distance_to(before_open) < 0.20,
        "E opens the shared gate without teleporting or switching sectors")
    verify.call(not barrier_mesh.visible and arena_door_mesh.visible,
        "Opening removes the barrier only; the two-sided physical door frame remains")
    # Godot applies CollisionShape3D.disabled through a deferred
    # physics-server update. Query after the change reaches the space.
    await _physics_frames(tree, 5)
    await _frames(tree, 2)
    var open_hit: Dictionary = gate_space.intersect_ray(gate_query)
    verify.call(open_hit.is_empty(),
        "Opened doorway allows unobstructed physical rays between arena and dungeon")
    # Cross the same doorway in world space with the original player node;
    # WorldSession observes the crossing after normal physics ticks.
    player.global_position = door.global_position + Vector3(1.5, 0.15, 0)
    await _physics_frames(tree, 3)
    await _frames(tree, 2)
    verify.call(tree.current_scene == stage and stage.get_instance_id() == stage_id
        and player.get_instance_id() == player_id and world.current_sector == &"encounter"
        and encounter.get_node("Floor").visible and encounter.process_mode != Node.PROCESS_MODE_DISABLED,
        "Walking across the shared east opening enters the live dungeon without replacing player")
    verify.call(gun.get_instance_id() == loose_id and gun.get_parent() == stage
        and gun.global_position.distance_to(dropped_position) < 0.01
        and gun.equipment_owner == null,
        "A Gun dropped in the arena remains at its exact world position during travel")
    verify.call(door.open and door.get_node("NavigationLink3D").enabled,
        "Opening the portal changes authoritative navigation-link state")
    verify.call(arena_door_mesh.visible and bool(door.get("keep_visual_when_open"))
        and not barrier_mesh.visible,
        "The same two-sided doorway remains visible in the dungeon while its barrier is open")
    await _physics_frames(tree, 2)
    verify.call(door.get_node("Body/CollisionShape3D").disabled,
        "An opened door disables its real physical collision, not just its mesh")

    var enemy_health := enemy.get_node("Health")
    enemy_health.take_hit(1000.0, player, null, Vector2.RIGHT, 0.0, 0)
    verify.call(enemy_health.current_health == 0.0 and not enemy.alive,
        "Actual Health death disables the encountered NPC")

    verify.call(encounter.get_node_or_null("ReturnDoor") == null
        and door.get_instance_id() == arena_door_id
        and door.position.distance_to(Vector3(14, 0, 0)) < 0.01,
        "The same gateway is seen from both areas; no duplicate far-side return door")
    # E works from the opposite physical side, too. The panel closes and
    # opens again while the Player's position stays unchanged.
    verify.call((door.call("get_interaction_point", player) as Vector3).distance_to(
        right_handle.global_position) < 0.001,
        "Dungeon-side E interaction point aligns with the opposite visible handle")
    _press(stage, KEY_E)
    await _physics_frames(tree, 2)
    verify.call(not door.open and barrier_mesh.visible
        and not door.get_node("NavigationLink3D").enabled
        and player.global_position.x >= door.global_position.x + 0.3
        and world.current_sector == &"encounter",
        "E from dungeon side closes the gate without teleporting across the boundary")
    _press(stage, KEY_E)
    await _physics_frames(tree, 2)
    verify.call(door.open and not barrier_mesh.visible
        and door.get_node("NavigationLink3D").enabled,
        "Dungeon-side E reopens the shared passage for walking back")
    player.global_position = door.global_position + Vector3(-1.5, 0.15, 0)
    await _physics_frames(tree, 3)
    await _frames(tree, 2)
    verify.call(world.current_sector == &"arena" and encounter.get_node("Floor").visible
        and tree.current_scene == stage and player.get_instance_id() == player_id,
        "Return detects arena while keeping the dungeon loaded near the real shared doorway")
    player.global_position = stage.to_global(Vector3(5, 0.15, 0))
    await _physics_frames(tree, 3)
    var ranged_alert: bool = (encounter.get_node("Ranged/AIController").get("target") == player)
    verify.call((encounter.process_mode != Node.PROCESS_MODE_DISABLED) == ranged_alert,
        "Beyond preload distance, only an actively alerted enemy keeps its dungeon processing awake")
    verify.call(not (stage.get_node("DungeonRoofOverlay/Tint") as ColorRect).visible,
        "Dungeon tint is removed immediately when returning to the arena")
    verify.call(door.get_instance_id() == arena_door_id
        and arena_door_mesh.visible and door.open,
        "Arena door remains visible and is the SAME interactable after returning")
    verify.call(door.open and arena_door_mesh.visible and not barrier_mesh.visible,
        "Returning to arena preserves the open two-sided portal and its frame")
    verify.call(is_instance_valid(gun) and gun.get_parent() == stage
        and gun.get_instance_id() == loose_id
        and gun.global_position.distance_to(dropped_position) < 0.01,
        "The main-scene dropped Gun remains on the ground after the entire round trip")

    player.global_position = gun.global_position
    _press(stage, KEY_E)
    verify.call(equipment.inventory.size() == 2
        and equipment.current_weapon == gun and gun.equipment_owner == equipment,
        "Returning player can pick up the exact same dropped Gun again")
    await _physics_frames(tree)
    player.global_position = door.global_position + Vector3(1.5, 0.15, 0)
    await _physics_frames(tree, 3)
    await _frames(tree, 2)
    verify.call(stage.get_node("EncounterSector/Melee").get_instance_id() == enemy_id
        and enemy_health.current_health == 0.0 and not enemy.alive,
        "Restore entry preserves the exact dead enemy instance without resurrection")
    verify.call(encounter.get_node("Floor").visible and arena_door_mesh.visible
        and door.get_instance_id() == arena_door_id and not barrier_mesh.visible,
        "Second visit reuses one visible open two-sided doorway; no duplicated portal")
    verify.call(equipment.inventory.size() == 2 and player.get_instance_id() == player_id,
        "Repeated travel never duplicates equipped items or the authoritative player")

    # Q and G have to remain operational while the player's physical position
    # is inside the encounter sector, not only in the main arena.
    _press(stage, KEY_Q)
    var selected := equipment.get("current_weapon") as Node3D
    verify.call(selected == bat and selected != gun,
        "Q switches Bat/Gun while playing inside the live encounter")
    _press(stage, KEY_G)
    var dropped_bat_position: Vector3 = bat.global_position
    verify.call(bat.get_parent() == stage and bat.equipment_owner == null
        and equipment.inventory.size() == 1,
        "G leaves an encounter weapon as a live world item instead of destroying it")
    player.global_position = door.global_position + Vector3(-1.5, 0.15, 0)
    await _physics_frames(tree, 3)
    player.global_position = door.global_position + Vector3(1.5, 0.15, 0)
    await _physics_frames(tree, 3)
    await _frames(tree, 2)
    verify.call(is_instance_valid(bat) and bat.get_parent() == stage
        and bat.equipment_owner == null
        and bat.global_position.distance_to(dropped_bat_position) < 0.01,
        "A weapon dropped in the encounter survives travel away and back")

    # The roof/lighting acceptance block requires an active dungeon.
    # Portal E interaction is separately asserted above; a prior failed
    # portal must not make the independent rendering test a false negative.
    if world.current_sector != &"encounter":
        verify.call(world.travel_to(player, &"encounter"),
            "Roof presentation fixture can directly enter the live dungeon")
        await _frames(tree, 3)
    # A physically elevated translucent mesh projected into only the
    # upper half of side/arcade cameras. The new full-screen CanvasLayer
    # is scene-local, independent of camera transforms, and draws behind
    # HUD but above 3D. The real ceiling remains a physics-only obstacle.
    var roof := encounter.get_node("Roof") as StaticBody3D
    var roof_shape := roof.get_node("CollisionShape3D") as CollisionShape3D
    var roof_layer := stage.get_node("DungeonRoofOverlay") as CanvasLayer
    var tint := roof_layer.get_node("Tint") as ColorRect
    verify.call(roof.get_node_or_null("Mesh") == null
        and not roof_shape.disabled and roof.collision_layer != 0,
        "Dungeon has one physical ceiling and no half-screen 3D canopy geometry")
    verify.call(roof_layer.layer == 0 and tint.mouse_filter == Control.MOUSE_FILTER_IGNORE
        and tint.anchor_left == 0.0 and tint.anchor_top == 0.0
        and tint.anchor_right == 1.0 and tint.anchor_bottom == 1.0
        and tint.color.a > 0.0 and tint.color.a <= 0.2,
        "Dungeon tint fills the viewport behind HUD without intercepting game input")
    var view_manager := stage.get_node("ViewManager")
    var tint_visible_per_view: bool = true
    for view_index in range(5):
        view_manager.switch_view(view_index)
        await _frames(tree, 2)
        var expected_visible: bool = view_index != 3
        tint_visible_per_view = (
            tint_visible_per_view
            and tint.visible == expected_visible
            and not roof_shape.disabled
            and roof.collision_layer != 0
        )
    verify.call(tint_visible_per_view,
        "Uniform dungeon tint covers F1/F2/F3/F5 and clears entirely for first person")
    verify.call(tint.size.distance_to(stage.get_viewport().get_visible_rect().size) < 1.0,
        "Dungeon tint covers full viewport dimensions rather than only the upper screen")
    var dungeon_light_a := encounter.get_node("DungeonFillLight") as OmniLight3D
    var dungeon_light_b := encounter.get_node("DungeonCombatLight") as OmniLight3D
    verify.call(dungeon_light_a != null and dungeon_light_b != null
        and dungeon_light_a.light_energy > 0.0
        and dungeon_light_a.light_energy <= 0.8
        and dungeon_light_b.light_energy > 0.0
        and dungeon_light_b.light_energy <= 0.8
        and not dungeon_light_a.shadow_enabled and not dungeon_light_b.shadow_enabled,
        "Dungeon fill lights remain subdued, without brightening via roof shadow changes")
    verify.call(encounter.scene_file_path == "res://demo/world/encounter_sector.tscn"
        and tree.current_scene == stage,
        "Dungeon is an independently authored PackedScene within one live world, not a scene swap")

    # Player and NPC/script callers share the exact same component contract.
    var interactor := stage.get_node("Interactor")
    var switch := stage.get_node("LightSwitch") as Node3D
    var switch_label := switch.get_node_or_null("Label3D") as Label3D
    var switch_off := switch.get_node_or_null("IndicatorOff") as MeshInstance3D
    var switch_on := switch.get_node_or_null("IndicatorOn") as MeshInstance3D
    verify.call(switch.get_node_or_null("Pedestal") is MeshInstance3D
        and switch.get_node_or_null("Console") is MeshInstance3D
        and switch_label != null and switch_label.visible and switch_label.no_depth_test
        and switch_label.text.contains("[E]")
        and switch_off != null and switch_off.visible
        and switch_on != null and not switch_on.visible,
        "Switch has a persistent visible console, labelled E prompt and OFF beacon")
    var scripted_actor := Node3D.new()
    scripted_actor.name = "ScriptedNPC"
    stage.add_child(scripted_actor)
    scripted_actor.global_position = switch.global_position + Vector3(1.0, 0, 0)
    await _physics_frames(tree)
    verify.call(interactor.interact(scripted_actor, switch)
        and switch.activated and switch.get_node("Light").visible
        and switch_on.visible and not switch_off.visible and switch_label.text.contains("ON"),
        "Switch E interaction lights the room and updates its visible ON beacon")
    await _physics_frames(tree)
    verify.call(interactor.interact(scripted_actor, switch)
        and not switch.activated and not switch.get_node("Light").visible
        and switch_off.visible and not switch_on.visible and switch_label.text.contains("OFF"),
        "Switch E toggles the light off and restores the visible OFF beacon")
    await _physics_frames(tree)
    verify.call(interactor.interact(scripted_actor, switch),
        "Switch can be activated again without rebuilding the visual fixture")
    await _physics_frames(tree)
    scripted_actor.global_position = switch.global_position + Vector3(10, 0, 0)
    verify.call(not interactor.interact(scripted_actor, switch),
        "Out-of-range scripted interaction is denied by the reusable Interactor")
    scripted_actor.global_position = switch.global_position + Vector3(2.0, 0, 0)
    var obstacle := StaticBody3D.new()
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(0.3, 2.5, 1.5)
    shape.shape = box
    obstacle.add_child(shape)
    stage.add_child(obstacle)
    obstacle.global_position = switch.global_position + Vector3(1.0, 1.0, 0)
    await _physics_frames(tree)
    verify.call(not interactor.interact(scripted_actor, switch),
        "Opaque physical obstruction blocks interaction independent of view mode")
    obstacle.queue_free()
    scripted_actor.queue_free()

    verify.call(encounter.has_node("TraversalFixture/LowStep")
        and encounter.has_node("TraversalFixture/GapStart")
        and encounter.has_node("TraversalFixture/GapEnd")
        and encounter.has_node("TraversalFixture/ThinLedge")
        and encounter.has_node("TraversalFixture/Overhang")
        and encounter.has_node("TraversalFixture/SteepFace"),
        "D08 sector includes low step, unsupported elevated gap, ledge, ceiling and steep face")

    # Configurable policy applies only to target sector. Fresh recreates NPCs
    # and removes loose weapons dropped there, but preserves Player/Gun.
    player.global_position = door.global_position + Vector3(-1.5, 0.15, 0)
    await _physics_frames(tree, 3)
    world.set("dungeon_entry_policy", 1)
    player.global_position = door.global_position + Vector3(1.5, 0.15, 0)
    await _physics_frames(tree, 3)
    await _frames(tree, 2)
    encounter = stage.get_node("EncounterSector") as Node3D
    var fresh_enemy := encounter.get_node("Melee") as CharacterBody3D
    verify.call(fresh_enemy.get_instance_id() != enemy_id
        and fresh_enemy.alive
        and fresh_enemy.get_node("Health").current_health > 0.0,
        "Start fresh reinitializes destination NPCs rather than reviving old instances")
    verify.call(not is_instance_valid(bat) and player.get_instance_id() == player_id
        and equipment.inventory.size() == 1 and equipment.inventory.has(gun),
        "Fresh resets only dungeon loose items; original player and inventoried Gun stay alive")
    verify.call(encounter.get_node_or_null("ReturnDoor") == null
        and stage.get_node("EncounterDoor").get_instance_id() == arena_door_id
        and arena_door_mesh.visible,
        "Fresh dungeon state never recreates the shared boundary door")
    world.set("arena_entry_policy", 1)
    player.global_position = door.global_position + Vector3(-1.5, 0.15, 0)
    await _physics_frames(tree, 3)
    await _frames(tree, 2)
    verify.call(stage.has_node("BatPickupWorldState")
        and stage.has_node("GunPickupWorldState")
        and stage.get_node("BatPickupWorldState").capture_state()["available"]
        and stage.get_node("GunPickupWorldState").capture_state()["available"]
        and equipment.inventory.size() == 1,
        "Start fresh arena re-creates original pickups without clearing carried Gun")
    verify.call(world.current_sector == &"arena" and tree.current_scene == stage,
        "Fresh entry updates destination only, keeping one live world and player")

    # P1: the weapon's original world parent can be freed while the
    # weapon is carried. Equipment must still drop it into the active
    # connected world, and the dropped prefab remains interactable.
    world.set("arena_entry_policy", 0)
    world.set("dungeon_entry_policy", 0)
    var dungeon_loot := (
        load("res://demo/equipment/shovel.tscn") as PackedScene
    ).instantiate() as Node3D
    dungeon_loot.position = Vector3(-9, 0.45, 4.5)
    encounter.add_child(dungeon_loot)
    player.global_position = dungeon_loot.global_position
    await _physics_frames(tree, 3)
    _press(stage, KEY_E)
    verify.call(equipment.inventory.has(dungeon_loot)
        and bool(equipment.call("equip", dungeon_loot)),
        "Dungeon-authored pickup uses E and remains owned by the same Equipment")
    player.global_position = stage.to_global(Vector3(-7, 0.15, 3.0))
    await _physics_frames(tree, 3)
    var destroyed_source: Node3D = encounter
    verify.call(bool(world.call("_reset_encounter")) and not is_instance_valid(destroyed_source)
        and equipment.inventory.has(dungeon_loot),
        "Start-fresh replacement frees the original weapon parent but preserves inventory")
    verify.call(bool(equipment.call("drop_current"))
        and dungeon_loot.get_parent() == stage and dungeon_loot.visible
        and dungeon_loot.equipment_owner == null,
        "Equipped weapon with freed original parent drops into the live world")
    player.global_position = dungeon_loot.global_position
    await _physics_frames(tree, 2)
    _press(stage, KEY_E)
    verify.call(equipment.inventory.has(dungeon_loot),
        "Dropped item remains pickable through its prefab-local interaction port")

    # Death UI is optional and independent: only explicitly pressing Restart
    # reloads a *whole session*, unlike ordinary door travel.
    var health := player.get_node("Health")
    health.take_hit(1000.0,
        stage.get_node("EncounterSector/Melee") as CharacterBody3D,
        null, Vector2.RIGHT, 0.0, 0)
    var overlay := stage.get_node("DeathOverlay")
    verify.call(overlay.get_node("Screen").visible,
        "Player death in either sector exposes the existing Restart button")
    overlay.call("restart")
    await _frames(tree, 7)
    var restarted := tree.current_scene as Node3D
    verify.call(is_instance_valid(restarted) and restarted != stage
        and restarted.scene_file_path == "res://demo/main.tscn"
        and restarted.get_node("Player/Health").current_health > 0.0
        and restarted.get_node("Player/Equipment").inventory.is_empty(),
        "Explicit Restart begins a fresh session; doors never implicitly restart it")
    tree.current_scene = original_scene
    if is_instance_valid(restarted):
        restarted.queue_free()
    await _frames(tree, 2)
