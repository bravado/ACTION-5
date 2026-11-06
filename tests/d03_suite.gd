extends RefCounted
## D03 real physics + input-map regression suite; called from tests/run_all.gd.

const MoveIntentScript = preload("res://addons/action5/actor/move_intent.gd")
const PolicyScript = preload("res://addons/action5/actor/movement_policy.gd")
const ActorScript = preload("res://addons/action5/actor/action_actor.gd")
const ViewProfileScript = preload("res://addons/action5/camera/view_profile.gd")
const AdapterScript = preload("res://addons/action5/input/actor_input_adapter.gd")


func run_tests(tree: SceneTree, level: Node3D, verify: Callable) -> void:
    var manager = level.get_node("ViewManager")
    var adapter: AdapterScript = level.get_node("ActorInput")
    var player: ActorScript = level.get_node("Player")

    verify.call(adapter != null and player != null, "D03 reusable actor/input adapter available")
    verify.call(player.get_node("Locomotion") != null and player.get_node("Visual") != null,
        "Locomotion and facing are independent actor components")

    verify.call(PolicyScript.deadzone(Vector2(0.10, 0.0), 0.20).is_zero_approx(),
        "Analogue stick drift is ignored by the configurable deadzone")
    verify.call(PolicyScript.deadzone(Vector2.RIGHT, 0.2).is_equal_approx(Vector2.RIGHT),
        "Full input remains full speed after deadzone removal")
    verify.call(PolicyScript.deadzone(Vector2(0.3, 0.0), 0.2).x > 0.1,
        "Intermediate analogue input is rescaled continuously")
    verify.call(PolicyScript.deadzone(Vector2(INF, 0.0)).is_zero_approx(),
        "Non-finite controller input cannot cause NaN movement")

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
    verify.call(player.get("_planar_intent").x > 0.9,
        "Actor accepts intents independently of physical key events")
    adapter._on_joy_connection_changed(1, false)
    verify.call(adapter.require_neutral
        and (player.get("_planar_intent") as Vector2).length() < 0.001,
        "Controller disconnect cancels held movement and requires neutral")
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
    dodge.dodge_pressed = true
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
    for i in range(85):
        await tree.physics_frame
    verify.call(actor.global_position.x > -3.0,
        "Collision-checked step assist climbs a low physical obstacle")
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
    verify.call((actor.get("_planar_intent") as Vector2) == Vector2.ZERO,
        "Disabling actor controls clears cached planar intent")
    actor.set_move_intent(Vector2.RIGHT)
    verify.call((actor.get("_planar_intent") as Vector2) == Vector2.ZERO,
        "Disabled actor rejects new intent without caching it")
    actor.set_controls_enabled(true)

    actor.queue_free()
    adapter.set_enabled(true)
    adapter.set_physics_process(true)
    manager.switch_view(1)
