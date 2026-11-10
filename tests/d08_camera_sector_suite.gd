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
        var expected_min := Vector2(
            minf(authored.bounds_min.x, authored.bounds_min.x + shift.x),
            minf(authored.bounds_min.y, authored.bounds_min.y + shift.y)
        )
        var expected_max := Vector2(
            maxf(authored.bounds_max.x, authored.bounds_max.x + shift.x),
            maxf(authored.bounds_max.y, authored.bounds_max.y + shift.y)
        )
        verify.call(profile.bounds_min.distance_to(expected_min) < 0.001
            and profile.bounds_max.distance_to(expected_max) < 0.001,
            "F%d has one continuous arena+dungeon camera rectangle" % (index + 1))

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
            var heading: Vector3 = Vector3(0.0, 4.5, 10.0).normalized()
            verify.call(camera.global_basis.z.distance_to(heading) < 0.001,
                "F2 fixed beat-em-up camera still points consistently")
        elif index == 4:
            verify.call(camera.global_basis.y.distance_to(Vector3.FORWARD) < 0.001
                and camera.global_basis.z.distance_to(Vector3.UP) < 0.001,
                "F5 overhead camera remains world-vertical")
        elif index == 3:
            verify.call(camera.global_basis.z.distance_to(before_heading.z) < 0.001,
                "F4 first-person look never resets at the doorway")

    tree.current_scene = original_scene
    world.queue_free()
    await _frames(tree, 2)
