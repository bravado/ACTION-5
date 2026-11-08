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
            (scene.get_node("Hud/SettingsToggle") as Button).pressed.emit()
            await process_frame
            await RenderingServer.frame_post_draw
            if not _save_image(output_dir.path_join("native-isometric-settings.png")):
                quit(1)
                return
            (scene.get_node("Hud/SettingsToggle") as Button).pressed.emit()
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
        for frame in range(action.startup_ticks + 2):
            await physics_frame
            await process_frame
        var limb: Node3D = limb_presenter.call("get_limb_root", attack_id)
        if limb == null or not limb.visible or not fps.first_person:
            push_error("D05: F4 animated limb not visible during " + str(attack_id))
            quit(1)
            return
        # A 15-tick punch may finish before the software renderer
        # produces its next frame. Freeze the REAL authoritative pose
        # immediately after the active tick, render it, then resume.
        # This is capture-only synchronization, not another attack clock
        # or a synthetic viewmodel pose.
        limb_presenter.call("refresh_presentation")
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
    manager.switch_view(3)
    for frame in range(10):
        await process_frame
    await RenderingServer.frame_post_draw
    var armed_f4: Image = root.get_texture().get_image()
    if not _save_image(output_dir.path_join("native-d06-bat-f4.png")):
        quit(1)
        return
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
