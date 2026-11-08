extends RefCounted
## Combat remains authoritative when the optional visual bridge is absent,
## removed during an attack, or replaced with a recording visual.

const CombatScript = preload("res://addons/action5/combat/combat_controller.gd")
const AdapterScript = preload("res://addons/action5/animation/combat_animation_adapter.gd")
const RecorderScript = preload("res://tests/fixtures/recording_action_visual.gd")


func run_tests(tree: SceneTree, level: Node3D, verify: Callable) -> void:
    var actor: CharacterBody3D = level.get_node("Player") as CharacterBody3D
    var combat: CombatScript = actor.get_node("CombatController") as CombatScript
    var health: Node = actor.get_node("Health")
    var animation: Node = actor.get_node("AnimationPresenter")
    var bridge: AdapterScript = actor.get_node_or_null("CombatAnimationAdapter") as AdapterScript
    verify.call(bridge != null and animation != null,
        "D05 animation is driven by a separate, optional adapter")
    if bridge == null or animation == null:
        return

    # The previous suite ends with lethal damage. Reset actor health before
    # detaching the visual bridge and exercising combat with no renderer.
    combat.cancel()
    health.set("current_health", health.get("max_health"))
    health.set("stagger_left", 0)
    health.set("invulnerability_left", 0)
    actor.call("set_alive", true)
    actor.call("set_controls_enabled", true)
    actor.remove_child(bridge)
    bridge.free()
    verify.call(animation.get("action_clip") == &""
        and animation.get("upper_body_clip") == &"",
        "Detaching the adapter restores its owned animation channels")

    var recorder = RecorderScript.new()
    recorder.name = "RecordedCombatVisual"
    actor.add_child(recorder)

    var punch: Resource = combat.get_attack(&"punch")
    verify.call(combat.request_attack(&"punch", Vector2.RIGHT),
        "Combat accepts attacks without any animation adapter")
    await tree.physics_frame
    var start_tick: int = combat.elapsed_ticks
    verify.call(combat.current_id == &"punch" and start_tick > 0
        and recorder.events.is_empty(),
        "Gameplay starts independently of animation playback")
    await tree.physics_frame
    verify.call(combat.elapsed_ticks > start_tick,
        "Combat timeline advances without a visual subscriber")

    var substitute: AdapterScript = AdapterScript.new()
    substitute.name = "CombatAnimationAdapter"
    substitute.animation_path = ^"../RecordedCombatVisual"
    actor.add_child(substitute)
    verify.call(recorder.upper_body_clip == &"punch"
        and combat.current_id == &"punch",
        "Late adapter resumes visible action without restarting the combat clock")
    combat.cancel()
    verify.call(recorder.upper_body_clip == &""
        and recorder.events.has("upper:clear"),
        "Attack cancellation clears its subscribed upper-body animation")

    var views: Node = level.get_node("ViewManager")
    var before_events: int = recorder.events.size()
    verify.call(combat.request_attack(&"kick", Vector2.RIGHT),
        "Full-body attack uses the generic substitute animation port")
    await tree.physics_frame
    verify.call(recorder.full_body_clip == &"kick"
        and recorder.events.size() == before_events + 1,
        "Kick starts through generic full-body playback, not combat core logic")
    views.call("switch_view", 2)
    views.call("switch_view", 3)
    verify.call(recorder.full_body_clip == &"kick"
        and recorder.events.size() == before_events + 1,
        "F3/F4 switches do not reset combat animations")
    for tick in range(combat.get_attack(&"kick").total_ticks() + 2):
        await tree.physics_frame
    verify.call(combat.current_attack == null and recorder.full_body_clip == &""
        and recorder.events.has("full:clear"),
        "Normal completion clears full-body animation via adapter")

    verify.call(combat.request_attack(&"punch", Vector2.RIGHT),
        "Combat can restart independently of previous animation")
    await tree.physics_frame
    var near: Node = level.get_node("NearDummy")
    health.call("take_hit", 1.0, near, punch, Vector2.ZERO, 0.0, 0, 4)
    verify.call(combat.current_attack == null
        and recorder.upper_body_clip == &""
        and recorder.full_body_clip == &"hit",
        "Stagger cancels gameplay and presents a hit reaction through adapter")
    for tick in range(6):
        await tree.physics_frame
    verify.call(recorder.full_body_clip == &"",
        "Hit visual clears after stagger expires")

    verify.call(combat.request_attack(&"kick", Vector2.RIGHT),
        "Combat can restart once stagger ends")
    await tree.physics_frame
    health.call("take_hit", 200.0, near, punch, Vector2.ZERO, 0.0, 0, 3)
    verify.call(not bool(actor.get("alive")) and combat.current_attack == null
        and recorder.full_body_clip == &"death",
        "Death cancels gameplay and only the adapter starts the death visual")
    for tick in range(5):
        await tree.physics_frame
    verify.call(recorder.full_body_clip == &"death",
        "Death animation is not cleared by the expired hit-stagger timer")

    # Respawning may restore gameplay without replacing the adapter.
    # Clearing the old death overlay is still the visual layer's job.
    health.set("current_health", 10.0)
    health.set("stagger_left", 0)
    actor.call("set_alive", true)
    actor.call("set_controls_enabled", true)
    verify.call(combat.request_attack(&"punch", Vector2.RIGHT),
        "Revived actor can attack with the same visual adapter")
    await tree.physics_frame
    verify.call(recorder.upper_body_clip == &"punch"
        and recorder.full_body_clip == &"",
        "First new attack clears the stale death overlay after revival")
    combat.cancel()

    # Missing optional death animation must clear an existing Hit visual,
    # not leave the actor permanently playing an unrelated reaction.
    health.call("take_hit", 1.0, near, punch, Vector2.ZERO, 0.0, 0, 8)
    verify.call(recorder.full_body_clip == &"hit",
        "A nonlethal stagger is rendered before an interrupted reaction")
    substitute.death_animation_key = &""
    health.call("take_hit", 20.0, near, punch, Vector2.ZERO, 0.0, 0, 0)
    verify.call(not bool(actor.get("alive")) and recorder.full_body_clip == &"",
        "Death without a clip clears the previous hit reaction without affecting combat")

    # No signal handlers survive adapter removal.
    actor.remove_child(substitute)
    verify.call(recorder.full_body_clip == &""
        and not combat.attack_started.is_connected(Callable(substitute, "_on_attack_started")),
        "Adapter removal disconnects subscriptions and clears owned visuals")
    substitute.free()
    recorder.queue_free()
