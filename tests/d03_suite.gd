extends RefCounted
## D03 real physics + input-map regression suite; called from tests/run_all.gd.

const MoveIntentScript = preload("res://addons/action5/actor/move_intent.gd")
const PolicyScript = preload("res://addons/action5/actor/movement_policy.gd")
const ActorScript = preload("res://addons/action5/actor/action_actor.gd")
const ViewProfileScript = preload("res://addons/action5/camera/view_profile.gd")
const AdapterScript = preload("res://addons/action5/input/actor_input_adapter.gd")
const CustomDashScript = preload("res://tests/fixtures/custom_dash_move.gd")
const CustomClimbScript = preload("res://tests/fixtures/custom_climb_move.gd")


func run_tests(tree: SceneTree, level: Node3D, verify: Callable) -> void:
    var manager = level.get_node("ViewManager")
    var adapter: AdapterScript = level.get_node("ActorInput")
    var player: ActorScript = level.get_node("Player")

    verify.call(adapter != null and player != null, "D03 reusable actor/input adapter available")
    verify.call(player.get_node("Locomotion") != null and player.get_node("Visual") != null,
        "Locomotion and facing are independent actor components")
    verify.call(adapter.process_physics_priority < player.locomotion.process_physics_priority,
        "Raw input is sampled before locomotion on the same physics tick")

    # A reusable controller discovers components directly from the actor
    # scene; bindings come from components, not the input adapter's switch.
    var demo_moves = player.locomotion.move_controller
    var installed_count: int = demo_moves.moves_root.get_child_count()
    verify.call(installed_count >= 4 and demo_moves.get_moves().size() == installed_count,
        "All configured move components auto-register without hardcoded counts")
    verify.call(demo_moves.get_move(&"grounded") != null
        and demo_moves.get_move(&"airborne") != null
        and demo_moves.get_move(&"dodge") != null
        and demo_moves.get_move(&"slide") != null,
        "Every shipped state is discoverable by its public move ID")
    verify.call(InputMap.has_action(&"actor_dodge") and InputMap.has_action(&"actor_slide"),
        "InputMap bindings are registered from move components")
    verify.call(not demo_moves.request_move(&"not_installed"),
        "Unknown move ID is rejected safely")

    # Dynamically install an entirely new move without touching Actor,
    # InputAdapter or the locomotion solver.
    var injected = CustomDashScript.new()
    verify.call(demo_moves.add_move(injected),
        "Custom move registers at runtime as a separate child component")
    verify.call(demo_moves.get_move(&"test_dash") == injected
        and demo_moves.get_moves().size() == installed_count + 1,
        "The controller automatically discovers the newly installed move")
    verify.call(InputMap.has_action(&"actor_test_dash")
        and not InputMap.action_get_events(&"actor_test_dash").is_empty(),
        "Custom move registers its default InputMap action via registry signal")
    var moves_before_duplicate: int = demo_moves.moves_root.get_child_count()
    var duplicate_move = CustomDashScript.new()
    verify.call(not demo_moves.add_move(duplicate_move)
        and demo_moves.moves_root.get_child_count() == moves_before_duplicate,
        "Duplicate move IDs are rejected without creating orphan child nodes")
    duplicate_move.free()

    # Direct scene-tree additions/removals must keep the registry synchronized,
    # even when a detached node is still a valid object.
    var removed_demo_ids: Array[StringName] = []
    demo_moves.move_unregistered.connect(
        func(id: StringName) -> void: removed_demo_ids.append(id)
    )
    demo_moves.moves_root.remove_child(injected)
    verify.call(demo_moves.get_move(&"test_dash") == null
        and demo_moves.get_moves().size() == installed_count
        and removed_demo_ids == [&"test_dash"],
        "Removing a valid child immediately unregisters its move and emits once")
    injected.free()

    var direct_move = CustomDashScript.new()
    demo_moves.moves_root.add_child(direct_move)
    verify.call(demo_moves.get_move(&"test_dash") == direct_move,
        "Adding a move directly to Moves automatically registers it")
    verify.call(demo_moves.unregister_move(&"test_dash")
        and demo_moves.get_move(&"test_dash") == null
        and removed_demo_ids == [&"test_dash", &"test_dash"],
        "Explicit unregistration emits once and removes the registered instance")
    verify.call(not demo_moves.unregister_move(&"test_dash"),
        "Unregistering an already removed move is a no-op")
    demo_moves.moves_root.remove_child(direct_move)
    direct_move.free()
    verify.call(removed_demo_ids.size() == 2,
        "Removing a previously unregistered node does not duplicate the signal")


    # The adapter uses Input.get_vector() for Godot's built-in radial deadzone.
    # The pure projection layer still rejects invalid and oversized vectors.
    verify.call(PolicyScript.to_world(Vector2(INF, 0.0),
        ViewProfileScript.Mode.BEATEMUP, Basis.IDENTITY).is_zero_approx(),
        "Non-finite input is rejected by world-space movement projection")
    verify.call(PolicyScript.to_world(Vector2(3.0, 4.0),
        ViewProfileScript.Mode.BEATEMUP, Basis.IDENTITY).length() <= 1.001,
        "World-space movement projection caps input magnitude")

    var basis: Basis = Basis.IDENTITY
    verify.call(PolicyScript.to_world(Vector2(0.6, 0.8), ViewProfileScript.Mode.SIDE, basis)
        .is_equal_approx(Vector2(0.6, 0.0)),
        "Side view ignores stage depth and preserves horizontal magnitude")
    verify.call(PolicyScript.to_world(Vector2(0.6, 0.8), ViewProfileScript.Mode.BEATEMUP, basis)
        .is_equal_approx(Vector2(0.6, 0.8)),
        "Brawler world-X/Z movement preserves normalized input")
    verify.call(PolicyScript.to_world(Vector2(1.0, 0.0),
        ViewProfileScript.Mode.FIRST_PERSON, basis).is_equal_approx(Vector2.RIGHT),
        "FPS camera-right maps to world +X at zero yaw")
    verify.call(PolicyScript.to_world(Vector2(0.0, -1.0),
        ViewProfileScript.Mode.FIRST_PERSON, basis).is_equal_approx(Vector2(0.0, -1.0)),
        "FPS screen-up maps to forward world -Z at zero yaw")

    manager.switch_view(4)
    var overhead: Basis = manager.get_active_camera().global_basis
    var up: Vector2 = PolicyScript.to_world(Vector2.UP, ViewProfileScript.Mode.RETRO_TOPDOWN, overhead)
    var down: Vector2 = PolicyScript.to_world(Vector2.DOWN, ViewProfileScript.Mode.RETRO_TOPDOWN, overhead)
    var left: Vector2 = PolicyScript.to_world(Vector2.LEFT, ViewProfileScript.Mode.RETRO_TOPDOWN, overhead)
    var right: Vector2 = PolicyScript.to_world(Vector2.RIGHT, ViewProfileScript.Mode.RETRO_TOPDOWN, overhead)
    verify.call(up.is_finite() and up.y < -0.99 and absf(up.x) < 0.01,
        "Exact-vertical F5 screen-up maps to world -Z")
    verify.call(down.is_finite() and down.y > 0.99,
        "Exact-vertical F5 screen-down maps to world +Z")
    verify.call(left.is_finite() and left.x < -0.99,
        "Exact-vertical F5 screen-left maps to world -X")
    verify.call(right.is_finite() and right.x > 0.99,
        "Exact-vertical F5 screen-right maps to world +X")

    verify.call(PolicyScript.quantize_facing(Vector2(0.6, 0.8), 4)
        .is_equal_approx(Vector2.DOWN),
        "Four-way facing snaps to a cardinal direction")
    verify.call(PolicyScript.quantize_facing(Vector2(0.6, 0.8), 8)
        .distance_to(Vector2(1.0, 1.0).normalized()) < 0.01,
        "Eight-way facing accepts diagonal directions")
    verify.call(PolicyScript.quantize_facing(Vector2.ZERO, 4) == Vector2.ZERO,
        "Neutral input never forces a new facing direction")

    adapter.retro_facing = 0
    var four: MoveIntentScript = adapter.compose_intent(Vector2(0.6, 0.8))
    verify.call(four.world_move.distance_to(Vector2(0.6, 0.8)) < 0.01
        and four.face_world.distance_to(Vector2.DOWN) < 0.0001,
        "F5 four-way facing quantization never changes actual movement")
    adapter.retro_facing = 1
    var eight: MoveIntentScript = adapter.compose_intent(Vector2(0.6, 0.8))
    verify.call(eight.face_world.distance_to(Vector2(1, 1).normalized()) < 0.01
        and eight.world_move.is_equal_approx(four.world_move),
        "F5 eight-way facing is independent of physical movement")
    var aimed: MoveIntentScript = adapter.compose_intent(Vector2.RIGHT, Vector2.UP)
    verify.call(aimed.world_move.x > 0.99 and aimed.aim_world.y < -0.99
        and aimed.face_world.y < -0.99,
        "Independent right-stick aiming does not steer or alter movement vector")
    verify.call(InputMap.has_action(&"actor_jump") and InputMap.has_action(&"actor_run")
        and InputMap.has_action(&"actor_dodge") and InputMap.has_action(&"move_left"),
        "Remappable keyboard/gamepad action bindings are registered")

    manager.switch_view(2)
    var iso_up: Vector2 = PolicyScript.to_world(Vector2.UP,
        ViewProfileScript.Mode.ISOMETRIC, manager.get_active_camera().global_basis)
    verify.call(iso_up.is_finite() and iso_up.length() > 0.99,
        "Isometric screen-up camera projection produces finite movement")
    var same_player_id: int = player.get_instance_id()
    var world_pos: Vector3 = player.global_position
    manager.switch_view(0)
    verify.call(player.locomotion.side_lane_locked
        and absf(player.locomotion.side_lane_z - world_pos.z) < 0.0001,
        "Entering F1 captures current Z lane without teleporting")
    manager.switch_view(1)
    verify.call(not player.locomotion.side_lane_locked
        and player.get_instance_id() == same_player_id,
        "Leaving F1 unlocks depth without replacing the actor")
    verify.call(player.global_position.distance_to(world_pos) < 0.0001,
        "Rapid view changes preserve actor world position")

    # Holding one motion input through every camera transition must preserve
    # the single actor's transform/velocity at switch time and obey speed caps.
    adapter.set_physics_process(false)
    var saved_world_transform: Transform3D = player.global_transform
    player.set_move_intent(Vector2.RIGHT)
    for i in range(12):
        await tree.physics_frame
    var speed_limit: float = player.locomotion.run_speed + 0.5
    for index in range(5):
        var current_position: Vector3 = player.global_position
        var current_velocity: Vector3 = player.velocity
        manager.switch_view(index)
        verify.call(player.global_position.distance_to(current_position) < 0.0001,
            "Moving camera switch %d never teleports the actor" % (index + 1))
        verify.call(player.velocity == current_velocity,
            "Moving camera switch %d never changes physical velocity" % (index + 1))
        var held: MoveIntentScript = adapter.compose_intent(Vector2.RIGHT)
        player.apply_move_intent(held)
        await tree.physics_frame
        var planar_speed: float = Vector2(player.velocity.x, player.velocity.z).length()
        verify.call(planar_speed <= speed_limit,
            "Held input across camera %d stays within safe speed cap" % (index + 1))
    player.set_move_intent(Vector2.ZERO)
    player.global_transform = saved_world_transform
    manager.switch_view(1)

    # Input safety: disabled actor and controller disconnect clear pending input.
    adapter.set_enabled(false)
    adapter.require_neutral = false
    var active_intent := MoveIntentScript.new(Vector2.RIGHT, Vector2.RIGHT)
    player.apply_move_intent(active_intent)
    verify.call(player.locomotion.desired.world_move.x > 0.9,
        "Actor forwards intent to the authoritative locomotion state")
    adapter.set_enabled(false)
    verify.call(player.locomotion.desired.world_move.x > 0.9,
        "Repeated disabling is a no-op and does not cancel an AI-supplied intent")
    adapter._on_joy_connection_changed(1, false)
    verify.call(adapter.require_neutral
        and player.locomotion.desired.world_move.is_zero_approx()
        and player.locomotion.desired.requested_moves.is_empty(),
        "Controller disconnect clears authoritative intent and requires neutral")
    adapter._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
    verify.call(not adapter.focus_active and adapter.require_neutral,
        "Focus loss forces neutral input before movement resumes")
    adapter._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
    verify.call(adapter.focus_active, "Focus restore enables future input sampling")
    adapter.set_physics_process(false)

    # Real CharacterBody3D physics exercise on the demo arena and floor.
    var packed := load("res://demo/player.tscn") as PackedScene
    var actor: ActorScript = packed.instantiate() as ActorScript
    level.add_child(actor)
    actor.global_position = Vector3(0.0, 0.25, -5.0)
    for i in range(24):
        await tree.physics_frame
    verify.call(actor.is_on_floor(), "D03 actor lands on Godot's collision floor")

    # A separate actor keeps arbitration tests isolated from movement distances
    # used by the existing walk/run/dodge/slide integration checks.
    await _test_simultaneous_moves(tree, level, verify)

    var starting_x: float = actor.global_position.x
    actor.set_move_intent(Vector2.RIGHT)
    for i in range(28):
        await tree.physics_frame
    verify.call(actor.global_position.x > starting_x + 0.8,
        "Walk intent moves the authoritative CharacterBody3D")
    verify.call(actor.velocity.x > 3.0 and actor.velocity.x <= actor.locomotion.walk_speed + 0.1,
        "Walk velocity accelerates to configured cap")
    var walk_speed: float = actor.velocity.x

    var run_intent := MoveIntentScript.new(Vector2.RIGHT, Vector2.RIGHT)
    run_intent.running = true
    actor.apply_move_intent(run_intent)
    for i in range(20):
        await tree.physics_frame
    verify.call(actor.velocity.x > walk_speed + 0.8 and actor.velocity.x <= actor.locomotion.run_speed + 0.1,
        "Run state increases speed without changing simulation tick")

    actor.set_move_intent(Vector2.ZERO)
    for i in range(30):
        await tree.physics_frame
    verify.call(absf(actor.velocity.x) < 0.05,
        "Deceleration returns horizontal speed to zero")
    verify.call(actor.is_on_floor(), "Actor remains grounded after braking")

    # Same plug-in installed on a second actor: AI/programmatic move requests
    # are interpreted by the registry and solved through one CharacterBody3D.
    var actor_moves = actor.locomotion.move_controller
    var custom = CustomDashScript.new()
    verify.call(actor_moves.add_move(custom),
        "Independent actor installs the test-only move with no solver changes")
    var custom_intent := MoveIntentScript.new(Vector2.RIGHT, Vector2.RIGHT)
    custom_intent.request_move(&"test_dash")
    var before_custom: float = actor.global_position.x
    actor.apply_move_intent(custom_intent)
    verify.call(actor_moves.active_id != &"test_dash",
        "Intent queues the move without changing state outside the physics tick")
    await tree.physics_frame
    verify.call(actor_moves.active_id == &"test_dash" and custom.enter_count == 1,
        "Custom move activates during the physics tick")
    verify.call(actor.velocity.x > actor.locomotion.walk_speed + 1.0,
        "Custom move controls horizontal motion through central physics")
    for i in range(8):
        await tree.physics_frame
    verify.call(custom.exit_count == 1
        and actor_moves.active_id != &"test_dash"
        and actor.global_position.x > before_custom + 0.4,
        "Custom move finishes, exits, and resumes fallback movement state")

    # Move components own their interruption policy; the controller enforces
    # it generically without importing concrete move types.
    custom.allow_exit = false
    actor.apply_move_intent(custom_intent)
    await tree.physics_frame
    verify.call(actor_moves.active_id == &"test_dash",
        "Custom movement can be activated repeatedly")
    var interrupt_cmd := MoveIntentScript.new(Vector2.RIGHT)
    interrupt_cmd.request_move(&"dodge")
    actor.apply_move_intent(interrupt_cmd)
    await tree.physics_frame
    verify.call(actor_moves.active_id == &"test_dash",
        "Component can_exit veto prevents higher-priority interruption")
    custom.allow_exit = true
    actor.apply_move_intent(interrupt_cmd)
    await tree.physics_frame
    verify.call(actor_moves.active_id == &"dodge" and custom.exit_count == 2,
        "Higher-priority dodge interrupts a move that permits exit")
    for i in range(17):
        await tree.physics_frame
    verify.call(actor_moves.active_id != &"dodge",
        "Generic controller restores fallback after interrupting move finishes")

    # Slide is another installed component. The solver never checks a
    # slide flag or imports a Slide class.
    actor.set_move_intent(Vector2.ZERO)
    for i in range(26):
        await tree.physics_frame
    var slide_early := MoveIntentScript.new(Vector2.RIGHT)
    slide_early.request_move(&"slide")
    actor.apply_move_intent(slide_early)
    await tree.physics_frame
    verify.call(actor_moves.active_id != &"slide",
        "Slide component rejects low-speed entry itself")
    actor.set_move_intent(Vector2.RIGHT)
    for i in range(16):
        await tree.physics_frame
    var slide_cmd := MoveIntentScript.new(Vector2.RIGHT, Vector2.RIGHT)
    slide_cmd.request_move(&"slide")
    actor.apply_move_intent(slide_cmd)
    await tree.physics_frame
    verify.call(actor_moves.active_id == &"slide",
        "Slide activates as an exclusive state with no global is_sliding flag")
    var low_priority := MoveIntentScript.new(Vector2.RIGHT)
    low_priority.request_move(&"test_dash")
    actor.apply_move_intent(low_priority)
    await tree.physics_frame
    verify.call(actor_moves.active_id == &"slide",
        "Lower-priority custom move cannot replace an active slide")
    var before_slide: float = actor.global_position.x
    for i in range(12):
        await tree.physics_frame
    verify.call(actor.global_position.x > before_slide + 1.0
        and actor.velocity.x > actor.locomotion.walk_speed + 2.0,
        "Slide produces a fast, collision-solved movement interval")
    for i in range(32):
        await tree.physics_frame
    verify.call(actor_moves.active_id != &"slide",
        "Slide duration ends automatically and restores fallback locomotion")
    actor.set_move_intent(Vector2.ZERO)
    for i in range(30):
        await tree.physics_frame


    var before_jump_y: float = actor.global_position.y
    var jump_intent := MoveIntentScript.new()
    jump_intent.jump_pressed = true
    actor.apply_move_intent(jump_intent)
    for i in range(3):
        await tree.physics_frame
    verify.call(actor.global_position.y > before_jump_y + 0.05 and actor.velocity.y > 0.0,
        "Jump launches the same 3D actor above the physical floor")
    actor.set_move_intent(Vector2.ZERO)
    for i in range(85):
        await tree.physics_frame
    verify.call(actor.is_on_floor() and actor.global_position.y < before_jump_y + 0.12,
        "Gravity and floor snap return actor to the floor after jump")

    actor.global_position = Vector3(0.0, 0.2, -5.0)
    actor.set_move_intent(Vector2.ZERO)
    for i in range(12):
        await tree.physics_frame
    var before_dodge: float = actor.global_position.x
    var dodge := MoveIntentScript.new(Vector2.RIGHT, Vector2.RIGHT)
    dodge.request_move(&"dodge")
    actor.apply_move_intent(dodge)
    await tree.physics_frame
    verify.call(actor.velocity.x > actor.locomotion.walk_speed + 2.0,
        "Dodge action creates an immediate configurable movement burst")
    for i in range(8):
        await tree.physics_frame
    verify.call(actor.global_position.x > before_dodge + 0.7,
        "Dodge burst visibly changes actor position using real physics")
    actor.set_move_intent(Vector2.ZERO)
    for i in range(30):
        await tree.physics_frame
    verify.call(absf(actor.velocity.x) < 0.05,
        "Dodge finishes and normal deceleration resumes")

    # Proof of extensibility beyond planar motion: a test-only vertical
    # move gets authoritative Y velocity and gravity control through the
    # same MoveContext, without touching the solver or player script.
    actor.global_position = Vector3(0.0, 0.2, -5.0)
    actor.set_move_intent(Vector2.ZERO)
    for i in range(12):
        await tree.physics_frame
    var climb = CustomClimbScript.new()
    # AI-only ability: no keyboard/gamepad action should be necessary to stay active.
    climb.action_name = &""
    verify.call(actor_moves.add_move(climb),
        "Independent climbing component installs without core code changes")
    var climb_request := MoveIntentScript.new()
    climb_request.request_move(&"test_climb")
    var climb_start_y: float = actor.global_position.y
    actor.apply_move_intent(climb_request)
    verify.call(actor_moves.active_id != &"test_climb",
        "AI-only ability waits until the next physics tick")
    await tree.physics_frame
    verify.call(actor_moves.active_id == &"test_climb" and climb.enter_count == 1,
        "Custom vertical move activates through the generic controller")
    verify.call(actor.velocity.x > 5.0,
        "Entry-time horizontal command survives and reaches the physics solver")
    for i in range(1):
        await tree.physics_frame
    verify.call(actor_moves.active_id == &"test_climb" and climb.ticks > 0,
        "AI-only move without action_name remains active and executes physics ticks")
    for i in range(6):
        await tree.physics_frame
    verify.call(actor.global_position.y > climb_start_y + 0.25
        and actor.velocity.y > 2.8,
        "Plug-in controls real Y velocity and disables gravity without solver branches")
    for i in range(12):
        await tree.physics_frame
    verify.call(actor_moves.active_id == &"airborne",
        "Input-unbound climb finishes and transitions to the airborne fallback")
    actor.set_move_intent(Vector2.ZERO)
    for i in range(90):
        await tree.physics_frame
    verify.call(actor.is_on_floor() and actor_moves.active_id == &"grounded",
        "AI-only climb completion restores gravity and grounded fallback after landing")

    actor.global_position = Vector3(0.0, 0.18, -4.0)
    actor.enter_side_view()
    var lane: float = actor.global_position.z
    actor.set_move_intent(Vector2(1.0, 0.8))
    for i in range(30):
        await tree.physics_frame
    verify.call(absf(actor.global_position.z - lane) < 0.005,
        "F1 depth lane remains fixed during diagonal world input")
    verify.call(actor.locomotion.side_lane_locked,
        "F1 lane lock remains active during physics updates")
    actor.exit_side_view()
    verify.call(not actor.locomotion.side_lane_locked and absf(actor.global_position.z - lane) < 0.005,
        "Leaving F1 releases lane constraint without a position snap")

    actor.global_position = Vector3(12.3, 0.2, -5.0)
    actor.set_move_intent(Vector2.RIGHT)
    for i in range(100):
        await tree.physics_frame
    verify.call(actor.global_position.x <= 13.5,
        "CharacterBody3D cannot pass through outer arena wall")
    verify.call(level.get_node("Ramp/CollisionShape3D") is CollisionShape3D
        and level.get_node("LowStep/CollisionShape3D") is CollisionShape3D,
        "Shared D03 arena contains a physical slope and low step")
    verify.call(actor.locomotion.floor_snap_distance > 0.0
        and actor.floor_max_angle >= deg_to_rad(40.0),
        "Locomotion uses physical floor snap and slope limit")
    actor.global_position = Vector3(-11.0, 0.25, 4.0)
    actor.set_move_intent(Vector2.RIGHT)
    for i in range(55):
        await tree.physics_frame
    verify.call(actor.global_position.x > -9.5 and actor.global_position.y > 0.19,
        "Actor walks onto real sloped floor collider")
    actor.global_position = Vector3(-6.0, 0.20, 4.0)
    actor.set_move_intent(Vector2.RIGHT)
    var step_peak_y: float = actor.global_position.y
    var step_landed: bool = false
    for i in range(85):
        await tree.physics_frame
        step_peak_y = maxf(step_peak_y, actor.global_position.y)
        if actor.global_position.x > -4.3 and actor.global_position.x < -3.7:
            step_landed = step_landed or (
                actor.is_on_floor() and absf(actor.global_position.y - 0.30) < 0.05
            )
    verify.call(actor.global_position.x > -3.0,
        "Collision-checked step assist climbs a low physical obstacle")
    verify.call(step_landed,
        "Low step provides a confirmed walkable landing at its real height")
    verify.call(step_peak_y <= 0.34,
        "Step assist rises only to the landing, never the full 0.35m step allowance")
    actor.set_move_intent(Vector2.ZERO)
    actor.set_alive(false)
    var disabled_x: float = actor.global_position.x
    actor.set_move_intent(Vector2.LEFT)
    for i in range(8):
        await tree.physics_frame
    verify.call(absf(actor.global_position.x - disabled_x) < 0.02,
        "Disabled/dead actor ignores movement even with new input")
    actor.set_alive(true)
    actor.set_controls_enabled(true)
    verify.call(actor.alive and actor.controls_enabled, "Actor can be re-enabled without replacement")
    var camera_basis_before: Basis = manager.get_active_camera().global_basis
    actor.facing.set_facing(Vector2.RIGHT)
    await tree.process_frame
    verify.call(manager.get_active_camera().global_basis.is_equal_approx(camera_basis_before),
        "Abrupt visual facing turns never rotate or jitter the camera rig")
    actor.set_controls_enabled(false)
    verify.call(not actor.locomotion.enabled
        and actor.locomotion.desired.world_move.is_zero_approx(),
        "Disabling actor controls clears the authoritative locomotion intent")
    actor.set_move_intent(Vector2.RIGHT)
    verify.call(actor.locomotion.desired.world_move.is_zero_approx()
        and actor.locomotion.desired.requested_moves.is_empty(),
        "Disabled actor rejects new movement without queuing it")
    actor.set_controls_enabled(true)

    # A pending request must not accidentally activate a newly installed
    # move with the same ID after the old instance was removed.
    var lifecycle_id: StringName = &"test_lifecycle"
    var removed_actor_ids: Array[StringName] = []
    actor_moves.move_unregistered.connect(
        func(id: StringName) -> void: removed_actor_ids.append(id)
    )
    var old_move = CustomDashScript.new()
    old_move.move_id = lifecycle_id
    verify.call(actor_moves.add_move(old_move),
        "Lifecycle move registers dynamically")
    var lifecycle_intent := MoveIntentScript.new(Vector2.RIGHT)
    lifecycle_intent.request_move(lifecycle_id)
    actor.apply_move_intent(lifecycle_intent)
    actor_moves.moves_root.remove_child(old_move)
    verify.call(actor_moves.get_move(lifecycle_id) == null
        and removed_actor_ids == [lifecycle_id],
        "Removing an inactive move clears its registry and pending request")
    old_move.free()

    var replacement_move = CustomDashScript.new()
    replacement_move.move_id = lifecycle_id
    verify.call(actor_moves.add_move(replacement_move),
        "A replacement may reuse an unregistered movement ID")
    actor.set_move_intent(Vector2.RIGHT)
    await tree.physics_frame
    verify.call(replacement_move.enter_count == 0
        and actor_moves.active_id != lifecycle_id,
        "Pending request for a removed component cannot activate its replacement")

    actor.apply_move_intent(lifecycle_intent)
    await tree.physics_frame
    verify.call(actor_moves.active_id == lifecycle_id
        and replacement_move.enter_count == 1,
        "An explicit new request activates the replacement on a physics tick")
    actor_moves.moves_root.remove_child(replacement_move)
    verify.call(actor_moves.active_id == &""
        and replacement_move.exit_count == 1
        and actor_moves.get_move(lifecycle_id) == null
        and removed_actor_ids == [lifecycle_id, lifecycle_id],
        "Detaching an active move forces exit and clears the active FSM reference")
    replacement_move.free()
    await tree.physics_frame
    verify.call(actor_moves.active_id == &"grounded"
        or actor_moves.active_id == &"airborne",
        "FSM selects a valid fallback on the tick following active move removal")

    # Freeing a component while it is still under Moves must also unregister.
    var freed_move = CustomDashScript.new()
    freed_move.move_id = &"test_freed"
    verify.call(actor_moves.add_move(freed_move), "Move slated for deletion registers")
    freed_move.queue_free()
    await tree.process_frame
    await tree.physics_frame
    verify.call(actor_moves.get_move(&"test_freed") == null
        and removed_actor_ids.has(&"test_freed"),
        "queue_free unregisters the component rather than leaving a dangling entry")

    actor.queue_free()
    adapter.set_enabled(true)
    adapter.set_physics_process(true)
    manager.switch_view(1)


## Multiple requests in one intent must cause one deterministic FSM transition.
## Check reversed input order, priority ties and a rejected top candidate.
func _test_simultaneous_moves(tree: SceneTree, level: Node3D, verify: Callable) -> void:
    var packed := load("res://demo/player.tscn") as PackedScene
    var actor: ActorScript = packed.instantiate() as ActorScript
    level.add_child(actor)
    actor.global_position = Vector3(0.0, 0.25, -6.5)
    for i in range(20):
        await tree.physics_frame
    verify.call(actor.is_on_floor(), "Arbitration fixture actor is grounded")

    var moves = actor.locomotion.move_controller
    var low = CustomDashScript.new()
    low.move_id = &"test_low"
    low.priority = 20
    low.action_name = &""
    var high = CustomDashScript.new()
    high.move_id = &"test_high"
    high.priority = 60
    high.action_name = &""
    var alpha = CustomDashScript.new()
    alpha.move_id = &"test_alpha"
    alpha.priority = 40
    alpha.action_name = &""
    var beta = CustomDashScript.new()
    beta.move_id = &"test_beta"
    beta.priority = 40
    beta.action_name = &""
    var rejected = CustomDashScript.new()
    rejected.move_id = &"test_rejected"
    rejected.priority = 90
    rejected.action_name = &""
    rejected.allow_enter = false
    # Register beta before alpha to prove tie-breaking ignores registration order.
    for move in [low, high, beta, alpha, rejected]:
        verify.call(moves.add_move(move),
            "Arbitration fixture registers move %s" % move.move_id)

    var transitions: Array[StringName] = []
    moves.move_changed.connect(
        func(_previous: StringName, current: StringName) -> void:
            transitions.append(current)
    )
    var cases: Array[Dictionary] = [
        {"requests": [&"test_low", &"test_high"], "winner": high, "loser": low},
        {"requests": [&"test_high", &"test_low"], "winner": high, "loser": low},
        {"requests": [&"test_beta", &"test_alpha"], "winner": alpha, "loser": beta},
        {"requests": [&"test_alpha", &"test_beta"], "winner": alpha, "loser": beta},
        {"requests": [&"test_rejected", &"test_low"], "winner": low, "loser": rejected},
    ]
    for case_index in range(cases.size()):
        var entry: Dictionary = cases[case_index]
        var winning_move: Node = entry["winner"]
        var losing_move: Node = entry["loser"]
        var winning_id: StringName = winning_move.get("move_id")
        var winner_enters_before: int = int(winning_move.get("enter_count"))
        var loser_enters_before: int = int(losing_move.get("enter_count"))
        var events_before: int = transitions.size()
        var command := MoveIntentScript.new(Vector2.RIGHT, Vector2.RIGHT)
        for id in entry["requests"]:
            command.request_move(id)
        actor.apply_move_intent(command)
        await tree.physics_frame
        verify.call(moves.active_id == winning_id
            and int(winning_move.get("enter_count")) == winner_enters_before + 1
            and int(losing_move.get("enter_count")) == loser_enters_before,
            "Batch %d activates only the highest eligible deterministic winner" % case_index)
        verify.call(transitions.size() == events_before + 1
            and transitions.back() == winning_id,
            "Batch %d produces exactly one requested move_changed event" % case_index)

        actor.set_move_intent(Vector2.ZERO)
        for i in range(8):
            await tree.physics_frame
        verify.call(moves.active_id == &"grounded",
            "Batch %d returns to grounded fallback after its move ends" % case_index)

    actor.queue_free()
    await tree.process_frame
