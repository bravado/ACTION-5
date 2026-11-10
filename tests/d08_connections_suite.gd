extends RefCounted
## D08: actual keyboard input, two-sided opaque doors, acquisition/aggro
## lifecycle and explicitly remote PackedScene travel with one live Player.
## Independent of older test actors by placing the entire fixture at X=1600.

func _ticks(tree: SceneTree, count: int = 4) -> void:
    for i in range(count):
        await tree.physics_frame


func _frames(tree: SceneTree, count: int = 3) -> void:
    for i in range(count):
        await tree.process_frame


func _press_e() -> void:
    var down := InputEventKey.new()
    down.keycode = KEY_E
    down.pressed = true
    Input.parse_input_event(down)
    var up := InputEventKey.new()
    up.keycode = KEY_E
    up.pressed = false
    Input.parse_input_event(up)


func run_tests(tree: SceneTree, verify: Callable) -> void:
    var original: Node = tree.current_scene
    var stage := (load("res://demo/main.tscn") as PackedScene).instantiate() as Node3D
    stage.position = Vector3(1600, 0, 1600)
    tree.root.add_child(stage)
    tree.current_scene = stage
    await _frames(tree, 10)
    var player := stage.get_node("Player") as CharacterBody3D
    var player_id: int = player.get_instance_id()
    var health: Node = player.get_node("Health")
    health.set("max_health", 10000.0)
    health.set("current_health", 10000.0)
    var session: Node = stage.get_node("WorldSession")
    var door: Node3D = stage.get_node("EncounterDoor")
    var panel := door.get_node("BarrierMesh") as MeshInstance3D
    var room := stage.get_node("EncounterSector") as Node3D
    var melee := room.get_node("Melee") as CharacterBody3D
    var sensor: Node = melee.get_node("TargetSensor")
    var ai: Node = melee.get_node("AIController")
    var filter: Node = door.get_node("AcquisitionFilter")
    var interactor: Node = stage.get_node("Interactor")

    player.global_position = door.global_position + Vector3(-1.5, 0.15, 0)
    player.velocity = Vector3.ZERO
    await _ticks(tree, 9)
    verify.call(bool(session.get("_encounter_active")) and not room.visible
        and not bool(door.get("open")) and panel.visible,
        "Closed connected gate preloads room collision but hides opposite room rendering")
    verify.call(sensor.get("_acquisition_gate") == filter
        and not bool(filter.call("allows_acquisition", melee, player))
        and sensor.call("get_target", melee) == null and ai.target == null,
        "Closed gate prevents new enemy aggro even inside detection range")
    verify.call(not door.get_node("NavigationLink3D").enabled,
        "Closed gate disables its cross-room navigation link")

    var no_teleport: Vector3 = player.global_position
    # Dispatch a real key through the viewport, not main._unhandled_input.
    _press_e()
    await _ticks(tree, 5)
    verify.call(bool(door.get("open")) and not panel.visible
        and door.get_node("Body/CollisionShape3D").disabled
        and door.get_node("NavigationLink3D").enabled,
        "Real E key opens the door and applies physical collision and nav changes")
    verify.call(player.global_position.distance_to(no_teleport) < 0.3
        and session.current_sector == &"arena" and room.visible,
        "Door opening reveals the dungeon but never teleports the player")
    verify.call(bool(filter.call("allows_acquisition", melee, player))
        and sensor.call("get_target", melee) == player,
        "Opening the door permits enemy detection across the boundary")
    await _ticks(tree, 5)
    verify.call(ai.target == player,
        "Enemy AI pursues its detected target once the physical gate opens")

    _press_e()
    await _ticks(tree, 5)
    verify.call(not door.open and panel.visible and not room.visible,
        "Closing gate re-occludes room from arena on every camera angle")
    verify.call(sensor.call("get_target", melee) == player
        and ai.target == player
        and not sensor.call("has_line_of_sight", melee, player),
        "Aggro persists after closing, but the solid door blocks attack sight")
    verify.call(not door.get_node("NavigationLink3D").enabled,
        "Closing the gate disables cross-room pathing without forgetting aggro")

    # Opposite-side rendering: on a closed door in the dungeon, no arena
    # meshes/ground items may appear, but all physical colliders stay.
    verify.call(session.travel_to(player, &"encounter"),
        "Scripted test warp enters dungeon with original player")
    await _ticks(tree, 4)
    verify.call(room.visible and not stage.get_node("Floor").visible
        and not stage.get_node("NearDummy").visible
        and stage.get_node("Floor/CollisionShape3D") is CollisionShape3D,
        "Dungeon side sees only dungeon through closed door, without removing arena physics")
    player.global_position = door.global_position + Vector3(1.55, 0.15, 0)
    player.velocity = Vector3.ZERO
    await _ticks(tree, 3)
    _press_e()
    await _ticks(tree, 5)
    verify.call(door.open and stage.get_node("Floor").visible,
        "E works from the dungeon side and re-reveals the adjoining arena")

    # Detached connections are separately scripted portals, NEVER
    # WorldDoor or a scene reload that recreates the Player/Equipment.
    verify.call(session.travel_to(player, &"arena"),
        "Test warp returns actor for detached-location experiment")
    await _ticks(tree, 3)
    var bat_pickup: Node3D = stage.get_node("BatPickup") as Node3D
    player.global_position = bat_pickup.global_position
    stage.call("_unhandled_input", _key_down(KEY_E))
    var equipment: Node = player.get_node("Equipment")
    var inventory_count: int = (equipment.get("inventory") as Array).size()
    verify.call(inventory_count > 0,
        "Actor owns equipment before transitioning to an unrelated PackedScene")

    var portal := stage.get_node("RemotePortal") as Node3D
    var manager: Node = stage.get_node("LocationManager")
    player.global_position = portal.global_position + Vector3(0.7, 0.15, 0)
    player.velocity = Vector3.ZERO
    await _ticks(tree, 3)
    var before_location: Vector3 = player.global_position
    stage.call("_unhandled_input", _key_down(KEY_E))
    await _ticks(tree, 5)
    var detached := manager.get("active_scene") as Node3D
    verify.call(is_instance_valid(detached)
        and detached.scene_file_path == "res://demo/world/remote_chamber.tscn"
        and manager.current_location != &"connected"
        and session.current_sector == &"remote",
        "Different-scene portal loads an independent PackedScene in the same persistent world")
    verify.call(player.get_instance_id() == player_id
        and (equipment.get("inventory") as Array).size() == inventory_count
        and player.global_position.distance_to(before_location) > 30.0,
        "Explicit remote transition moves same player without inventory or combat replacement")
    verify.call(not stage.get_node("Floor").visible and not room.visible
        and not stage.get_node("EncounterDoor").visible,
        "Detached location hides the connected world without removing its physics")
    var remote_id: int = detached.get_instance_id()
    var remote_floor := detached.get_node("Floor") as Node3D
    verify.call(remote_floor.visible
        and stage.get_node("SectorCameraBounds") != null,
        "Detached scene remains visible and keeps same ViewManager")
    var exit := detached.get_node("ReturnPortal") as Node3D
    player.global_position = exit.global_position + Vector3(0.9, 0.15, 0)
    player.velocity = Vector3.ZERO
    await _ticks(tree, 3)
    stage.call("_unhandled_input", _key_down(KEY_E))
    await _ticks(tree, 4)
    verify.call(manager.current_location == &"connected"
        and session.current_sector == &"arena"
        and not detached.visible
        and detached.process_mode == Node.PROCESS_MODE_DISABLED,
        "Marker return portal restores arena and pauses remote environment")
    verify.call(player.get_instance_id() == player_id
        and (equipment.get("inventory") as Array).size() == inventory_count,
        "Return from detached PackedScene preserves exact actor and weapon instances")

    player.global_position = portal.global_position + Vector3(0.7, 0.15, 0)
    await _ticks(tree, 3)
    stage.call("_unhandled_input", _key_down(KEY_E))
    await _ticks(tree, 3)
    verify.call(manager.active_scene.get_instance_id() == remote_id
        and player.get_instance_id() == player_id,
        "Repeated remote visit restores cached environment instead of duplicating scenes")

    tree.current_scene = original
    stage.queue_free()
    await _frames(tree, 3)


func _key_down(code: int) -> InputEventKey:
    var e := InputEventKey.new()
    e.keycode = code
    e.pressed = true
    return e
