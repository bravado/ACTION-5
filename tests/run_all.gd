extends SceneTree

const ViewManagerScript = preload("res://addons/action5/camera/view_manager.gd")
const ViewInputScript = preload("res://addons/action5/camera/view_input.gd")
const ViewProfileScript = preload("res://addons/action5/camera/view_profile.gd")
const D03SuiteScript = preload("res://tests/d03_suite.gd")
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
    # The CharacterBody3D may be moved out of floor penetration on its
    # first physics frame. Verify the authored spawn before attaching it.
    var authored_spawn: Vector3 = (level.get_node("Player") as Node3D).position
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
        _check(authored_spawn.distance_to(Vector3(0.0, 0.15, 0.0)) < 0.01,
            "Actor scene defines documented spawn before physics correction")

    # D02: one actor and one camera, five selectable perspectives.
    var manager := level.get_node_or_null("ViewManager") as ViewManagerScript
    var input_adapter := level.get_node_or_null("ViewInput") as ViewInputScript
    _check(manager != null and input_adapter != null, "View manager and input adapter present")
    if manager != null and player != null:
        _check(manager.profiles.size() == 5, "Exactly five camera profiles")
        var expected_names := [
            "Side-Scroller", "Beat 'em Up", "Isometric / Third-Person",
            "First-Person", "Retro Top-Down"
        ]
        for index in range(5):
            _check(manager.profiles[index].display_name == expected_names[index],
                "View %d uses consistent human-readable camera name" % (index + 1))
        _check(manager.active_index == 1, "Initial brawler camera selected")
        _check(manager.camera_rig.camera == level.get_node("ViewManager/CameraRig/Camera3D"),
            "One persistent Camera3D across all five views")
        _check(manager.profiles[2].mode == ViewProfileScript.Mode.ISOMETRIC
            and manager.profiles[3].mode == ViewProfileScript.Mode.FIRST_PERSON
            and manager.profiles[4].mode == ViewProfileScript.Mode.RETRO_TOPDOWN,
            "Mode 3 is shared isometric/shoulder, 4 is FPS, 5 retro top-down")
        var player_id: int = player.get_instance_id()
        var camera_id: int = manager.get_active_camera().get_instance_id()
        var original_transform: Transform3D = player.global_transform
        var original_velocity: Vector3 = player.velocity
        for repeat_index in range(20):
            for index in range(5):
                _check(manager.switch_view(index),
                    "Switch camera to %d, cycle %d" % [index + 1, repeat_index + 1])
        _check(manager.switch_count >= 100, "Five modes cycled 20 times")
        _check(player.get_instance_id() == player_id
            and manager.get_active_camera().get_instance_id() == camera_id,
            "Camera and actor identities retained through 100 switches")
        _check(player.global_transform == original_transform
            and player.velocity == original_velocity,
            "Switching views preserves player transform and velocity")
        _check(manager.last_position_delta < 0.0001,
            "Switches do not teleport the player")

        manager.switch_view(4)
        _check(manager.current_profile.mode == ViewProfileScript.Mode.RETRO_TOPDOWN,
            "F5 is dedicated NES-style overhead profile")
        _check(manager.camera_rig.is_vertical_overhead(),
            "F5 camera is precisely vertical")
        _check(manager.get_active_camera().projection == Camera3D.PROJECTION_ORTHOGONAL,
            "F5 uses orthographic rendering")
        var world_up: Vector2 = level.call("_map_demo_movement", Vector2(0.0, -1.0))
        var world_right: Vector2 = level.call("_map_demo_movement", Vector2(1.0, 0.0))
        _check(world_up.is_finite() and world_up.y < -0.95 and absf(world_up.x) < 0.05,
            "F5 screen-up maps to finite world -Z movement")
        _check(world_right.is_finite() and world_right.x > 0.95,
            "F5 screen-right maps to finite world +X movement")

        manager.switch_view(3)
        _check(manager.current_profile.mode == ViewProfileScript.Mode.FIRST_PERSON,
            "F4 is first-person")
        _check(manager.get_active_camera().projection == Camera3D.PROJECTION_PERSPECTIVE,
            "F4 uses perspective rendering")
        _check(not player.get_node("Visual").visible,
            "F4 hides the locally owned player's mesh")
        manager.switch_view(2)
        _check(player.get_node("Visual").visible,
            "F3 restores third-person actor visuals")
        _check(manager.get_active_camera().projection == Camera3D.PROJECTION_ORTHOGONAL,
            "Wide F3 isometric view uses orthographic projection")
        _check(manager.camera_rig.get_isometric_close_factor() < 0.01,
            "Wide F3 view starts at isometric zoom, not the shoulder zoom")
        _check(manager.get_active_camera().global_basis.z.y > 0.5,
            "Wide F3 isometric view is visibly inclined")
        _check(manager.profiles[2].shoulder_offset > 0.5
            and manager.profiles[2].aim_ahead > 1.0
            and manager.profiles[2].close_chase_distance < 4.0,
            "Former F4 shoulder and aiming settings moved to F3 resource")
        _check(not InputMap.has_action(&"view_6"),
            "No unused sixth camera action registered")

        var side_button := level.get_node("Hud/ModeButtons/Mode1") as Button
        side_button.pressed.emit()
        _check(manager.active_index == 0, "Camera selector button chooses F1")
        _check((level.get_node("Hud/Status") as Label).text.contains("VIEW 1 / 5"),
            "HUD displays five-mode index and active camera")
        _check(level.get_node_or_null("Hud/ModeButtons/Mode5") is Button
            and level.get_node_or_null("Hud/ModeButtons/Mode6") == null,
            "HUD exposes exactly five view-selection buttons")

        if input_adapter != null:
            var key_one := InputEventKey.new()
            key_one.keycode = KEY_1
            key_one.pressed = true
            var key_five := InputEventKey.new()
            key_five.keycode = KEY_5
            key_five.pressed = true
            _check(InputMap.event_is_action(key_one, &"view_1")
                and InputMap.event_is_action(key_five, &"view_5"),
                "Number keys 1 and 5 are primary view bindings")
            input_adapter._unhandled_input(key_five)
            _check(manager.active_index == 4, "Key 5 selects retro top-down")
            input_adapter._unhandled_input(key_one)
            _check(manager.active_index == 0, "Key 1 selects side-scroller")
            _check(manager.cycle_view(-1) and manager.active_index == 4,
                "Camera cycle wraps backward F1 to F5")
            _check(manager.cycle_view(1) and manager.active_index == 0,
                "Camera cycle wraps forward F5 to F1")

        # F1 keeps the strict horizontal Mario/Altered Beast camera.
        manager.switch_view(0)
        var side_cam: Camera3D = manager.get_active_camera()
        _check(side_cam.global_basis == Basis.IDENTITY,
            "F1 remains an exactly horizontal X/Y side camera")
        _check(is_zero_approx(manager.current_profile.fixed_offset.y),
            "F1 side view has no downward pitch")
        _check(level.call("_map_demo_movement", Vector2(0.0, 1.0)) == Vector2.ZERO,
            "F1 movement ignores depth input")
        var front_wall := level.get_node("SouthWall/MeshInstance3D") as MeshInstance3D
        _check(not front_wall.visible
            and (level.get_node("SouthWall") as StaticBody3D).collision_layer != 0,
            "F1 foreground wall hidden visually, still physical")
        manager.switch_view(1)
        _check(not front_wall.visible, "F2 also hides front-wall graphics")
        _check(manager.current_profile.orthographic_size <= 7.0,
            "F2 brawler uses close arcade-scale framing")

        var settings := level.get_node("Hud/CameraSettings")
        var toggle := level.get_node("Hud/SettingsToggle") as Button
        toggle.pressed.emit()
        _check(settings.visible, "Camera settings panel can be opened")
        player.call("set_move_intent", Vector2.RIGHT)
        level._process(0.0)
        _check((player.get("_planar_intent") as Vector2) == Vector2.ZERO,
            "Open camera settings prevent raw movement keys from moving the actor")
        _check(settings.get_node("Padding/Controls/Row_fixed_height").visible,
            "F2 stage elevation can be adjusted")
        _check(not settings.get_node("Padding/Controls/Row_shoulder_offset").visible,
            "Shoulder controls are not shown for F2")
        _check(settings.call("set_current_value", "orthographic_size", 6.5),
            "F2 zoom is editable in the settings panel")
        var zoom_slider := settings.get_node("Padding/Controls/Row_orthographic_size/Slider") as HSlider
        zoom_slider.value = 7.25
        _check(absf(manager.get_active_camera().size - 7.25) < 0.01,
            "UI slider immediately updates F2 camera zoom")
        settings.call("reset_current_camera")

        # Mode 3 moves continuously between wide isometric and the close
        # over-shoulder framing by adjusting ONE zoom setting.
        manager.switch_view(2)
        _check(settings.get_node("Padding/Controls/Row_orthographic_size").visible,
            "Mode 3 shares an orthographic zoom slider")
        _check(settings.get_node("Padding/Controls/Row_shoulder_offset").visible
            and settings.get_node("Padding/Controls/Row_close_chase_distance").visible
            and settings.get_node("Padding/Controls/Row_close_pitch_degrees").visible
            and settings.get_node("Padding/Controls/Row_aim_ahead").visible,
            "Former F4 shoulder, near distance, pitch, look-ahead controls available on F3")
        _check(not settings.get_node("Padding/Controls/Row_field_of_view").visible,
            "Unused perspective FOV is not presented on orthographic F3")
        var actor_before: Transform3D = player.global_transform
        _check(settings.call("set_current_value", "orthographic_size", 4.0),
            "F3 zoom can reach shoulder framing through the UI")
        _check(manager.camera_rig.get_isometric_close_factor() > 0.99,
            "Close zoom selects shoulder composition within the SAME F3 profile")
        _check(manager.active_index == 2
            and manager.current_profile.mode == ViewProfileScript.Mode.ISOMETRIC,
            "Close zoom never changes camera profile or mode")
        var shoulder: Vector3 = manager.get_active_camera().global_position - player.global_position
        _check(shoulder.x > 0.5 and shoulder.z > 1.0 and shoulder.z < 4.0,
            "Close F3 uses an offset camera a few metres behind shoulder")
        _check(shoulder.y > 1.5, "Close F3 camera sits above the shoulder")
        _check(manager.get_active_camera().projection == Camera3D.PROJECTION_ORTHOGONAL,
            "F3 remains orthographic as it zooms toward the player")
        _check(settings.call("set_current_value", "shoulder_offset", -0.6),
            "F3 shoulder side can be edited")
        _check(manager.get_active_camera().global_position.x < -0.4,
            "Changing F3 shoulder offset immediately updates camera")
        _check(player.global_transform == actor_before,
            "Zoom and shoulder edits do not teleport the player")

        _check(settings.call("set_current_value", "orthographic_size", 6.25),
            "Isometric zoom override can be saved")
        var config := ConfigFile.new()
        _check(config.load(settings.preferences_path) == OK,
            "Per-mode camera overrides are saved")
        _check(int(config.get_value("meta", "schema", 0)) == 2
            and absf(float(config.get_value("profile_isometric", "orthographic_size", 0.0)) - 6.25) < 0.01,
            "Saved zoom belongs to the stable isometric profile ID")
        _check(not config.has_section_key("profile_retro_topdown", "fixed_distance"),
            "Mode 5 overhead cannot inherit F2 camera depth")
        settings.call("reset_current_camera")
        _check(manager.camera_rig.get_isometric_close_factor() < 0.01
            and absf(manager.current_profile.orthographic_size - 17.0) < 0.01,
            "Reset restores a wide isometric view")
        toggle.pressed.emit()
        _check(not settings.visible, "Settings panel can be closed")
        player.call("set_move_intent", Vector2.RIGHT)
        level._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
        _check((player.get("_planar_intent") as Vector2) == Vector2.ZERO,
            "Losing window focus immediately clears movement intent")
        _check(not bool(level.get("_has_window_focus")),
            "Focus-out event disables demo movement polling")
        level._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
        _check(bool(level.get("_has_window_focus")),
            "Focus-in event restores input processing")

        # Near zoom camera collision must keep the camera in front of walls.
        player.global_position = Vector3(0.0, 0.15, 7.35)
        _check(settings.call("set_current_value", "orthographic_size", 4.0),
            "F3 can zoom close near a wall")
        manager.camera_rig._update_camera(1.0)
        _check(manager.get_active_camera().global_position.z < 8.5,
            "Isometric near-shoulder camera respects the arena wall")
        _check(player.global_position.z > 7.3,
            "Camera collision doesn't move the actor")
        player.global_transform = original_transform
        settings.call("reset_current_camera")

        # Upgrade the old six-slot preferences without applying old first-
        # person/retro preferences to the wrong slots.
        settings.preferences_path = "user://action5_migration_test.cfg"
        var old_config := ConfigFile.new()
        old_config.set_value("view_3", "orthographic_size", 14.5)
        old_config.set_value("view_4", "chase_distance", 3.7)
        old_config.set_value("view_4", "pitch", 21.0)
        old_config.set_value("view_4", "shoulder_offset", -0.45)
        old_config.set_value("view_5", "eye_height", 1.9)
        old_config.set_value("view_6", "orthographic_size", 12.0)
        _check(old_config.save(settings.preferences_path) == OK,
            "Legacy six-slot settings test file created")
        settings.call("_load_preferences")
        _check(absf(manager.profiles[2].orthographic_size - 14.5) < 0.01
            and absf(manager.profiles[2].close_chase_distance - 3.7) < 0.01
            and absf(manager.profiles[2].close_pitch_degrees - 21.0) < 0.01
            and absf(manager.profiles[2].shoulder_offset + 0.45) < 0.01,
            "Old mode-4 shoulder controls migrated to mode-3 isometric")
        _check(absf(manager.profiles[3].eye_height - 1.9) < 0.01,
            "Old first-person view 5 preferences migrated to new view 4")
        _check(absf(manager.profiles[4].orthographic_size - 12.0) < 0.01,
            "Old retro view 6 preferences migrated to new view 5")
        var migrated := ConfigFile.new()
        _check(migrated.load(settings.preferences_path) == OK
            and int(migrated.get_value("meta", "schema", 0)) == 2
            and migrated.has_section_key("profile_isometric", "shoulder_offset"),
            "Migrated settings are saved in stable five-mode schema")
        settings.save_user_settings = false
        for index in range(5):
            manager.switch_view(index)
            settings.call("reset_current_camera")
        manager.switch_view(4)
        _check(manager.camera_rig.is_vertical_overhead(),
            "Migrating settings does not corrupt vertical top-down mode")
        manager.switch_view(1)

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

    var d03_suite := D03SuiteScript.new()
    await d03_suite.run_tests(self, level, Callable(self, "_check"))

    # Regression: clicking a camera/menu button must never steal Space from
    # actor_jump. This used to re-select the previously focused camera.
    var ui_buttons := level.get_node("Hud/ModeButtons") as HBoxContainer
    var settings_button := level.get_node("Hud/SettingsToggle") as Button
    var settings_panel := level.get_node("Hud/CameraSettings") as PanelContainer
    for i in range(5):
        var mode_button := ui_buttons.get_node("Mode" + str(i + 1)) as Button
        _check(mode_button.focus_mode == Control.FOCUS_NONE,
            "View selector %d never captures Space-to-jump focus" % (i + 1))
    _check(settings_button.focus_mode == Control.FOCUS_NONE,
        "Camera Settings toggle never captures Space-to-jump focus")
    settings_button.pressed.emit()
    var reset_button := settings_panel.find_child("ResetCamera", true, false) as Button
    var close_button := settings_panel.find_child("CloseSettings", true, false) as Button
    _check(reset_button != null and close_button != null
        and reset_button.focus_mode == Control.FOCUS_NONE
        and close_button.focus_mode == Control.FOCUS_NONE,
        "Reset and Close controls cannot reactivate on Space")
    var slider := settings_panel.get_node("Padding/Controls/Row_orthographic_size/Slider") as HSlider
    slider.grab_focus()
    await process_frame
    _check(root.gui_get_focus_owner() == slider,
        "Camera settings slider remains keyboard-accessible")
    close_button.pressed.emit()
    _check(not settings_panel.visible
        and root.gui_get_focus_owner() != slider,
        "Closing camera settings releases slider focus")
    var previously_clicked := ui_buttons.get_node("Mode3") as Button
    previously_clicked.pressed.emit()
    previously_clicked.grab_focus()
    await process_frame
    _check(root.gui_get_focus_owner() != previously_clicked,
        "Clicked view button cannot retain keyboard focus")
    var views := level.get_node("ViewManager") as ViewManagerScript
    views.switch_view(1)
    var count_before_space: int = views.switch_count
    var space_down := InputEventKey.new()
    space_down.keycode = KEY_SPACE
    space_down.pressed = true
    Input.parse_input_event(space_down)
    await physics_frame
    var space_up := InputEventKey.new()
    space_up.keycode = KEY_SPACE
    space_up.pressed = false
    Input.parse_input_event(space_up)
    await process_frame
    _check(views.active_index == 1 and views.switch_count == count_before_space,
        "Space after switching with 1–5 cannot activate previous view")
    settings_button.pressed.emit()
    settings_button.grab_focus()
    settings_button.pressed.emit()
    var count_after_settings: int = views.switch_count
    Input.parse_input_event(space_down)
    await physics_frame
    Input.parse_input_event(space_up)
    await process_frame
    _check(not settings_panel.visible
        and views.switch_count == count_after_settings
        and root.gui_get_focus_owner() != settings_button,
        "Space after closing Camera Settings cannot reopen it or switch views")

    level.queue_free()
    # Flush Godot's deferred deletion queue before inspecting ResourceDB at
    # process exit, especially with dynamically installed move components.
    await process_frame

    if OS.get_cmdline_user_args().has("--self-test-failure"):
        _check(false, "Intentional assertion verifies runner exits nonzero")

    _finish()


func _finish() -> void:
    print("ACTION5_TEST_RESULT assertions=", assertions, " failures=", failures)
    quit(1 if failures > 0 else 0)
