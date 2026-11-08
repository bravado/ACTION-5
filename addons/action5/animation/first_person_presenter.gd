extends Node
class_name Action5FirstPersonPresenter
## Local camera presentation for a single authoritative actor. World meshes
## remain skinned/animated; this component only assigns render/shadow policy.
## Equipment and demo assets register visuals without knowing camera layers.

const AnimationPresenterScript = preload("res://addons/action5/animation/animation_presenter.gd")
const ViewProfileScript = preload("res://addons/action5/camera/view_profile.gd")

@export var view_manager_path: NodePath = ^"../../ViewManager"
@export_range(2, 20, 1) var local_body_render_layer: int = 20
@export_range(2, 20, 1) var first_person_render_layer: int = 19

var first_person: bool = false
var body_meshes: Array[MeshInstance3D] = []
var shadow_meshes: Array[MeshInstance3D] = []
var world_visual_shadows: Array[MeshInstance3D] = []
var _camera: Camera3D
var _view_manager: Node
var _original_body_rendering: Dictionary = {}
var _local_actor: bool = false
var _initial_body_cull: bool = true
var _initial_first_person_cull: bool = true
var _registered_world_visuals: Dictionary = {}
var _first_person_visuals: Array[Node3D] = []


func _ready() -> void:
    var animation_presenter: AnimationPresenterScript = (
        get_node_or_null("../AnimationPresenter") as AnimationPresenterScript
    )
    var model: Node = animation_presenter.model if animation_presenter != null else null
    var manager: Node = get_node_or_null(view_manager_path)
    if manager == null or not manager.has_signal("view_changed") or model == null:
        return
    # The scene may also be instantiated for NPCs. Only the local actor has
    # private camera visuals and layer remapping.
    if manager.get_node_or_null(manager.get("actor_path")) != get_parent():
        return
    if local_body_render_layer == first_person_render_layer:
        push_error("ACTION5: world-body and first-person layers must differ")
        return

    _camera = manager.get_node_or_null("CameraRig/Camera3D") as Camera3D
    if _camera == null:
        push_warning("ACTION5: FirstPersonPresenter could not find local Camera3D")
        return
    _local_actor = true
    _view_manager = manager
    _initial_body_cull = _camera.get_cull_mask_value(local_body_render_layer)
    _initial_first_person_cull = _camera.get_cull_mask_value(first_person_render_layer)

    for descendant in model.find_children("*", "MeshInstance3D", true, false):
        var mesh := descendant as MeshInstance3D
        if _belongs_to_attachment(mesh, model):
            continue
        # Preserve the imported renderer's settings, including custom layers
        # and shadow policies, so this component can be removed independently.
        var original_layers: int = mesh.layers
        var original_shadow: GeometryInstance3D.ShadowCastingSetting = mesh.cast_shadow
        var shadow := _make_world_shadow(mesh, "ShadowCaster_" + str(mesh.name))
        if shadow == null:
            continue
        _original_body_rendering[mesh] = {
            "layers": original_layers, "cast_shadow": original_shadow
        }
        body_meshes.append(mesh)
        shadow_meshes.append(shadow)

    manager.view_changed.connect(_on_view_changed)
    set_first_person(false)
    if manager.get("current_profile") != null:
        _on_view_changed(manager.get("current_profile"), null)


func is_local_actor() -> bool:
    return _local_actor


## Register an equipped/world-space visual after attaching it to a bone
## socket. NPCs remain entirely unmodified. The registration is idempotent.
func register_world_visual(mesh: MeshInstance3D) -> bool:
    if not _local_actor or not is_instance_valid(mesh) or mesh.get_parent() == null:
        return false
    if _registered_world_visuals.has(mesh):
        return true
    var original_layers: int = mesh.layers
    var original_shadow: GeometryInstance3D.ShadowCastingSetting = mesh.cast_shadow
    var shadow := _make_world_shadow(mesh, str(mesh.name) + "Shadow")
    if shadow == null:
        return false
    _registered_world_visuals[mesh] = {
        "shadow": shadow, "layers": original_layers, "cast_shadow": original_shadow
    }
    world_visual_shadows.append(shadow)
    var cleanup: Callable = unregister_world_visual.bind(mesh)
    if not mesh.tree_exiting.is_connected(cleanup):
        mesh.tree_exiting.connect(cleanup, CONNECT_ONE_SHOT)
    return true


func unregister_world_visual(mesh: MeshInstance3D) -> void:
    if not _registered_world_visuals.has(mesh):
        return
    var state: Dictionary = _registered_world_visuals[mesh]
    _registered_world_visuals.erase(mesh)
    # Manual unequip must remove the one-shot listener. Otherwise re-equipping
    # the same mesh attempts to connect the same callable a second time.
    if is_instance_valid(mesh):
        var cleanup: Callable = unregister_world_visual.bind(mesh)
        if mesh.tree_exiting.is_connected(cleanup):
            mesh.tree_exiting.disconnect(cleanup)
    var shadow: MeshInstance3D = state["shadow"]
    world_visual_shadows.erase(shadow)
    if is_instance_valid(shadow):
        shadow.queue_free()
    if is_instance_valid(mesh):
        mesh.layers = int(state["layers"])
        mesh.cast_shadow = state["cast_shadow"]


## A viewmodel is presentation only: it is not an actor, weapon state, or
## independent animation controller. The caller supplies a scene/visual.
func register_first_person_visual(visual: Node3D) -> bool:
    if not _local_actor or not is_instance_valid(_camera) or visual == null:
        return false
    if visual.get_parent() != null:
        return false
    _camera.add_child(visual)
    _configure_first_person_geometry(visual)
    _first_person_visuals.append(visual)
    return true


func unregister_first_person_visual(visual: Node3D) -> void:
    if not _first_person_visuals.has(visual):
        return
    _first_person_visuals.erase(visual)
    if is_instance_valid(visual):
        visual.queue_free()


func _configure_first_person_geometry(visual: Node3D) -> void:
    var geometry_nodes: Array[GeometryInstance3D] = []
    if visual is GeometryInstance3D:
        geometry_nodes.append(visual as GeometryInstance3D)
    for child in visual.find_children("*", "GeometryInstance3D", true, false):
        geometry_nodes.append(child as GeometryInstance3D)
    for geometry in geometry_nodes:
        geometry.layers = 1 << (first_person_render_layer - 1)
        geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _make_world_shadow(mesh: MeshInstance3D, shadow_name: String) -> MeshInstance3D:
    if mesh.get_parent() == null:
        return null
    var shadow := mesh.duplicate(0) as MeshInstance3D
    if shadow == null:
        return null
    shadow.name = shadow_name
    mesh.get_parent().add_child(shadow)
    shadow.layers = 1
    shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
    mesh.layers = 1 << (local_body_render_layer - 1)
    mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    return shadow


func _belongs_to_attachment(mesh: MeshInstance3D, model: Node) -> bool:
    var ancestor: Node = mesh.get_parent()
    while ancestor != null and ancestor != model:
        if ancestor is BoneAttachment3D:
            return true
        ancestor = ancestor.get_parent()
    return false


func _on_view_changed(current: ViewProfileScript, _previous: ViewProfileScript) -> void:
    if current != null:
        set_first_person(current.mode == ViewProfileScript.Mode.FIRST_PERSON)


func set_first_person(value: bool) -> void:
    first_person = value
    if is_instance_valid(_camera):
        _camera.set_cull_mask_value(local_body_render_layer, not value)
        _camera.set_cull_mask_value(first_person_render_layer, value)


func _exit_tree() -> void:
    # Removing just this presenter must leave the actor and its equipment
    # fully renderable. Disconnect first to prevent detached components from
    # responding to later view changes.
    if is_instance_valid(_view_manager):
        var callback := Callable(self, "_on_view_changed")
        if _view_manager.is_connected(&"view_changed", callback):
            _view_manager.disconnect(&"view_changed", callback)

    for mesh in _registered_world_visuals.keys():
        unregister_world_visual(mesh as MeshInstance3D)

    for i in range(body_meshes.size()):
        var mesh: MeshInstance3D = body_meshes[i]
        if is_instance_valid(mesh):
            var original: Dictionary = _original_body_rendering.get(mesh, {})
            if not original.is_empty():
                mesh.layers = int(original["layers"])
                mesh.cast_shadow = original["cast_shadow"]
        if i < shadow_meshes.size() and is_instance_valid(shadow_meshes[i]):
            shadow_meshes[i].queue_free()
    body_meshes.clear()
    shadow_meshes.clear()
    _original_body_rendering.clear()

    for visual in _first_person_visuals:
        if is_instance_valid(visual):
            visual.queue_free()
    _first_person_visuals.clear()

    if is_instance_valid(_camera):
        _camera.set_cull_mask_value(local_body_render_layer, _initial_body_cull)
        _camera.set_cull_mask_value(first_person_render_layer, _initial_first_person_cull)
    first_person = false
    _local_actor = false
    _view_manager = null
    _camera = null
