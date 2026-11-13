extends RefCounted
## Geometry-agnostic authoring regression: nested imported-style mesh, tiled
## GridMap, separate policies and ordinary collision. No demo wall names.

const Policy = preload("res://addons/action5/world/visibility_policy.gd")
const Target = preload("res://addons/action5/world/visibility_target.gd")


func run_tests(tree: SceneTree, verify: Callable) -> void:
    var world := (load("res://demo/main.tscn") as PackedScene).instantiate() as Node3D
    world.position = Vector3(2400, 0, 2400)
    tree.root.add_child(world)
    await tree.process_frame
    await tree.process_frame
    var player := world.get_node("Player") as Node3D
    var views := world.get_node("ViewManager")
    var controller := world.get_node("VisibilityController")

    # Simulate an arbitrary nested imported GLB wrapper with two meshes.
    var imported := Node3D.new()
    imported.name = "ImportedLevel"
    world.add_child(imported)
    var root := Node3D.new()
    imported.add_child(root)
    var mesh := MeshInstance3D.new()
    mesh.mesh = BoxMesh.new()
    var material := StandardMaterial3D.new()
    mesh.set_surface_override_material(0, material)
    root.add_child(mesh)
    imported.position = Vector3(0, 0, 35)
    var collider := StaticBody3D.new()
    imported.add_child(collider)
    var shape := CollisionShape3D.new()
    shape.shape = BoxShape3D.new()
    collider.add_child(shape)
    var policy := Policy.new()
    policy.fade_modes = 1 << 1
    policy.hidden_modes = 1 << 0
    var target := Target.new()
    target.policy = policy
    target.visual_root_path = ^"../ImportedGeometry"
    target.proximity_shape_path = ^""
    root.name = "ImportedGeometry"
    imported.add_child(target)
    await tree.process_frame
    await tree.process_frame

    player.global_position = mesh.global_position + Vector3(0, 0.15, 0)
    views.switch_view(1)
    controller._process(1.0)
    var faded := mesh.get_surface_override_material(0) as StandardMaterial3D
    verify.call(faded != null and faded != material
        and faded.albedo_color.a < 0.35,
        "Nested imported mesh fades using its geometry bounds without BoxShape3D")
    verify.call(not shape.disabled and collider.collision_layer != 0,
        "Imported visual fades never disable level collisions")
    views.switch_view(0)
    verify.call(not mesh.visible and mesh.get_surface_override_material(0) == material,
        "Independent view policy hides nested imported geometry without editing its material")
    views.switch_view(4)
    verify.call(mesh.visible and mesh.get_surface_override_material(0) == material,
        "Imported geometry restores original render state in top-down")

    # GridMap intentionally uses whole-node visibility, never per-cell alpha.
    var grid := GridMap.new()
    grid.name = "Tiles"
    world.add_child(grid)
    var tile_policy := Policy.new()
    tile_policy.hidden_modes = 1 << 0
    var tile_target := Target.new()
    tile_target.policy = tile_policy
    tile_target.visual_root_path = ^".."
    grid.add_child(tile_target)
    await tree.process_frame
    await tree.process_frame
    views.switch_view(0)
    verify.call(not grid.visible,
        "GridMap can be controlled as one authored visual group")
    views.switch_view(4)
    verify.call(grid.visible,
        "GridMap authored visibility returns without touching tile collision")

    # A target may disappear during fresh sector loading. No stale ownership.
    var target_id: int = mesh.get_instance_id()
    imported.free()
    controller._process(0.0)
    verify.call(not (controller._materials as Dictionary).has(target_id),
        "Dynamic imported scenes release material cache on unload")

    controller.queue_free()
    await tree.process_frame
    verify.call(grid.visible, "Removing controller restores authored GridMap visibility")
    world.queue_free()
    await tree.process_frame
