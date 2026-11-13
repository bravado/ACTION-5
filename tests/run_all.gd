extends SceneTree

const ViewManagerScript = preload("res://addons/action5/camera/view_manager.gd")
const ViewInputScript = preload("res://addons/action5/camera/view_input.gd")
const ViewProfileScript = preload("res://addons/action5/camera/view_profile.gd")
const D03SuiteScript = preload("res://tests/d03_suite.gd")
const D04SuiteScript = preload("res://tests/d04_suite.gd")
const CrouchSuiteScript = preload("res://tests/crouch_suite.gd")
const D05SuiteScript = preload("res://tests/d05_suite.gd")
const D05AnimationSuiteScript = preload("res://tests/d05_animation_suite.gd")
const D05FirstPersonSuiteScript = preload("res://tests/d05_first_person_suite.gd")
const D05CombatAnimationSuiteScript = preload("res://tests/d05_combat_animation_suite.gd")
const D06EquipmentSuiteScript = preload("res://tests/d06_equipment_suite.gd")
const D06HardeningSuiteScript = preload("res://tests/d06_hardening_suite.gd")
const D06FastSwingSuiteScript = preload("res://tests/d06_fast_swing_suite.gd")
const D06MovementViewSuiteScript = preload("res://tests/d06_movement_view_suite.gd")
const D06GunSuiteScript = preload("res://tests/d06_gun_suite.gd")
const D07SuiteScript = preload("res://tests/d07_suite.gd")
const D08WorldSuiteScript = preload("res://tests/d08_world_suite.gd")
const D08CameraSectorSuiteScript = preload("res://tests/d08_camera_sector_suite.gd")
const D08ConnectionsSuiteScript = preload("res://tests/d08_connections_suite.gd")
const D09ReferenceSuiteScript = preload("res://tests/d09_reference_suite.gd")
const D09SideAimSuiteScript = preload("res://tests/d09_side_aim_suite.gd")
const D09RetroSuiteScript = preload("res://tests/d09_retro_suite.gd")
const D09HudSuiteScript = preload("res://tests/d09_hud_suite.gd")
const LocomotionScript = preload("res://addons/action5/actor/locomotion.gd")
const ActorInputScript = preload("res://addons/action5/input/actor_input_adapter.gd")
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
    var actor_input := level.get_node_or_null("ActorInput") as ActorInputScript
    var player_locomotion: LocomotionScript
    if player != null:
        player_locomotion = player.get_node_or_null("Locomotion") as LocomotionScript
    _check(player != null, "One CharacterBody3D exists in the world")
    _check(player_locomotion != null, "Player has one authoritative locomotion component")
    _check(actor_input != null, "Input adapter handles game input and window focus")
    _check(level.get_node_or_null("Floor/CollisionShape3D") is CollisionShape3D,
        "Floor includes a physical collision shape")
    _check(level.get_node_or_null("NorthWall/CollisionShape3D") is CollisionShape3D,
        "North wall includes a physical collision shape")
    _check(level.get_node_or_null("SouthWall/CollisionShape3D") is CollisionShape3D,
        "South wall includes a physical collision shape")
    _check(level.get_node_or_null("WestWall/CollisionShape3D") is CollisionShape3D,
        "West wall includes a physical collision shape")
    _check(level.get_node_or_null("EastWall/Upper/CollisionShape3D") is CollisionShape3D
        and level.get_node_or_null("EastWall/Lower/CollisionShape3D") is CollisionShape3D
        and level.get_node_or_null("PassageFloor/CollisionShape3D") is CollisionShape3D,
        "East wall has two physical sections around a collidable shared doorway")
    _check(level.get_node_or_null("ViewManager/CameraRig/Camera3D") is Camera3D,
        "Diagnostic 3D camera is present")
    _check(level.get_node_or_null("Hud/Reliquary/HelpPanel/Content/Scroll/HelpText") is Label,
        "D01 on-demand help is authored in the scene")

    if player != null:
        _check(player.get_node_or_null("CollisionShape3D") is CollisionShape3D,
            "Actor has a capsule body collider")
        var imported_model: Node = player.get_node_or_null("Visual/Model")
        _check(imported_model != null and not imported_model.find_children(
            "*", "MeshInstance3D", true, false
        ).is_empty(), "Actor displays the imported skinned character model")
        _check(player.get_node_or_null("Visual/Body") == null
            and player.get_node_or_null("Visual/FacingMarker") == null,
            "Obsolete hidden placeholder meshes are absent")
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
            "First-Person", "Top-Down"
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
        var fps_presenter = player.get_node("FirstPersonPresenter")
        _check(player.get_node("Visual").visible
            and fps_presenter.first_person
            and fps_presenter.body_meshes.size() >= 2
            and not manager.get_active_camera().get_cull_mask_value(
                fps_presenter.local_body_render_layer),
            "F4 camera culls the local skinned head, torso and arms but preserves the rig")
        _check(not manager.current_profile.invert_y,
            "First-person mouse Y starts non-inverted")
        var fps_rig = manager.camera_rig
        var start_pitch: float = fps_rig.orbit_pitch
        fps_rig.apply_mouse_motion(Vector2(0.0, 80.0))
        fps_rig._update_camera(1.0 / 60.0)
        _check(fps_rig.orbit_pitch > start_pitch
            and manager.get_active_camera().global_basis.z.y > 0.05,
            "First-person mouse-down looks down by default")

        # F4 must resume the *last* mouse-look angle, not its configured
        # defaults, after any other view is selected. The same Camera3D and
        # authoritative player must remain alive throughout the switches.
        var start_yaw: float = fps_rig.orbit_yaw
        fps_rig.apply_mouse_motion(Vector2(120.0, 0.0))
        fps_rig._update_camera(1.0 / 60.0)
        var saved_fps_yaw: float = fps_rig.orbit_yaw
        var saved_fps_pitch: float = fps_rig.orbit_pitch
        var saved_fps_basis: Basis = manager.get_active_camera().global_basis
        manager.switch_view(2)
        manager.switch_view(3)
        _check(is_equal_approx(fps_rig.orbit_yaw, saved_fps_yaw)
            and is_equal_approx(fps_rig.orbit_pitch, saved_fps_pitch)
            and manager.get_active_camera().global_basis.is_equal_approx(saved_fps_basis),
            "F4 restores mouse yaw/pitch and camera look after visiting F3")
        manager.switch_view(4)
        manager.switch_view(3)
        _check(is_equal_approx(fps_rig.orbit_yaw, saved_fps_yaw)
            and is_equal_approx(fps_rig.orbit_pitch, saved_fps_pitch)
            and manager.get_active_camera().global_basis.is_equal_approx(saved_fps_basis)
            and player.get_instance_id() == player_id
            and manager.get_active_camera().get_instance_id() == camera_id,
            "F4 look remains stable through F5 and repeated switches without re-creation")
        fps_rig.apply_mouse_motion(Vector2(15.0, -10.0))
        _check(fps_rig.orbit_yaw < saved_fps_yaw
            and fps_rig.orbit_pitch < saved_fps_pitch,
            "F4 mouse look continues smoothly from its restored orientation")
        # Restore initial orientation so later camera tests remain independent.
        fps_rig.apply_mouse_motion(Vector2(-135.0, -70.0))
        fps_rig._update_camera(1.0 / 60.0)
        _check(is_equal_approx(fps_rig.orbit_yaw, start_yaw)
            and is_equal_approx(fps_rig.orbit_pitch, start_pitch),
            "F4 test mouse input returns to its initial orientation")
        manager.switch_view(2)
        _check(player.get_node("Visual").visible,
            "F3 restores third-person actor visuals")
        _check(manager.get_active_camera().projection == Camera3D.PROJECTION_ORTHOGONAL,
            "Wide F3 isometric view uses orthographic projection")
        _check(manager.camera_rig.get_isometric_close_factor() < 0.01,
            "Wide F3 view starts at isometric zoom, not the shoulder zoom")
        _check(manager.get_active_camera().global_basis.z.y > 0.5,
            "Wide F3 isometric view is visibly inclined")

        # Reproduce 3 -> 4 -> 3 while the actor is facing east and idle.
        # Both the isometric mouse orbit AND the visual facing must survive.
        var original_facing: Vector2 = player.facing.facing_world
        player.facing.set_facing(Vector2.RIGHT)
        player.facing._process(1.0)
        var iso_base_basis: Basis = manager.get_active_camera().global_basis
        fps_rig.apply_mouse_motion(Vector2(170.0, -95.0))
        # Compare fully resolved orbits, not transitional follow smoothing.
        fps_rig._snap_next = true
        fps_rig._update_camera(1.0 / 60.0)
        var iso_orbit_yaw: float = fps_rig.orbit_yaw
        var iso_orbit_pitch: float = fps_rig.orbit_pitch
        var iso_orbit_basis: Basis = manager.get_active_camera().global_basis
        _check(not iso_orbit_basis.is_equal_approx(iso_base_basis),
            "F3 mouse orbit is non-default before the round trip")
        var prior_fps_pitch: float = 0.0
        for repeat_index in range(3):
            manager.switch_view(3)
            await physics_frame
            var fps_forward: Vector3 = -manager.get_active_camera().global_basis.z
            _check(Vector2(fps_forward.x, fps_forward.z).distance_to(Vector2.RIGHT) < 0.01,
                "F4 looks east on entry while the character faces east")
            prior_fps_pitch = fps_rig.orbit_pitch
            var idle_first_person = actor_input.compose_intent(Vector2.ZERO)
            _check(idle_first_person.face_world.is_zero_approx()
                and idle_first_person.aim_world.is_zero_approx(),
                "Entering F4 without input does not issue an implicit north-facing command")
            player.apply_move_intent(idle_first_person)
            manager.switch_view(2)
            await physics_frame
        # Physics can shift the actor/follow target slightly between
        # switches. Compare the same settled isometric camera composition.
        fps_rig._snap_next = true
        fps_rig._update_camera(1.0 / 60.0)
        _check(is_equal_approx(fps_rig.orbit_yaw, iso_orbit_yaw)
            and is_equal_approx(fps_rig.orbit_pitch, iso_orbit_pitch)
            and manager.get_active_camera().global_basis.is_equal_approx(iso_orbit_basis),
            "F3 keeps its yaw, pitch and camera basis after repeated F4 switches")
        _check(player.facing.facing_world.is_equal_approx(Vector2.RIGHT),
            "Idle F4 round trips preserve the player's east-facing direction")

        # Turning in F3 must update F4's heading, without resetting the
        # first-person pitch or the already established isometric orbit.
        player.facing.set_facing(Vector2.LEFT)
        player.facing._process(1.0)
        manager.switch_view(3)
        var west_forward: Vector3 = -manager.get_active_camera().global_basis.z
        _check(Vector2(west_forward.x, west_forward.z).distance_to(Vector2.LEFT) < 0.01
            and is_equal_approx(fps_rig.orbit_pitch, prior_fps_pitch),
            "F4 follows the player's new west-facing heading, preserving pitch")
        _check(player.facing.facing_world.is_equal_approx(Vector2.LEFT),
            "F4 camera heading alignment does not rotate the actor")
        manager.switch_view(2)
        _check(manager.get_active_camera().global_basis.is_equal_approx(iso_orbit_basis),
            "Syncing FPS to the actor never changes F3 isometric orbit")

        # Actual F4 mouse look still directs the character, and that new
        # intentional facing must remain when returning to F3.
        manager.switch_view(3)
        fps_rig.apply_mouse_motion(Vector2(150.0, 0.0))
        fps_rig._update_camera(1.0 / 60.0)
        var looked_intent = actor_input.compose_intent(Vector2.ZERO)
        _check(looked_intent.face_world.length_squared() > 0.9,
            "Active F4 mouse look provides a world-space facing direction")
        player.apply_move_intent(looked_intent)
        manager.switch_view(2)
        _check(player.facing.facing_world.is_equal_approx(looked_intent.face_world),
            "Intentional F4 mouse look remains the actor facing in F3")
        # Restore independent camera and facing state for subsequent tests.
        fps_rig.apply_mouse_motion(Vector2(-170.0, 95.0))
        fps_rig._snap_next = true
        fps_rig._update_camera(1.0 / 60.0)
        player.facing.set_facing(original_facing)
        player.facing._process(1.0)
        _check(manager.get_active_camera().global_basis.is_equal_approx(iso_base_basis),
            "F3 orbit returns to its previous angle after inverse mouse input")
        _check(manager.profiles[2].shoulder_offset > 0.5
            and manager.profiles[2].aim_ahead > 1.0
            and manager.profiles[2].close_chase_distance < 4.0,
            "Former F4 shoulder and aiming settings moved to F3 resource")
        _check(not InputMap.has_action(&"view_6"),
            "No unused sixth camera action registered")

        var selector := level.get_node("Hud/Reliquary/HelpPanel/Content/ViewSelector") as HBoxContainer
        var side_button := selector.get_child(3) as Button
        side_button.pressed.emit()
        _check(manager.active_index == 0, "Real F6 selector chooses side-scroller")
        _check((level.get_node("Hud/Reliquary") as Control).get("_view").text.begins_with("4"),
            "HUD displays remapped shortcut and active camera")
        _check(selector.get_child_count() == 5,
            "HUD has exactly five F6 view buttons")

        if input_adapter != null:
            var key_one := InputEventKey.new()
            key_one.keycode = KEY_1
            key_one.pressed = true
            var key_five := InputEventKey.new()
            key_five.keycode = KEY_5
            key_five.pressed = true
            var key_four := InputEventKey.new()
            key_four.keycode = KEY_4
            key_four.pressed = true
            _check(InputMap.event_is_action(key_one, &"view_1")
                and InputMap.event_is_action(key_four, &"view_4")
                and InputMap.event_is_action(key_five, &"view_5"),
                "Number keys 1, 4 and 5 remain primary view bindings")
            _check(input_adapter.profile_index_for_shortcut(0) == 3
                and input_adapter.profile_index_for_shortcut(3) == 0
                and input_adapter.shortcut_for_profile_index(3) == 0
                and input_adapter.shortcut_for_profile_index(0) == 3,
                "Input mapping swaps shortcuts 1/4 without reordering camera profiles")
            input_adapter._unhandled_input(key_five)
            _check(manager.active_index == 4, "Key 5 selects retro top-down")
            input_adapter._unhandled_input(key_one)
            _check(manager.active_index == 3, "Key 1 selects first-person")
            _check(input_adapter.cycle_shortcut_view(1) and manager.active_index == 1,
                "Camera shortcut next from key 1 selects key 2 beat-em-up")
            _check(input_adapter.cycle_shortcut_view(-1) and manager.active_index == 3,
                "Camera shortcut previous from key 2 returns to key 1 first-person")
            input_adapter._unhandled_input(key_four)
            _check(manager.active_index == 0, "Key 4 selects side-scroller")
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
        _check(front_wall.visible, "F2 keeps the outer wall rendered for proximity fading")
        _check(manager.current_profile.orthographic_size <= 7.0,
            "F2 brawler uses close arcade-scale framing")

        var settings := level.get_node("Hud/CameraSettings")
        player.call("set_move_intent", Vector2.RIGHT)
        level.call("_toggle_camera_settings")
        _check(settings.visible, "Camera settings panel can be opened")
        _check(not actor_input.enabled
            and player_locomotion.desired.world_move.is_zero_approx(),
            "Opening camera settings clears input immediately, without demo polling")
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
        var peek_row := settings.get_node("Padding/Controls/Row_lateral_peek_degrees") as HBoxContainer
        var peek_response_row := settings.get_node("Padding/Controls/Row_lateral_peek_response") as HBoxContainer
        _check(peek_row.visible and peek_response_row.visible,
            "F2 exposes lateral camera angle and response in Camera Settings")
        _check(settings.call("set_current_value", "lateral_peek_degrees", 3.5)
            and absf(manager.current_profile.lateral_peek_degrees - 3.5) < 0.01,
            "F2 camera peek can be reduced live without editing resource files")
        var peek_slider := settings.get_node(
            "Padding/Controls/Row_lateral_peek_degrees/Slider") as HSlider
        peek_slider.value = 5.0
        _check(absf(manager.current_profile.lateral_peek_degrees - 5.0) < 0.01,
            "F2 lateral camera setting responds to its in-game slider")
        var peek_config := ConfigFile.new()
        _check(peek_config.load(settings.preferences_path) == OK
            and absf(float(peek_config.get_value(
                "profile_beatemup", "lateral_peek_degrees", -1.0)) - 5.0) < 0.01,
            "F2 lateral peek override is persisted under its stable profile ID")
        settings.call("reset_current_camera")
        _check(absf(manager.current_profile.lateral_peek_degrees - 6.0) < 0.01,
            "F2 reset restores the subtler shipped camera peek")
        var reset_peek_config := ConfigFile.new()
        _check(reset_peek_config.load(settings.preferences_path) == OK
            and not reset_peek_config.has_section_key(
                "profile_beatemup", "lateral_peek_degrees"),
            "Reset removes F2 peek overrides so future defaults remain editable")

        # First-person's boolean Y-axis setting is a per-profile checkbox,
        # not a numeric slider. Changing it must preserve actor and camera IDs.
        var fps_checkbox := settings.get_node("Padding/Controls/Row_invert_y/InvertY") as CheckBox
        var fps_row := settings.get_node("Padding/Controls/Row_invert_y") as HBoxContainer
        _check(not fps_row.visible, "Invert Y-axis option is hidden for beat'em up")
        manager.switch_view(3)
        var fps_profile: ViewProfileScript = manager.current_profile
        var fps_actor_before: Transform3D = player.global_transform
        _check(fps_row.visible and not fps_checkbox.button_pressed
            and not fps_profile.invert_y,
            "First-person settings show an unchecked Invert Y-axis checkbox")
        fps_checkbox.button_pressed = true
        _check(fps_profile.invert_y and fps_checkbox.button_pressed,
            "First-person checkbox toggles mouse inversion live")
        var inverted_start: float = manager.camera_rig.orbit_pitch
        manager.camera_rig.apply_mouse_motion(Vector2(0.0, 80.0))
        manager.camera_rig._update_camera(1.0 / 60.0)
        _check(manager.camera_rig.orbit_pitch < inverted_start
            and manager.get_active_camera().global_basis.z.y < -0.05,
            "When inverted, mouse-down looks upward")
        _check(player.global_transform == fps_actor_before
            and manager.get_active_camera().get_instance_id() == camera_id,
            "Mouse inversion never moves the actor or recreates the camera")
        var invert_config := ConfigFile.new()
        _check(invert_config.load(settings.preferences_path) == OK
            and invert_config.get_value("profile_first_person", "invert_y", false) == true,
            "Invert Y-axis is saved under the stable first-person profile ID")
        fps_profile.invert_y = false
        settings.call("_load_preferences")
        _check(fps_profile.invert_y,
            "Saved first-person inversion is restored when preferences reload")
        settings.call("refresh_controls")
        manager.switch_view(2)
        _check(not fps_row.visible
            and not settings.call("set_current_invert_y", false),
            "Other camera modes cannot change first-person inversion")
        manager.switch_view(3)
        _check(fps_checkbox.button_pressed and fps_profile.invert_y,
            "First-person inversion survives switching away and back")
        settings.call("reset_current_camera")
        _check(not fps_profile.invert_y and not fps_checkbox.button_pressed,
            "Reset this camera restores default non-inverted mouse look")
        var reset_invert_config := ConfigFile.new()
        _check(reset_invert_config.load(settings.preferences_path) == OK
            and not reset_invert_config.has_section_key("profile_first_person", "invert_y"),
            "Reset removes the inversion override from persisted preferences")
        manager.switch_view(2)

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
        level.call("_toggle_camera_settings")
        _check(not settings.visible and actor_input.enabled,
            "Closing settings restores the independent UI input gate")
        player.call("set_move_intent", Vector2.RIGHT)
        actor_input._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
        _check(player_locomotion.desired.world_move.is_zero_approx()
            and not actor_input.focus_active and actor_input.enabled,
            "Input adapter alone clears movement on focus loss; UI gate stays enabled")
        # Closing the settings panel while unfocused must not bypass the
        # adapter's focus gate, even though the demo enables its UI gate.
        level.call("_toggle_camera_settings")
        _check(settings.visible and not actor_input.enabled,
            "Opening settings disables input independently of window focus")
        level.call("_toggle_camera_settings")
        _check(not settings.visible and actor_input.enabled
            and not actor_input.focus_active,
            "Closing settings while unfocused cannot restore gameplay input")
        actor_input._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
        _check(actor_input.focus_active and actor_input.enabled
            and actor_input.require_neutral,
            "Focus return restores input sampling only after neutralization")

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
    var d04_suite := D04SuiteScript.new()
    await d04_suite.run_tests(self, level, Callable(self, "_check"))
    var crouch_suite := CrouchSuiteScript.new()
    await crouch_suite.run_tests(self, level, Callable(self, "_check"))

    # Regression: clicking a camera/menu button must never steal Space from
    # actor_jump. This used to re-select the previously focused camera.
    var hud := level.get_node("Hud")
    var ui_buttons := level.get_node("Hud/Reliquary/HelpPanel/Content/ViewSelector") as HBoxContainer
    var settings_button := level.get_node("Hud/Reliquary/HelpPanel/Content/CameraSettings") as Button
    var settings_panel := level.get_node("Hud/CameraSettings") as PanelContainer
    for i in range(5):
        _check((ui_buttons.get_child(i) as Button).focus_mode != Control.FOCUS_NONE,
            "F6 view button %d remains keyboard-navigable" % (i + 1))
    hud.call("set_help_open", true)
    _check(not level.get_node("ActorInput").enabled, "Opening help gates gameplay")
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
    var previously_clicked := ui_buttons.get_child(2) as Button
    hud.call("set_help_open", true)
    previously_clicked.grab_focus()
    await process_frame
    _check(root.gui_get_focus_owner() == previously_clicked,
        "F6 view button can receive keyboard focus")
    hud.call("set_help_open", false)
    _check(root.gui_get_focus_owner() != previously_clicked,
        "Closing F6 releases selector focus before gameplay")
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
    hud.call("set_help_open", true)
    settings_button.pressed.emit()
    settings_button.grab_focus()
    level.call("_toggle_camera_settings")
    var count_after_settings: int = views.switch_count
    Input.parse_input_event(space_down)
    await physics_frame
    Input.parse_input_event(space_up)
    await process_frame
    _check(not settings_panel.visible
        and views.switch_count == count_after_settings
        and root.gui_get_focus_owner() != settings_button,
        "Space after closing Camera Settings cannot reopen it or switch views")

    # Verify the actual source rig and imported articulated strikes before
    # the damage suite runs lethal actor tests.
    var d05_animation_suite := D05AnimationSuiteScript.new()
    d05_animation_suite.run_tests(level, Callable(self, "_check"))

    var d05_fps_suite := D05FirstPersonSuiteScript.new()
    await d05_fps_suite.run_tests(self, level, Callable(self, "_check"))

    # D05 deliberately exercises lethal damage: run after legacy view/UI
    # checks so their live-player assumptions remain independent.
    var d05_suite := D05SuiteScript.new()
    await d05_suite.run_tests(self, level, Callable(self, "_check"))

    # Run last: the regular combat suite ends with a lethal damage test.
    var d05_combat_animation_suite := D05CombatAnimationSuiteScript.new()
    await d05_combat_animation_suite.run_tests(self, level, Callable(self, "_check"))

    # D06 runs after the destructive D05 lifecycle suite and restores the
    # same actor; it verifies real equipment/mount/visual registration.
    var d06_equipment_suite := D06EquipmentSuiteScript.new()
    await d06_equipment_suite.run_tests(self, level, Callable(self, "_check"))
    var d06_hardening_suite := D06HardeningSuiteScript.new()
    await d06_hardening_suite.run_tests(self, level, Callable(self, "_check"))
    var d06_fast_suite := D06FastSwingSuiteScript.new()
    await d06_fast_suite.run_tests(self, level, Callable(self, "_check"))
    var d06_movement_suite := D06MovementViewSuiteScript.new()
    await d06_movement_suite.run_tests(self, Callable(self, "_check"))

    # Separate D06-02 fixture starts with an intact living actor and a
    # physical world, so destructive older melee tests cannot mask failures.
    var d06_gun_suite := D06GunSuiteScript.new()
    await d06_gun_suite.run_tests(self, Callable(self, "_check"))

    var d07_suite := D07SuiteScript.new()
    await d07_suite.run_tests(self, Callable(self, "_check"))
    var d08_world_suite := D08WorldSuiteScript.new()
    await d08_world_suite.run_tests(self, Callable(self, "_check"))
    var d08_camera_sector_suite := D08CameraSectorSuiteScript.new()
    await d08_camera_sector_suite.run_tests(self, Callable(self, "_check"))
    var d08_connections_suite := D08ConnectionsSuiteScript.new()
    await d08_connections_suite.run_tests(self, Callable(self, "_check"))

    var d09_suite := D09ReferenceSuiteScript.new()
    await d09_suite.run_tests(self, Callable(self, "_check"))
    var side_aim_suite := D09SideAimSuiteScript.new()
    await side_aim_suite.run_tests(self, Callable(self, "_check"))
    var retro_suite := D09RetroSuiteScript.new()
    await retro_suite.run_tests(self, Callable(self, "_check"))
    var hud_suite := D09HudSuiteScript.new()
    await hud_suite.run_tests(self, Callable(self, "_check"))

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
