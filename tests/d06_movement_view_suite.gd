extends RefCounted
## D06-01 movement/view integration. This is a second real main scene,
## translated away from the primary test arena: it uses the production
## player, FSM, animation presenter, equipment and F1-F5 manager.
const MoveIntentScript = preload("res://addons/action5/actor/move_intent.gd")


func run_tests(tree: SceneTree, verify: Callable) -> void:
    var scene: PackedScene = load("res://demo/main.tscn") as PackedScene
    var arena: Node3D = scene.instantiate() as Node3D
    arena.position = Vector3(90, 0, 90)
    tree.root.add_child(arena)
    await tree.process_frame
    # This fixture supplies authoritative Run/Jump/Crouch intents directly;
    # disable its human input adapter so a neutral global keyboard does not
    # overwrite those commands every physics tick.
    arena.get_node("ActorInput").call("set_enabled", false)
    for tick in range(3):
        await tree.physics_frame
    var actor: CharacterBody3D = arena.get_node("Player") as CharacterBody3D
    var equipment: Node = actor.get_node("Equipment")
    var combat: Node = actor.get_node("CombatController")
    var views: Node = arena.get_node("ViewManager")
    var animation: Node = actor.get_node("AnimationPresenter")
    var fps: Node = actor.get_node("FirstPersonPresenter")
    var visual: Node = actor.get_node("EquipmentVisualAdapter")
    var controller: Node = actor.get_node("Locomotion/MovementController")
    var bat: Node3D = arena.get_node("BatPickup") as Node3D
    var shovel: Node3D = arena.get_node("ShovelPickup") as Node3D
    var socket: Node3D = animation.call("get_socket", &"right_hand") as Node3D
    var actor_id: int = actor.get_instance_id()
    var bat_id: int = bat.get_instance_id()
    var baseline_shadows: int = fps.world_visual_shadows.size()

    verify.call(equipment.call("pickup", bat) and equipment.call("pickup", shovel)
        and equipment.get("current_weapon") == bat
        and bat.get_parent() == socket
        and fps.world_visual_shadows.size() > baseline_shadows,
        "D06 integration loads two real weapons on the persistent world actor")

    var running: MoveIntentScript = MoveIntentScript.new(Vector2.RIGHT)
    running.running = true
    actor.call("apply_move_intent", running)
    for tick in range(6):
        await tree.physics_frame
    verify.call(actor.velocity.x > 0.05 and bat.get_parent() == socket
        and bat.get_instance_id() == bat_id,
        "Running moves the actual actor while the same Bat remains socket-attached")

    verify.call(combat.call("request_attack", &"bat_horizontal", Vector2.RIGHT),
        "Bat secondary action begins during live locomotion")
    for tick in range(2):
        await tree.physics_frame
    var last_tick: int = combat.get("elapsed_ticks")
    var timeline_preserved: bool = combat.get("current_id") == &"bat_horizontal"
    for view in [2, 3, 4]:
        views.call("switch_view", view)
        await tree.physics_frame
        var this_tick: int = combat.get("elapsed_ticks")
        timeline_preserved = timeline_preserved and (
            combat.get("current_id") == &"bat_horizontal"
            and this_tick > last_tick and bat.get_parent() == socket
            and bat.get_instance_id() == bat_id
            and actor.get_instance_id() == actor_id
            and fps.world_visual_shadows.size() == baseline_shadows + 1
        )
        last_tick = this_tick
    verify.call(timeline_preserved,
        "F3-F4-F5 mid-strike preserves Bat identity, action clock, socket and one world shadow")
    combat.call("cancel")
    verify.call(combat.get("current_id") == &"" and bat.get_parent() == socket,
        "Ending view-switched attack restores idle without reconstructing equipment")

    # Real airborne Jump while still equipped; view changes may not detach
    # the socket, replace the actor or hide the world's shadow caster.
    views.call("switch_view", 2)
    var jump: MoveIntentScript = MoveIntentScript.new(Vector2.RIGHT)
    jump.jump_pressed = true
    actor.call("apply_move_intent", jump)
    for tick in range(3):
        await tree.physics_frame
    var airborne: bool = not actor.is_on_floor()
    views.call("switch_view", 3)
    verify.call(airborne and bat.get_parent() == socket
        and equipment.get("current_weapon") == bat
        and fps.world_visual_shadows.size() == baseline_shadows + 1,
        "Jump + F4 keeps one equipped Bat and its world shadow")

    actor.call("apply_move_intent", MoveIntentScript.new())
    for tick in range(120):
        await tree.physics_frame
        if actor.is_on_floor():
            break
    verify.call(actor.is_on_floor(), "Integrated actor lands before grounded Crouch test")
    var crouch: MoveIntentScript = MoveIntentScript.new()
    crouch.request_move(&"crouch")
    actor.call("apply_move_intent", crouch)
    for tick in range(3):
        await tree.physics_frame
    actor.call("apply_move_intent", MoveIntentScript.new())
    for tick in range(2):
        await tree.physics_frame
    verify.call(controller.get("active_id") == &"crouch"
        and equipment.get("current_weapon") == bat and bat.get_parent() == socket,
        "Crouching uses the registered movement component without modifying equipment")

    var crouch_walk: MoveIntentScript = MoveIntentScript.new(Vector2.RIGHT)
    actor.call("apply_move_intent", crouch_walk)
    for tick in range(5):
        await tree.physics_frame
    views.call("switch_view", 3)
    verify.call(controller.get("active_id") == &"crouch_walk"
        and fps.first_person and equipment.get("current_weapon") == bat
        and visual.get("_viewmodel") != null,
        "Crouch-walking with equipment keeps the separate first-person viewmodel")

    verify.call(combat.call("request_attack", &"bat_swing", Vector2.RIGHT),
        "Bat primary action can start while crouch-walking")
    for tick in range(3):
        await tree.physics_frame
    var before_swap: int = combat.get("elapsed_ticks")
    verify.call(combat.get("current_id") == &"bat_swing" and before_swap > 0,
        "Crouch/attack timeline is shared with normal locomotion")

    # Swapping an equipped weapon cancels only its removed attack; it does
    # not reset movement FSM, actor pose, player world or logical inventory.
    verify.call(equipment.call("swap_next")
        and equipment.get("current_weapon") == shovel
        and shovel.get_parent() == socket
        and combat.call("get_attack", &"bat_swing") == null
        and combat.call("get_attack", &"bat_horizontal") == null
        and combat.call("get_attack", &"shovel_swing") != null
        and combat.get("current_id") == &""
        and actor.get_instance_id() == actor_id,
        "Swap mid-attack preserves actor/sockets and unregisters only Bat actions")
    verify.call(combat.call("request_attack", &"shovel_swing", Vector2.RIGHT),
        "Same action runner executes Shovel overhead during active movement")
    for tick in range(3):
        await tree.physics_frame
    var shovel_tick: int = combat.get("elapsed_ticks")
    views.call("switch_view", 4)
    await tree.physics_frame
    verify.call(combat.get("current_id") == &"shovel_swing"
        and combat.get("elapsed_ticks") > shovel_tick
        and equipment.get("current_weapon") == shovel
        and shovel.get_parent() == socket,
        "Shovel world animation and D05 timeline survive switching directly to F5")

    verify.call(equipment.call("drop_current")
        and equipment.get("current_weapon") == null
        and combat.call("get_attack", &"shovel_swing") == null
        and combat.get("current_id") == &"",
        "Dropping active Shovel clears only its action and retains persistent actor")
    verify.call(equipment.call("swap_next")
        and equipment.get("current_weapon") == bat
        and bat.get_parent() == socket
        and equipment.call("drop_current")
        and equipment.get("inventory").is_empty(),
        "Swap to remaining stowed Bat and drop leaves both original items in the world")
    for tick in range(3):
        await tree.process_frame
    verify.call(fps.world_visual_shadows.size() == baseline_shadows
        and visual.get("_viewmodel") == null
        and actor.get_instance_id() == actor_id,
        "F5 drop restores original skinned body/world shadows and removes all extra F4 visuals")
    arena.queue_free()
    await tree.process_frame
    await tree.process_frame
