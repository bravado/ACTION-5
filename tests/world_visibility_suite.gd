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
    controller.call("_process", 1.0)
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

    # Removing a target while keeping its imported mesh alive restores its
    # authored state and releases ownership for a replacement target.
    views.switch_view(0)
    verify.call(not mesh.visible, "Fixture starts hidden before target removal")
    var mesh_id: int = mesh.get_instance_id()
    target.free()
    controller.call("_process", 0.0)
    verify.call(mesh.visible and mesh.get_surface_override_material(0) == material
        and not (controller.get("_visibility") as Dictionary).has(mesh_id)
        and not (controller.get("_materials") as Dictionary).has(mesh_id),
        "Removing a target restores its surviving mesh and releases its cache")
    var replacement := Target.new()
    replacement.policy = policy
    replacement.visual_root_path = ^"../ImportedGeometry"
    replacement.proximity_shape_path = ^""
    imported.add_child(replacement)
    views.switch_view(1)
    controller.call("_process", 1.0)
    verify.call((controller.get("_materials") as Dictionary).has(mesh_id)
        and mesh.get_surface_override_material(0) != material,
        "A new target can acquire the same mesh without leaking its old owner")
    # A replacement may also be attached before the next controller tick.
    replacement.free()
    var immediate := Target.new()
    immediate.policy = policy
    immediate.visual_root_path = ^"../ImportedGeometry"
    immediate.proximity_shape_path = ^""
    imported.add_child(immediate)
    controller.call("_process", 1.0)
    verify.call((controller.get("_materials") as Dictionary).has(mesh_id)
        and mesh.get_surface_override_material(0) != material,
        "Replacing a target in the same frame correctly releases old ownership")
    views.switch_view(4)
    verify.call(mesh.get_surface_override_material(0) == material,
        "Same-frame replacement retains the original material, not the old fade clone")

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

    # Imported meshes with a material_override must fade the actual rendered
    # material, not an ineffective surface override behind it.
    var override_root := Node3D.new()
    world.add_child(override_root)
    var override_mesh := MeshInstance3D.new()
    override_mesh.name = "OverrideMesh"
    override_mesh.mesh = BoxMesh.new()
    var original_override := StandardMaterial3D.new()
    original_override.albedo_color.a = 0.6
    override_mesh.material_override = original_override
    override_root.add_child(override_mesh)
    var override_target := Target.new()
    var override_policy := Policy.new()
    override_policy.fade_modes = 1 << 1
    override_target.policy = override_policy
    override_target.visual_root_path = ^"../OverrideMesh"
    override_target.proximity_shape_path = ^""
    override_root.add_child(override_target)
    player.global_position = override_mesh.global_position + Vector3(0, 0.15, 0)
    views.switch_view(1)
    controller.call("_process", 1.0)
    var faded_override := override_mesh.material_override as StandardMaterial3D
    verify.call(faded_override != null and faded_override != original_override
        and faded_override.albedo_color.a < 0.25
        and is_equal_approx(original_override.albedo_color.a, 0.6),
        "Imported material_override fades with a clone, preserving its source")
    views.switch_view(4)
    verify.call(override_mesh.material_override == original_override,
        "Opaque camera restores the exact imported material_override")
    views.switch_view(1)
    controller.call("_process", 1.0)
    override_target.free()
    controller.call("_process", 0.0)
    verify.call(override_mesh.material_override == original_override,
        "Removing a target restores an actively faded material_override")

    # Unsupported material types do not create ghost shadow changes.
    var unsupported := ORMMaterial3D.new()
    override_mesh.material_override = unsupported
    var unsupported_target := Target.new()
    unsupported_target.policy = override_policy
    unsupported_target.visual_root_path = ^"../OverrideMesh"
    unsupported_target.proximity_shape_path = ^""
    override_root.add_child(unsupported_target)
    var original_shadow: int = override_mesh.cast_shadow
    controller.call("_process", 1.0)
    verify.call(override_mesh.material_override == unsupported
        and override_mesh.cast_shadow == original_shadow,
        "Unsupported materials remain opaque with unchanged shadow state")
    unsupported_target.free()
    override_root.free()
    controller.call("_process", 0.0)

    # A target may disappear during fresh sector loading. No stale ownership.
    var target_id: int = mesh.get_instance_id()
    imported.free()
    controller.call("_process", 0.0)
    verify.call(not (controller.get("_materials") as Dictionary).has(target_id),
        "Dynamic imported scenes release material cache on unload")

    controller.queue_free()
    await tree.process_frame
    verify.call(grid.visible, "Removing controller restores authored GridMap visibility")
    world.queue_free()
    await tree.process_frame
