extends Node
const ViewProfileScript = preload("res://addons/action5/camera/view_profile.gd")
## Visual-only proximity fade for explicitly tagged *outer* perimeter
## walls. Only optional F1 front-mesh visibility changes with the view;
## no door, AI, navigation or collision state is changed.
##
## Use a duplicated StandardMaterial3D with alpha blending instead of
## GeometryInstance3D.transparency: the latter is unsupported by Godot's
## Compatibility/WebGL2 renderer. Cache one translucent material per mesh
## and restore its exact original surface override at full opacity.
## The wall group is opt-in; inner walls, door panels and obstacles are
## never affected. Newly loaded remote PackedScenes join automatically.

@export var actor_path: NodePath = ^"../Player"
@export var view_manager_path: NodePath = ^"../ViewManager"
@export var outer_wall_group: StringName = &"action5_outer_wall"
@export_range(1.0, 10.0, 0.1) var fade_start_distance: float = 3.8
@export_range(0.1, 5.0, 0.1) var fully_faded_distance: float = 1.1
@export_range(0.05, 0.95, 0.05) var closest_opacity: float = 0.20
@export_range(1.0, 30.0, 0.5) var fade_speed: float = 11.0
## Keep physical walls visibly solid in F4 (first person).
@export var preserve_first_person: bool = true
## Optional side-on wall hiding belongs to this same outer-wall presenter;
## the demo main script never directly writes a wall's visibility.
@export var side_hidden_mesh_path: NodePath

@onready var actor: Node3D = get_node_or_null(actor_path) as Node3D
@onready var views: Node = get_node_or_null(view_manager_path)

# Key: mesh instance id. Value: mesh weak ref, original material override,
# original shadow mode, cached fade material, current opacity.
var _materials: Dictionary = {}
var _side_mesh: MeshInstance3D
var _side_original_visible: bool = true


func _ready() -> void:
    _side_mesh = get_node_or_null(side_hidden_mesh_path) as MeshInstance3D
    if is_instance_valid(_side_mesh):
        _side_original_visible = _side_mesh.visible
    if is_instance_valid(views):
        views.view_changed.connect(_on_view_changed)
    _refresh_side_wall()


func _on_view_changed(_current: Resource, _previous: Resource) -> void:
    _refresh_side_wall()


func _refresh_side_wall() -> void:
    if not is_instance_valid(_side_mesh):
        return
    # Only its mesh is hidden in F1; the StaticBody3D remains solid.
    var side_view: bool = is_instance_valid(views) and views.current_profile != null \
        and views.current_profile.mode == ViewProfileScript.Mode.SIDE
    _side_mesh.visible = _side_original_visible and not side_view


func _process(delta: float) -> void:
    if not is_instance_valid(actor):
        return
    var first_person: bool = preserve_first_person and is_instance_valid(views) \
        and views.current_profile != null and views.current_profile.mode == ViewProfileScript.Mode.FIRST_PERSON
    var fade_rate: float = 1.0 - exp(-fade_speed * maxf(delta, 0.0))
    var distance_span: float = maxf(fade_start_distance - fully_faded_distance, 0.01)
    # Fresh-entry room replacement frees old wall meshes. Keep the cache
    # proportional to currently live meshes, not total room visits.
    _prune_materials()
    for candidate in get_tree().get_nodes_in_group(outer_wall_group):
        var wall := candidate as StaticBody3D
        if not is_instance_valid(wall) or not get_parent().is_ancestor_of(wall):
            continue
        var shape: CollisionShape3D = wall.get_node_or_null("CollisionShape3D") as CollisionShape3D
        if shape == null or not (shape.shape is BoxShape3D):
            continue
        # Use the physical box footprint, NOT the wall origin: a 28-m
        # wall must fade near its end just as it does at its midpoint.
        var p: Vector3 = shape.to_local(actor.global_position)
        var half: Vector3 = (shape.shape as BoxShape3D).size * 0.5
        var horizontal_distance: float = Vector2(
            maxf(absf(p.x) - half.x, 0.0),
            maxf(absf(p.z) - half.z, 0.0)
        ).length()
        var proximity: float = clampf(
            (fade_start_distance - horizontal_distance) / distance_span,
            0.0, 1.0
        )
        proximity = proximity * proximity * (3.0 - 2.0 * proximity)
        var desired_alpha: float = (
            1.0 if first_person else lerpf(1.0, closest_opacity, proximity)
        )
        for node in wall.get_children():
            var mesh := node as MeshInstance3D
            if not is_instance_valid(mesh):
                continue
            _set_opacity(mesh, desired_alpha, fade_rate)


func _prune_materials() -> void:
    for id in _materials.keys():
        var mesh: MeshInstance3D = (
            (_materials[id]["mesh"] as WeakRef).get_ref() as MeshInstance3D
        )
        if not is_instance_valid(mesh) or mesh.is_queued_for_deletion():
            _materials.erase(id)


func _set_opacity(mesh: MeshInstance3D, target: float, blend: float) -> void:
    var id: int = mesh.get_instance_id()
    if not _materials.has(id):
        var original: Material = mesh.get_surface_override_material(0)
        var base := (original if original != null
            else mesh.get_active_material(0)) as StandardMaterial3D
        if base == null:
            return
        var transparent := base.duplicate(true) as StandardMaterial3D
        transparent.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        _materials[id] = {
            "mesh": weakref(mesh),
            "original": original,
            "transparent": transparent,
            "alpha": 1.0,
            "shadow": mesh.cast_shadow
        }
    var entry: Dictionary = _materials[id]
    var alpha: float = lerpf(float(entry["alpha"]), target, blend)
    entry["alpha"] = alpha
    var fade_material: StandardMaterial3D = entry["transparent"]
    if alpha > 0.995:
        if mesh.get_surface_override_material(0) != entry["original"]:
            mesh.set_surface_override_material(0, entry["original"])
        mesh.cast_shadow = entry["shadow"]
    else:
        var shade: Color = fade_material.albedo_color
        shade.a = alpha
        fade_material.albedo_color = shade
        if mesh.get_surface_override_material(0) != fade_material:
            mesh.set_surface_override_material(0, fade_material)
        mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _exit_tree() -> void:
    if is_instance_valid(views) and views.view_changed.is_connected(_on_view_changed):
        views.view_changed.disconnect(_on_view_changed)
    if is_instance_valid(_side_mesh):
        _side_mesh.visible = _side_original_visible
    for entry in _materials.values():
        var mesh: MeshInstance3D = (entry["mesh"] as WeakRef).get_ref() as MeshInstance3D
        if is_instance_valid(mesh):
            mesh.set_surface_override_material(0, entry["original"])
            mesh.cast_shadow = entry["shadow"]
    _materials.clear()
