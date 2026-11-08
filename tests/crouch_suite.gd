extends RefCounted
## End-to-end demonstration: install one move component twice, configure two
## imported clips, and leave the movement/animation/input core untouched.

const ActorScript = preload("res://addons/action5/actor/action_actor.gd")
const IntentScript = preload("res://addons/action5/actor/move_intent.gd")
const CrouchScript = preload("res://addons/action5/actor/moves/crouch.gd")
const ValidatorScript = preload("res://addons/action5/animation/model_validator.gd")


func run_tests(tree: SceneTree, level: Node3D, verify: Callable) -> void:
    var scene := load("res://demo/main.tscn") as PackedScene
    var fixture := scene.instantiate() as Node3D
    tree.root.add_child(fixture)
    await tree.process_frame
    var actor := fixture.get_node("Player") as ActorScript
    var adapter := fixture.get_node("ActorInput")
    adapter.set_enabled(false)
    var view_manager := fixture.get_node("ViewManager")
    var controller := actor.locomotion.move_controller
    var crouch := controller.get_move(&"crouch") as CrouchScript
    var walk := controller.get_move(&"crouch_walk") as CrouchScript
    var animation := actor.get_node("AnimationPresenter")
    var collision := actor.get_node("CollisionShape3D") as CollisionShape3D
    var standing_shape := collision.shape as CapsuleShape3D
    var standing_position: Vector3 = collision.position
    var eye_offset := actor.get_node("EyeOffset") as Node3D
    var eye_presenter := actor.get_node("EyeHeightPresenter") as Action5EyeHeightPresenter
    var camera_rig := view_manager.get_node("CameraRig") as Action5CameraRig
    var camera: Camera3D = camera_rig.camera
    var first_person_height: float = view_manager.profiles[3].eye_height

    verify.call(is_equal_approx(eye_offset.position.y, 0.0)
        and is_equal_approx(eye_presenter.target_offset_y, 0.0)
        and controller.move_changed.is_connected(
            Callable(eye_presenter, "_on_move_changed")),
        "Generic eye presenter observes the movement signal with neutral default")

    # This optional actor-local offset must affect F4 exclusively.
    view_manager.switch_view(2)
    camera_rig.refresh_settings()
    var f3_position: Vector3 = camera.global_position
    eye_offset.position.y = -0.25
    camera_rig.refresh_settings()
    verify.call(camera.global_position.is_equal_approx(f3_position),
        "Actor eye offset never affects third-person framing")
    eye_offset.position.y = 0.0
    view_manager.switch_view(3)
    verify.call(is_equal_approx(camera.global_position.y,
        actor.global_position.y + first_person_height),
        "F4 keeps the editable profile eye height when not crouched")
    view_manager.switch_view(2)

    verify.call(crouch != null and walk != null and not crouch.walking_variant
        and walk.walking_variant and crouch.priority == walk.priority
        and controller.get_move(&"slide") != null
        and controller.get_move(&"dodge") != null,
        "Crouch installs as two configured moves without replacing default moves")
    var ctrl_key := InputEventKey.new()
    ctrl_key.keycode = KEY_CTRL
    verify.call(crouch.action_name == &"actor_crouch"
        and InputMap.event_is_action(ctrl_key, &"actor_crouch")
        and walk.action_name == &"",
        "The crouch toggle registers from the move metadata, not input core branches")
    var imported: AnimationPlayer = ValidatorScript.find_animation_player(
        actor.get_node("Visual/Model"))
    verify.call(animation.profile.clip_name(&"crouch") == &"crouch"
        and animation.profile.clip_name(&"crouch_walk") == &"crouch_walk"
        and imported.has_animation(&"crouch")
        and imported.has_animation(&"crouch_walk")
        and imported.get_animation(&"crouch").loop_mode == Animation.LOOP_LINEAR
        and imported.get_animation(&"crouch_walk").loop_mode == Animation.LOOP_LINEAR,
        "Both crouch animation clips import and loop through data-only mappings")

    # The original two-bone legs could only rotate a straight segment
    # forward, producing a seated pose. Imported thigh->knee->foot chains
    # must have separate skinned knee joints in both crouch animations.
    var rig: Skeleton3D = ValidatorScript.find_skeleton(actor.get_node("Visual/Model"))
    verify.call(rig != null and rig.get_bone_count() >= 13,
        "Crouch rig imports the two new articulated knee joints")
    for side in ["L", "R"]:
        var thigh_index: int = rig.find_bone("Leg_" + side)
        var knee_index: int = rig.find_bone("Knee_" + side)
        var ankle_index: int = rig.find_bone("Foot_" + side)
        verify.call(thigh_index >= 0 and knee_index >= 0 and ankle_index >= 0
            and rig.get_bone_parent(knee_index) == thigh_index
            and rig.get_bone_parent(ankle_index) == knee_index,
            "Articulated %s leg hierarchy is thigh -> knee -> ankle" % side)

    for clip_name in [&"crouch", &"crouch_walk"]:
        var clip: Animation = imported.get_animation(clip_name)
        var folded: Dictionary = {}
        for track_index in range(clip.get_track_count()):
            var path: NodePath = clip.track_get_path(track_index)
            if path.get_subname_count() == 0:
                continue
            var bone_name: String = str(path.get_subname(0))
            if not bone_name in ["Spine", "Leg_L", "Leg_R",
                    "Knee_L", "Knee_R", "Foot_L", "Foot_R"]:
                continue
            var key: Variant = clip.track_get_key_value(track_index, 0)
            if not (key is Quaternion):
                continue
            var angle: float = (key as Quaternion).get_euler().x
            folded[bone_name] = (
                angle < -0.2 if bone_name == "Spine"
                else angle > 0.6 if bone_name.begins_with("Leg_")
                else angle < -1.4 if bone_name.begins_with("Knee_")
                else angle > 0.6
            )
        verify.call(folded.size() == 7
            and folded.values().all(func(ok: bool) -> bool: return ok),
            "Imported %s bends knees forward and folds shins back beneath hips" % clip_name)

        # Check the actual articulated leg geometry in rig coordinates.
        # +X thigh rotation moves a downward knee vector toward -Z
        # (forward); the combined thigh+knee rotation moves the ankle
        # back toward +Z relative to the knee.
        for side in ["L", "R"]:
            var thigh_angle: float = 0.0
            var knee_angle: float = 0.0
            for track_index in range(clip.get_track_count()):
                var bone_path: NodePath = clip.track_get_path(track_index)
                if bone_path.get_subname_count() == 0:
                    continue
                var bone_name: String = str(bone_path.get_subname(0))
                if bone_name == "Leg_" + side:
                    thigh_angle = (clip.track_get_key_value(track_index, 0)
                        as Quaternion).get_euler().x
                elif bone_name == "Knee_" + side:
                    knee_angle = (clip.track_get_key_value(track_index, 0)
                        as Quaternion).get_euler().x
            var knee_offset: Vector3 = Vector3(0.0, -0.32, 0.0).rotated(
                Vector3.RIGHT, thigh_angle)
            var ankle_offset: Vector3 = Vector3(0.0, -0.30, 0.0).rotated(
                Vector3.RIGHT, thigh_angle + knee_angle)
            verify.call(knee_offset.z < -0.20 and ankle_offset.z > 0.17,
                "%s %s knee is forward of hip while shin folds back" % [
                    clip_name, side
                ])


    var walk_clip: Animation = imported.get_animation(&"crouch_walk")
    var left_stride: float = 0.0
    var right_stride: float = 0.0
    for track_index in range(walk_clip.get_track_count()):
        var path: NodePath = walk_clip.track_get_path(track_index)
        if path.get_subname_count() == 0:
            continue
        var name: String = str(path.get_subname(0))
        if name == "Leg_L" or name == "Leg_R":
            var first: Quaternion = walk_clip.track_get_key_value(track_index, 1)
            var second: Quaternion = walk_clip.track_get_key_value(track_index, 3)
            var travel: float = first.get_euler().x - second.get_euler().x
            if name == "Leg_L":
                left_stride = travel
            else:
                right_stride = travel
    verify.call(left_stride * right_stride < -0.05,
        "Crouch walking alternates back-swept legs instead of using a static seated pose")

    for i in range(12):
        await tree.physics_frame
    var request := IntentScript.new()
    request.request_move(&"crouch")
    actor.apply_move_intent(request)
    await tree.physics_frame
    actor.apply_move_intent(IntentScript.new())
    for i in range(4):
        await tree.physics_frame
    verify.call(controller.active_id == &"crouch"
        and animation.base_clip == &"crouch" and actor.is_on_floor(),
        "Crouch idle enters through the standard movement FSM and plays its own clip")
    verify.call(is_equal_approx(eye_presenter.target_offset_y, -0.45)
        and eye_offset.position.y < -0.05,
        "Crouch automatically lowers the view anchor without camera references")
    view_manager.switch_view(3)
    verify.call(absf(camera.global_position.y -
        (actor.global_position.y + first_person_height + eye_offset.position.y)) < 0.02,
        "Switching directly into F4 while crouched uses its lowered anchor")
    view_manager.switch_view(2)
    var crouched_shape := collision.shape as CapsuleShape3D
    verify.call(crouched_shape != standing_shape
        and is_equal_approx(crouched_shape.height, crouch.crouch_height)
        and collision.position.y < standing_position.y
        and is_equal_approx(standing_shape.height, 1.7),
        "Crouching shortens only this actor's collider and anchors its bottom")

    var start_x: float = actor.global_position.x
    actor.set_move_intent(Vector2.RIGHT)
    for i in range(20):
        await tree.physics_frame
    verify.call(controller.active_id == &"crouch_walk"
        and animation.base_clip == &"crouch_walk"
        and actor.global_position.x > start_x + 0.30
        and actor.global_position.x < start_x + 1.10
        and actor.velocity.x <= crouch.crouch_speed + 0.01,
        "Crouch-walk uses its own looping animation and reduced speed")

    verify.call(is_equal_approx(eye_presenter.target_offset_y, -0.45)
        and eye_offset.position.y < -0.25,
        "Crouch walking keeps exactly the same lowered eye-height target")

    # Camera switching must never reset stance or create another actor.
    var actor_id: int = actor.get_instance_id()
    for index in [2, 3, 4, 1]:
        view_manager.switch_view(index)
        await tree.physics_frame
        verify.call(controller.active_id == &"crouch_walk"
            and animation.base_clip == &"crouch_walk"
            and actor.get_instance_id() == actor_id,
            "Crouch-walk survives view %d with one authoritative actor" % [index + 1])
        if index == 3:
            verify.call(absf(camera.global_position.y -
                (actor.global_position.y + first_person_height + eye_offset.position.y)) < 0.02,
                "F3 -> F4 preserves the currently crouched eye anchor")

    actor.set_move_intent(Vector2.ZERO)
    for i in range(5):
        await tree.physics_frame
    verify.call(controller.active_id == &"crouch" and animation.base_clip == &"crouch",
        "Stopping while crouched returns to crouch idle without standing")

    # Prevent standing into a ceiling. A separate collision probe checks only
    # the volume newly occupied by the taller capsule, not the standing floor.
    var ceiling := StaticBody3D.new()
    var ceiling_collision := CollisionShape3D.new()
    var ceiling_shape := BoxShape3D.new()
    ceiling_shape.size = Vector3(1.1, 0.16, 1.1)
    ceiling_collision.shape = ceiling_shape
    ceiling.add_child(ceiling_collision)
    fixture.add_child(ceiling)
    ceiling.global_position = actor.global_position + Vector3(0.0, 1.51, 0.0)
    await tree.physics_frame
    request = IntentScript.new()
    request.request_move(&"crouch")
    actor.apply_move_intent(request)
    await tree.physics_frame
    actor.apply_move_intent(IntentScript.new())
    for i in range(2):
        await tree.physics_frame
    verify.call(controller.active_id == &"crouch"
        and (collision.shape as CapsuleShape3D).height < standing_shape.height
        and is_equal_approx(eye_presenter.target_offset_y, -0.45),
        "Blocked standing preserves both crouch collider and lowered eye target")
    ceiling.queue_free()
    await tree.physics_frame

    request = IntentScript.new()
    request.request_move(&"crouch")
    actor.apply_move_intent(request)
    await tree.physics_frame
    actor.apply_move_intent(IntentScript.new())
    for i in range(3):
        await tree.physics_frame
    verify.call(controller.active_id == &"grounded"
        and collision.shape == standing_shape
        and collision.position.is_equal_approx(standing_position)
        and animation.base_clip == &"idle"
        and is_zero_approx(eye_presenter.target_offset_y),
        "Standing restores the collider and default eye-height target")

    # A new Ctrl press on the SAME physics tick as the idle->walk
    # transition must not be swallowed by the walking variant's entry flag.
    request = IntentScript.new()
    request.request_move(&"crouch")
    actor.apply_move_intent(request)
    await tree.physics_frame
    actor.set_move_intent(Vector2.RIGHT)
    await tree.physics_frame  # Queues the crouch_walk transition.
    var early_stand := IntentScript.new(Vector2.RIGHT)
    early_stand.request_move(&"crouch")
    actor.apply_move_intent(early_stand)
    await tree.physics_frame
    verify.call(controller.active_id == &"grounded"
        and collision.shape == standing_shape
        and collision.position.is_equal_approx(standing_position),
        "First-frame crouch-walk toggle stands instead of swallowing Ctrl")

    # Re-entry and cancellation must not leave a crouched capsule behind.
    request = IntentScript.new()
    request.request_move(&"crouch")
    actor.apply_move_intent(request)
    await tree.physics_frame
    actor.apply_move_intent(IntentScript.new())
    for i in range(2):
        await tree.physics_frame
    actor.clear_motion()
    verify.call(collision.shape == standing_shape
        and collision.position.is_equal_approx(standing_position)
        and controller.active_id == &"",
        "Cancel/death-style cleanup restores the capsule without core changes")

    # Removing the presenter independently must restore the anchor,
    # disconnect move_changed, and leave the actor/camera fully operational.
    request = IntentScript.new()
    request.request_move(&"crouch")
    actor.apply_move_intent(request)
    await tree.physics_frame
    actor.apply_move_intent(IntentScript.new())
    await tree.physics_frame
    await tree.process_frame
    verify.call(controller.active_id == &"crouch"
        and eye_offset.position.y < 0.0,
        "Teardown fixture starts with an active lowered crouch view")
    actor.remove_child(eye_presenter)
    verify.call(is_zero_approx(eye_offset.position.y)
        and not controller.move_changed.is_connected(
            Callable(eye_presenter, "_on_move_changed")),
        "Removing eye presenter restores its anchor and disconnects signals")
    view_manager.switch_view(3)
    verify.call(absf(camera.global_position.y -
        (actor.global_position.y + first_person_height)) < 0.02,
        "F4 reverts to profile eye height after optional presenter is removed")
    eye_presenter.free()

    fixture.queue_free()
    await tree.process_frame
    (level.get_node("ViewManager/CameraRig/Camera3D") as Camera3D).current = true
