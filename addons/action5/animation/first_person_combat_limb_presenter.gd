extends Node
class_name Action5FirstPersonCombatLimbPresenter
## First-person visual host. Reads ONE generic visual-action snapshot:
## {key: StringName, progress: float}. Never reads Skeleton3D, movement FSM,
## input actions, attack resources, world camera transforms or physics.
##
## F1–F3/F5 use the world rig. F4 uses independently authored camera-space
## viewmodel profiles and exactly the same authoritative gameplay action clock.

const ProfileScript = preload("res://addons/action5/animation/first_person_limb_profile.gd")
const GeometryScript = preload("res://addons/action5/animation/first_person_limb_geometry.gd")
const FPScript = preload("res://addons/action5/animation/first_person_presenter.gd")

signal visible_limb_changed(key: StringName)

@export var profiles: Array[Resource] = []
@export var visual_state_path: NodePath = ^"../CombatVisualState"

@onready var fps: FPScript = get_node_or_null("../FirstPersonPresenter") as FPScript
@onready var visual_state: Node = get_node_or_null(visual_state_path)

var _limbs: Dictionary = {}
var _last_action: StringName = &""
var _view_manager: Node


func _ready() -> void:
    if not is_instance_valid(fps) or not fps.is_local_actor() or \
        not is_instance_valid(visual_state) or \
        not visual_state.has_method("get_visual_action"):
        set_process(false)
        return
    for resource in profiles:
        if resource is ProfileScript:
            register_profile(resource as ProfileScript)
    _view_manager = fps.get_node_or_null(fps.view_manager_path)
    if is_instance_valid(_view_manager):
        _view_manager.view_changed.connect(_on_view_changed)
    refresh_presentation()


func register_profile(profile: ProfileScript) -> bool:
    if profile == null or not profile.valid() or not is_instance_valid(fps) \
        or not fps.is_local_actor() or _limbs.has(profile.animation_key):
        return false
    var viewmodel: Node3D = null
    if profile.viewmodel_scene != null:
        viewmodel = profile.viewmodel_scene.instantiate() as Node3D
        if viewmodel == null or not viewmodel.has_method("configure") \
            or not viewmodel.has_method("apply_pose"):
            if is_instance_valid(viewmodel):
                viewmodel.free()
            push_warning("ACTION5: viewmodel scene must implement configure() and apply_pose()")
            return false
    else:
        viewmodel = GeometryScript.new()
    viewmodel.name = "CombatLimb_" + str(profile.animation_key)
    viewmodel.visible = false
    viewmodel.call("configure", profile)
    if not fps.register_first_person_visual(viewmodel):
        viewmodel.free()
        return false
    _limbs[profile.animation_key] = {
        "profile": profile,
        "root": viewmodel,
    }
    return true


func get_limb_root(key: StringName) -> Node3D:
    var state: Dictionary = _limbs.get(key, {})
    return state.get("root") as Node3D


func active_limb_key() -> StringName:
    if not is_instance_valid(fps) or not fps.first_person \
        or not is_instance_valid(visual_state):
        return &""
    var action: Dictionary = visual_state.call("get_visual_action")
    var key: StringName = action.get("key", &"")
    return key if _limbs.has(key) else &""


func _process(_delta: float) -> void:
    refresh_presentation()


func _on_view_changed(_current: Resource, _previous: Resource) -> void:
    refresh_presentation()


func refresh_presentation() -> void:
    if not is_instance_valid(fps) or not is_instance_valid(visual_state):
        return
    var action: Dictionary = visual_state.call("get_visual_action")
    var key: StringName = action.get("key", &"") if fps.first_person else &""
    if not _limbs.has(key):
        key = &""
    if key != _last_action:
        _last_action = key
        visible_limb_changed.emit(key)
        print("ACTION5_F4_LIMB_VISIBLE key=", key)
    var progress: float = float(action.get("progress", 0.0))
    for registered in _limbs:
        var state: Dictionary = _limbs[registered]
        var viewmodel: Node3D = state["root"]
        if not is_instance_valid(viewmodel) or viewmodel.is_queued_for_deletion():
            continue
        var profile: ProfileScript = state["profile"]
        viewmodel.visible = fps.first_person and (
            profile.visible_at_rest or registered == key
        )
        if viewmodel.visible:
            viewmodel.call("apply_pose", progress if registered == key else 0.0)


func _exit_tree() -> void:
    if is_instance_valid(_view_manager):
        var cb := Callable(self, "_on_view_changed")
        if _view_manager.view_changed.is_connected(cb):
            _view_manager.view_changed.disconnect(cb)
    _view_manager = null
    if is_instance_valid(fps):
        for state in _limbs.values():
            var viewmodel: Node3D = state["root"]
            if is_instance_valid(viewmodel):
                fps.unregister_first_person_visual(viewmodel)
    _limbs.clear()
    _last_action = &""
