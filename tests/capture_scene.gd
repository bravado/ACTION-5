extends SceneTree
## Native screenshot with a real renderer (run with xvfb-run, not --headless).
## Output: build/evidence/native-scene.png

func _initialize() -> void:
    call_deferred("_capture")


func _capture() -> void:
    var packed := load("res://demo/main.tscn") as PackedScene
    if packed == null:
        push_error("D01 screenshot: main scene could not load")
        quit(1)
        return
    root.add_child(packed.instantiate())
    await process_frame
    await RenderingServer.frame_post_draw
    var snapshot := root.get_texture().get_image()
    if snapshot == null or snapshot.is_empty():
        push_error("D01 screenshot: viewport returned no pixels")
        quit(1)
        return

    var output_dir := ProjectSettings.globalize_path("res://build/evidence")
    var error := DirAccess.make_dir_recursive_absolute(output_dir)
    if error != OK:
        push_error("D01 screenshot: cannot create output directory")
        quit(1)
        return

    var output_file := output_dir.path_join("native-scene.png")
    error = snapshot.save_png(output_file)
    if error != OK:
        push_error("D01 screenshot: cannot save image")
        quit(1)
        return

    print("ACTION5_SCREENSHOT_OK ", output_file, " ", snapshot.get_width(), "x", snapshot.get_height())
    quit(0)
