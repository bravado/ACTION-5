extends SceneTree
## D02 rendered evidence in Xvfb (real renderer, not --headless).
## Saves native-scene.png + native-view-1.png .. native-view-5.png.

func _initialize() -> void:
    call_deferred("_capture")


func _capture() -> void:
    var packed := load("res://demo/main.tscn") as PackedScene
    if packed == null:
        push_error("D02 screenshot: main scene failed to load")
        quit(1)
        return

    var scene := packed.instantiate()
    root.add_child(scene)
    await process_frame
    await RenderingServer.frame_post_draw

    var output_dir := ProjectSettings.globalize_path("res://build/evidence")
    if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
        push_error("D02 screenshot: cannot create evidence directory")
        quit(1)
        return

    if not _save_image(output_dir.path_join("native-scene.png")):
        quit(1)
        return

    var manager := scene.get_node("ViewManager") as Action5ViewManager
    for i in range(5):
        if not manager.switch_view(i):
            push_error("D02 screenshot: cannot switch view " + str(i + 1))
            quit(1)
            return
        for frame in range(20):
            await process_frame
        await RenderingServer.frame_post_draw
        if not _save_image(output_dir.path_join("native-view-%d.png" % (i + 1))):
            quit(1)
            return
        if i == 2:
            # Same isometric profile at two zoom levels; no sixth view.
            var settings := scene.get_node("Hud/CameraSettings")
            settings.call("set_current_value", "orthographic_size", 4.0)
            for frame in range(12):
                await process_frame
            await RenderingServer.frame_post_draw
            if not _save_image(output_dir.path_join("native-isometric-shoulder.png")):
                quit(1)
                return
            scene.call("_toggle_camera_settings")
            await process_frame
            await RenderingServer.frame_post_draw
            if not _save_image(output_dir.path_join("native-isometric-settings.png")):
                quit(1)
                return
            scene.call("_toggle_camera_settings")
            settings.call("reset_current_camera")

    # VT-12 visual evidence: the F4 eye camera must remain clear even
    # beside solid geometry. The wall is the existing NorthWall collider.
    var actor := scene.get_node("Player") as CharacterBody3D
    actor.call("clear_motion")
    actor.velocity = Vector3.ZERO
    actor.global_position = Vector3(0.0, 0.15, -8.1)
    for frame in range(12):
        await physics_frame
    if not actor.is_on_floor() or not manager.switch_view(2):
        push_error("VT-12: cannot ground the actor / switch to F3 beside NorthWall")
        quit(1)
        return
    for frame in range(12):
        await process_frame
    await RenderingServer.frame_post_draw
    if not _save_image(output_dir.path_join("native-f3-near-wall.png")):
        quit(1)
        return
    if not manager.switch_view(3):
        push_error("VT-12: cannot enter F4")
        quit(1)
        return
    for frame in range(12):
        await process_frame
    var eye: Camera3D = manager.get_active_camera()
    var ray := PhysicsRayQueryParameters3D.create(
        eye.global_position, eye.global_position - eye.global_basis.z * 2.0
    )
    ray.exclude = [actor.get_rid()]
    var hit: Dictionary = actor.get_world_3d().direct_space_state.intersect_ray(ray)
    var fps: Node = actor.get_node("FirstPersonPresenter")
    var body_layer: int = int(fps.get("local_body_render_layer"))
    if not (
        hit.get("collider") == scene.get_node("NorthWall")
        and not eye.get_cull_mask_value(body_layer)
        and eye.get_cull_mask_value(1)
        and actor.get_node("Visual").visible
    ):
        push_error("VT-12: wall ray, local body culling or world rendering failed")
        quit(1)
        return
    await RenderingServer.frame_post_draw
    if not _save_image(output_dir.path_join("native-f4-near-wall.png")):
        quit(1)
        return
    print("ACTION5_FPS_NEAR_WALL_NATIVE_OK wall=1 body_culled=1")

    # The local body is excluded by the camera, yet must still CAST a real
    # shadow. Capture the same overhead scene with its shadow-only skinned
    # counterparts enabled, then disabled. Only the shadows may differ.
    actor.global_position = Vector3(0, 0.15, 0)
    actor.velocity = Vector3.ZERO
    for frame in range(15):
        await physics_frame
    if not manager.switch_view(4):
        push_error("D04 shadow regression: F5 camera unavailable")
        quit(1)
        return
    var overhead: Camera3D = manager.get_active_camera()
    overhead.set_cull_mask_value(body_layer, false)
    overhead.set_cull_mask_value(int(fps.get("first_person_render_layer")), false)
    var shadow_meshes: Array = fps.get("shadow_meshes")
    if shadow_meshes.is_empty():
        push_error("D04 shadow regression: missing animated player shadow casters")
        quit(1)
        return
    # Exclude the separate weapon shadow throughout the comparison: only
    # the PLAYER's skinned body shadow should change between captures.
    var weapon_socket: Node3D = actor.get_node("AnimationPresenter").call(
        "get_socket", &"right_hand"
    ) as Node3D
    var socket_shadow: MeshInstance3D = (
        weapon_socket.get_node_or_null("TrainingToolShadow") as MeshInstance3D
    ) if weapon_socket != null else null
    if socket_shadow != null:
        socket_shadow.visible = false
    for frame in range(15):
        await process_frame
    await RenderingServer.frame_post_draw
    var with_shadow: Image = root.get_texture().get_image()
    if not _save_image(output_dir.path_join("native-player-shadow-on.png")):
        quit(1)
        return

    for mesh in shadow_meshes:
        (mesh as MeshInstance3D).visible = false
    for frame in range(10):
        await process_frame
    await RenderingServer.frame_post_draw
    var without_shadow: Image = root.get_texture().get_image()
    if not _save_image(output_dir.path_join("native-player-shadow-off.png")):
        quit(1)
        return

    var changed_pixels: int = 0
    for y in range(240, with_shadow.get_height(), 3):
        for x in range(0, with_shadow.get_width(), 3):
            var before: Color = with_shadow.get_pixel(x, y)
            var after: Color = without_shadow.get_pixel(x, y)
            if absf(before.r - after.r) + absf(before.g - after.g) + absf(before.b - after.b) > 0.04:
                changed_pixels += 1
    if changed_pixels < 15:
        push_error("D04 shadow regression: player shadow not visible on the rendered arena floor; changed pixels=" + str(changed_pixels))
        quit(1)
        return
    print("ACTION5_PLAYER_SHADOW_NATIVE_OK pixels=", changed_pixels)

    # D05 actual-render evidence: observe full-body vs upper-body
    # authored action and its real active physics hitbox on the same actor.
    for mesh in shadow_meshes:
        (mesh as MeshInstance3D).visible = true
    if socket_shadow != null:
        socket_shadow.visible = true
    var dummy: Node3D = scene.get_node("NearDummy") as Node3D
    dummy.global_position = Vector3(0, 0, -1.0)
    var target_health: Node = dummy.get_node("Health")
    actor.global_position = Vector3(0, 0.15, 0)
    actor.velocity = Vector3.ZERO
    actor.call("clear_motion")
    manager.switch_view(2)
    var combat: Node = actor.get_node("CombatController")
    combat.set("debug_hitboxes", true)
    for frame in range(12):
        await physics_frame
    for attack_id in [&"punch", &"kick"]:
        target_health.set("current_health", 100.0)
        var action = combat.call("get_attack", attack_id)
        if not combat.call("request_attack", attack_id, Vector2(0, -1)):
            push_error("D05: could not begin native " + str(attack_id))
            quit(1)
            return
        var active_seen: bool = false
        for frame in range(30):
            await physics_frame
            if combat.get("phase") == &"active":
                active_seen = true
                break
        if not active_seen:
            push_error("D05: active hit window not observed for " + str(attack_id))
            quit(1)
            return
        # Capture near the contact pose (last active physics tick), rather
        # than only the chamber/startup silhouette. This makes the newly
        # articulated elbows/knees visible in native rendered evidence.
        for frame in range(action.active_ticks - 1):
            await physics_frame
        if combat.get("phase") != &"active":
            push_error("D05: lost active phase before strike capture")
            quit(1)
            return
        await RenderingServer.frame_post_draw
        if not _save_image(output_dir.path_join("native-d05-%s.png" % attack_id)):
            quit(1)
            return
        for frame in range(action.total_ticks() + 5):
            await physics_frame
        if not is_equal_approx(target_health.get("current_health"), 100.0 - action.damage):
            push_error("D05: native hitbox failed to damage training target exactly once: " + str(attack_id))
            quit(1)
            return
    print("ACTION5_D05_NATIVE_COMBAT_OK punch=1 kick=1 active=1 dedup=1")

    # F4 camera-local articulated arm/leg evidence. Capture the idle
    # baseline, then compare large central/lower viewport regions during
    # Punch/Kick, not just the HUD or a debug log.
    manager.switch_view(3)
    for frame in range(12):
        await physics_frame
        await process_frame
    await RenderingServer.frame_post_draw
    var f4_idle: Image = root.get_texture().get_image()
    var f4_arm: Node3D = actor.get_node("FirstPersonCombatLimbs").call(
        "get_limb_root", &"punch") as Node3D
    if f4_arm == null or not f4_arm.visible or (
        eye.get_node_or_null("FirstPersonTrainingTool") != null
    ):
        push_error("D05: F4 rest must show only the real articulated arm, not the fake tool")
        quit(1)
        return
    var f4_fist: Node3D = f4_arm.get_node("Extremity") as Node3D
    var f4_fist_screen: Vector2 = eye.unproject_position(f4_fist.global_position)
    var f4_dimensions: Vector2 = Vector2(eye.get_viewport().get_visible_rect().size)
    var f4_pose: Dictionary = (f4_arm.get("profile") as Resource).call("sample", 0.0)
    var shoulder_screen: Vector2 = eye.unproject_position(
        eye.to_global(f4_pose["shoulder"])) / f4_dimensions
    var elbow_screen: Vector2 = eye.unproject_position(
        eye.to_global(f4_pose["joint"])) / f4_dimensions
    if shoulder_screen.x <= 1.02 or shoulder_screen.y <= 1.03 or (
        elbow_screen.x < 0.52 or elbow_screen.x > 0.98
    ) or (
        elbow_screen.y < 0.58 or elbow_screen.y > 0.98
    ):
        push_error("D05: resting arm is detached from viewport edge: shoulder="
            + str(shoulder_screen) + " elbow=" + str(elbow_screen))
        quit(1)
        return
    if eye.is_position_behind(f4_fist.global_position) or (
        f4_fist_screen.x < f4_dimensions.x * 0.52 or f4_fist_screen.x > f4_dimensions.x * 0.96
    ) or (
        f4_fist_screen.y < f4_dimensions.y * 0.40 or f4_fist_screen.y > f4_dimensions.y * 0.96
    ):
        push_error("D05: resting F4 fist is outside lower-right frame: " + str(f4_fist_screen))
        quit(1)
        return
    if not _save_image(output_dir.path_join("native-f4-combat-idle.png")):
        quit(1)
        return
    var limb_presenter: Node = actor.get_node("FirstPersonCombatLimbs")
    for attack_id in [&"punch", &"kick"]:
        var action = combat.call("get_attack", attack_id)
        if not combat.call("request_attack", attack_id, Vector2(0, -1)):
            push_error("D05: failed to start F4 " + str(attack_id))
            quit(1)
            return
        # Capture at authored contact progress, not after an arbitrary
        # number of paired render/physics waits. Software CI may advance
        # two physics ticks per iteration and finish a 15-tick Punch.
        var sampled_limb_contact: bool = false
        for frame in range(action.total_ticks() + 2):
            await physics_frame
            limb_presenter.call("refresh_presentation")
            var snapshot: Dictionary = actor.get_node(
                "CombatVisualState").call("get_visual_action")
            var progress: float = float(snapshot.get("progress", 0.0))
            if snapshot.get("key", &"") == attack_id and progress >= 0.27 and progress <= 0.43:
                sampled_limb_contact = true
                break
        var limb: Node3D = limb_presenter.call("get_limb_root", attack_id)
        if not sampled_limb_contact or limb == null or not limb.visible or not fps.first_person:
            push_error("D05: F4 authored contact pose not observed for " + str(attack_id))
            quit(1)
            return
        # Freeze the REAL authoritative pose at contact for a rendered
        # screenshot, without creating a second action or animation clock.
        paused = true
        await RenderingServer.frame_post_draw
        var frame_image: Image = root.get_texture().get_image()
        if not _save_image(output_dir.path_join("native-f4-%s-limb.png" % attack_id)):
            paused = false
            quit(1)
            return
        paused = false
        var changed: int = 0
        for y in range(int(frame_image.get_height() * 0.33), int(frame_image.get_height() * 0.93), 3):
            for x in range(int(frame_image.get_width() * 0.30), int(frame_image.get_width() * 0.88), 3):
                var a: Color = f4_idle.get_pixel(x, y)
                var b: Color = frame_image.get_pixel(x, y)
                if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.12:
                    changed += 1
        if changed < 50:
            push_error("D05: F4 %s limb did not alter rendered central frame (pixels=%d)" % [
                attack_id, changed
            ])
            quit(1)
            return
        for frame in range(action.total_ticks() + 2):
            await physics_frame
        print("ACTION5_F4_NATIVE_LIMB_OK action=", attack_id, " pixels=", changed)

    # D05 placed a training dummy directly against the camera for hitbox
    # checks. Restore an unobstructed view of the held Bat: F4 pose
    # evidence must reflect moving arm/weapon geometry, not a damaged
    # training dummy changing color in the center of the screenshot.
    dummy.global_position = Vector3(6.0, 0.0, -5.0)

    # D06-01 native evidence: the real Bat remains attached to the world
    # skeleton during camera switches. The camera-only prop must disappear
    # after dropping, while the original D04 training tool returns.
    var equipment: Node = actor.get_node("Equipment")
    var equipment_visual: Node = actor.get_node("EquipmentVisualAdapter")
    var bat: Node3D = scene.get_node("BatPickup") as Node3D
    if not equipment.call("pickup", bat):
        push_error("D06: cannot pick up Bat in native arena")
        quit(1)
        return
    if equipment_visual.get("_viewmodel") == null:
        push_error("D06: F4 viewmodel missing after native Bat pickup")
        quit(1)
        return
    manager.switch_view(2)
    for frame in range(10):
        await process_frame
    await RenderingServer.frame_post_draw
    if not _save_image(output_dir.path_join("native-d06-bat-world.png")):
        quit(1)
        return

    # VT-08: capture the imported world rig's TWO distinct Bat clips in all
    # four exterior cameras. Each view observes the SAME physical skeleton,
    # right-hand socket, D05 clock and actual animation (not a static prop).
    var world_socket: Node3D = actor.get_node("AnimationPresenter").call(
        "get_socket", &"right_hand") as Node3D
    var world_animator: Node = actor.get_node("AnimationPresenter")
    for world_view_index in [0, 1, 2, 4]:
        if not manager.switch_view(world_view_index):
            push_error("D06: cannot enter world view " + str(world_view_index + 1))
            quit(1)
            return
        for settle in range(8):
            await process_frame
        for strike_index in range(2):
            combat.call("cancel")
            for settle in range(2):
                await process_frame
            var world_clip: StringName = (
                &"bat_vertical" if strike_index == 0 else &"bat_horizontal"
            )
            var rest_hand: Vector3 = world_socket.global_position
            if not equipment.call("request_equipped_action", strike_index, Vector2(0, -1)):
                push_error("D06: world Bat action not registered: " + str(world_clip))
                quit(1)
                return
            var sampled_world: bool = false
            # Clip selection is authored in the AttackDefinition, independent
            # of camera input and the equipment's index.
            var selected_action: Resource = combat.call("get_attack",
                &"bat_swing" if strike_index == 0 else &"bat_horizontal")
            for tick in range(int(selected_action.call("total_ticks")) + 3):
                await physics_frame
                var snapshot: Dictionary = actor.get_node(
                    "CombatVisualState").call("get_visual_action")
                if snapshot.get("action_id", &"") == selected_action.get("attack_id") \
                        and float(snapshot.get("progress", 0.0)) >= 0.42 \
                        and float(snapshot.get("progress", 0.0)) <= 0.61:
                    sampled_world = true
                    break
            if not sampled_world or world_animator.get("upper_body_clip") != world_clip:
                push_error("D06: world Bat skeletal clip did not play in view "
                    + str(world_view_index + 1) + " clip=" + str(world_clip))
                quit(1)
                return
            paused = true
            await RenderingServer.frame_post_draw
            var image_path: String = output_dir.path_join(
                "native-d06-bat-%s-view-%d.png" % [world_clip, world_view_index + 1])
            if not _save_image(image_path):
                paused = false
                quit(1)
                return
            paused = false
            print("ACTION5_D06_WORLD_POSE_NATIVE_OK view=", world_view_index + 1,
                " attack=", world_clip, " hand_travel=",
                world_socket.global_position.distance_to(rest_hand))
            combat.call("cancel")
    manager.switch_view(2)
    for settle in range(10):
        await process_frame
    manager.switch_view(3)
    for frame in range(10):
        await process_frame

    # Real equipped F4 near-wall evidence; the gripping hand/weapon must
    # stay in frame while the player is against the actual NorthWall.
    actor.global_position = Vector3(0, 0.15, -8.1)
    for settle in range(12):
        await physics_frame
    for settle in range(8):
        await process_frame
    var near_model: Node3D = equipment_visual.get("_viewmodel") as Node3D
    var near_grip: Node3D = (
        near_model.get_node_or_null("Grip") as Node3D if near_model != null else null
    )
    var near_eye: Camera3D = manager.get_active_camera()
    var near_screen: Vector2 = (
        near_eye.unproject_position(near_grip.global_position)
        if near_grip != null else Vector2(-1, -1)
    )
    var viewport_size: Vector2 = near_eye.get_viewport().get_visible_rect().size
    if near_grip == null or near_eye.is_position_behind(near_grip.global_position) \
            or near_screen.x < 0.0 or near_screen.x > viewport_size.x \
            or near_screen.y < 0.0 or near_screen.y > viewport_size.y:
        push_error("D06: equipped F4 grip clipped outside viewport near solid wall")
        quit(1)
        return
    await RenderingServer.frame_post_draw
    if not _save_image(output_dir.path_join("native-d06-bat-f4-near-wall.png")):
        quit(1)
        return
    actor.global_position = Vector3(0, 0.15, 0)
    for settle in range(12):
        await physics_frame
    for frame in range(10):
        await process_frame
    await RenderingServer.frame_post_draw
    var armed_f4: Image = root.get_texture().get_image()
    if not _save_image(output_dir.path_join("native-d06-bat-f4.png")):
        quit(1)
        return
    # The weapon has its own camera-space arm/profile. F4 must NOT render
    # the old unarmed Punch fist behind it. Capture a real active physics
    # tick with the hand, grip and weapon moving as one visual unit.
    var equipped_view: Node3D = equipment_visual.get("_viewmodel") as Node3D
    var gripped_arm: Node3D = (
        equipped_view.get("arm") as Node3D if equipped_view != null else null
    )
    var grip: Node3D = (
        equipped_view.get_node_or_null("Grip") as Node3D if equipped_view != null else null
    )
    var bare_limbs: Node = actor.get_node("FirstPersonCombatLimbs")
    bare_limbs.call("refresh_presentation")
    if gripped_arm == null or grip == null or (
        bare_limbs.call("get_limb_root", &"punch") as Node3D
    ).visible:
        push_error("D06: F4 equipped view must show one gripping arm, not Punch")
        quit(1)
        return
    var rest_grip: Vector3 = grip.position
    if not equipment.call("request_equipped_action", 0, Vector2(0, -1)):
        push_error("D06: Bat's authoritative native swing request failed")
        quit(1)
        return
    var bat_action: Resource = combat.call("get_attack", &"bat_swing")
    var sampled_contact: bool = false
    # Sample each actual physics tick until we reach the authored contact
    # window, instead of awaiting both process_frame and physics_frame in
    # every iteration (which advances two ticks on some CI runners).
    for frame in range(int(bat_action.call("total_ticks")) + 3):
        await physics_frame
        equipment_visual.call("refresh_presentation")
        var current_progress: float = float(equipped_view.get("pose_progress"))
        if current_progress >= 0.42 and current_progress <= 0.56:
            sampled_contact = true
            break
    var active_grip: Vector3 = grip.position
    if not sampled_contact or active_grip.distance_to(rest_grip) < 0.22 or not grip.position.is_equal_approx(
        (gripped_arm.get_node("Extremity") as Node3D).position
    ):
        push_error("D06: weapon/gripping hand did not follow contact pose; progress="
            + str(equipped_view.get("pose_progress"))
            + " displacement=" + str(active_grip.distance_to(rest_grip))
            + " contact=" + str(sampled_contact))
        quit(1)
        return
    paused = true
    await RenderingServer.frame_post_draw
    var bat_swing_image: Image = root.get_texture().get_image()
    if not _save_image(output_dir.path_join("native-d06-bat-f4-swing.png")):
        paused = false
        quit(1)
        return
    paused = false
    var swing_pixels: int = 0
    for y in range(int(armed_f4.get_height() * 0.33), int(armed_f4.get_height() * 0.95), 4):
        for x in range(int(armed_f4.get_width() * 0.28), int(armed_f4.get_width() * 0.95), 4):
            var start_color: Color = armed_f4.get_pixel(x, y)
            var strike_color: Color = bat_swing_image.get_pixel(x, y)
            if absf(start_color.r - strike_color.r) + absf(start_color.g - strike_color.g) + absf(start_color.b - strike_color.b) > 0.24:
                swing_pixels += 1
    if swing_pixels < 50:
        push_error("D06: active weapon grip did not visibly move in F4; pixels=" + str(swing_pixels))
        quit(1)
        return
    print("ACTION5_D06_F4_SWING_NATIVE_OK grip=1 unarmed_hidden=1 pixels=", swing_pixels)

    # The Bat also has a separately authored lateral RMB/K swing.
    # Verify a real D05 secondary attack drives its own F4 profile,
    # without adding another hand, changing the world weapon or reusing
    # the vertical pose. The same physical Grip follows the arm.
    combat.call("cancel")
    equipment_visual.call("refresh_presentation")
    if not equipment.call("request_equipped_action", 1, Vector2(0, -1)):
        push_error("D06: Bat horizontal action not registered on its secondary slot")
        quit(1)
        return
    var horizontal_action: Resource = combat.call("get_attack", &"bat_horizontal")
    var sampled_horizontal: bool = false
    for frame in range(int(horizontal_action.call("total_ticks")) + 3):
        await physics_frame
        equipment_visual.call("refresh_presentation")
        var current_progress: float = float(equipped_view.get("pose_progress"))
        if current_progress >= 0.43 and current_progress <= 0.57:
            sampled_horizontal = true
            break
    var lateral_grip: Vector3 = grip.position
    var horizontal_profile: Resource = gripped_arm.get("profile") as Resource
    var hand_follows_grip: bool = grip.position.is_equal_approx(
        (gripped_arm.get_node("Extremity") as Node3D).position)
    if not (sampled_horizontal
            and lateral_grip.x < active_grip.x - 0.65
            and horizontal_profile != null
            and horizontal_profile.get("animation_key") == &"bat_horizontal"
            and hand_follows_grip):
        push_error("D06: F4 horizontal Bat pose did not sweep sideways with the hand"
            + " x_delta=" + str(lateral_grip.x - active_grip.x)
            + " progress=" + str(equipped_view.get("pose_progress")))
        quit(1)
        return
    paused = true
    await RenderingServer.frame_post_draw
    var horizontal_image: Image = root.get_texture().get_image()
    if not _save_image(output_dir.path_join("native-d06-bat-f4-horizontal.png")):
        paused = false
        quit(1)
        return
    paused = false
    var horizontal_pixels: int = 0
    for y in range(int(armed_f4.get_height() * 0.33), int(armed_f4.get_height() * 0.95), 4):
        for x in range(int(armed_f4.get_width() * 0.28), int(armed_f4.get_width() * 0.95), 4):
            var start_color: Color = armed_f4.get_pixel(x, y)
            var strike_color: Color = horizontal_image.get_pixel(x, y)
            if absf(start_color.r - strike_color.r) + absf(start_color.g - strike_color.g) + absf(start_color.b - strike_color.b) > 0.24:
                horizontal_pixels += 1
    if horizontal_pixels < 50:
        push_error("D06: horizontal F4 Bat strike not visibly different from rest")
        quit(1)
        return
    print("ACTION5_D06_F4_HORIZONTAL_NATIVE_OK grip=1 distinct=1 pixels=",
        horizontal_pixels)
    combat.call("cancel")
    equipment_visual.call("refresh_presentation")

    if not equipment.call("drop_current"):
        push_error("D06: cannot drop Bat from native equipped state")
        quit(1)
        return
    for frame in range(12):
        await process_frame
    await RenderingServer.frame_post_draw
    var dropped_f4: Image = root.get_texture().get_image()
    if not _save_image(output_dir.path_join("native-d06-dropped-f4.png")):
        quit(1)
        return
    var delta: int = 0
    for y in range(int(armed_f4.get_height() * 0.44), int(armed_f4.get_height() * 0.93), 4):
        for x in range(int(armed_f4.get_width() * 0.50), int(armed_f4.get_width() * 0.94), 4):
            var a: Color = armed_f4.get_pixel(x, y)
            var b: Color = dropped_f4.get_pixel(x, y)
            if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.24:
                delta += 1
    if delta < 50 or equipment_visual.get("_viewmodel") != null:
        push_error("D06: native first-person Bat visual did not clear after drop; pixels=" + str(delta))
        quit(1)
        return
    print("ACTION5_D06_NATIVE_EQUIPMENT_OK world=1 f4=1 drop=1 pixels=", delta)

    # Shovel also uses a dedicated world overhead clip, not unarmed Punch.
    var shovel: Node3D = scene.get_node("ShovelPickup") as Node3D
    if not equipment.call("pickup", shovel):
        push_error("D06: cannot pick up Shovel for native world pose matrix")
        quit(1)
        return
    for world_view_index in [0, 1, 2, 4]:
        if not manager.switch_view(world_view_index):
            push_error("D06: cannot enter Shovel world view " + str(world_view_index + 1))
            quit(1)
            return
        for settle in range(8):
            await process_frame
        combat.call("cancel")
        for settle in range(2):
            await process_frame
        if not equipment.call("request_equipped_action", 0, Vector2(0, -1)):
            push_error("D06: Shovel world overhead clip could not start")
            quit(1)
            return
        var sampled_shovel: bool = false
        var shovel_attack: Resource = combat.call("get_attack", &"shovel_swing")
        for tick in range(int(shovel_attack.call("total_ticks")) + 3):
            await physics_frame
            var snapshot: Dictionary = actor.get_node(
                "CombatVisualState").call("get_visual_action")
            if snapshot.get("action_id", &"") == &"shovel_swing" \
                    and float(snapshot.get("progress", 0.0)) >= 0.42 \
                    and float(snapshot.get("progress", 0.0)) <= 0.61:
                sampled_shovel = true
                break
        if not sampled_shovel or world_animator.get("upper_body_clip") != &"shovel_overhead":
            push_error("D06: Shovel overhead clip missing in view " + str(world_view_index + 1))
            quit(1)
            return
        paused = true
        await RenderingServer.frame_post_draw
        if not _save_image(output_dir.path_join(
            "native-d06-shovel-overhead-view-%d.png" % (world_view_index + 1))):
            paused = false
            quit(1)
            return
        paused = false
        print("ACTION5_D06_WORLD_POSE_NATIVE_OK view=", world_view_index + 1,
            " attack=shovel_overhead")
        combat.call("cancel")

    manager.switch_view(3)
    for settle in range(10):
        await process_frame
    if not equipment.call("request_equipped_action", 0, Vector2(0, -1)):
        push_error("D06: Shovel F4 swing could not start")
        quit(1)
        return
    var shovel_view: Node3D = equipment_visual.get("_viewmodel") as Node3D
    var shovel_f4_seen: bool = false
    var shovel_attack: Resource = combat.call("get_attack", &"shovel_swing")
    for tick in range(int(shovel_attack.call("total_ticks")) + 3):
        await physics_frame
        equipment_visual.call("refresh_presentation")
        if shovel_view != null \
                and float(shovel_view.get("pose_progress")) >= 0.42 \
                and float(shovel_view.get("pose_progress")) <= 0.60:
            shovel_f4_seen = true
            break
    if not shovel_f4_seen or shovel_view.get_node_or_null("Grip") == null:
        push_error("D06: Shovel F4 authored grip animation was not observed")
        quit(1)
        return
    paused = true
    await RenderingServer.frame_post_draw
    if not _save_image(output_dir.path_join("native-d06-shovel-f4-overhead.png")):
        paused = false
        quit(1)
        return
    paused = false
    combat.call("cancel")

    if not equipment.call("drop_current"):
        push_error("D06: cannot drop Shovel after world pose matrix")
        quit(1)
        return

    # D06-02 actual-render evidence: the same physical Gun is socket-mounted
    # in four exterior views and has one camera-local F4 gripping arm.
    # Rendering never supplies the authoritative muzzle or a second weapon.
    var gun: Node3D = scene.get_node("GunPickup") as Node3D
    gun.global_position = actor.global_position + Vector3(0.4, 0.4, 0)
    if not equipment.call("pickup", gun):
        push_error("D06-02: cannot pick up Gun after Shovel drop")
        quit(1)
        return
    var gun_muzzle := gun.get_node_or_null("Muzzle") as Node3D
    var gun_viewmodel: Node3D = equipment_visual.get("_viewmodel") as Node3D
    if gun_muzzle == null or gun_viewmodel == null or gun_viewmodel.get_node_or_null("Grip") == null:
        push_error("D06-02: missing physical Gun muzzle or camera-only hand/grip")
        quit(1)
        return
    for gun_view_index in [0, 1, 2, 4]:
        if not manager.switch_view(gun_view_index):
            push_error("D06-02: cannot enter Gun view " + str(gun_view_index + 1))
            quit(1)
            return
        for settle in range(10):
            await process_frame
        await RenderingServer.frame_post_draw
        if not _save_image(output_dir.path_join("native-d06-gun-view-%d.png" % (gun_view_index + 1))):
            quit(1)
            return
    # Capture a true in-flight world projectile in F3, not merely a
    # static held-gun screenshot. The shot's physics hit already resolved.
    manager.switch_view(2)
    for settle in range(12):
        await process_frame
    var projectile_presenter: Node = gun.get_node("ProjectilePresenter")
    var captured_projectiles: Array[Node3D] = []
    projectile_presenter.projectile_spawned.connect(func(effect: Node3D) -> void:
        captured_projectiles.append(effect)
    )
    if not equipment.call("request_equipped_action", 0, Vector2(0, -1)):
        push_error("D06-02: cannot fire Gun for visible exterior tracer")
        quit(1)
        return
    for tick in range(4):
        await physics_frame
    var world_projectile: Node3D = (
        captured_projectiles[0] if captured_projectiles.size() > 0 else null
    )
    if world_projectile == null or world_projectile.get_node_or_null("VisibleProjectile") == null:
        push_error("D06-02: fired world projectile was not rendered")
        quit(1)
        return
    paused = true
    await RenderingServer.frame_post_draw
    if not _save_image(output_dir.path_join("native-d06-gun-f3-projectile.png")):
        paused = false
        quit(1)
        return
    paused = false
    combat.call("cancel")
    for tick in range(20):
        await physics_frame

    manager.switch_view(3)
    for settle in range(15):
        await process_frame
    await RenderingServer.frame_post_draw
    if not _save_image(output_dir.path_join("native-d06-gun-f4-idle.png")):
        quit(1)
        return
    var captured_f4_muzzles: Array[Vector3] = []
    gun.fired.connect(func(_impact: Vector3, _did_hit: bool) -> void:
        captured_f4_muzzles.append(
            (gun_viewmodel.get_node("Grip/VisualMuzzle") as Node3D).global_position
        )
    )
    if not equipment.call("request_equipped_action", 0, Vector2(0, -1)):
        push_error("D06-02: cannot start F4 Gun fire through equipment")
        quit(1)
        return
    for tick in range(4):
        await physics_frame
    equipment_visual.call("refresh_presentation")
    var f4_projectile: Node3D = (
        captured_projectiles[1] if captured_projectiles.size() > 1 else null
    )
    if not is_instance_valid(gun_viewmodel) or gun.get("shots_fired") != 2             or f4_projectile == null             or f4_projectile.get_node_or_null("VisibleProjectile") == null:
        push_error("D06-02: Gun F4 did not show a visible active-phase projectile")
        quit(1)
        return
    var visible_shot_start: Vector3 = f4_projectile.get("from_world")
    if captured_f4_muzzles.size() != 1 \
            or not visible_shot_start.is_equal_approx(captured_f4_muzzles[0]) \
            or captured_f4_muzzles[0].distance_to(gun_muzzle.global_position) < 0.2:
        push_error("D06-02: F4 tracer did not start from the actual on-screen weapon barrel")
        quit(1)
        return
    print("ACTION5_D06_F4_VISUAL_MUZZLE_OK aligned=1 world_physics_unchanged=1")
    paused = true
    await RenderingServer.frame_post_draw
    if not _save_image(output_dir.path_join("native-d06-gun-f4-fire.png")):
        paused = false
        quit(1)
        return
    paused = false
    combat.call("cancel")
    for tick in range(20):
        await physics_frame
    if not gun.call("request_weapon_command", &"weapon_reload"):
        push_error("D06-02: failed to begin ammo reload for F4 visual")
        quit(1)
        return
    for tick in range(18):
        await physics_frame
    equipment_visual.call("refresh_presentation")
    await RenderingServer.frame_post_draw
    if not _save_image(output_dir.path_join("native-d06-gun-f4-reload.png")):
        quit(1)
        return
    # Near-wall F4 checks that world geometry remains readable while the
    # rendered gun/hand and physics muzzle stay separate.
    actor.call("clear_motion")
    actor.global_position = Vector3(0, 0.15, -8.1)
    actor.velocity = Vector3.ZERO
    for settle in range(15):
        await physics_frame
    await RenderingServer.frame_post_draw
    if not _save_image(output_dir.path_join("native-d06-gun-f4-near-wall.png")):
        quit(1)
        return
    if gun_muzzle.get_parent() != gun or equipment.get("current_weapon") != gun:
        push_error("D06-02: near-wall view disowned the physical world Gun")
        quit(1)
        return
    print("ACTION5_D06_GUN_NATIVE_OK world=4 f4=1 muzzle=1 reload=1 projectile=1")
    equipment.call("drop_current")

    print("ACTION5_FIVE_VIEW_SCREENSHOTS_OK 5")
    quit(0)


func _save_image(path: String) -> bool:
    var snapshot := root.get_texture().get_image()
    if snapshot == null or snapshot.is_empty():
        push_error("D02 screenshot: viewport is empty")
        return false
    if snapshot.save_png(path) != OK:
        push_error("D02 screenshot: could not save " + path)
        return false
    print("ACTION5_SCREENSHOT_OK ", path, " ", snapshot.get_width(), "x", snapshot.get_height())
    return true
