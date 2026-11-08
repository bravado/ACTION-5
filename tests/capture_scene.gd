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
