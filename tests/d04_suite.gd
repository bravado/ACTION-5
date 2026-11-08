extends RefCounted
## D04 import, skeleton/socket mapping and real AnimationTree regression tests.

const ActorScript = preload("res://addons/action5/actor/action_actor.gd")
const ProfileScript = preload("res://addons/action5/animation/skeleton_profile.gd")
const ValidatorScript = preload("res://addons/action5/animation/model_validator.gd")
const PresenterScript = preload("res://addons/action5/animation/animation_presenter.gd")
const FirstPersonScript = preload("res://addons/action5/animation/first_person_presenter.gd")
const MoveIntentScript = preload("res://addons/action5/actor/move_intent.gd")
const ModelReplacementSuiteScript = preload("res://tests/d04_model_replacement_suite.gd")


func run_tests(tree: SceneTree, level: Node3D, verify: Callable) -> void:
    var actor: ActorScript = level.get_node("Player")
    var manager = level.get_node("ViewManager")
    var model: Node = actor.get_node("Visual/Model")
    var presenter: PresenterScript = actor.get_node("AnimationPresenter")
    var fps: FirstPersonScript = actor.get_node("FirstPersonPresenter")
    var input_adapter = level.get_node("ActorInput")
    # AI/programmatic commands must not be overwritten by the keyboard input
    # adapter while we test physics-driven visual state selection.
    input_adapter.set_enabled(false)
    input_adapter.set_physics_process(false)

    verify.call(model != null and presenter != null and fps != null,
        "D04 imported model and independent animation/FPS presentation components exist")
    var report: Dictionary = ValidatorScript.validate(model, presenter.profile)
    verify.call(bool(report.get("valid", false)),
        "Original GLB model validates its skeleton and all required clips")
    var skeleton: Skeleton3D = ValidatorScript.find_skeleton(model)
    var animation_player: AnimationPlayer = ValidatorScript.find_animation_player(model)
    if skeleton == null or animation_player == null:
        verify.call(false, "D04 imported GLB exposes real Skeleton3D and AnimationPlayer")
        return

    verify.call(skeleton.get_bone_count() >= 11
        and skeleton.find_bone("Hand_R") >= 0 and skeleton.find_bone("Hand_L") >= 0,
        "Imported GLB uses a skinned humanoid with mapped hand bones")
    for key in [&"idle", &"run", &"punch", &"kick", &"hit", &"death"]:
        verify.call(animation_player.has_animation(presenter.profile.clip_name(key)),
            "Required D04 animation clip available: %s" % key)
    verify.call(presenter.animation_tree != null and presenter.animation_tree.active
        and presenter.playback != null,
        "Real AnimationTree state machine drives the imported AnimationPlayer")

    var right_socket: Node3D = presenter.get_socket(&"right_hand")
    var left_socket: Node3D = presenter.get_socket(&"left_hand")
    verify.call(right_socket is BoneAttachment3D and left_socket is BoneAttachment3D,
        "Both hand sockets use real animated BoneAttachment3D nodes")
    var item: Node3D = right_socket.get_node_or_null("TrainingTool")
    verify.call(item is MeshInstance3D,
        "Test equipment is attached to the right hand, not the actor origin")

    var bad_clips: ProfileScript = presenter.profile.duplicate(true) as ProfileScript
    bad_clips.clip_map["run"] = "missing_run"
    var invalid_report: Dictionary = ValidatorScript.validate(model, bad_clips)
    verify.call(not bool(invalid_report.get("valid", true))
        and (invalid_report["errors"] as Array).size() > 0,
        "Validator rejects a missing required source clip")
    var alternate_clips: ProfileScript = presenter.profile.duplicate(true) as ProfileScript
    alternate_clips.clip_map["run"] = "walk"
    verify.call(bool(ValidatorScript.validate(model, alternate_clips).get("valid", false)),
        "Compatible source rigs can remap clips through data only")
    var bad_bones: ProfileScript = presenter.profile.duplicate(true) as ProfileScript
    bad_bones.right_hand_bone = &"missing_bone"
    var missing_bone_report: Dictionary = ValidatorScript.validate(model, bad_bones)
    verify.call(bool(missing_bone_report.get("valid", false))
        and (missing_bone_report["warnings"] as Array).size() > 0,
        "Missing optional bone produces a report warning, not a fatal import error")
    # Imported body meshes may have arbitrary names or be combined into a
    # single mesh; validating a skeleton must not depend on head mesh names.
    var unnamed_mesh: MeshInstance3D = fps.body_meshes[0]
    var original_mesh_name: StringName = unnamed_mesh.name
    unnamed_mesh.name = "RenamedSkinSurface"
    verify.call(bool(ValidatorScript.validate(model, presenter.profile).get("valid", false)),
        "Skeletal validation does not depend on special mesh or head names")
    unnamed_mesh.name = original_mesh_name

    var camera: Camera3D = manager.get_active_camera()
    var view_tool := camera.get_node_or_null("FirstPersonTrainingTool") as MeshInstance3D
    var body_layer: int = fps.local_body_render_layer
    var view_layer: int = fps.first_person_render_layer
    verify.call(view_tool != null and view_tool.get_parent() == camera
        and view_tool.layers == (1 << (view_layer - 1))
        and view_tool.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        and (view_tool.material_override as StandardMaterial3D).shading_mode
            == BaseMaterial3D.SHADING_MODE_UNSHADED
        and (view_tool.mesh as BoxMesh).size.z < 0.30
        and view_tool.get_node_or_null("GripHand") is MeshInstance3D
        and view_tool.get_node_or_null("Forearm") is MeshInstance3D
        and view_tool.get_node_or_null("ToolHandle") is MeshInstance3D,
        "F4 view contains a compact tool, grip, hand and forearm—not a floating block")
    var equipment_shadow := right_socket.get_node_or_null("TrainingToolShadow") as MeshInstance3D
    verify.call((item as MeshInstance3D).layers == (1 << (body_layer - 1))
        and (item as MeshInstance3D).cast_shadow
            == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        and equipment_shadow != null
        and equipment_shadow.layers == 1
        and equipment_shadow.cast_shadow
            == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
        and equipment_shadow.mesh == (item as MeshInstance3D).mesh,
        "World tool stays socket-mounted and casts its physical shadow in F4")
    var body_on_isolated_layer: bool = fps.body_meshes.size() >= 2
    for mesh in fps.body_meshes:
        body_on_isolated_layer = (
            body_on_isolated_layer and mesh.visible
            and mesh.layers == (1 << (body_layer - 1))
        )
    verify.call(body_on_isolated_layer,
        "Every local skinned mesh (body, arms and head) uses an isolated render layer")
    var shadow_copies_valid: bool = fps.shadow_meshes.size() == fps.body_meshes.size()
    for i in range(mini(fps.body_meshes.size(), fps.shadow_meshes.size())):
        var original: MeshInstance3D = fps.body_meshes[i]
        var shadow: MeshInstance3D = fps.shadow_meshes[i]
        shadow_copies_valid = (
            shadow_copies_valid
            and original.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            and shadow.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
            and shadow.layers == 1 and shadow.visible
            and shadow.mesh == original.mesh and shadow.skin == original.skin
            and shadow.skeleton == original.skeleton
            and shadow.get_parent() == original.get_parent()
        )
    verify.call(shadow_copies_valid,
        "F4-cullable local rig has an animated shadow-only counterpart on world layer 1")
    verify.call(fps.is_local_actor() and fps.world_visual_shadows.size() == 1
        and fps.world_visual_shadows[0] == equipment_shadow
        and view_layer != body_layer,
        "One local presenter owns equipment shadow policy and both reserved camera layers")

    # Register a previously unknown item and viewmodel through the public API.
    # Neither the demo actor nor the camera/animation core needs a new branch.
    var extra_world := MeshInstance3D.new()
    extra_world.name = "TestRegisteredWorldVisual"
    extra_world.mesh = BoxMesh.new()
    right_socket.add_child(extra_world)
    verify.call(fps.register_world_visual(extra_world)
        and fps.register_world_visual(extra_world),
        "World visual registration is generic and idempotent")
    var extra_shadow := right_socket.get_node_or_null(
        "TestRegisteredWorldVisualShadow") as MeshInstance3D
    verify.call(extra_shadow != null
        and extra_shadow.mesh == extra_world.mesh and extra_shadow.layers == 1
        and extra_shadow.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
        and extra_world.layers == (1 << (body_layer - 1))
        and extra_world.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        and fps.world_visual_shadows.size() == 2
        and fps.body_meshes.size() == fps.shadow_meshes.size(),
        "New world equipment receives culling and shadows without editing the presenter")

    var extra_view := Node3D.new()
    extra_view.name = "TestRegisteredViewmodel"
    var extra_visual := MeshInstance3D.new()
    extra_visual.name = "TestRegisteredViewGeometry"
    extra_visual.mesh = BoxMesh.new()
    extra_view.add_child(extra_visual)
    verify.call(fps.register_first_person_visual(extra_view)
        and extra_view.get_parent() == camera
        and extra_visual.layers == (1 << (view_layer - 1))
        and extra_visual.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
        "An arbitrary configured FPS scene gains camera layers without code branches")

    manager.switch_view(2)
    verify.call(actor.get_node("Visual").visible and not fps.first_person
        and camera.get_cull_mask_value(body_layer)
        and not camera.get_cull_mask_value(view_layer) and body_on_isolated_layer,
        "F3 renders the world tool/body but excludes the F4 camera model")
    manager.switch_view(3)
    verify.call(fps.first_person and actor.get_node("Visual").visible
        and not camera.get_cull_mask_value(body_layer)
        and body_on_isolated_layer and is_instance_valid(right_socket),
        "F4 excludes all skinned meshes without hiding the shared rig or sockets")
    verify.call(item.get_parent() == right_socket and item.visible
        and not camera.get_cull_mask_value(body_layer)
        and camera.get_cull_mask_value(view_layer)
        and view_tool.visible and view_tool.position.z < -0.5,
        "F4 shows a camera-anchored tool while preserving the animated world socket")
    manager.switch_view(2)
    verify.call(camera.get_cull_mask_value(body_layer)
        and not camera.get_cull_mask_value(view_layer) and body_on_isolated_layer,
        "Switching F4 back to F3 restores the world body and hides the F4 tool")
    var exit_cleanup: Callable = fps.unregister_world_visual.bind(extra_world)
    fps.unregister_world_visual(extra_world)
    fps.unregister_first_person_visual(extra_view)
    verify.call(extra_world.layers == 1
        and extra_world.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
        and extra_shadow.is_queued_for_deletion()
        and extra_view.is_queued_for_deletion()
        and fps.world_visual_shadows.size() == 1
        and not extra_world.tree_exiting.is_connected(exit_cleanup),
        "Manual unregistration restores rendering, shadows and signal connections")

    # Re-equip the exact same node, not a fresh instance. The tree-exit
    # listener must be connected once and cleaned up on its actual deletion.
    verify.call(fps.register_world_visual(extra_world)
        and fps.register_world_visual(extra_world)
        and extra_world.tree_exiting.is_connected(exit_cleanup)
        and fps.world_visual_shadows.size() == 2,
        "The same world visual can be registered again after being unequipped")
    var replacement_shadow: MeshInstance3D = fps.world_visual_shadows.back()
    verify.call(replacement_shadow != extra_shadow
        and replacement_shadow.mesh == extra_world.mesh
        and replacement_shadow.cast_shadow
            == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY,
        "Re-registration creates only one fresh shadow for the original mesh")
    extra_world.queue_free()
    await tree.process_frame
    verify.call(fps.world_visual_shadows.size() == 1
        and not is_instance_valid(replacement_shadow),
        "Freeing a re-registered visual runs automatic cleanup exactly once")


    actor.clear_motion()
    for i in range(8):
        await tree.physics_frame
    var hand_before: Vector3 = right_socket.global_position
    verify.call(presenter.set_action_visual(&"punch"),
        "Combat can request punch visual without moving the actor")
    for i in range(14):
        await tree.physics_frame
    var hand_after: Vector3 = right_socket.global_position
    verify.call(presenter.current_clip == &"punch"
        and hand_before.distance_to(hand_after) > 0.02,
        "Punch clip animates the hand bone and its attached prop in 3D")
    var current_time: float = presenter.playback.get_current_play_position()
    for view in [0, 1, 2, 3, 4, 2]:
        manager.switch_view(view)
    verify.call(presenter.current_clip == &"punch" and presenter.action_clip == &"punch"
        and is_equal_approx(current_time, presenter.playback.get_current_play_position()),
        "Switching all five cameras does not restart or reset a playing clip")
    presenter.clear_action_visual()

    for clip in [&"kick", &"hit", &"death", &"reload"]:
        verify.call(presenter.set_action_visual(clip),
            "Independent visual API accepts imported %s animation" % clip)
        for i in range(5):
            await tree.physics_frame
        verify.call(presenter.current_clip == clip,
            "AnimationTree travels to requested %s without changing combat state" % clip)
    presenter.clear_action_visual()

    # Every required clip must remain active across every view (including
    # head-hidden F4) without re-instantiating the shared skeleton or prop.
    var original_rig_id: int = skeleton.get_instance_id()
    var original_socket_id: int = right_socket.get_instance_id()
    for clip in [&"idle", &"run", &"punch", &"kick", &"hit", &"death"]:
        verify.call(presenter.set_action_visual(clip),
            "Required clip can be selected for five-view continuity: %s" % clip)
        for i in range(8):
            await tree.physics_frame
        for view_index in range(5):
            manager.switch_view(view_index)
            await tree.physics_frame
            verify.call(presenter.current_clip == clip
                and skeleton.get_instance_id() == original_rig_id
                and right_socket.get_instance_id() == original_socket_id,
                "Clip %s stays active in view %d with the original skeleton/socket" % [
                    clip, view_index + 1
                ])
    presenter.clear_action_visual()
    actor.clear_motion()
    for i in range(10):
        await tree.physics_frame
    verify.call(presenter.current_clip == &"idle",
        "Clearing visual action restores idle without re-instantiating the actor")
    var run := MoveIntentScript.new(Vector2.RIGHT)
    run.running = true
    actor.apply_move_intent(run)
    for i in range(32):
        await tree.physics_frame
    verify.call(presenter.current_clip == &"run"
        and actor.velocity.x > actor.locomotion.walk_speed,
        "AnimationTree selects Run from actual authoritative physics velocity")
    var run_socket_before: Vector3 = skeleton.to_local(right_socket.global_position)
    for i in range(7):
        await tree.physics_frame
    var run_socket_after: Vector3 = skeleton.to_local(right_socket.global_position)
    verify.call(run_socket_before.distance_to(run_socket_after) > 0.02
        and item.get_parent() == right_socket,
        "Run clip animates the hand socket and preserves the attached equipment")

    # Independent channel composition: the Run state machine must keep playing
    # while Punch is blended into only the upper-body bone tracks.
    var blend_graph := presenter.animation_tree.tree_root as AnimationNodeBlendTree
    var upper_mix := blend_graph.get_node(&"UpperBodyBlend") as AnimationNodeBlend2
    verify.call(blend_graph.has_node(&"Base") and blend_graph.has_node(&"Upper")
        and blend_graph.has_node(&"Full") and blend_graph.has_node(&"FullBodyBlend")
        and upper_mix != null and upper_mix.filter_enabled,
        "Three independent animation playheads are connected by two blend channels")
    var filters_arm: bool = false
    var filters_legs: bool = false
    for path in presenter.upper_body_filter_paths:
        filters_arm = filters_arm or str(path).contains("UpperArm_R")
        filters_legs = filters_legs or str(path).contains("Leg_R")
    verify.call(filters_arm and not filters_legs,
        "Upper-body blending masks animated arms but never the leg tracks")
    var timeline_before: float = presenter.base_playback.get_current_play_position()
    verify.call(presenter.set_upper_body_action(&"punch"),
        "Independent upper-body action accepts any mapped animation ID")
    for i in range(4):
        await tree.physics_frame
    verify.call(presenter.base_clip == &"run" and presenter.current_clip == &"run"
        and presenter.upper_body_clip == &"punch"
        and is_equal_approx(float(presenter.animation_tree.get(
            "parameters/UpperBodyBlend/blend_amount")), 1.0)
        and presenter.base_playback.get_current_play_position() != timeline_before,
        "Run advances underneath the Punch upper-body overlay")
    verify.call(not presenter.set_upper_body_action(&"missing_clip")
        and presenter.upper_body_clip == &"punch",
        "Invalid action requests do not interrupt a running overlay")
    var pose_time: float = presenter.upper_body_playback.get_current_play_position()
    for view_index in range(5):
        manager.switch_view(view_index)
    verify.call(presenter.upper_body_clip == &"punch"
        and is_equal_approx(pose_time, presenter.upper_body_playback.get_current_play_position()),
        "Camera changes do not restart the independent upper-body channel")

    verify.call(presenter.set_full_body_action(&"kick"),
        "A full-body action can override a running move and upper-body action")
    for i in range(2):
        await tree.physics_frame
    verify.call(presenter.current_clip == &"kick" and presenter.base_clip == &"run"
        and presenter.upper_body_clip == &"punch"
        and is_equal_approx(float(presenter.animation_tree.get(
            "parameters/FullBodyBlend/blend_amount")), 1.0),
        "Full-body override hides both presentation channels without canceling them")
    presenter.clear_full_body_action()
    verify.call(presenter.current_clip == &"run"
        and presenter.upper_body_clip == &"punch"
        and is_zero_approx(float(presenter.animation_tree.get(
            "parameters/FullBodyBlend/blend_amount"))),
        "Clearing full-body override restores Run plus the upper-body action")
    presenter.clear_upper_body_action()
    verify.call(presenter.upper_body_clip == &""
        and is_zero_approx(float(presenter.animation_tree.get(
            "parameters/UpperBodyBlend/blend_amount"))),
        "Clearing the upper-body overlay leaves locomotion in full control")

    # Real registered Slide overrides locomotion velocity, but an imported rig
    # without a slide clip must not keep cycling the Run animation.
    var slide_intent := MoveIntentScript.new(Vector2.RIGHT)
    slide_intent.request_move(&"slide")
    actor.apply_move_intent(slide_intent)
    await tree.physics_frame
    verify.call(actor.locomotion.move_controller.active_id == &"slide"
        and presenter.current_clip == &"idle",
        "Active Slide without a mapped clip uses Idle, not the previous Run cycle")
    actor.clear_motion()
    for i in range(4):
        await tree.physics_frame

    # Jump changes physical grounded state after the locomotion tick. Without
    # an imported airborne/jump clip, keep a safe idle pose instead of Run.
    verify.call(actor.is_on_floor(),
        "Animation fixture returns to the ground before testing jump")
    var jump_intent := MoveIntentScript.new()
    jump_intent.jump_pressed = true
    actor.apply_move_intent(jump_intent)
    for i in range(3):
        await tree.physics_frame
    verify.call(not actor.is_on_floor() and presenter.current_clip == &"idle",
        "Airborne fallback uses Idle when no jump/fall animations are mapped")
    var camera_tool_offset: Vector3 = view_tool.position
    manager.switch_view(3)
    await tree.physics_frame
    verify.call(not actor.is_on_floor()
        and camera.get_cull_mask_value(view_layer)
        and not camera.get_cull_mask_value(body_layer)
        and view_tool.visible
        and view_tool.position.is_equal_approx(camera_tool_offset)
        and camera.to_local(view_tool.global_position).is_equal_approx(camera_tool_offset),
        "F4 jumping keeps the weapon framed relative to the camera, not the moving hand")
    var tool_screen: Vector2 = camera.unproject_position(view_tool.global_position)
    var viewport_size := Vector2(camera.get_viewport().get_visible_rect().size)
    verify.call(not camera.is_position_behind(view_tool.global_position)
        and tool_screen.x > 0.0 and tool_screen.x < viewport_size.x
        and tool_screen.y > 0.0 and tool_screen.y < viewport_size.y,
        "The F4 weapon remains within the visible screen during the jump")
    manager.switch_view(2)
    verify.call(not camera.get_cull_mask_value(view_layer)
        and camera.get_cull_mask_value(body_layer)
        and item.get_parent() == right_socket,
        "Returning to F3 during a jump restores only the real socket-mounted weapon")
    verify.call(presenter.set_upper_body_action(&"punch"),
        "A Jump may start an independent upper-body attack")
    await tree.physics_frame
    verify.call(not actor.is_on_floor() and presenter.base_clip == &"idle"
        and presenter.upper_body_clip == &"punch",
        "Jump physics and upper-body action execute simultaneously")
    verify.call(presenter.set_full_body_action(&"kick"),
        "An airborne Jump can compose with a full-body Kick override")
    await tree.physics_frame
    verify.call(not actor.is_on_floor() and presenter.current_clip == &"kick"
        and presenter.upper_body_clip == &"punch",
        "Jump+Kick overrides visuals without canceling movement or action playback")
    presenter.clear_full_body_action()
    verify.call(presenter.current_clip == &"idle" and presenter.upper_body_clip == &"punch",
        "Releasing Kick restores airborne base and underlying upper-body action")
    presenter.clear_upper_body_action()
    verify.call(presenter.set_action_visual(&"hit"),
        "Explicit combat visual can override the airborne movement fallback")
    await tree.physics_frame
    verify.call(presenter.current_clip == &"hit",
        "Hit action visual retains priority while the actor is in the air")
    presenter.clear_action_visual()
    await tree.physics_frame
    verify.call(presenter.current_clip == &"idle",
        "Clearing Hit returns to the appropriate airborne fallback")
    for i in range(100):
        await tree.physics_frame
    verify.call(actor.is_on_floor() and presenter.current_clip == &"idle",
        "Landing returns to grounded Idle without resetting the AnimationTree")
    # A 'kick' animation moves Leg_R. If played through the upper-body mask
    # while idle, the leg must remain in the base pose and only the arm moves.
    var right_leg: int = skeleton.find_bone("Leg_R")
    var leg_pose_before: Quaternion = skeleton.get_bone_pose_rotation(right_leg)
    verify.call(presenter.set_upper_body_action(&"kick"),
        "Upper-body channel accepts a clip containing both arm and leg tracks")
    for i in range(12):
        await tree.physics_frame
    verify.call(skeleton.get_bone_pose_rotation(right_leg).is_equal_approx(leg_pose_before)
        and presenter.base_clip == &"idle" and presenter.upper_body_clip == &"kick",
        "Upper-body bone filtering prevents Kick leg tracks from overriding Idle legs")
    presenter.clear_upper_body_action()
    verify.call(not presenter.set_upper_body_action(&"not_installed"),
        "Unavailable upper-body clips fail safely without corrupting any channel")

    var other_scene := load("res://demo/player.tscn") as PackedScene
    var other: ActorScript = other_scene.instantiate() as ActorScript
    var other_presenter: PresenterScript = other.get_node("AnimationPresenter")
    var fallback_profile: ProfileScript = other_presenter.profile.duplicate(true) as ProfileScript
    fallback_profile.right_hand_bone = &"not_installed"
    fallback_profile.clip_map["walk"] = "missing_walk"
    fallback_profile.clip_map["dodge"] = "punch"
    fallback_profile.clip_map["jump"] = "kick"
    other_presenter.profile = fallback_profile
    level.add_child(other)
    verify.call(other_presenter.get_socket(&"right_hand") != null
        and not (other_presenter.get_socket(&"right_hand") is BoneAttachment3D),
        "Missing mapped hand bone installs stable fallback socket for equipment")
    verify.call(bool(other_presenter.validation.get("valid", false)),
        "Missing optional Walk still validates a rig with mapped Dodge/Jump clips")

    # Optional clip availability is determined from actual imported animations,
    # not merely from nonempty profile names. Exercise real physics transitions.
    for i in range(12):
        await tree.physics_frame
    other.set_move_intent(Vector2.RIGHT)
    for i in range(20):
        await tree.physics_frame
    verify.call(other.is_on_floor() and other_presenter.current_clip == &"run",
        "Unavailable optional Walk safely falls back to the imported Run clip")
    var dodge_intent := MoveIntentScript.new(Vector2.RIGHT)
    dodge_intent.request_move(&"dodge")
    other.apply_move_intent(dodge_intent)
    await tree.physics_frame
    verify.call(other.locomotion.move_controller.active_id == &"dodge"
        and other_presenter.current_clip == &"dodge",
        "Active Dodge uses its optional mapped clip even at high movement speed")
    other.clear_motion()
    for i in range(3):
        await tree.physics_frame
    var jump_mapped := MoveIntentScript.new()
    jump_mapped.jump_pressed = true
    other.apply_move_intent(jump_mapped)
    for i in range(3):
        await tree.physics_frame
    verify.call(not other.is_on_floor() and other_presenter.current_clip == &"jump",
        "Airborne ascent uses a configured Jump clip when available")
    var other_fps: FirstPersonScript = other.get_node("FirstPersonPresenter")
    manager.switch_view(3)
    var npc_meshes: Array[Node] = other.get_node("Visual/Model").find_children(
        "*", "MeshInstance3D", true, false
    )
    var npc_meshes_visible: bool = not npc_meshes.is_empty()
    for mesh_node in npc_meshes:
        var npc_mesh := mesh_node as MeshInstance3D
        npc_meshes_visible = (
            npc_meshes_visible and npc_mesh.visible
            and (npc_mesh.layers & 1) != 0
        )
    verify.call(fps.first_person and not camera.get_cull_mask_value(body_layer)
        and not other_fps.first_person and other_fps.body_meshes.is_empty()
        and npc_meshes_visible,
        "F4 excludes only the local body; NPC meshes retain default camera visibility")
    other.queue_free()

    # VT-12: Eye-level camera near a REAL solid wall, not an empty-room
    # cull-mask test. Switch F3 -> F4 while the actor stays inside the arena.
    var near_wall_previous_position: Vector3 = actor.global_position
    actor.clear_motion()
    actor.velocity = Vector3.ZERO
    actor.global_position = Vector3(0.0, 0.15, -8.1)
    for i in range(8):
        await tree.physics_frame
    var near_wall_position: Vector3 = actor.global_position
    verify.call(manager.switch_view(2) and manager.switch_view(3),
        "VT-12 switches from third-person to first-person beside a real wall")
    var near_wall_camera: Camera3D = manager.get_active_camera()
    # This collision fixture intentionally looks north at NorthWall.
    # F4 now inherits actual player facing, so set the test ray's camera
    # orientation explicitly instead of depending on a north-reset bug.
    var prior_wall_test_yaw: float = manager.camera_rig.orbit_yaw
    var prior_wall_test_pitch: float = manager.camera_rig.orbit_pitch
    manager.camera_rig.orbit_yaw = 0.0
    manager.camera_rig.orbit_pitch = 0.0
    manager.camera_rig._update_camera(1.0 / 60.0)
    var forward_ray := PhysicsRayQueryParameters3D.create(
        near_wall_camera.global_position,
        near_wall_camera.global_position
            - near_wall_camera.global_basis.z * 2.0
    )
    forward_ray.exclude = [actor.get_rid()]
    var wall_hit: Dictionary = actor.get_world_3d().direct_space_state.intersect_ray(forward_ray)
    verify.call(wall_hit.get("collider") == level.get_node("NorthWall")
        and near_wall_camera.global_position.z > -8.7
        and near_wall_camera.global_position.z < -7.4,
        "VT-12 F4 camera faces a real nearby wall without penetrating its collider")
    verify.call(not near_wall_camera.get_cull_mask_value(body_layer)
        and near_wall_camera.get_cull_mask_value(1)
        and actor.get_node("Visual").visible
        and item.get_parent() == right_socket and item.visible,
        "VT-12 body stays culled near the wall while equipment and rig stay visible")
    verify.call(actor.global_position.distance_to(near_wall_position) < 0.01,
        "VT-12 camera switch does not move or teleport the actor near a wall")
    manager.camera_rig.orbit_yaw = prior_wall_test_yaw
    manager.camera_rig.orbit_pitch = prior_wall_test_pitch
    actor.global_position = near_wall_previous_position
    actor.velocity = Vector3.ZERO

    # Independent fixture: actually swap the imported model and remap bone/
    # animation names before the actor's presenter initializes.
    await ModelReplacementSuiteScript.new().run_tests(tree, level, verify)
    actor.clear_motion()
    input_adapter.set_enabled(true)
    input_adapter.set_physics_process(true)
    manager.switch_view(1)

    await _test_presenter_teardown(tree, level, verify)


func _test_presenter_teardown(tree: SceneTree, level: Node3D, verify: Callable) -> void:
    # Use a separate live arena so removing its presenter cannot invalidate
    # the main runner's player, camera or later input tests.
    var scene := load("res://demo/main.tscn") as PackedScene
    if scene == null:
        verify.call(false, "D04 teardown fixture loads")
        return
    var fixture := scene.instantiate() as Node3D
    var actor := fixture.get_node("Player") as CharacterBody3D
    var imported_model: Node = actor.get_node("Visual/Model")
    var body_nodes: Array[Node] = imported_model.find_children(
        "*", "MeshInstance3D", true, false
    )
    if body_nodes.is_empty():
        verify.call(false, "D04 teardown fixture has imported body meshes")
        fixture.free()
        return

    # Exercise non-default renderer settings, not merely layer-1 defaults.
    var first_mesh := body_nodes[0] as MeshInstance3D
    first_mesh.layers = (1 << 2) | 1
    first_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
    var original_layers: Array[int] = []
    var original_shadows: Array[int] = []
    # The original camera policy deliberately differs from the defaults.
    # Teardown must restore the captured mask bits, not hardcode true.
    var authored_fps := actor.get_node("FirstPersonPresenter") as FirstPersonScript
    var authored_camera := fixture.get_node(
        "ViewManager/CameraRig/Camera3D") as Camera3D
    authored_camera.set_cull_mask_value(authored_fps.local_body_render_layer, false)
    authored_camera.set_cull_mask_value(authored_fps.first_person_render_layer, false)
    for node in body_nodes:
        var mesh := node as MeshInstance3D
        original_layers.append(mesh.layers)
        original_shadows.append(mesh.cast_shadow)

    tree.root.add_child(fixture)
    await tree.process_frame
    var view_manager: Node = fixture.get_node("ViewManager")
    var camera: Camera3D = view_manager.get_node("CameraRig/Camera3D") as Camera3D
    var fps: FirstPersonScript = actor.get_node("FirstPersonPresenter") as FirstPersonScript
    var socket: Node3D = actor.get_node("AnimationPresenter").get_socket(&"right_hand")
    var world_tool := socket.get_node("TrainingTool") as MeshInstance3D
    var world_shadow := socket.get_node("TrainingToolShadow") as MeshInstance3D
    var view_tool := camera.get_node_or_null("FirstPersonTrainingTool") as MeshInstance3D
    var body_shadows: Array[MeshInstance3D] = fps.shadow_meshes.duplicate()
    var original_body_cull: bool = false
    var original_view_cull: bool = false
    var body_layer: int = fps.local_body_render_layer
    var view_layer: int = fps.first_person_render_layer

    # Simulate a D06 multi-mesh item without adding weapon-type branches.
    # Its non-default settings must survive an independent presenter removal.
    var extra_mesh := MeshInstance3D.new()
    extra_mesh.name = "LifecycleExtraWorld"
    extra_mesh.mesh = BoxMesh.new()
    extra_mesh.layers = (1 << 4) | 1
    extra_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
    socket.add_child(extra_mesh)
    var extra_layers: int = extra_mesh.layers
    var extra_cast_shadow: GeometryInstance3D.ShadowCastingSetting = extra_mesh.cast_shadow
    var extra_registered: bool = fps.register_world_visual(extra_mesh)
    var extra_shadow := socket.get_node_or_null(
        "LifecycleExtraWorldShadow") as MeshInstance3D
    verify.call(extra_registered and extra_shadow != null
        and extra_mesh.layers == (1 << (body_layer - 1))
        and extra_shadow.cast_shadow
            == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY,
        "D04 extra socket-mounted mesh is managed by the shared FPS render policy")

    # Camera-local presentation may contain nested meshes; teardown must
    # release the entire registered scene instead of leaving children behind.
    var fps_visual := Node3D.new()
    fps_visual.name = "LifecycleExtraViewmodel"
    var fps_mesh := MeshInstance3D.new()
    fps_mesh.mesh = BoxMesh.new()
    fps_visual.add_child(fps_mesh)
    var nested := Node3D.new()
    fps_visual.add_child(nested)
    var nested_mesh := MeshInstance3D.new()
    nested_mesh.mesh = SphereMesh.new()
    nested.add_child(nested_mesh)
    verify.call(fps.register_first_person_visual(fps_visual)
        and fps_mesh.layers == (1 << (view_layer - 1))
        and nested_mesh.layers == (1 << (view_layer - 1))
        and fps.world_visual_shadows.size() == 2,
        "D04 nested FPS visual and multiple world meshes share one presenter lifecycle")

    view_manager.call("switch_view", 2)
    verify.call(camera.get_cull_mask_value(body_layer)
        and not camera.get_cull_mask_value(view_layer),
        "D04 F3 changes custom initial camera-mask settings")
    view_manager.call("switch_view", 3)
    verify.call(fps.first_person
        and not camera.get_cull_mask_value(body_layer)
        and camera.get_cull_mask_value(view_layer)
        and fps.world_visual_shadows.size() == 2
        and body_shadows.size() == body_nodes.size(),
        "D04 fixture starts with F4 body culling and both equipment shadow casters")

    actor.remove_child(fps)
    var body_restored: bool = true
    for i in range(body_nodes.size()):
        var mesh := body_nodes[i] as MeshInstance3D
        body_restored = body_restored and (
            mesh.layers == original_layers[i]
            and mesh.cast_shadow == original_shadows[i]
        )
    verify.call(is_instance_valid(actor) and actor.is_inside_tree()
        and world_tool.get_parent() == socket
        and body_restored
        and world_tool.layers == 1
        and world_tool.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
        and extra_mesh.layers == extra_layers
        and extra_mesh.cast_shadow == extra_cast_shadow
        and not extra_mesh.tree_exiting.is_connected(
            fps.unregister_world_visual.bind(extra_mesh)),
        "Removing only the presenter restores custom body and equipment settings")
    var cleanup_pending: bool = (
        world_shadow != null and world_shadow.is_queued_for_deletion()
        and extra_shadow != null and extra_shadow.is_queued_for_deletion()
        and view_tool != null and view_tool.is_queued_for_deletion()
        and fps_visual.is_queued_for_deletion()
    )
    for shadow in body_shadows:
        cleanup_pending = cleanup_pending and shadow.is_queued_for_deletion()
    verify.call(cleanup_pending and fps.body_meshes.is_empty()
        and fps.shadow_meshes.is_empty()
        and fps.world_visual_shadows.is_empty()
        and camera.get_cull_mask_value(body_layer) == original_body_cull
        and camera.get_cull_mask_value(view_layer) == original_view_cull
        and not view_manager.is_connected(&"view_changed", Callable(fps, "_on_view_changed")),
        "Presenter teardown releases shadows/viewmodel and restores both camera masks")

    view_manager.call("switch_view", 2)
    verify.call(body_restored
        and camera.get_cull_mask_value(body_layer) == original_body_cull
        and camera.get_cull_mask_value(view_layer) == original_view_cull
        and world_tool.layers == 1 and extra_mesh.layers == extra_layers,
        "Subsequent camera switches cannot reactivate a detached FPS presenter")
    fps.free()
    fixture.queue_free()
    await tree.process_frame
    verify.call(not is_instance_valid(world_shadow)
        and not is_instance_valid(extra_shadow)
        and not is_instance_valid(view_tool)
        and not is_instance_valid(fps_visual),
        "All world shadows and nested viewmodels are freed after removal")
    (level.get_node("ViewManager/CameraRig/Camera3D") as Camera3D).current = true
