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
    verify.call(bool(session.get("_encounter_active")) and not room.get_node("Floor").visible
        and not bool(door.get("open")) and panel.visible,
        "Closed connected gate preloads room collision but hides opposite room rendering")
    verify.call(sensor.get("_acquisition_gate") == filter
        and not bool(filter.call("allows_acquisition", melee, player))
        and sensor.call("get_target", melee) == null and ai.target == null,
        "Closed gate prevents new enemy aggro even inside detection range")
    verify.call(not door.get_node("NavigationLink3D").enabled,
        "Closed gate disables its cross-room navigation link")

    var views: Node = stage.get_node("ViewManager")
    var closed_in_every_view: bool = true
    for camera_index in range(5):
        views.switch_view(camera_index)
        await _frames(tree, 2)
        closed_in_every_view = (
            closed_in_every_view
            and not room.get_node("Floor").visible
            and not room.get_node("Obstacle").visible
            and not melee.visible
            and panel.visible
        )
    verify.call(closed_in_every_view,
        "The opaque gate hides dungeon geometry and undiscovered enemies in all five views")
    views.switch_view(1)
    await _frames(tree, 2)

    var no_teleport: Vector3 = player.global_position
    # Dispatch a real key through the viewport, not main._unhandled_input.
    _press_e()
    await _ticks(tree, 5)
    verify.call(bool(door.get("open")) and not panel.visible
        and door.get_node("Body/CollisionShape3D").disabled
        and door.get_node("NavigationLink3D").enabled,
        "Real E key opens the door and applies physical collision and nav changes")
    verify.call(player.global_position.distance_to(no_teleport) < 0.3
        and session.current_sector == &"arena" and room.get_node("Floor").visible,
        "Door opening reveals the dungeon but never teleports the player")
    verify.call(bool(filter.call("allows_acquisition", melee, player))
        and sensor.call("get_target", melee) == player,
        "Opening the door permits enemy detection across the boundary")
    await _ticks(tree, 5)
    verify.call(ai.target == player,
        "Enemy AI pursues its detected target once the physical gate opens")
    # First close while NPCs are still on the OTHER side of the
    # doorway: they must remember the target but LOS/combat and the
    # conditional navigation link must be physically blocked.
    _press_e()
    await _ticks(tree, 5)
    verify.call(not door.open and panel.visible
        and not room.get_node("Floor").visible,
        "Closing before an enemy crosses re-occludes the dungeon")
    verify.call(sensor.call("get_target", melee) == player
        and ai.target == player
        and not sensor.call("has_line_of_sight", melee, player),
        "Already detected target remains acquired, while closed gate blocks attack sight")
    verify.call(not door.get_node("NavigationLink3D").enabled,
        "Closed physical gate disables cross-room navigation without erasing aggro")

    # Reopen, then give the enemy long enough to actually walk across
    # the boundary. A door closing BEHIND an enemy that has crossed
    # must not make that enemy invisible or stop its AI.
    _press_e()
    await _ticks(tree, 5)
    verify.call(door.open and room.get_node("Floor").visible,
        "Reopening the same gate restores dungeon visuals and navigation")
    var chase_start_x: float = melee.global_position.x
    await _ticks(tree, 100)
    verify.call(melee.global_position.x < chase_start_x - 1.0,
        "Alerted enemy physically moves along navigation toward the player through an open gate")
    _press_e()
    await _ticks(tree, 5)
    verify.call(not door.open and panel.visible
        and not room.get_node("Floor").visible
        and not door.get_node("NavigationLink3D").enabled,
        "Door remains operable after pursuit and hides dungeon geometry when closed")
    verify.call(sensor.call("get_target", melee) == player and ai.target == player,
        "Closing after the chase never forgets an already acquired target")
    var crossed_to_arena: bool = melee.global_position.x < door.global_position.x - 0.3
    verify.call(
        (melee.visible and melee.is_visible_in_tree()) if crossed_to_arena
        else not sensor.call("has_line_of_sight", melee, player),
        "A crossed enemy stays visible beside player; a behind-door enemy has no attack sight"
    )

    # Opposite-side rendering: on a closed door in the dungeon, no arena
    # meshes/ground items may appear, but all physical colliders stay.
    verify.call(session.travel_to(player, &"encounter"),
        "Scripted test warp enters dungeon with original player")
    await _ticks(tree, 4)
    verify.call(room.get_node("Floor").visible and not stage.get_node("Floor").visible
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
    var portal_label := portal.get_node("Label3D") as Label3D
    verify.call(portal_label.visible and portal.get("show_label"),
        "Nonadjacent portals may display an optional destination label")
    portal.call("set_label_visible", false)
    verify.call(not portal_label.visible and not portal.get("show_label")
        and portal.has_method("can_interact"),
        "Hiding a remote portal label does not disable its interaction")
    portal.call("set_label_visible", true)
    verify.call(portal_label.visible,
        "Remote portal label can be re-enabled without recreating the scene")
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
    verify.call(not stage.get_node("Floor").visible and not room.get_node("Floor").visible
        and not stage.get_node("EncounterDoor").visible,
        "Detached location hides the connected world without removing its physics")
    var remote_id: int = detached.get_instance_id()
    var remote_floor := detached.get_node("Floor") as Node3D
    verify.call(remote_floor.visible
        and stage.get_node("SectorCameraBounds") != null,
        "Detached scene remains visible and keeps same ViewManager")
    # P1: a weapon picked in the arena must drop in the active remote
    # scene, remain cached there on exit, then be pickable through E.
    var carried := equipment.get("current_weapon") as Node3D
    verify.call(is_instance_valid(carried)
        and bool(equipment.call("drop_current"))
        and carried.get_parent() == detached and carried.visible,
        "Remote weapon drop uses active detached scene, not the arena spawn parent")
    var dropped_in_remote: Vector3 = carried.global_position
    var remote_return: Marker3D = stage.get_node("RemoteReturnSpawn") as Marker3D
    verify.call(manager.call("travel_to_marker", player, remote_return)
        and not detached.visible and carried.get_parent() == detached,
        "Remote dropped item stays cached in its location after player returns to arena")
    verify.call(manager.call("travel_to_scene", player,
        load("res://demo/world/remote_chamber.tscn") as PackedScene,
        NodePath("Arrival"))
        and manager.active_scene == detached
        and carried.get_parent() == detached and carried.visible,
        "Revisiting remote PackedScene restores its exact loose weapon instance")
    player.global_position = dropped_in_remote
    await _ticks(tree, 3)
    stage.call("_unhandled_input", _key_down(KEY_E))
    verify.call(equipment.current_weapon == carried
        and (equipment.get("inventory") as Array).size() == inventory_count,
        "Remote dropped weapon is re-collected using generic physical-LoS E interaction")
    # A newly instantiated *detached* PackedScene uses the same
    # opt-in wall group; no hardcoded list of arena/dungeon wall nodes.
    var remote_south := detached.get_node("SouthWall") as StaticBody3D
    var remote_wall_mesh := remote_south.get_node("Mesh") as MeshInstance3D
    var remote_original := remote_wall_mesh.get_surface_override_material(0)
    player.global_position = detached.to_global(Vector3(0, 0.15, 5.9))
    stage.get_node("OuterWallFader").call("_process", 1.0)
    var remote_faded := remote_wall_mesh.get_surface_override_material(0) as StandardMaterial3D
    verify.call(remote_south.is_in_group("action5_outer_wall")
        and remote_faded != null
        and remote_faded != remote_original
        and remote_faded.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA
        and remote_faded.albedo_color.a < 0.35,
        "Cached remote PackedScene perimeter walls automatically share the player-proximity fade")
    player.global_position = detached.to_global(Vector3(0, 0.15, 0))
    stage.get_node("OuterWallFader").call("_process", 1.0)
    verify.call(remote_wall_mesh.get_surface_override_material(0) == remote_original,
        "Returning to the center restores detached wall's opaque authored material")
    # The same opt-in foreground group is active for cached PackedScenes,
    # without a hard-coded path or cloned side-scroller camera.
    var remote_north := detached.get_node("NorthWall/Mesh") as MeshInstance3D
    views.switch_view(0)
    stage.get_node("OuterWallFader").call("_process", 0.0)
    verify.call(not remote_wall_mesh.visible and remote_north.visible
        and remote_south.collision_layer != 0
        and not (remote_south.get_node("CollisionShape3D") as CollisionShape3D).disabled,
        "F1 hides remote chamber foreground but preserves its rear wall and solid collider")
    player.global_position = detached.to_global(Vector3(0, 0.15, 5.9))
    views.switch_view(1)
    stage.get_node("OuterWallFader").call("_process", 1.0)
    verify.call(remote_wall_mesh.visible
        and remote_wall_mesh.get_surface_override_material(0) != remote_original,
        "F2 resumes remote-room proximity fade when switching from side view")
    views.switch_view(4)
    verify.call(remote_wall_mesh.visible
        and remote_wall_mesh.get_surface_override_material(0) == remote_original,
        "F5 keeps a close remote-room wall opaque after a fade in F2")
    views.switch_view(1)
    player.global_position = detached.to_global(Vector3(0, 0.15, 0))
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
    var cached_floor := detached.get_node("Floor") as StaticBody3D
    var authored_layer: int = 1
    verify.call(cached_floor.collision_layer == 1 and cached_floor.collision_mask == 1
        and cached_floor.disable_mode == CollisionObject3D.DISABLE_MODE_REMOVE
        and not cached_floor.can_process() and not cached_floor.is_visible_in_tree(),
        "Inactive remote scene preserves authored layers but has no physics body")
    var probe := PhysicsRayQueryParameters3D.create(
        detached.to_global(Vector3(3, 3, 0)),
        detached.to_global(Vector3(3, -2, 0)), authored_layer)
    await _ticks(tree, 2)
    verify.call(stage.get_world_3d().direct_space_state.intersect_ray(probe).is_empty(),
        "Cached inactive scene cannot block a physical world-space ray")

    player.global_position = portal.global_position + Vector3(0.7, 0.15, 0)
    await _ticks(tree, 3)
    stage.call("_unhandled_input", _key_down(KEY_E))
    await _ticks(tree, 3)
    verify.call(manager.active_scene.get_instance_id() == remote_id
        and player.get_instance_id() == player_id,
        "Repeated remote visit restores cached environment instead of duplicating scenes")
    await _ticks(tree, 2)
    verify.call(cached_floor.collision_layer == authored_layer
        and stage.get_world_3d().direct_space_state.intersect_ray(probe).get("collider")
            == cached_floor,
        "Re-entering the first cached scene restores authored floor collision")

    # Two independently cached rooms intentionally overlap at the SAME
    # remote origin. Only the currently active scene may own physics.
    var arena_return := stage.get_node("RemoteReturnSpawn") as Marker3D
    verify.call(manager.call("travel_to_marker", player, arena_return),
        "Detached scene can return without a player reload")
    var alternate := load("res://demo/world/remote_chamber_alternate.tscn") as PackedScene
    var cache_count: int = (manager.get("_loaded") as Dictionary).size()
    verify.call(not manager.call("travel_to_scene", player, alternate,
        NodePath("MissingArrival"))
        and (manager.get("_loaded") as Dictionary).size() == cache_count,
        "Broken remote arrival does not add an orphan cached scene")
    verify.call(manager.call("travel_to_scene", player, alternate, NodePath("Arrival")),
        "Second independent PackedScene uses the same portal contract")
    var second := manager.active_scene as Node3D
    var second_floor := second.get_node("Floor") as StaticBody3D
    var remote_pickup := (load("res://demo/equipment/gun.tscn") as PackedScene
        ).instantiate() as Node3D
    remote_pickup.position = Vector3(2, 0.4, 0)
    second.add_child(remote_pickup)
    var remote_nav := NavigationLink3D.new()
    remote_nav.start_position = Vector3(0, 0, 0)
    remote_nav.end_position = Vector3(2, 0, 0)
    second.add_child(remote_nav)
    # Explicitly authored KEEP_ACTIVE must not leave ghost physics when
    # the cached location is later disabled.
    var persistent_body := StaticBody3D.new()
    persistent_body.position = Vector3(3, 1.1, 3)
    persistent_body.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
    var special_shape := CollisionShape3D.new()
    special_shape.shape = BoxShape3D.new()
    persistent_body.add_child(special_shape)
    second.add_child(persistent_body)
    var special_probe := PhysicsRayQueryParameters3D.create(
        second.to_global(Vector3(3, 3, 3)), second.to_global(Vector3(3, 0.8, 3)), 1)
    await _frames(tree, 3)
    await _ticks(tree, 2)
    verify.call(stage.get_world_3d().direct_space_state.intersect_ray(
        special_probe).get("collider") == persistent_body,
        "Non-default KEEP_ACTIVE body collides while its scene is active")
    verify.call(remote_pickup.visible
        and not (stage.get_node("RoomVisibility").get("_ground_weapons") as Dictionary
            ).has(remote_pickup.get_instance_id())
        and remote_nav.enabled,
        "Detached-scene pickup visuals and navigation are not owned by connected-room adapter")
    await _ticks(tree, 2)
    verify.call(second != detached
        and second.global_position.distance_to(detached.global_position) < 0.01
        and cached_floor.collision_layer == authored_layer
        and not cached_floor.can_process() and second_floor.can_process()
        and second_floor.collision_layer == authored_layer
        and stage.get_world_3d().direct_space_state.intersect_ray(probe).get("collider")
            == second_floor,
        "Overlapping inactive room cannot supply ghost physics to active room")
    # P1: two cached PackedScenes overlap. The inactive first room's
    # portal must not compete even if its Label3D and node stay in tree.
    # Give the active portal a DIFFERENT target to catch wrong selection.
    var inactive_return := detached.get_node("ReturnPortal") as Node3D
    var active_return := second.get_node("ReturnPortal") as Node3D
    active_return.set("destination_marker_path", NodePath("../../EncounterSpawn"))
    player.global_position = active_return.global_position + Vector3(0.7, 0.15, 0)
    await _ticks(tree, 3)
    verify.call(not inactive_return.can_process()
        and not bool(inactive_return.call("can_interact", player))
        and not bool(interactor.call("_eligible", player, inactive_return))
        and bool(interactor.call("_eligible", player, active_return)),
        "Paused cached return portal is not eligible even at the same physical position")
    stage.call("_unhandled_input", _key_down(KEY_E))
    await _ticks(tree, 4)
    verify.call(manager.current_location == &"connected"
        and session.current_sector == &"encounter"
        and not active_return.can_process(),
        "E follows only the active portal's distinct destination, never an inactive cached portal")
    await _ticks(tree, 2)
    verify.call(persistent_body.disable_mode == CollisionObject3D.DISABLE_MODE_REMOVE
        and persistent_body.collision_layer == authored_layer
        and not persistent_body.can_process()
        and stage.get_world_3d().direct_space_state.intersect_ray(
            special_probe).is_empty(),
        "Disabling cached scene overrides KEEP_ACTIVE and removes physics without layer mutation")
    verify.call(manager.call("travel_to_marker", player, arena_return)
        and second_floor.collision_layer == authored_layer
        and not second_floor.can_process() and not remote_nav.enabled
        and manager.call("travel_to_scene", player,
            load("res://demo/world/remote_chamber.tscn") as PackedScene,
            NodePath("Arrival")),
        "Both cached scenes independently deactivate and reactivate")
    await _ticks(tree, 2)
    verify.call(manager.active_scene.get_instance_id() == remote_id
        and cached_floor.collision_layer == authored_layer
        and second_floor.collision_layer == authored_layer
        and not second_floor.can_process()
        and player.get_instance_id() == player_id
        and (equipment.get("inventory") as Array).size() == inventory_count,
        "Returning to first room preserves physics and the original inventory")
    verify.call(manager.call("travel_to_marker", player, arena_return)
        and manager.call("travel_to_scene", player, alternate, NodePath("Arrival"))
        and remote_nav.enabled and remote_pickup.visible,
        "Cached second scene restores authored navigation and preserves its loose pickup")
    await _ticks(tree, 2)
    verify.call(stage.get_world_3d().direct_space_state.intersect_ray(
        special_probe).get("collider") == persistent_body,
        "Reactivating cached scene restores physical collision without reconstructing bodies")
    verify.call(manager.call("travel_to_marker", player, arena_return)
        and not remote_nav.enabled,
        "Pausing second scene restores collision and navigation isolation on every visit")

    tree.current_scene = original
    stage.queue_free()
    await _frames(tree, 3)


func _key_down(code: int) -> InputEventKey:
    var e := InputEventKey.new()
    e.keycode = code
    e.pressed = true
    return e
