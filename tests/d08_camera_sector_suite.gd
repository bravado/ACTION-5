extends RefCounted
## D08 regression: the persistent world uses one global orientation.
## Dungeon content is offset +X but its camera clamp follows that offset;
## movement mapping and camera heading must not change at a doorway.

const MovementPolicyScript = preload("res://addons/action5/actor/movement_policy.gd")

const INPUTS = [
    Vector2(0, -1),  # W
    Vector2(-1, 0),  # A
    Vector2(0, 1),   # S
    Vector2(1, 0),   # D
]


func _frames(tree: SceneTree, count: int = 2) -> void:
    for i in range(count):
        await tree.process_frame


func _movement(views: Node) -> Array[Vector2]:
    var result: Array[Vector2] = []
    var basis: Basis = views.get_active_camera().global_basis
    var mode: int = views.current_profile.mode
    for axes in INPUTS:
        result.append(MovementPolicyScript.to_world(axes, mode, basis))
    return result


func _same_movement(a: Array[Vector2], b: Array[Vector2]) -> bool:
    if a.size() != b.size():
        return false
    for i in range(a.size()):
        if a[i].distance_to(b[i]) > 0.001:
            return false
    return true


func run_tests(tree: SceneTree, verify: Callable) -> void:
    var original_scene: Node = tree.current_scene
    var world := (load("res://demo/main.tscn") as PackedScene).instantiate() as Node3D
    tree.root.add_child(world)
    tree.current_scene = world
    await _frames(tree, 8)

    var session: Node = world.get_node("WorldSession")
    var views: Node = world.get_node("ViewManager")
    var player: Node3D = world.get_node("Player")
    var dungeon: Node3D = world.get_node("EncounterSector")
    var bound_port: Node = world.get_node("SectorCameraBounds")
    var camera: Camera3D = views.get_active_camera()
    var player_id: int = player.get_instance_id()
    var world_id: int = world.get_instance_id()
    var shift := Vector2(
        dungeon.global_position.x - world.global_position.x,
        dungeon.global_position.z - world.global_position.z
    )
    verify.call(shift.distance_to(Vector2(36, 0)) < 0.01
        and dungeon.global_basis.x.distance_to(world.global_basis.x) < 0.001
        and dungeon.global_basis.z.distance_to(world.global_basis.z) < 0.001,
        "Arena and separately authored dungeon share global X/Z axes without rotation")
    verify.call(is_instance_valid(bound_port)
        and views.profiles.size() == 5
        and views.profiles[1] != load("res://addons/action5/views/beatemup.tres"),
        "Sector-specific camera bounds use private profile instances, not shared .tres assets")

    for index in range(5):
        views.switch_view(index)
        await _frames(tree)
        var profile: Resource = views.current_profile
        var initial_bounds_min: Vector2 = profile.bounds_min
        var initial_bounds_max: Vector2 = profile.bounds_max
        var initial_view: int = views.active_index
        var before: Array[Vector2] = _movement(views)
        var initial_camera_heading: Basis = camera.global_basis
        var initial_player_id: int = player.get_instance_id()
        verify.call(session.travel_to(player, &"encounter"),
            "F%d enters dungeon without scene swap" % (index + 1))
        await _frames(tree, 2)
        var in_dungeon: Array[Vector2] = _movement(views)
        var expected_min: Vector2 = initial_bounds_min + shift
        var expected_max: Vector2 = initial_bounds_max + shift
        var offsets_correct: bool = profile.bounds_min.distance_to(expected_min) < 0.001             and profile.bounds_max.distance_to(expected_max) < 0.001
        verify.call(offsets_correct and views.active_index == initial_view
            and player.get_instance_id() == initial_player_id
            and world.get_instance_id() == world_id and tree.current_scene == world,
            "F%d dungeon preserves view and player identity while offsetting camera bounds" % (index + 1))
        verify.call(_same_movement(before, in_dungeon),
            "F%d WASD maps to the same world vectors in arena and dungeon" % (index + 1))
        if profile.bound_camera_target:
            verify.call(absf(camera.global_position.x - player.global_position.x) < 0.15,
                "F%d camera follows dungeon player rather than clamping to arena X" % (index + 1))
        verify.call(session.travel_to(player, &"arena"),
            "F%d returns to arena without scene swap" % (index + 1))
        await _frames(tree, 2)
        verify.call(profile.bounds_min.distance_to(initial_bounds_min) < 0.001
            and profile.bounds_max.distance_to(initial_bounds_max) < 0.001
            and _same_movement(before, _movement(views))
            and player.get_instance_id() == player_id,
            "F%d return restores arena framing and original WASD orientation" % (index + 1))
        # A room transition is never allowed to rotate the camera basis.
        verify.call(camera.global_basis.x.distance_to(initial_camera_heading.x) < 0.001
            and camera.global_basis.z.distance_to(initial_camera_heading.z) < 0.001,
            "F%d return leaves camera yaw and pitch unchanged" % (index + 1))
        if index == 1:
            var arcade_heading: Vector3 = Vector3(0.0, 4.5, 10.0).normalized()
            verify.call(camera.global_basis.z.distance_to(arcade_heading) < 0.001,
                "F2 beat-em-up camera maintains its authored fixed pitch at a room boundary")
        elif index == 4:
            verify.call(camera.global_basis.y.distance_to(Vector3.FORWARD) < 0.001
                and camera.global_basis.z.distance_to(Vector3.UP) < 0.001,
                "F5 retro camera remains world-vertical and screen-up stays global -Z")

    tree.current_scene = original_scene
    world.queue_free()
    await _frames(tree, 2)
