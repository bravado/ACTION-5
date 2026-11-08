extends RefCounted
## D05 camera-space viewmodel architecture, visual bounds and lifecycle.
## Fixed gameplay tests remain in d05_suite.gd. No attack/animation changes.

const LimbScript = preload("res://addons/action5/animation/first_person_combat_limb_presenter.gd")
const GeometryScript = preload("res://addons/action5/animation/first_person_limb_geometry.gd")
const ProfileScript = preload("res://addons/action5/animation/first_person_limb_profile.gd")
const PoseScript = preload("res://addons/action5/animation/first_person_pose_key.gd")
const FPScript = preload("res://addons/action5/animation/first_person_presenter.gd")
const CombatScript = preload("res://addons/action5/combat/combat_controller.gd")
const AnimationScript = preload("res://addons/action5/animation/animation_presenter.gd")
const ViewManagerScript = preload("res://addons/action5/camera/view_manager.gd")


func _in_screen(camera: Camera3D, local_position: Vector3,
        min_x: float, max_x: float, min_y: float, max_y: float) -> bool:
    var world_position: Vector3 = camera.to_global(local_position)
    if camera.is_position_behind(world_position):
        return false
    var uv: Vector2 = camera.unproject_position(world_position)
    var size: Vector2 = Vector2(camera.get_viewport().get_visible_rect().size)
    if size.x < 2.0 or size.y < 2.0:
        return false
    uv /= size
    return uv.x >= min_x and uv.x <= max_x and uv.y >= min_y and uv.y <= max_y


## Pure perspective-frustum estimate for aspect-ratio coverage; native
## screenshot checks use Camera3D.unproject_position() to verify Godot.
func _project_pose(local_position: Vector3, field_of_view: float,
        aspect: float) -> Vector2:
    var half_height: float = -local_position.z * tan(deg_to_rad(field_of_view) * 0.5)
    return Vector2(
        0.5 + local_position.x / (2.0 * half_height * aspect),
        0.5 - local_position.y / (2.0 * half_height)
    )


func run_tests(tree: SceneTree, level: Node3D, verify: Callable) -> void:
    var actor: CharacterBody3D = level.get_node("Player") as CharacterBody3D
    var views: ViewManagerScript = level.get_node("ViewManager") as ViewManagerScript
    var combat: CombatScript = actor.get_node("CombatController") as CombatScript
    var fps: FPScript = actor.get_node("FirstPersonPresenter") as FPScript
    var visual: LimbScript = actor.get_node("FirstPersonCombatLimbs") as LimbScript
    var source: Node = actor.get_node("CombatVisualState")
    var animator: AnimationScript = actor.get_node("AnimationPresenter") as AnimationScript
    var camera: Camera3D = views.get_active_camera()
    var arm: GeometryScript = visual.get_limb_root(&"punch") as GeometryScript
    var leg: GeometryScript = visual.get_limb_root(&"kick") as GeometryScript

    verify.call(fps.is_local_actor() and arm != null and leg != null
        and source.has_method("get_visual_action"),
        "Camera-local viewmodels receive a generic action snapshot and no second gameplay actor")
    if arm == null or leg == null:
        return

    verify.call(arm.get_parent() == camera and leg.get_parent() == camera
        and arm.get_node_or_null("UpperLimb") is MeshInstance3D
        and arm.get_node_or_null("LowerLimb") is MeshInstance3D
        and arm.get_node_or_null("Extremity") is MeshInstance3D,
        "Arm and leg are isolated camera-local visual components")
    var layer: int = 1 << (fps.first_person_render_layer - 1)
    var presentation_isolated: bool = true
    for root in [arm, leg]:
        presentation_isolated = presentation_isolated and root.find_children(
            "*", "Skeleton3D", true, false).is_empty()
        for mesh in root.find_children("*", "MeshInstance3D", true, false):
            var part: MeshInstance3D = mesh as MeshInstance3D
            presentation_isolated = presentation_isolated and (
                part.layers == layer and part.cast_shadow
                    == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            )
    verify.call(presentation_isolated
        and (arm.upper.mesh is CapsuleMesh) and (leg.lower.mesh is CapsuleMesh)
        and arm.profile.upper_radius <= 0.075 and leg.profile.upper_radius <= 0.09,
        "Small rounded, shadow-free limbs replace the giant circular cylinder caps")
    verify.call(arm.profile.visible_at_rest and not leg.profile.visible_at_rest,
        "Only the articulated right arm is persistent; leg belongs to its attack")

    # Authoring is camera-space, not skeleton-space. Interpolation must not
    # mutate source pose Resources shared among actor instances.
    var rest_pose: Dictionary = arm.profile.sample(0.0)
    var windup: Dictionary = arm.profile.sample(0.16)
    var contact: Dictionary = arm.profile.sample(0.33)
    verify.call(rest_pose["extremity"].z < -0.7
        and windup["extremity"].z > rest_pose["extremity"].z
        and contact["extremity"].z < rest_pose["extremity"].z - 0.35,
        "First-person punch has chamber, extension and recovery authored in view space")
    verify.call((arm.profile.sample(1.0)["extremity"] as Vector3).is_equal_approx(
        rest_pose["extremity"]),
        "Authored Punch returns exactly to its camera-space rest pose")
    var leg_start: Dictionary = leg.profile.sample(0.0)
    var leg_chamber: Dictionary = leg.profile.sample(0.22)
    var leg_contact: Dictionary = leg.profile.sample(0.35)
    verify.call(leg_chamber["joint"].y > leg_start["joint"].y + 0.15
        and leg_contact["extremity"].z < leg_chamber["extremity"].z - 0.45,
        "Kick raises its knee first, then extends the foot independently of world rig")
    verify.call(arm.profile.valid() and leg.profile.valid()
        and not (ProfileScript.new()).valid(),
        "Invalid pose configurations fail without modifying combat/controller code")

    var bad := ProfileScript.new()
    bad.animation_key = &"broken_viewmodel"
    var malformed: Array[Resource] = []
    malformed.append(PoseScript.new())
    bad.poses = malformed
    verify.call(not visual.register_profile(bad) and
        visual.get_limb_root(&"broken_viewmodel") == null,
        "Malformed viewmodel timelines are rejected without affecting other views")
    var duplicate: ProfileScript = arm.profile.duplicate() as ProfileScript
    verify.call(not visual.register_profile(duplicate),
        "Duplicate viewmodel profiles cannot register twice")
    var extra: ProfileScript = arm.profile.duplicate() as ProfileScript
    extra.animation_key = &"another_attack"
    extra.visible_at_rest = false
    verify.call(visual.register_profile(extra)
        and visual.get_limb_root(&"another_attack") != null,
        "A third attack adds only data, without core gameplay or camera branches")

    var original_skeleton_id: int = animator.skeleton.get_instance_id()
    var original_shadows: int = fps.shadow_meshes.size()
    var camera_body_layer: int = fps.local_body_render_layer
    combat.cancel()
    views.switch_view(2)
    await tree.process_frame
    verify.call(not arm.visible and not leg.visible
        and camera.get_cull_mask_value(camera_body_layer),
        "F3 sees world actor with no F4 viewmodel leakage")
    views.switch_view(3)
    await tree.process_frame
    verify.call(arm.visible and not leg.visible
        and visual.active_limb_key() == &""
        and not camera.get_cull_mask_value(camera_body_layer),
        "Idle F4 always shows the resting arm and still hides world torso")
    verify.call(camera.get_node_or_null("FirstPersonTrainingTool") == null,
        "Retired demo fake hand and tool do not coexist with the new viewmodel")

    # An arm that starts entirely inside the viewport looks detached,
    # even when the fist is correctly placed. Every Punch pose must
    # originate beyond the lower-right screen edge, keeping the elbow
    # and fist inside. The default view still uses one camera and
    # must not unhide the world torso to conceal this problem.
    var rest_fist: Vector3 = arm.current_pose["extremity"]
    verify.call(_in_screen(camera, rest_fist, 0.55, 0.95, 0.54, 0.91),
        "F4 idle fist is lower-right, not a giant cylinder crossing the sightline")
    for t in [0.0, 0.16, 0.33, 0.62, 1.0]:
        var pose: Dictionary = arm.profile.sample(t)
        verify.call(_in_screen(camera, pose["extremity"], 0.45, 0.95, 0.50, 0.92),
            "F4 fist fits the viewport for authored Punch time %.2f" % t)
    for t in [0.13, 0.22, 0.35, 0.62]:
        var pose: Dictionary = leg.profile.sample(t)
        verify.call(_in_screen(camera, pose["joint"], 0.40, 0.85, 0.55, 0.96)
            and _in_screen(camera, pose["extremity"], 0.40, 0.85, 0.53, 0.99),
            "F4 knee and foot stay BELOW screen center at kick time %.2f" % t)
    # FOV settings must not reproduce the screenshot's extreme near-eye
    # circular caps, detached elbow or knee above the horizon. Viewmodel
    # coordinates are constant camera-relative metres, not scaled by FOV.
    var original_fov: float = camera.fov
    for test_fov in [65.0, 80.0, 100.0]:
        camera.fov = test_fov
        verify.call(_in_screen(camera, rest_pose["extremity"],
            0.50, 0.99, 0.50, 0.98),
            "Resting F4 fist remains framed at FOV %.0f degrees" % test_fov)
        for t in [0.0, 0.16, 0.33, 0.62, 1.0]:
            var pose: Dictionary = arm.profile.sample(t)
            var shoulder_uv: Vector2 = camera.unproject_position(
                camera.to_global(pose["shoulder"]))
            var screen: Vector2 = Vector2(camera.get_viewport().get_visible_rect().size)
            shoulder_uv /= screen
            verify.call(shoulder_uv.y > 1.03 and shoulder_uv.x > 1.02,
                "F4 arm shoulder stays OUTSIDE lower-right frame at FOV %.0f, pose %.2f" % [
                    test_fov, t
                ])
            verify.call(_in_screen(camera, pose["joint"],
                0.52, 0.98, 0.58, 0.98) and _in_screen(camera,
                pose["extremity"], 0.52, 0.98, 0.57, 0.98),
                "F4 elbow and fist stay CONNECTED to screen edge at FOV %.0f, pose %.2f" % [
                    test_fov, t
                ])
        # A visible hip cap makes the kicking leg float above the bottom
        # edge. The upper-thigh origin must remain beyond the lower edge,
        # while the knee stays in view, across all supported FOV settings.
        for t in [0.13, 0.22, 0.35, 0.62]:
            var kick_pose: Dictionary = leg.profile.sample(t)
            var hip_uv: Vector2 = camera.unproject_position(
                camera.to_global(kick_pose["shoulder"]))
            var knee_uv: Vector2 = camera.unproject_position(
                camera.to_global(kick_pose["joint"]))
            var viewport_size: Vector2 = Vector2(camera.get_viewport().get_visible_rect().size)
            hip_uv /= viewport_size
            knee_uv /= viewport_size
            verify.call(hip_uv.y > 1.08 and knee_uv.y < 0.99,
                "F4 kick thigh enters from BELOW the frame at FOV %.0f, pose %.2f" % [
                    test_fov, t
                ])
        verify.call(_in_screen(camera, leg_chamber["joint"],
            0.40, 0.95, 0.53, 0.99) and _in_screen(camera,
            leg_contact["extremity"], 0.40, 0.95, 0.53, 0.99),
            "Knee chamber and extending foot remain below aimline at FOV %.0f" % test_fov)
    camera.fov = original_fov

    # The reported floating arm happened in a 632x404 viewport. Guard
    # common wide/square aspect ratios without tying pose authoring to
    # the native CI viewport size or changing the gameplay camera.
    for dimensions in [Vector2(632, 404), Vector2(1280, 720), Vector2(1024, 768)]:
        for test_fov in [65.0, 80.0, 100.0]:
            var aspect: float = dimensions.x / dimensions.y
            var geometry_valid: bool = true
            for t in [0.0, 0.16, 0.33, 0.62, 1.0]:
                var pose: Dictionary = arm.profile.sample(t)
                var shoulder: Vector2 = _project_pose(pose["shoulder"], test_fov, aspect)
                var elbow: Vector2 = _project_pose(pose["joint"], test_fov, aspect)
                var fist: Vector2 = _project_pose(pose["extremity"], test_fov, aspect)
                geometry_valid = geometry_valid and (
                    shoulder.x > 1.02 and shoulder.y > 1.03
                    and elbow.x > 0.52 and elbow.x < 0.98
                    and elbow.y > 0.58 and elbow.y < 0.98
                    and fist.x > 0.52 and fist.x < 0.98
                    and fist.y > 0.57 and fist.y < 0.98
                )
            verify.call(geometry_valid,
                "F4 arm stays edge-attached at %dx%d / %.0f FOV" % [
                    int(dimensions.x), int(dimensions.y), test_fov
                ])

    # Check the leg's lower-edge attachment at the narrow screenshot
    # aspect as well as widescreen; the authored pose is camera-local.
    for dimensions in [Vector2(632, 404), Vector2(1280, 720), Vector2(1024, 768)]:
        for test_fov in [65.0, 80.0, 100.0]:
            var aspect: float = dimensions.x / dimensions.y
            var hip_attached: bool = true
            for t in [0.13, 0.22, 0.35, 0.62]:
                var pose: Dictionary = leg.profile.sample(t)
                var hip_uv: Vector2 = _project_pose(pose["shoulder"], test_fov, aspect)
                var knee_uv: Vector2 = _project_pose(pose["joint"], test_fov, aspect)
                hip_attached = hip_attached and hip_uv.y > 1.08 and knee_uv.y < 0.99
            verify.call(hip_attached,
                "F4 kick stays joined to bottom edge at %dx%d / %.0f FOV" % [
                    int(dimensions.x), int(dimensions.y), test_fov
                ])

    var action_ticks: int = combat.get_attack(&"punch").total_ticks()
    verify.call(combat.request_attack(&"punch", Vector2(0.0, -1.0)),
        "Gameplay Punch requests are independent of the F4 viewmodel")
    await tree.physics_frame
    await tree.process_frame
    var action: Dictionary = source.call("get_visual_action")
    verify.call(action.get("key", &"") == &"punch" and arm.visible
        and is_equal_approx(action.get("progress", 0.0),
            float(combat.elapsed_ticks) / float(action_ticks)),
        "Viewmodel reads normalized physics progress, not world-skeleton transforms")
    var first_fist: Vector3 = arm.current_pose["extremity"]
    for tick in range(4):
        await tree.physics_frame
        await tree.process_frame
    verify.call(first_fist.distance_to(arm.current_pose["extremity"]) > 0.2,
        "A fast F4 punch moves the visible fist without changing the world rig")
    views.switch_view(2)
    await tree.process_frame
    verify.call(not arm.visible and combat.current_id == &"punch",
        "F3 switch hides viewmodel but never restarts the action clock")
    views.switch_view(3)
    await tree.process_frame
    verify.call(arm.visible and combat.current_id == &"punch",
        "F4 re-entry resumes the same authored pose at current action progress")
    for tick in range(action_ticks + 3):
        await tree.physics_frame
    await tree.process_frame
    verify.call(arm.visible and not leg.visible and
        (arm.current_pose["extremity"] as Vector3).distance_to(rest_fist) < 0.001,
        "After Punch the persistent arm returns to its exact rest pose")

    var kick_ticks: int = combat.get_attack(&"kick").total_ticks()
    verify.call(combat.request_attack(&"kick", Vector2(0.0, -1.0)),
        "Kick does not need a camera-specific gameplay action")
    await tree.physics_frame
    # SceneTree.process_frame fires BEFORE Node._process(). Allow the
    # independent visual subscriber to consume the new combat snapshot;
    # the physics action clock must not be coupled to render scheduling.
    await tree.process_frame
    await tree.process_frame
    verify.call(arm.visible and leg.visible and visual.active_limb_key() == &"kick",
        "Kick adds only the leg while keeping the resting arm visible")
    var initial_foot: Vector3 = leg.current_pose["extremity"]
    for tick in range(6):
        await tree.physics_frame
        await tree.process_frame
    verify.call((leg.current_pose["extremity"] as Vector3).z < initial_foot.z - 0.35,
        "Foot extends forward from the knee chamber at the authoritative attack time")
    combat.cancel()
    await tree.process_frame
    verify.call(arm.visible and not leg.visible and visual.active_limb_key() == &"",
        "Cancel only removes kick leg, preserving permanent F4 arm")

    verify.call(animator.skeleton.get_instance_id() == original_skeleton_id
        and fps.shadow_meshes.size() == original_shadows,
        "Camera viewmodel never replaces world rig, sockets or animated shadows")
    views.switch_view(1)
    await tree.process_frame
    verify.call(not arm.visible and not leg.visible and
        camera.get_cull_mask_value(camera_body_layer),
        "F2 restores world-body rendering and hides viewmodel resources")
