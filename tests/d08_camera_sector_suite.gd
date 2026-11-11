extends RefCounted
## One physically connected level, one camera/world coordinate system.
## Camera clamps cover the union of the two rooms; crossing the boundary
## never changes their bounds or rotates the actor's input orientation.

const MovementPolicyScript = preload("res://addons/action5/actor/movement_policy.gd")
const INPUTS = [
    Vector2(0, -1), Vector2(-1, 0), Vector2(0, 1), Vector2(1, 0),
]
const PROFILES = [
    "res://addons/action5/views/side.tres",
    "res://addons/action5/views/beatemup.tres",
    "res://addons/action5/views/isometric.tres",
    "res://addons/action5/views/first_person.tres",
    "res://addons/action5/views/retro_topdown.tres",
]


func _frames(tree: SceneTree, count: int = 3) -> void:
    for i in range(count):
        await tree.process_frame


func _physics_frames(tree: SceneTree, count: int = 3) -> void:
    for i in range(count):
        await tree.physics_frame


func _movement(views: Node) -> Array[Vector2]:
    var result: Array[Vector2] = []
    var basis: Basis = views.get_active_camera().global_basis
    var mode: int = views.current_profile.mode
    for axes in INPUTS:
        result.append(MovementPolicyScript.to_world(axes, mode, basis))
    return result


func _same_movement(a: Array[Vector2], b: Array[Vector2], tolerance: float = 0.02) -> bool:
    if a.size() != b.size():
        return false
    for i in range(a.size()):
        if a[i].distance_to(b[i]) > tolerance:
            return false
    return true


func run_tests(tree: SceneTree, verify: Callable) -> void:
    var original_scene: Node = tree.current_scene
    var world := (load("res://demo/main.tscn") as PackedScene).instantiate() as Node3D
    # Keep world-space collision and camera checks away from other suites.
    world.position = Vector3(1200, 0, 1200)
    tree.root.add_child(world)
    tree.current_scene = world
    await _frames(tree, 8)

    var session: Node = world.get_node("WorldSession")
    var views: Node = world.get_node("ViewManager")
    var player: Node3D = world.get_node("Player")
    var dungeon: Node3D = world.get_node("EncounterSector")
    var bounds_adapter: Node = world.get_node("SectorCameraBounds")
    var camera: Camera3D = views.get_active_camera()
    var doorway: Node3D = world.get_node("EncounterDoor")
    var player_id: int = player.get_instance_id()
    var world_id: int = world.get_instance_id()
    var shift := Vector2(
        dungeon.global_position.x - world.global_position.x,
        dungeon.global_position.z - world.global_position.z
    )
    var arena_edge: float = 14.0
    var dungeon_west: float = dungeon.position.x - 12.0
    verify.call(shift.distance_to(Vector2(26, 0)) < 0.01
        and absf(dungeon_west - arena_edge) < 0.001
        and doorway.position.x == arena_edge
        and dungeon.global_basis.x.distance_to(world.global_basis.x) < 0.001
        and dungeon.global_basis.z.distance_to(world.global_basis.z) < 0.001,
        "Dungeon starts exactly at arena east edge: no gap, no rotated axes")
    verify.call(is_instance_valid(bounds_adapter) and views.profiles.size() == 5
        and views.profiles[1] != load("res://addons/action5/views/beatemup.tres"),
        "Connected-world camera bounds use private profile instances")

    for index in range(5):
        var profile: Resource = views.profiles[index]
        var authored: Resource = load(PROFILES[index])
        var level_origin := Vector2(world.global_position.x, world.global_position.z)
        var expected_min := level_origin + Vector2(
            minf(authored.bounds_min.x, authored.bounds_min.x + shift.x),
            minf(authored.bounds_min.y, authored.bounds_min.y + shift.y)
        )
        var expected_max := level_origin + Vector2(
            maxf(authored.bounds_max.x, authored.bounds_max.x + shift.x),
            maxf(authored.bounds_max.y, authored.bounds_max.y + shift.y)
        )
        verify.call(profile.bounds_min.distance_to(expected_min) < 0.001
            and profile.bounds_max.distance_to(expected_max) < 0.001,
            "F%d has one global-space connected bounds rectangle for an offset level" % (index + 1))

        # Position at the arena side of the actual physical doorway.
        player.global_position = world.to_global(Vector3(12.25, 0.15, 0))
        await _physics_frames(tree, 4)
        views.switch_view(index)
        await _frames(tree, 12)
        var before: Array[Vector2] = _movement(views)
        var before_heading: Basis = camera.global_basis
        var frame_before: Vector3 = camera.global_position
        verify.call(session.current_sector == &"arena",
            "F%d starts on the arena side of one physical doorway" % (index + 1))

        # Cross only 3.5 meters in WORLD space; opening the gate never
        # invokes a teleport or reinitializes camera/profile resources.
        player.global_position = world.to_global(Vector3(15.75, 0.15, 0))
        await _physics_frames(tree, 4)
        await _frames(tree, 12)
        verify.call(session.current_sector == &"encounter"
            and world.get_instance_id() == world_id
            and player.get_instance_id() == player_id,
            "F%d detects physical passage with same world and player" % (index + 1))
        verify.call(profile.bounds_min.distance_to(expected_min) < 0.001
            and profile.bounds_max.distance_to(expected_max) < 0.001,
            "F%d entering dungeon does not jump the camera bounds" % (index + 1))
        verify.call(_same_movement(before, _movement(views)),
            "F%d WASD world direction matches arena on dungeon side" % (index + 1))
        verify.call(absf(camera.global_position.x - frame_before.x) < 6.0,
            "F%d camera follows near doorway without a 26m teleport snap" % (index + 1))

        player.global_position = world.to_global(Vector3(12.25, 0.15, 0))
        await _physics_frames(tree, 4)
        await _frames(tree, 12)
        verify.call(session.current_sector == &"arena" and
            profile.bounds_min.distance_to(expected_min) < 0.001
            and profile.bounds_max.distance_to(expected_max) < 0.001,
            "F%d returns via same boundary without reconfiguring camera" % (index + 1))
        verify.call(_same_movement(before, _movement(views))
            and player.get_instance_id() == player_id,
            "F%d return preserves input direction and actor identity" % (index + 1))
        if index == 1:
            # F2's optional lateral peek rotates the CAMERA to reveal
            # X-facing walls, but keeps world-axis WASD unchanged.
            var rig: Node = views.get_node("CameraRig")
            var actor_body := player as CharacterBody3D
            var configured_peek: float = float(profile.lateral_peek_degrees)
            verify.call(configured_peek >= 5.5 and configured_peek <= 6.5,
                "F2 starts with a subtle, profile-configurable 6-degree yaw")
            var original_velocity: Vector3 = actor_body.velocity
            actor_body.velocity = Vector3(4.0, 0.0, 0.0)
            rig.call("_update_camera", 0.5)
            var right_heading_x: float = camera.global_basis.z.x
            var right_input: Array[Vector2] = _movement(views)
            actor_body.velocity = Vector3(-4.0, 0.0, 0.0)
            rig.call("_update_camera", 0.5)
            var left_heading_x: float = camera.global_basis.z.x
            var left_input: Array[Vector2] = _movement(views)
            actor_body.velocity = Vector3.ZERO
            rig.call("_update_camera", 0.5)
            var idle_heading_x: float = camera.global_basis.z.x
            actor_body.velocity = original_velocity
            verify.call(right_heading_x < -0.05 and left_heading_x > 0.05
                and idle_heading_x > 0.05
                and absf(right_heading_x) < 0.14 and left_heading_x < 0.14,
                "F2 gently peeks with movement and retains a small viewing angle at rest")
            verify.call(_same_movement(right_input, left_input)
                and _same_movement(right_input, before),
                "F2 left/right camera peek never rotates arena or dungeon WASD")
            var panel := doorway.get_node("BarrierMesh") as MeshInstance3D
            var body_shape := doorway.get_node("Body/CollisionShape3D") as CollisionShape3D
            verify.call(panel.global_position.distance_to(body_shape.global_position) < 0.001
                and panel.mesh is BoxMesh
                and (panel.mesh as BoxMesh).size.is_equal_approx(
                    (body_shape.shape as BoxShape3D).size),
                "F2 visible door panel occupies the exact authoritative solid collider")
            verify.call(
                not camera.is_position_behind(doorway.global_position + Vector3.UP * 1.2),
                "F2 camera looks toward the physical doorway rather than seeing its edge from behind")

        elif index == 4:
            verify.call(camera.global_basis.y.distance_to(Vector3.FORWARD) < 0.001
                and camera.global_basis.z.distance_to(Vector3.UP) < 0.001,
                "F5 overhead camera remains world-vertical")
        elif index == 3:
            verify.call(camera.global_basis.z.distance_to(before_heading.z) < 0.001,
                "F4 first-person look never resets at the doorway")

    # Per-profile camera rectangles are unioned across arbitrarily rotated
    # connected sectors, not hard-coded arena/dungeon translation.
    var extra := Node3D.new()
    extra.name = "RotatedSectorFixture"
    extra.position = Vector3(50, 0, 40)
    extra.rotation.y = PI * 0.5
    world.add_child(extra)
    var sectors: Array[Node3D] = [world, extra]
    var expanded: Dictionary = bounds_adapter.call("_bounds_for_sectors",
        Vector2(-2, -3), Vector2(4, 5), sectors)
    verify.call(absf(expanded["max"].x - (extra.global_position.x + 5.0)) < 0.01
        and absf(expanded["max"].y - (extra.global_position.z + 2.0)) < 0.01
        and expanded["min"].distance_to(Vector2(
            world.global_position.x - 2.0, world.global_position.z - 3.0)) < 0.01,
        "A rotated third sector can extend connected bounds without core camera changes")
    extra.queue_free()

    # Proximity fade is explicitly limited to exterior perimeter walls.
    # It must work under WebGL2's Compatibility renderer, where generic
    # GeometryInstance3D.transparency is ignored. The material override
    # remains per mesh; collision and the interior props never change.
    var fader: Node = world.get_node("OuterWallFader")
    var south := world.get_node("SouthWall") as StaticBody3D
    var south_visual := south.get_node("MeshInstance3D") as MeshInstance3D
    var original_south: Material = south_visual.get_surface_override_material(0)
    var south_collider := south.get_node("CollisionShape3D") as CollisionShape3D
    var pillar := world.get_node("PillarA/MeshInstance3D") as MeshInstance3D
    var pillar_material: Material = pillar.get_surface_override_material(0)
    var shared_wall := world.get_node("EastWall/Upper/MeshInstance3D") as MeshInstance3D
    var shared_material: Material = shared_wall.get_surface_override_material(0)
    views.switch_view(1)
    player.global_position = world.to_global(Vector3(0, 0.15, 7.6))
    fader.call("_process", 1.0)
    var faded: StandardMaterial3D = south_visual.get_surface_override_material(0)
    verify.call(south.is_in_group("action5_outer_wall")
        and south_visual.visible
        and faded != original_south
        and faded != null
        and faded.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA
        and faded.albedo_color.a < 0.35
        and not south_collider.disabled and south.collision_layer != 0,
        "Close to south/front outer wall uses alpha-blended opacity without disabling collision")
    verify.call(not pillar.get_parent().is_in_group("action5_outer_wall")
        and pillar.get_surface_override_material(0) == pillar_material
        and shared_wall.get_surface_override_material(0) == shared_material,
        "Interior obstacles and shared physical doorway walls never fade")
    player.global_position = world.to_global(Vector3(0, 0.15, 0))
    fader.call("_process", 1.0)
    verify.call(south_visual.get_surface_override_material(0) == original_south,
        "Moving away restores the exact opaque outer-wall material override")
    player.global_position = world.to_global(Vector3(0, 0.15, 7.6))
    views.switch_view(3)
    fader.call("_process", 1.0)
    verify.call(south_visual.get_surface_override_material(0) == original_south,
        "First-person wall remains opaque at point-blank range")
    views.switch_view(1)
    player.global_position = world.to_global(Vector3(26, 0.15, 6.9))
    fader.call("_process", 1.0)
    var dungeon_south := dungeon.get_node("SouthWall") as StaticBody3D
    var dungeon_mesh := dungeon_south.get_node("Mesh") as MeshInstance3D
    var dungeon_mat := dungeon_mesh.get_surface_override_material(0) as StandardMaterial3D
    verify.call(dungeon_south.is_in_group("action5_outer_wall")
        and dungeon_mat != null
        and dungeon_mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA
        and dungeon_mat.albedo_color.a < 0.35
        and not (dungeon_south.get_node("CollisionShape3D") as CollisionShape3D).disabled,
        "Independent dungeon outer wall uses the same camera-only proximity fade")

    # Composition regression: F1 owns only the front mesh hide, the
    # gate owns collision/room switching, and F2 fader owns opacity.
    var room_visibility: Node = world.get_node("RoomVisibility")
    views.switch_view(0)
    doorway.call("set_open", true)
    doorway.call("set_open", false)
    await _frames(tree, 2)
    verify.call(not south_visual.visible and not south_collider.disabled
        and south.collision_layer != 0,
        "F1 front wall stays graphically hidden but physically solid across door toggles")
    views.switch_view(1)
    player.global_position = world.to_global(Vector3(0, 0.15, 7.6))
    fader.call("_process", 1.0)
    verify.call(south_visual.visible and south_visual.get_surface_override_material(0)
        is StandardMaterial3D,
        "F2 re-shows the wall and applies independent proximity opacity")

    # Dynamically spawned pickups must hide, reappear on room crossing,
    # and hand rendering authority back to Equipment when collected.
    player.global_position = world.to_global(Vector3(11, 0.15, 0))
    await _physics_frames(tree, 4)
    var new_weapon := (load("res://demo/equipment/gun.tscn") as PackedScene).instantiate() as Node3D
    new_weapon.position = Vector3(18, 0.4, 0)
    world.add_child(new_weapon)
    await _frames(tree, 4)
    var weapon_id: int = new_weapon.get_instance_id()
    verify.call(not new_weapon.visible
        and (room_visibility.get("_ground_weapons") as Dictionary).has(weapon_id),
        "New pickup behind closed door is immediately registered and hidden")
    new_weapon.position = Vector3(11.5, 0.4, 0)
    await _physics_frames(tree, 4)
    verify.call(new_weapon.visible,
        "Tracked loose pickup becomes visible when physically relocated to arena")
    var equipment: Node = player.get_node("Equipment")
    var picked: bool = bool(equipment.call("pickup", new_weapon))
    verify.call(picked and not (room_visibility.get("_ground_weapons") as Dictionary).has(weapon_id)
        and not (room_visibility.get("_original_visibility") as Dictionary).has(weapon_id),
        "Collecting pickup releases visual ownership to Equipment")
    player.global_position = world.to_global(Vector3(18, 0.15, 0))
    await _physics_frames(tree, 4)
    verify.call(bool(equipment.call("drop_current"))
        and (room_visibility.get("_ground_weapons") as Dictionary).has(weapon_id),
        "Dropping weapon registers it for room-aware visibility immediately")
    player.global_position = world.to_global(Vector3(12.5, 0.15, 0))
    await _physics_frames(tree, 6)
    new_weapon.global_position = world.to_global(Vector3(14.5, 0.4, 0))
    await _physics_frames(tree, 4)
    verify.call(not new_weapon.visible
        and not bool(world.get_node("Interactor").call("interact",
            player, new_weapon.get_node("PickupInteraction"))),
        "Closed-door hidden pickup cannot pass generic Interactor eligibility")

    # Repeated fresh-entry replacement must not leak obsolete visibility or
    # duplicated material cache entries from old sector instances.
    for iteration in range(3):
        var old_dungeon := world.get_node("EncounterSector") as Node3D
        var old_mesh := old_dungeon.get_node("SouthWall/Mesh") as MeshInstance3D
        var old_floor := old_dungeon.get_node("Floor") as Node3D
        var mesh_id: int = old_mesh.get_instance_id()
        var floor_id: int = old_floor.get_instance_id()
        player.global_position = world.to_global(Vector3(26, 0.15, 6.9))
        fader.call("_process", 1.0)
        room_visibility.call("refresh")
        verify.call((fader.get("_materials") as Dictionary).has(mesh_id)
            and (room_visibility.get("_original_visibility") as Dictionary).has(floor_id),
            "Active dungeon visuals have an authored material and visible-state cache")
        player.global_position = world.to_global(Vector3(12, 0.15, 0))
        verify.call(bool(session.call("_reset_encounter")),
            "Fresh dungeon replaces only the sector, not the shared player")
        room_visibility.call("refresh")
        fader.call("_process", 1.0)
        verify.call(not (fader.get("_materials") as Dictionary).has(mesh_id)
            and not (room_visibility.get("_original_visibility") as Dictionary).has(floor_id),
            "Fresh sector prunes its replaced mesh and room-visibility cache entries")
    tree.current_scene = original_scene
    world.queue_free()
    await _frames(tree, 2)
