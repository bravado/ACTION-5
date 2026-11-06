extends SceneTree
## D02 rendered evidence in Xvfb (real renderer, not --headless).
## Saves native-scene.png + native-view-1.png .. native-view-6.png.

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

    print("ACTION5_FIVE_VIEW_SCREENSHOTS_OK 6")
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
