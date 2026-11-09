extends RefCounted
## A genuinely distinct imported GLB with different bone, mesh and clip names
## replaces the player model in-place before _ready(). No core code changes.

const ActorScript = preload("res://addons/action5/actor/action_actor.gd")
const ProfileScript = preload("res://addons/action5/animation/skeleton_profile.gd")
const ValidatorScript = preload("res://addons/action5/animation/model_validator.gd")
const PresenterScript = preload("res://addons/action5/animation/animation_presenter.gd")


func run_tests(tree: SceneTree, level: Node3D, verify: Callable) -> void:
    var alternate_scene := load("res://tests/fixtures/alternate_training_character.glb") as PackedScene
    verify.call(alternate_scene != null, "D04 alternate GLB imports as a distinct PackedScene")
    if alternate_scene == null:
        return

    var actor_scene := load("res://demo/player.tscn") as PackedScene
    var actor: ActorScript = actor_scene.instantiate() as ActorScript
    var visual: Node3D = actor.get_node("Visual") as Node3D
    var previous_model: Node = visual.get_node("Model")
    visual.remove_child(previous_model)
    previous_model.free()

    var replacement: Node3D = alternate_scene.instantiate() as Node3D
    replacement.name = "Model"
    visual.add_child(replacement)

    var presenter: PresenterScript = actor.get_node("AnimationPresenter") as PresenterScript
    var profile: ProfileScript = presenter.profile.duplicate(true) as ProfileScript
    profile.right_hand_bone = &"Grip_R"
    profile.left_hand_bone = &"Grip_L"
    profile.head_bone = &"Skull"
    profile.upper_body_root_bone = &"Torso"
    profile.clip_map = {
        "idle": "rest", "walk": "stride", "run": "sprint",
        "punch": "jab", "kick": "boot", "hit": "flinch",
        "death": "collapse", "reload": "rearm",
        "bat_vertical": "club_chop", "bat_horizontal": "club_sweep",
        "shovel_overhead": "spade_chop",
    }
    presenter.profile = profile

    var imported_player: AnimationPlayer = ValidatorScript.find_animation_player(replacement)
    var alternate_skeleton: Skeleton3D = ValidatorScript.find_skeleton(replacement)
    if imported_player == null or alternate_skeleton == null:
        verify.call(false, "Alternate imported rig exposes a skeleton and animation player")
        actor.free()
        return

    # Take the snapshot BEFORE constructing the AnimationTree. This would
    # catch a presenter writing clip.loop_mode on shared imported resources.
    var original_resources: Dictionary = {}
    var original_modes: Dictionary = {}
    var original_lengths: Dictionary = {}
    var original_track_counts: Dictionary = {}
    for key in [&"idle", &"walk", &"run"]:
        var resource: Animation = imported_player.get_animation(profile.clip_name(key))
        original_resources[key] = resource
        original_modes[key] = resource.loop_mode
        original_lengths[key] = resource.length
        original_track_counts[key] = resource.get_track_count()

    verify.call(alternate_skeleton.find_bone("Grip_R") >= 0
        and alternate_skeleton.find_bone("Grip_L") >= 0
        and alternate_skeleton.find_bone("Torso") >= 0
        and alternate_skeleton.find_bone("Hand_R") == -1
        and imported_player.has_animation(&"sprint")
        and not imported_player.has_animation(&"run"),
        "Replacement GLB actually renames bones and clips; it is not the original rig")

    actor.position = Vector3(7.0, 0.5, 0.0)
    level.add_child(actor)
    await tree.physics_frame
    verify.call(bool(presenter.validation.get("valid", false))
        and presenter.model == replacement
        and presenter.skeleton == alternate_skeleton
        and presenter.animation_tree != null and presenter.animation_tree.active,
        "Unmodified AnimationPresenter initializes with a replaced GLB and mapped profile")

    var right_hand: Node3D = presenter.get_socket(&"right_hand")
    var left_hand: Node3D = presenter.get_socket(&"left_hand")
    verify.call(right_hand is BoneAttachment3D
        and left_hand is BoneAttachment3D
        and (right_hand as BoneAttachment3D).bone_name == "Grip_R"
        and (left_hand as BoneAttachment3D).bone_name == "Grip_L",
        "Imported alternative hand bones create real animated equipment sockets")
    var alternative_filters_arms: bool = false
    var alternative_filters_legs: bool = false
    for path in presenter.upper_body_filter_paths:
        alternative_filters_arms = alternative_filters_arms or str(path).contains("UpperR")
        alternative_filters_legs = alternative_filters_legs or str(path).contains("Thigh_R")
    verify.call(alternative_filters_arms and not alternative_filters_legs,
        "Upper-body overlay automatically follows the alternative Torso bone hierarchy")

    var root := presenter.animation_tree.tree_root as AnimationNodeBlendTree
    var base_machine := root.get_node(&"Base") as AnimationNodeStateMachine
    var run_node := base_machine.get_node(&"run") as AnimationNodeAnimation
    verify.call(run_node.use_custom_timeline
        and run_node.loop_mode == Animation.LOOP_LINEAR
        and is_equal_approx(run_node.timeline_length, original_lengths[&"run"]),
        "Looping is configured on a per-presenter AnimationNodeAnimation, not the GLB clip")

    # The profile remaps logical 'punch' to source animation 'jab', and the
    # differently named Grip_R socket must physically follow its rotation.
    var before: Vector3 = right_hand.global_position
    verify.call(presenter.set_full_body_action(&"punch"),
        "Alternate rig accepts logical Punch without a presenter-specific branch")
    for i in range(14):
        await tree.physics_frame
    verify.call(presenter.current_clip == &"punch"
        and right_hand.global_position.distance_to(before) > 0.02,
        "Remapped Jab clip animates the replacement rig's Grip_R socket")

    verify.call(presenter.set_upper_body_action(&"reload"),
        "Alternative Reload source clip is resolved through the same profile")
    for i in range(6):
        await tree.physics_frame
    verify.call(presenter.upper_body_clip == &"reload",
        "Alternative upper-body animation plays through Torso-filtered tracks")
    presenter.clear_full_body_action()
    presenter.clear_upper_body_action()

    for key in [&"bat_vertical", &"bat_horizontal", &"shovel_overhead"]:
        var before_weapon: Vector3 = right_hand.global_position
        verify.call(presenter.set_upper_body_action(key),
            "Alternate rig maps and starts world weapon clip " + str(key))
        for i in range(9):
            await tree.physics_frame
        verify.call(presenter.upper_body_clip == key
            and right_hand.global_position.distance_to(before_weapon) > 0.015,
            "Alternate rig animates the real equipment socket with " + str(key))
        presenter.clear_upper_body_action()

    # Imported Animation resources are read-only, even after building three
    # state machines and transitioning through their action channels.
    var resources_unchanged: bool = true
    for key in [&"idle", &"walk", &"run"]:
        var source: Animation = imported_player.get_animation(profile.clip_name(key))
        resources_unchanged = resources_unchanged and (
            source == original_resources[key]
            and source.loop_mode == original_modes[key]
            and is_equal_approx(source.length, original_lengths[key])
            and source.get_track_count() == original_track_counts[key]
        )
    verify.call(resources_unchanged,
        "Multiple animation channels never mutate the imported source animations")

    var default_actor: ActorScript = level.get_node("Player") as ActorScript
    var default_presenter: PresenterScript = default_actor.get_node("AnimationPresenter")
    verify.call(default_presenter.skeleton.find_bone("Hand_R") >= 0
        and default_presenter.profile.clip_name(&"run") == &"run"
        and default_presenter.model != replacement,
        "Replacing another actor's model leaves the original actor and profile unchanged")

    actor.queue_free()
    await tree.process_frame
