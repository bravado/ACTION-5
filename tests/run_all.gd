extends SceneTree
## Self-contained headless test runner. Exit 0 only when all assertions pass.
## Run: godot --headless --path . --script res://tests/run_all.gd
## Expected failing proof: append -- --self-test-failure (must exit nonzero).

var assertions: int = 0
var failures: int = 0


func _initialize() -> void:
    call_deferred("_run_tests")


func _check(condition: bool, description: String) -> void:
    assertions += 1
    if condition:
        print("PASS: ", description)
    else:
        failures += 1
        push_error("FAIL: " + description)


func _run_tests() -> void:
    var version := Engine.get_version_info()
    _check(int(version["major"]) == 4 and int(version["minor"]) == 7 and int(version["patch"]) == 2,
        "Pinned Godot 4.7.2 is running")
    _check(Engine.physics_ticks_per_second == 60, "Physics tick is 60 Hz")
    _check(str(ProjectSettings.get_setting("rendering/renderer/rendering_method")) == "gl_compatibility",
        "Compatibility renderer configured")

    var level_resource := load("res://demo/main.tscn") as PackedScene
    var actor_resource := load("res://demo/player.tscn") as PackedScene
    _check(level_resource != null, "Main scene resource loads")
    _check(actor_resource != null, "Actor scene resource loads")
    if level_resource == null or actor_resource == null:
        _finish()
        return

    var level := level_resource.instantiate()
    root.add_child(level)
    await process_frame

    var player := level.get_node_or_null("Player") as CharacterBody3D
    _check(player != null, "One CharacterBody3D exists in the world")
    _check(level.get_node_or_null("Floor/CollisionShape3D") is CollisionShape3D,
        "Floor includes a physical collision shape")
    _check(level.get_node_or_null("NorthWall/CollisionShape3D") is CollisionShape3D,
        "North wall includes a physical collision shape")
    _check(level.get_node_or_null("SouthWall/CollisionShape3D") is CollisionShape3D,
        "South wall includes a physical collision shape")
    _check(level.get_node_or_null("WestWall/CollisionShape3D") is CollisionShape3D,
        "West wall includes a physical collision shape")
    _check(level.get_node_or_null("EastWall/CollisionShape3D") is CollisionShape3D,
        "East wall includes a physical collision shape")
    _check(level.get_node_or_null("Camera3D") is Camera3D,
        "Diagnostic 3D camera is present")
    _check(level.get_node_or_null("Hud/Help") is Label,
        "D01 help text is visible in the scene")

    if player != null:
        _check(player.get_node_or_null("CollisionShape3D") is CollisionShape3D,
            "Actor has a capsule body collider")
        _check(player.get_node_or_null("Visual/Body") is MeshInstance3D,
            "Actor has a rendered 3D primitive")
        var original_position: Vector3 = player.global_position
        _check(original_position.distance_to(Vector3(0.0, 0.15, 0.0)) < 0.01,
            "Actor begins at documented spawn")

    # Test reusable movement without the demo-level keyboard input adapter.
    var actor := actor_resource.instantiate() as CharacterBody3D
    root.add_child(actor)
    actor.global_position = Vector3(0.0, 2.0, 0.0)
    var start_x: float = actor.global_position.x
    actor.call("set_move_intent", Vector2.RIGHT)
    for i in range(30):
        await physics_frame
    _check(actor.global_position.x > start_x + 0.4,
        "World-plane intent produces actual physics-frame movement")
    _check(actor.velocity.x > 0.0,
        "CharacterBody3D receives positive X velocity")
    actor.call("set_move_intent", Vector2.ZERO)
    for i in range(30):
        await physics_frame
    _check(absf(actor.velocity.x) < 0.05,
        "Zero intent decelerates actor")

    actor.queue_free()
    level.queue_free()

    if OS.get_cmdline_user_args().has("--self-test-failure"):
        _check(false, "Intentional assertion verifies runner exits nonzero")

    _finish()


func _finish() -> void:
    print("ACTION5_TEST_RESULT assertions=", assertions, " failures=", failures)
    quit(1 if failures > 0 else 0)
