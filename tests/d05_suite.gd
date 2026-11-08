extends RefCounted
## D05 integration test: real bodies/areas, timelines, damage and input gates.

const CombatScript = preload("res://addons/action5/combat/combat_controller.gd")
const HealthScript = preload("res://addons/action5/combat/health.gd")
const AttackScript = preload("res://addons/action5/combat/attack_definition.gd")
const AimScript = preload("res://addons/action5/combat/aim_provider.gd")
const CombatInputScript = preload("res://addons/action5/combat/combat_input_adapter.gd")
const ViewProfileScript = preload("res://addons/action5/camera/view_profile.gd")
const ActionContextScript = preload("res://addons/action5/input/action_input_context.gd")
const TestContextProviderScript = preload("res://tests/fixtures/action_input_context_source.gd")


func run_tests(tree: SceneTree, level: Node3D, verify: Callable) -> void:
    var actor = level.get_node("Player")
    var views = level.get_node("ViewManager")
    var adapter = level.get_node("ActorInput")
    var combat: CombatScript = actor.get_node("CombatController") as CombatScript
    var health: HealthScript = actor.get_node("Health") as HealthScript
    var input: CombatInputScript = level.get_node("CombatInput") as CombatInputScript
    var near: Node3D = level.get_node("NearDummy") as Node3D
    var far: Node3D = level.get_node("FarDummy") as Node3D
    var target: HealthScript = near.get_node("Health") as HealthScript

    verify.call(combat != null and health != null and input != null,
        "D05 combat, health and input are independent actor components")

    # Health cannot assume an Actor parent or a Locomotion sibling. A
    # plain Node with Health alone must be a complete, usable receiver.
    var standalone_host := Node.new()
    standalone_host.name = "IndependentHealthFixture"
    var standalone_health: HealthScript = HealthScript.new()
    standalone_health.name = "Health"
    standalone_host.add_child(standalone_health)
    level.add_child(standalone_host)
    var observed_impulses: Array[Vector2] = []
    var observed_ticks: Array[int] = []
    var observed_deaths: Array[Node] = []
    standalone_health.knockback_requested.connect(
        func(velocity: Vector2, ticks: int) -> void:
            observed_impulses.append(velocity)
            observed_ticks.append(ticks)
    )
    standalone_health.died.connect(
        func(source: Node) -> void:
            observed_deaths.append(source)
    )
    var accepted_standalone: bool = standalone_health.take_hit(
        5.0, near, null, Vector2(3.0, 4.0), 5.0, 9
    )
    verify.call(accepted_standalone and is_equal_approx(
        standalone_health.current_health, standalone_health.max_health - 5.0
    ) and observed_impulses.size() == 1
        and observed_impulses[0].distance_to(Vector2(3.0, 4.0)) < 0.001
        and observed_ticks == [9],
        "Standalone Health accepts damage and emits a normalized knockback command")
    var lethal_standalone: bool = standalone_health.take_hit(
        999.0, near, null, Vector2.RIGHT, 9.0, 15
    )
    verify.call(lethal_standalone and standalone_health.current_health == 0.0
        and observed_deaths.size() == 1 and observed_deaths[0] == near
        and observed_impulses.size() == 1
        and not standalone_health.take_hit(1.0, near, null, Vector2.RIGHT, 9.0, 15),
        "Lethal Health emits death exactly once, never queues knockback, and rejects further hits")
    standalone_host.queue_free()
    verify.call(combat.get_attack(&"punch") != null and combat.get_attack(&"kick") != null,
        "D05 imported Punch and Kick are configured resources")
    verify.call(combat.get_attack(&"punch").animation_channel == 0
        and combat.get_attack(&"kick").animation_channel == 1,
        "Punch uses upper-body channel and Kick uses full-body channel")
    verify.call(InputMap.has_action(&"actor_punch") and InputMap.has_action(&"actor_kick")
        and not InputMap.action_get_events(&"actor_punch").is_empty()
        and not InputMap.action_get_events(&"actor_kick").is_empty(),
        "Combat inputs are registered from attack configuration, not Actor code")
    # Per-attack mouse defaults preserve keyboard mappings.
    var punch_events: Array[InputEvent] = InputMap.action_get_events(&"actor_punch")
    var kick_events: Array[InputEvent] = InputMap.action_get_events(&"actor_kick")
    var punch_mouse: bool = false
    var kick_mouse: bool = false
    var punch_key: bool = false
    var kick_key: bool = false
    for event in punch_events:
        if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
            punch_mouse = true
        if event is InputEventKey and event.keycode == KEY_J:
            punch_key = true
    for event in kick_events:
        if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
            kick_mouse = true
        if event is InputEventKey and event.keycode == KEY_K:
            kick_key = true
    # Input arrives before GUI; only unhandled mouse clicks can become
    # combat commands. This also covers a click released before physics.
    var pointer := InputEventMouseButton.new()
    pointer.button_index = MOUSE_BUTTON_LEFT
    pointer.pressed = true
    input._input(pointer)
    verify.call(input._pressed_mouse_edges.has(&"actor_punch")
        and not input._unhandled_mouse_edges.has(&"actor_punch"),
        "A GUI-consumed left-click is classified as blocked, even if released quickly")
    input._unhandled_input(pointer)
    verify.call(input._unhandled_mouse_edges.has(&"actor_punch"),
        "An unhandled left-click is classified as a valid combat input")
    input._pressed_mouse_edges.clear()
    input._unhandled_mouse_edges.clear()

    verify.call(punch_mouse and kick_mouse and punch_key and kick_key,
        "Punch/Kick bind left/right mouse alongside original J/K defaults")
    verify.call(combat.get_attack(&"punch").default_mouse_button == MOUSE_BUTTON_LEFT
        and combat.get_attack(&"kick").default_mouse_button == MOUSE_BUTTON_RIGHT,
        "Mouse mappings belong to attack resources, not core classes")

    # Existing InputMap entries are user mappings and must not be replaced.
    var custom_action: StringName = &"actor_test_custom_mouse"
    if not InputMap.has_action(custom_action):
        InputMap.add_action(custom_action)
    var custom_key := InputEventKey.new()
    custom_key.keycode = KEY_U
    InputMap.action_add_event(custom_action, custom_key)
    var custom_attack: AttackScript = AttackScript.new()
    custom_attack.attack_id = &"test_custom_mouse"
    custom_attack.input_action = custom_action
    custom_attack.default_mouse_button = MOUSE_BUTTON_LEFT
    input.register_action(custom_attack)
    var custom_events: Array[InputEvent] = InputMap.action_get_events(custom_action)
    verify.call(custom_events.size() == 1 and custom_events[0] is InputEventKey,
        "User-rebound attack mapping is preserved when mouse defaults register")
    InputMap.erase_action(custom_action)

    verify.call(actor.get_node("Hurtbox").get_health() == health
        and near.get_node("HeadHurtbox").get_health() == target
        and near.get_node("Hurtbox").get_health() == target,
        "Several independently shaped hurtboxes resolve to one health component")

    var third: AttackScript = AttackScript.new()
    third.attack_id = &"test_elbow"
    third.input_action = &"actor_test_elbow"
    third.default_key = KEY_L
    third.startup_ticks = 0
    third.active_ticks = 2
    third.recovery_ticks = 1
    third.damage = 7
    third.hitbox_size = Vector3(0.9, 1.0, 0.95)
    third.hitbox_forward = 0.8
    third.animation_key = &"punch"
    third.knockback_speed = 0.0
    verify.call(combat.register_attack(third)
        and combat.get_attack(&"test_elbow") == third,
        "Third independently defined attack registers without any core modification")
    verify.call(not combat.register_attack(third) and not combat.request_attack(&"unknown"),
        "Duplicate and unknown attack IDs fail safely")
    verify.call(InputMap.has_action(&"actor_test_elbow")
        and not InputMap.action_get_events(&"actor_test_elbow").is_empty(),
        "Runtime third attack registers its own default input with no input-adapter edit")

    # 3D camera rays retain vertical information; F5 never projects camera
    # forward onto the ground plane at exact overhead pitch.
    views.switch_view(3)
    var ray: Dictionary = AimScript.camera_ray(views.get_active_camera())
    verify.call(ray.has("origin") and ray.has("direction")
        and (ray["direction"] as Vector3).length() > 0.99,
        "First-person aim exposes a world-space 3D origin and ray")
    var fps_dir: Vector2 = AimScript.resolve_direction(
        Vector2.ZERO, Vector2.RIGHT, ViewProfileScript.Mode.FIRST_PERSON,
        views.get_active_camera()
    )
    verify.call(fps_dir.is_finite() and fps_dir.length() > 0.99,
        "F4 fallback resolves a finite camera-based attack direction")
    var four: Vector2 = AimScript.resolve_direction(
        Vector2(0.8, -0.4), Vector2.ZERO, ViewProfileScript.Mode.RETRO_TOPDOWN, null, 4
    )
    var eight: Vector2 = AimScript.resolve_direction(
        Vector2(0.8, -0.4), Vector2.ZERO, ViewProfileScript.Mode.RETRO_TOPDOWN, null, 8
    )
    verify.call(four == Vector2.RIGHT and eight != four
        and eight.length() > 0.99,
        "F5 configurable cardinal/diagonal combat facing leaves world movement independent")
    verify.call(not AimScript.resolve_direction(
        Vector2(INF, 0), Vector2.ZERO, ViewProfileScript.Mode.BEATEMUP
    ).is_zero_approx(), "Bad aim input falls back to a finite direction")

    actor.set_alive(true)
    actor.set_controls_enabled(true)
    adapter.set_enabled(true)
    combat.cancel()
    # Input-source contract: combat reads only this generic typed snapshot,
    # never actor_adapter.actor.locomotion or facing internals. A completely
    # different source can be injected without changing combat or the actor.
    var real_input_source: Node = input.context_source
    var live_snapshot: ActionContextScript = adapter.get_action_input_context()
    verify.call(input.context_source == adapter
        and live_snapshot != null and live_snapshot.camera == views.get_active_camera()
        and live_snapshot.view_mode == views.current_profile.mode,
        "ActorInput publishes camera/view context through the stable action snapshot")
    var substitute_source: Node = TestContextProviderScript.new()
    substitute_source.name = "MockActionInputContext"
    level.add_child(substitute_source)
    substitute_source.set("snapshot", ActionContextScript.new(
        true, Vector2.RIGHT, Vector2.UP, ViewProfileScript.Mode.BEATEMUP,
        views.get_active_camera()
    ))
    input.context_source = substitute_source
    input.release_to_rearm = false
    combat.cancel()
    Input.action_press(&"actor_punch")
    input._physics_process(1.0 / 60.0)
    Input.action_release(&"actor_punch")
    verify.call(combat._pending_id == &"punch"
        and combat._pending_direction.distance_to(Vector2.RIGHT) < 0.001,
        "Combat uses a replaceable context provider for its world-space aim")
    combat.cancel()

    # A provider that denies input, or a missing provider, must fail closed
    # and never replay a held attack when the real source comes back.
    substitute_source.set("snapshot", ActionContextScript.new(
        false, Vector2.RIGHT, Vector2.UP, ViewProfileScript.Mode.BEATEMUP,
        views.get_active_camera()
    ))
    Input.action_press(&"actor_kick")
    input._physics_process(1.0 / 60.0)
    Input.action_release(&"actor_kick")
    verify.call(combat._pending_id == &"" and input.release_to_rearm,
        "ActionContext denying controls blocks attacks and requires release")
    input.context_source = null
    input._physics_process(1.0 / 60.0)
    verify.call(combat._pending_id == &"" and input.release_to_rearm,
        "Missing input context fails closed without exposing core internals")
    input.context_source = real_input_source
    input._physics_process(1.0 / 60.0)
    verify.call(not input.release_to_rearm and combat._pending_id == &"",
        "Restoring the original context provider rearms with no stale attack")
    substitute_source.queue_free()

    var punch: AttackScript = combat.get_attack(&"punch")
    var phase_changes: Array[String] = []
    var events: Array[StringName] = []
    combat.attack_phase_changed.connect(func(id: StringName, value: StringName, tick: int) -> void:
        if id == &"punch":
            phase_changes.append("%s:%d" % [value, tick])
    )
    combat.attack_hit.connect(func(id: StringName, _victim: Node) -> void:
        events.append(id)
    )

    # For each mode, force the same actor/target geometry. View changes must
    # not reset the actor's authoritative attack clock or collision query.
    for mode_index in range(5):
        views.switch_view(mode_index)
        actor.global_position = Vector3(0.0, 0.15, 0.0)
        actor.velocity = Vector3.ZERO
        actor.clear_motion()
        near.global_position = Vector3(0.0, 0.0, -1.0)
        far.global_position = Vector3(4.0, 0.0, -5.0)
        target.current_health = target.max_health
        target.team_id = 2
        target.immune = false
        target.blocking = false
        target.invulnerability_left = 0
        await tree.physics_frame
        await tree.physics_frame
        var before_events: int = events.size()
        verify.call(combat.request_attack(&"punch", Vector2(0.0, -1.0)),
            "D05 mode %d accepts punch independent of camera" % (mode_index + 1))
        for tick in range(punch.total_ticks() + 3):
            await tree.physics_frame
        verify.call(is_equal_approx(target.current_health, target.max_health - punch.damage)
            and events.size() == before_events + 1,
            "D05 mode %d punches adjacent multi-hurtbox target exactly once" % (mode_index + 1))
        verify.call(combat.current_attack == null,
            "D05 mode %d attack finishes without visual-state coupling" % (mode_index + 1))

    verify.call(phase_changes.has("startup:0")
        and phase_changes.has("active:%d" % punch.startup_ticks)
        and phase_changes.has("recovery:%d" % (punch.startup_ticks + punch.active_ticks)),
        "Startup/active/recovery occur on exact configured physics tick indices")

    # A real Run+Punch must leave the base locomotion playback running.
    # Kick uses a full-body override but never changes airborne physics.
    var animation: Node = actor.get_node("AnimationPresenter")
    views.switch_view(1)
    actor.global_position = Vector3(0, 0.15, 0)
    actor.velocity = Vector3.ZERO
    actor.clear_motion()
    near.global_position = Vector3(0, 0, -5.0)
    Input.action_press(&"move_right")
    Input.action_press(&"actor_run")
    for tick in range(25):
        await tree.physics_frame
    verify.call(animation.get("base_clip") == &"run" and actor.velocity.x > 6.0,
        "Actor is actually running before the combat overlay starts")
    combat.request_attack(&"punch", Vector2.RIGHT)
    for tick in range(3):
        await tree.physics_frame
    verify.call(combat.current_id == &"punch"
        and animation.get("base_clip") == &"run"
        and animation.get("upper_body_clip") == &"punch",
        "Run+Punch uses independent base and upper-body animation channels")
    views.switch_view(2)
    verify.call(combat.current_id == &"punch"
        and animation.get("upper_body_clip") == &"punch",
        "F3 switch during Run+Punch leaves the same action and overlay active")
    Input.action_release(&"move_right")
    Input.action_release(&"actor_run")
    for tick in range(punch.total_ticks() + 3):
        await tree.physics_frame
    verify.call(animation.get("upper_body_clip") == &"",
        "Combat clears its upper-body override after final recovery")

    # Re-ground the player and issue the original jump input through D03.
    views.switch_view(1)
    actor.global_position = Vector3(0, 0.15, 0)
    actor.velocity = Vector3.ZERO
    actor.clear_motion()
    for tick in range(12):
        await tree.physics_frame
    Input.action_press(&"actor_jump")
    for tick in range(3):
        await tree.physics_frame
    Input.action_release(&"actor_jump")
    verify.call(actor.velocity.y > 0.0,
        "Real input and authoritative solver produce airborne movement")
    combat.request_attack(&"kick", Vector2.RIGHT)
    for tick in range(3):
        await tree.physics_frame
    verify.call(combat.current_id == &"kick"
        and animation.get("action_clip") == &"kick",
        "Jump+Kick selects a full-body clip without owning vertical velocity")
    views.switch_view(3)
    verify.call(combat.current_id == &"kick"
        and animation.get("action_clip") == &"kick",
        "F4 preserves Jump+Kick action clock, not a recreated actor")
    for tick in range(combat.get_attack(&"kick").total_ticks() + 3):
        await tree.physics_frame
    verify.call(animation.get("action_clip") == &"",
        "Kick clears the full-body animation on its own tick-based completion")
    actor.global_position = Vector3(0, 0.15, 0)
    actor.velocity = Vector3.ZERO
    actor.clear_motion()

    # A render FPS cap changes neither the fixed 60 Hz combat phase indices
    # nor the number of active hit-query ticks.
    var previous_fps: int = Engine.max_fps
    for fps in [30, 60, 120]:
        Engine.max_fps = fps
        var observed: Array[String] = []
        var callback := func(id: StringName, value: StringName, tick: int) -> void:
            if id == &"test_elbow":
                observed.append("%s:%d" % [value, tick])
        combat.attack_phase_changed.connect(callback)
        combat.request_attack(&"test_elbow", Vector2.RIGHT)
        for tick in range(third.total_ticks() + 4):
            await tree.physics_frame
        combat.attack_phase_changed.disconnect(callback)
        verify.call(observed.has("active:0") and observed.has("recovery:2")
            and combat.current_attack == null,
            "D05 at render FPS %d preserves exact 60Hz active/recovery tick boundaries" % fps)
    Engine.max_fps = previous_fps

    # The second action buffers while the first is active. Its own timeline
    # begins after the first recovery, never as a mid-attack replacement.
    var started: Array[StringName] = []
    combat.attack_started.connect(func(id: StringName) -> void:
        started.append(id)
    )
    near.global_position = Vector3(0, 0, -4)
    combat.request_attack(&"punch", Vector2(0, -1))
    for tick in range(3):
        await tree.physics_frame
    verify.call(combat.current_id == &"punch"
        and combat.request_attack(&"kick", Vector2(0, -1))
        and combat._pending_id == &"kick",
        "An attack may buffer one configured follow-up without cancelling its active timeline")
    for tick in range(punch.total_ticks() + combat.get_attack(&"kick").total_ticks() + 5):
        await tree.physics_frame
    verify.call(started.size() >= 2
        and started[started.size() - 2] == &"punch"
        and started[started.size() - 1] == &"kick"
        and combat.current_attack == null,
        "Buffered attack starts after prior recovery and completes independently")

    # Move target outside both action boxes; independent camera changes must
    # never turn a range miss into a collision hit.
    near.global_position = Vector3(0.0, 0.0, -4.0)
    await tree.physics_frame
    var previous_health: float = target.current_health
    verify.call(combat.request_attack(&"kick", Vector2(0.0, -1.0)),
        "Kick can start independently of Punch")
    for tick in range(combat.get_attack(&"kick").total_ticks() + 2):
        await tree.physics_frame
    verify.call(is_equal_approx(target.current_health, previous_health),
        "Out-of-range kick misses, regardless of camera")

    near.global_position = Vector3(0.0, 0.0, -1.0)
    await tree.physics_frame
    target.team_id = health.team_id
    previous_health = target.current_health
    combat.request_attack(&"test_elbow", Vector2(0.0, -1.0))
    for tick in range(third.total_ticks() + 3):
        await tree.physics_frame
    verify.call(is_equal_approx(target.current_health, previous_health),
        "Combat rejects same-team hits by default")
    target.team_id = 2
    target.blocking = true
    combat.request_attack(&"test_elbow", Vector2(0.0, -1.0))
    for tick in range(third.total_ticks() + 3):
        await tree.physics_frame
    verify.call(is_equal_approx(target.current_health, previous_health),
        "Blocking hook prevents damage")
    target.blocking = false
    target.immune = true
    combat.request_attack(&"test_elbow", Vector2(0.0, -1.0))
    for tick in range(third.total_ticks() + 3):
        await tree.physics_frame
    verify.call(is_equal_approx(target.current_health, previous_health),
        "Immunity hook prevents damage")
    target.immune = false
    combat.request_attack(&"test_elbow", Vector2(0.0, -1.0))
    for tick in range(third.total_ticks() + 3):
        await tree.physics_frame
    verify.call(is_equal_approx(target.current_health, previous_health - third.damage),
        "Third attack hitbox and damage come entirely from its data")

    # An active attack survives switching modes with no duplicate hit; the
    # action controller does not subscribe to the ViewManager.
    target.current_health = 100.0
    near.global_position = Vector3(0.0, 0.0, -1.0)
    await tree.physics_frame
    var actor_id: int = actor.get_instance_id()
    combat.request_attack(&"kick", Vector2(0.0, -1.0))
    for tick in range(combat.get_attack(&"kick").total_ticks() + 3):
        views.switch_view(tick % 5)
        await tree.physics_frame
    verify.call(is_equal_approx(target.current_health, 100.0 - combat.get_attack(&"kick").damage)
        and actor.get_instance_id() == actor_id,
        "Switches during active Kick preserve exactly-once hit and player identity")

    # Health does not know about actors or locomotion. The optional actor
    # bridge forwards its event to the single movement solver. Verify it
    # really disconnects on removal and can reconnect after reattachment.
    var health_bridge: Node = actor.get_node_or_null("HealthActorAdapter")
    verify.call(health_bridge != null and health.knockback_requested.is_connected(
        Callable(health_bridge, "_on_knockback_requested")
    ) and health.died.is_connected(Callable(health_bridge, "_on_died")),
        "HealthActorAdapter subscribes independently to Health's public events")
    if health_bridge != null:
        actor.clear_motion()
        actor.remove_child(health_bridge)
        health.current_health = 100.0
        health.invulnerability_left = 0
        var orphan_damage: bool = health.take_hit(
            1.0, near, punch, Vector2.RIGHT, 5.0, 12
        )
        verify.call(orphan_damage and health.current_health == 99.0
            and actor.locomotion._impulse_ticks_left == 0
            and not health.knockback_requested.is_connected(
                Callable(health_bridge, "_on_knockback_requested")),
            "Health still takes damage without the adapter, without moving the actor")
        # Godot only calls _ready again when explicitly requested.
        health_bridge.request_ready()
        actor.add_child(health_bridge)
        verify.call(health.knockback_requested.is_connected(
            Callable(health_bridge, "_on_knockback_requested"))
            and health.died.is_connected(Callable(health_bridge, "_on_died")),
            "Reattached health bridge reconnects without changing Health or the actor")
        health.current_health = 100.0
        health.invulnerability_left = 0

    # View switches retain a forwarded external impulse; Health itself
    # never writes velocity or resolves any actor-relative NodePath.
    actor.global_position = Vector3(0.0, 0.15, 0.0)
    actor.velocity = Vector3.ZERO
    actor.clear_motion()
    views.switch_view(1)
    health.current_health = 100.0
    var knock_ok: bool = health.take_hit(
        2.0, near, punch, Vector2.RIGHT, 4.0, 12
    )
    var knock_before: int = actor.locomotion._impulse_ticks_left
    views.switch_view(3)
    verify.call(knock_ok and knock_before == 12
        and actor.locomotion._impulse_ticks_left == knock_before,
        "Knockback is queued in locomotion and unaffected by camera switching")
    await tree.physics_frame
    await tree.physics_frame
    verify.call(actor.velocity.x > 0.0 and actor.locomotion._impulse_ticks_left < knock_before,
        "Authoritative physics solver applies external impulse with decay")
    actor.clear_motion()
    verify.call(actor.locomotion._impulse_ticks_left == 0
        and actor.locomotion._applied_impulse_velocity.is_zero_approx(),
        "Cancelling locomotion clears external knockback and its cached contribution")

    # The external impulse is a *velocity*, not a per-tick acceleration.
    # Test the complete timeline in an open space with neutral movement.
    views.switch_view(1)
    actor.global_position = Vector3(0, 0.15, 0)
    actor.velocity = Vector3.ZERO
    actor.clear_motion()
    await tree.physics_frame
    actor.locomotion.apply_external_impulse(Vector2(4.0, 0.0), 12)
    var decay_samples: Array[float] = []
    for tick in range(12):
        await tree.physics_frame
        decay_samples.append(actor.velocity.x)
    var bounded_decay: bool = true
    for tick in range(decay_samples.size()):
        var expected: float = 4.0 * float(12 - tick) / 12.0
        bounded_decay = bounded_decay and absf(decay_samples[tick] - expected) < 0.08
    verify.call(bounded_decay,
        "External 4 m/s impulse stays bounded and decays linearly over 12 physics ticks")
    await tree.physics_frame
    verify.call(absf(actor.velocity.x) < 0.08
        and actor.locomotion._applied_impulse_velocity.is_zero_approx(),
        "Expired impulse leaves no residual velocity or cached contribution")

    # A new command replaces the remaining old impulse instead of stacking
    # with it; stop() must clear the applied portion as well as the timer.
    actor.clear_motion()
    actor.locomotion.apply_external_impulse(Vector2(3.0, 0.0), 10)
    await tree.physics_frame
    actor.locomotion.apply_external_impulse(Vector2(-2.0, 0.0), 5)
    await tree.physics_frame
    verify.call(absf(actor.velocity.x + 2.0) < 0.08,
        "Replacing an impulse does not inherit the previous command's velocity")
    actor.clear_motion()
    await tree.physics_frame
    verify.call(absf(actor.velocity.x) < 0.08,
        "Cancelling an in-flight impulse prevents delayed motion")

    # Locomotion's own movement velocity remains independent of the
    # decaying contribution, including while the player is running.
    Input.action_press(&"move_right")
    Input.action_press(&"actor_run")
    for tick in range(25):
        await tree.physics_frame
    var running_speed: float = actor.velocity.x
    actor.locomotion.apply_external_impulse(Vector2(3.0, 0.0), 6)
    var running_bounded: bool = true
    for tick in range(6):
        await tree.physics_frame
        var expected: float = running_speed + 3.0 * float(6 - tick) / 6.0
        running_bounded = running_bounded and absf(actor.velocity.x - expected) < 0.16
    await tree.physics_frame
    running_bounded = running_bounded and absf(actor.velocity.x - running_speed) < 0.16
    verify.call(running_speed > 6.0 and running_bounded,
        "Run plus external push remains bounded; its decay never alters base movement")
    Input.action_release(&"move_right")
    Input.action_release(&"actor_run")
    actor.clear_motion()

    # Closing settings / focus loss requires *release* before another press
    # is accepted; previously held buttons cannot generate delayed attacks.
    combat.cancel()
    Input.action_press(&"actor_punch")
    adapter.set_enabled(false)
    input._physics_process(1.0 / 60.0)
    adapter.set_enabled(true)
    input._physics_process(1.0 / 60.0)
    verify.call(input.release_to_rearm and combat.current_attack == null
        and combat._pending_id == &"",
        "Blocked UI action cannot become a deferred attack when UI closes")
    Input.action_release(&"actor_punch")
    input._physics_process(1.0 / 60.0)
    verify.call(not input.release_to_rearm and combat._pending_id == &"",
        "Releasing the stale attack button rearms without attacking")
    # Window-focus transitions independently enforce the same rule.
    adapter.focus_active = false
    input._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
    Input.action_press(&"actor_punch")
    input._physics_process(1.0 / 60.0)
    adapter.focus_active = true
    input._physics_process(1.0 / 60.0)
    verify.call(input.release_to_rearm and combat._pending_id == &"",
        "Focus-loss/re-entry cannot replay a held punch")
    Input.action_release(&"actor_punch")
    input._physics_process(1.0 / 60.0)

    # Hit-stun independently interrupts attacks and suppresses new requests.
    health.current_health = 100.0
    health.take_hit(1.0, near, punch, Vector2.ZERO, 0.0, 0, 5)
    verify.call(health.stagger_left == 5
        and not combat.request_attack(&"kick", Vector2.RIGHT),
        "Stagger blocks new actions without becoming a movement state")
    for tick in range(7):
        await tree.physics_frame
    verify.call(health.stagger_left == 0,
        "Hit reaction expires on physics ticks independently of view/animation")

    # Side-lane Z is locked even under external push; side view is one
    # world plane, never a second player actor or a teleport.
    actor.global_position = Vector3(0, 0.15, 0)
    actor.velocity = Vector3.ZERO
    actor.clear_motion()
    views.switch_view(0)
    health.take_hit(1.0, near, punch, Vector2(0, -1), 8.0, 8)
    for tick in range(4):
        await tree.physics_frame
    verify.call(absf(actor.global_position.z) < 0.03
        and absf(actor.velocity.z) < 0.03,
        "F1 side-view lane blocks external Z impulse")
    actor.clear_motion()

    # World obstacles still stop a direct external impulse; this is real
    # CharacterBody3D wall physics, not camera-space velocity.
    views.switch_view(1)
    actor.global_position = Vector3(0, 0.15, -8.05)
    actor.velocity = Vector3.ZERO
    for tick in range(7):
        await tree.physics_frame
    health.take_hit(1.0, near, punch, Vector2(0, -1), 18.0, 14)
    var wall_recoil: bool = false
    for tick in range(18):
        await tree.physics_frame
        # Once the wall blocks the incoming impulse, subtracting it on
        # the following tick must not produce an opposite-direction bounce.
        if tick >= 3 and actor.velocity.z > 0.2:
            wall_recoil = true
    verify.call(actor.global_position.z > -8.55 and not wall_recoil,
        "External knockback collides with north wall without artificial rebound")
    actor.clear_motion()
    actor.global_position = Vector3(0, 0.15, 0)
    actor.velocity = Vector3.ZERO
    near.global_position = Vector3(0, 0, -1)

    # Death is authoritative and cancels any in-flight attack.
    target.current_health = third.damage
    target.invulnerability_left = 0
    combat.request_attack(&"test_elbow", Vector2(0.0, -1.0))
    for tick in range(third.total_ticks() + 3):
        await tree.physics_frame
    verify.call(target.current_health == 0.0, "Lethal hit clamps HP to zero")
    health.current_health = 2.0
    combat.request_attack(&"kick", Vector2(0.0, -1.0))
    await tree.physics_frame
    health.take_hit(10.0, near, punch, Vector2.RIGHT, 8.0, 10)
    verify.call(not actor.alive and combat.current_attack == null
        and combat._pending_id == &"" and actor.locomotion._impulse_ticks_left == 0,
        "Health death event disables the actor and stops pending attacks and knockback via adapters")
