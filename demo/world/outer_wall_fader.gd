extends Node
const ViewProfileScript = preload("res://addons/action5/camera/view_profile.gd")
## Render-only rules for explicitly tagged exterior perimeter walls.
## F1 hides authored camera-foreground meshes; F2/F3 may proximity fade;
## F4/F5 remain opaque. Never change collision, AI, doors or navigation.
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
## Keep exterior walls opaque in first-person and overhead views.
@export var preserve_first_person: bool = true
@export var preserve_top_down: bool = true
## Camera-foreground meshes in F1 opt in on their StaticBody3D parents.
## Only meshes disappear; the collider and other room-root visuals persist.
@export var side_hidden_wall_group: StringName = &"action5_side_hidden_wall"

@onready var actor: Node3D = get_node_or_null(actor_path) as Node3D
@onready var views: Node = get_node_or_null(view_manager_path)

# Key: mesh instance id. Original visibility, material and shadow state
# share one weak-reference cache, so scene reset/reload cannot leak either.
var _materials: Dictionary = {}


func _ready() -> void:
    if is_instance_valid(views):
        views.view_changed.connect(_on_view_changed)
    _process(0.0)


func _on_view_changed(_current: Resource, _previous: Resource) -> void:
    # Apply F1 mesh hiding and F4/F5 opacity before the next physics tick.
    _process(0.0)


func _process(delta: float) -> void:
    if not is_instance_valid(actor):
        return
    var mode: int = -1
    if is_instance_valid(views) and views.current_profile != null:
        mode = views.current_profile.mode
    var side_view: bool = mode == ViewProfileScript.Mode.SIDE
    var opaque_view: bool = (
        (preserve_first_person and mode == ViewProfileScript.Mode.FIRST_PERSON)
        or (preserve_top_down and mode == ViewProfileScript.Mode.RETRO_TOPDOWN)
    )
    # Do not leave an old alpha material on screen during F4/F5 entry.
    var fade_rate: float = (
        1.0 if opaque_view else 1.0 - exp(-fade_speed * maxf(delta, 0.0))
    )
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
            1.0 if opaque_view else lerpf(1.0, closest_opacity, proximity)
        )
        var hide_in_side: bool = side_view and wall.is_in_group(side_hidden_wall_group)
        for node in wall.get_children():
            var mesh := node as MeshInstance3D
            if not is_instance_valid(mesh):
                continue
            _set_opacity(mesh, desired_alpha, fade_rate)
            if wall.is_in_group(side_hidden_wall_group):
                var original_visible: bool = bool(_materials[mesh.get_instance_id()]["visible"])
                var should_show: bool = original_visible and not hide_in_side
                if mesh.visible != should_show:
                    mesh.visible = should_show


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
        var transparent: StandardMaterial3D
        if base != null:
            transparent = base.duplicate(true) as StandardMaterial3D
            transparent.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        _materials[id] = {
            "mesh": weakref(mesh),
            "original": original,
            "transparent": transparent,
            "alpha": 1.0,
            "shadow": mesh.cast_shadow,
            "visible": mesh.visible
        }
    var entry: Dictionary = _materials[id]
    var fade_material: StandardMaterial3D = entry["transparent"]
    if fade_material == null:
        return
    var alpha: float = lerpf(float(entry["alpha"]), target, blend)
    entry["alpha"] = alpha
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
    for entry in _materials.values():
        var mesh: MeshInstance3D = (entry["mesh"] as WeakRef).get_ref() as MeshInstance3D
        if is_instance_valid(mesh):
            mesh.visible = bool(entry["visible"])
            mesh.set_surface_override_material(0, entry["original"])
            mesh.cast_shadow = entry["shadow"]
    _materials.clear()
