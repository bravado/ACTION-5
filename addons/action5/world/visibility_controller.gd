extends Node
class_name Action5VisibilityController
## View-dependent rendering only; never edits colliders, navigation or AI.
## Registration happens on scene insertion, not via a scene-tree scan per frame.
## A single controller owns each registered visual's presentation state.
## Works with mesh prefabs and GLB imports; GridMap supports visibility only.

@export var actor_path: NodePath = ^"../Player"
@export var view_manager_path: NodePath = ^"../ViewManager"

@onready var actor: Node3D = get_node_or_null(actor_path) as Node3D
@onready var views: Node = get_node_or_null(view_manager_path)

## Target instance ID -> {node: WeakRef, visuals: Array[WeakRef]}.
var _targets: Dictionary = {}
## Visual instance ID -> original visibility and owning target.
var _visibility: Dictionary = {}
## Mesh instance ID -> original per-surface materials/shadow and fade copies.
var _materials: Dictionary = {}


func _ready() -> void:
    if is_instance_valid(views):
        views.view_changed.connect(_on_view_changed)
    get_tree().node_added.connect(_on_node_added)
    for candidate in get_tree().get_nodes_in_group(&"action5_visibility_target"):
        _register_target(candidate)
    _process(0.0)


func _on_view_changed(_current: Resource, _previous: Resource) -> void:
    # Switching to a non-fading view restores opaque materials immediately.
    _process(0.0)


func _on_node_added(candidate: Node) -> void:
    if candidate is Action5VisibilityTarget:
        call_deferred("_register_target", weakref(candidate))


func _register_target(candidate: Variant) -> void:
    var target: Action5VisibilityTarget
    if candidate is WeakRef:
        target = (candidate as WeakRef).get_ref() as Action5VisibilityTarget
    else:
        target = candidate as Action5VisibilityTarget
    if not is_instance_valid(target) or not is_inside_tree() \
            or target.policy == null or not get_parent().is_ancestor_of(target) \
            or _targets.has(target.get_instance_id()):
        return
    var registered: Array[WeakRef] = []
    for visual in target.visuals():
        if _visibility.has(visual.get_instance_id()):
            push_warning("ACTION5: Visual already has a VisibilityTarget: " + str(visual.get_path()))
            continue
        var id: int = visual.get_instance_id()
        _visibility[id] = {
            "node": weakref(visual), "visible": visual.visible,
            "target": weakref(target)
        }
        if visual is MeshInstance3D:
            _cache_mesh(visual as MeshInstance3D)
        registered.append(weakref(visual))
    _targets[target.get_instance_id()] = {"node": weakref(target), "visuals": registered}


func _cache_mesh(mesh: MeshInstance3D) -> void:
    var surfaces: Array[Dictionary] = []
    if mesh.mesh != null:
        for i in range(mesh.mesh.get_surface_count()):
            var original: Material = mesh.get_surface_override_material(i)
            var base: Material = original if original != null else mesh.get_active_material(i)
            var transparent: StandardMaterial3D
            var original_alpha: float = 1.0
            if base is StandardMaterial3D:
                var material := base as StandardMaterial3D
                transparent = material.duplicate(true) as StandardMaterial3D
                transparent.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
                original_alpha = material.albedo_color.a
            surfaces.append({
                "index": i, "original": original,
                "fade": transparent, "original_alpha": original_alpha
            })
    _materials[mesh.get_instance_id()] = {
        "mesh": weakref(mesh), "surfaces": surfaces,
        "shadow": mesh.cast_shadow, "alpha": 1.0
    }


func _process(delta: float) -> void:
    if not is_instance_valid(actor):
        return
    var mode: int = -1
    if is_instance_valid(views) and views.current_profile != null:
        mode = views.current_profile.mode
    _prune()
    for entry in _targets.values():
        var target := (entry["node"] as WeakRef).get_ref() as Action5VisibilityTarget
        if not is_instance_valid(target):
            continue
        var policy: Action5VisibilityPolicy = target.policy
        if policy == null:
            continue
        var hidden: bool = policy.hides_in(mode)
        var fading: bool = policy.fades_in(mode) and not hidden
        var opacity: float = (
            policy.opacity_at(target.horizontal_distance(
                actor.global_position, entry["visuals"])) if fading else 1.0)
        var blend: float = (
            1.0 - exp(-policy.fade_speed * maxf(delta, 0.0)) if fading else 1.0)
        for reference in entry["visuals"]:
            var visual := (reference as WeakRef).get_ref() as Node3D
            if not is_instance_valid(visual):
                continue
            var state: Dictionary = _visibility.get(visual.get_instance_id(), {})
            if state.is_empty():
                continue
            var desired_visible: bool = bool(state["visible"]) and not hidden
            if visual.visible != desired_visible:
                visual.visible = desired_visible
            if visual is MeshInstance3D:
                _set_opacity(visual as MeshInstance3D, opacity, blend)


func _set_opacity(mesh: MeshInstance3D, opacity: float, blend: float) -> void:
    var entry: Dictionary = _materials.get(mesh.get_instance_id(), {})
    if entry.is_empty():
        return
    var alpha: float = lerpf(float(entry["alpha"]), opacity, blend)
    entry["alpha"] = alpha
    var opaque: bool = alpha > 0.995
    for surface in entry["surfaces"]:
        var index: int = surface["index"]
        var material: StandardMaterial3D = surface["fade"]
        var original: Material = surface["original"]
        if opaque or material == null:
            if mesh.get_surface_override_material(index) != original:
                mesh.set_surface_override_material(index, original)
        else:
            var tint: Color = material.albedo_color
            tint.a = float(surface["original_alpha"]) * alpha
            material.albedo_color = tint
            if mesh.get_surface_override_material(index) != material:
                mesh.set_surface_override_material(index, material)
    mesh.cast_shadow = (
        entry["shadow"] if opaque else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)


func _prune() -> void:
    for id in _targets.keys():
        var node: Node = (_targets[id]["node"] as WeakRef).get_ref()
        if not is_instance_valid(node) or node.is_queued_for_deletion():
            _targets.erase(id)
    for id in _visibility.keys():
        var node: Node = (_visibility[id]["node"] as WeakRef).get_ref()
        if not is_instance_valid(node) or node.is_queued_for_deletion():
            _visibility.erase(id)
            _materials.erase(id)


func _exit_tree() -> void:
    if is_instance_valid(views) and views.view_changed.is_connected(_on_view_changed):
        views.view_changed.disconnect(_on_view_changed)
    if get_tree().node_added.is_connected(_on_node_added):
        get_tree().node_added.disconnect(_on_node_added)
    for state in _visibility.values():
        var visual: Node3D = (state["node"] as WeakRef).get_ref() as Node3D
        if is_instance_valid(visual):
            visual.visible = bool(state["visible"])
    for state in _materials.values():
        var mesh: MeshInstance3D = (state["mesh"] as WeakRef).get_ref() as MeshInstance3D
        if not is_instance_valid(mesh):
            continue
        for surface in state["surfaces"]:
            mesh.set_surface_override_material(surface["index"], surface["original"])
        mesh.cast_shadow = state["shadow"]
    _targets.clear()
    _visibility.clear()
    _materials.clear()
