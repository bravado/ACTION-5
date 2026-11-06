extends SceneTree

const ViewManagerScript = preload("res://addons/action5/camera/view_manager.gd")
const ViewInputScript = preload("res://addons/action5/camera/view_input.gd")
const ViewProfileScript = preload("res://addons/action5/camera/view_profile.gd")
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
    _check(level.get_node_or_null("ViewManager/CameraRig/Camera3D") is Camera3D,
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

    # D02: all six camera profiles must share the exact same world/actor.
    var manager := level.get_node_or_null("ViewManager") as ViewManagerScript
    var input_adapter := level.get_node_or_null("ViewInput") as ViewInputScript
    _check(manager != null and input_adapter != null, "View manager and input adapter present")
    if manager != null and player != null:
        _check(manager.profiles.size() == 6, "Exactly six editable camera profiles")
        _check(manager.active_index == 1, "Initial beat'em-up camera is selected")
        _check(manager.camera_rig.camera == level.get_node("ViewManager/CameraRig/Camera3D"),
            "One persistent Camera3D is shared across all modes")
        var player_id: int = player.get_instance_id()
        var camera_id: int = manager.get_active_camera().get_instance_id()
        var original_transform: Transform3D = player.global_transform
        var original_velocity: Vector3 = player.velocity
        var next_index := 0
        for repeat_index in range(20):
            for index in range(6):
                next_index = index
                _check(manager.switch_view(index), "Switch camera to %d, cycle %d" % [index + 1, repeat_index + 1])
        _check(manager.switch_count >= 120, "All six profiles cycled 20 times")
        _check(player.get_instance_id() == player_id and manager.get_active_camera().get_instance_id() == camera_id,
            "Camera/actor identities preserved for 120 switches")
        _check(player.global_transform == original_transform and player.velocity == original_velocity,
            "Camera switching never changes actor transform or velocity")
        _check(manager.last_position_delta < 0.0001,
            "Camera switching preserves actor position exactly")
        _check(manager.active_index == next_index, "Selected camera index tracks last switch")

        manager.switch_view(2)
        _check(manager.current_profile.mode == ViewProfileScript.Mode.ISOMETRIC,
            "F3 loads tilted isometric camera resource")
        _check(manager.get_active_camera().projection == Camera3D.PROJECTION_ORTHOGONAL,
            "F3 uses orthographic projection")
        manager.switch_view(5)
        _check(manager.current_profile.mode == ViewProfileScript.Mode.RETRO_TOPDOWN,
            "F6 loads distinct retro top-down camera resource")
        _check(manager.camera_rig.is_vertical_overhead(),
            "F6 camera orientation is exactly vertical")
        _check(manager.get_active_camera().projection == Camera3D.PROJECTION_ORTHOGONAL,
            "F6 uses orthographic projection")
        _check(manager.current_profile.orthographic_size < manager.profiles[2].orthographic_size,
            "F6 has independently editable zoom")
        manager.switch_view(4)
        _check(manager.get_active_camera().projection == Camera3D.PROJECTION_PERSPECTIVE,
            "F5 uses perspective projection")
        _check(not player.get_node("Visual").visible,
            "First-person mode hides local player model only")
        manager.switch_view(3)
        _check(player.get_node("Visual").visible, "F4 restores local player model")

        var gui_button := level.get_node("Hud/ModeButtons/Mode1") as Button
        gui_button.pressed.emit()
        _check(manager.active_index == 0, "In-game view selector switches to F1")
        _check((level.get_node("Hud/Status") as Label).text.contains("VIEW 1 / 6"),
            "HUD displays active view and switch instrumentation")

        if input_adapter != null:
            var key_one := InputEventKey.new()
            key_one.keycode = KEY_1
            key_one.pressed = true
            _check(InputMap.event_is_action(key_one, &"view_1"),
                "Primary number key 1 is registered in InputMap")
            var key_six := InputEventKey.new()
            key_six.keycode = KEY_6
            key_six.pressed = true
            _check(InputMap.event_is_action(key_six, &"view_6"),
                "Primary number key 6 is registered in InputMap")
            input_adapter._unhandled_input(key_six)
            _check(manager.active_index == 5, "Pressing 6 activates retro top-down")
            input_adapter._unhandled_input(key_one)
            _check(manager.active_index == 0, "Pressing 1 activates side camera")
            _check(manager.cycle_view(-1) and manager.active_index == 5,
                "View cycling wraps from F1 to F6")
            _check(manager.cycle_view(1) and manager.active_index == 0,
                "View cycling wraps from F6 to F1")

    # D02 regression: camera bounds/collision and overhead screen axes.
    if manager != null and player != null:
        var saved_transform: Transform3D = player.global_transform
        manager.switch_view(5)
        var world_up: Vector2 = level.call("_map_demo_movement", Vector2(0.0, -1.0))
        var world_right: Vector2 = level.call("_map_demo_movement", Vector2(1.0, 0.0))
        _check(world_up.is_finite() and world_up.length() > 0.95,
            "F6 screen-up maps to nonzero finite world-plane movement")
        _check(world_up.y < -0.95 and absf(world_up.x) < 0.05,
            "F6 screen-up maps to world minus Z")
        _check(world_right.x > 0.95 and absf(world_right.y) < 0.05,
            "F6 screen-right maps to world plus X")

        player.global_position = Vector3(30.0, 0.15, 30.0)
        manager.switch_view(2)
        manager.switch_view(5)
        _check(absf(manager.get_active_camera().global_position.x - 8.0) < 0.02
            and absf(manager.get_active_camera().global_position.z - 3.5) < 0.02,
            "F6 follows a bounded camera target without moving the actor")
        _check(player.global_position.x == 30.0 and player.global_position.z == 30.0,
            "Overhead tracking clamp does not clamp character position")

        player.global_transform = saved_transform
        player.global_position = Vector3(0.0, 0.15, 7.35)
        manager.switch_view(3)
        manager.camera_rig._update_camera(2.0)
        _check(manager.get_active_camera().global_position.z < 8.5,
            "F4 chase camera respects the south wall blocker")
        _check(player.global_position.z > 7.3, "Camera collision leaves actor untouched")

        player.global_transform = saved_transform
        manager.switch_view(0)
        var no_depth: Vector2 = level.call("_map_demo_movement", Vector2(0.0, 1.0))
        _check(no_depth.length_squared() < 0.0001,
            "Temporary side-view movement ignores depth input")
        manager.switch_view(1)

        # F1 must be a strict side-scroller: X horizontal, Y vertical,
        # camera looks directly down -Z, never pitched or orbiting the actor.
        manager.switch_view(0)
        var side_camera: Camera3D = manager.get_active_camera()
        _check(side_camera.global_basis.x.is_equal_approx(Vector3.RIGHT),
            "F1 screen-right is world +X, with no camera roll or yaw")
        _check(side_camera.global_basis.y.is_equal_approx(Vector3.UP),
            "F1 screen-up is world +Y, with no overhead pitch")
        _check(side_camera.global_basis.z.is_equal_approx(Vector3.BACK),
            "F1 camera looks strictly along world -Z")
        _check(is_zero_approx(manager.current_profile.fixed_offset.y),
            "F1 side-camera preset never elevates its viewing angle")
        _check(side_camera.projection == Camera3D.PROJECTION_ORTHOGONAL,
            "F1 uses classic orthographic side projection")
        var front_wall_visual := level.get_node("SouthWall/MeshInstance3D") as MeshInstance3D
        var front_wall_body := level.get_node("SouthWall") as StaticBody3D
        _check(not front_wall_visual.visible,
            "F1 hides foreground arena wall visual to reveal the player")
        _check(front_wall_body.collision_layer != 0,
            "F1 retains foreground wall collision while hiding its mesh")

        # Follow smoothing must not rotate the fixed side-view camera.
        manager.camera_rig._update_camera(0.25)
        _check(side_camera.global_basis == Basis.IDENTITY,
            "F1 remains perfectly side-on after camera follow update")
        manager.switch_view(1)
        _check(front_wall_visual.visible,
            "F2 restores foreground wall visuals")
        manager.camera_rig._update_camera(1.0)
        _check(manager.get_active_camera().global_basis.z.y > 0.05,
            "F2 retains its intentionally elevated beat'em-up view")

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
