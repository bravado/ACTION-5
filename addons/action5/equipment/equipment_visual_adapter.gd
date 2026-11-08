extends Node
class_name Action5EquipmentVisualAdapter
## Optional bridge between equipment instances and D04 world/FPS presentation.
## The inventory never imports AnimationPresenter, FirstPersonPresenter or
## CameraRig. NPCs without a local FPS presenter render ordinary world meshes.

@export var equipment_path: NodePath = ^"../Equipment"
@export var animation_path: NodePath = ^"../AnimationPresenter"
@export var first_person_path: NodePath = ^"../FirstPersonPresenter"
@export var visual_state_path: NodePath = ^"../CombatVisualState"

@onready var equipment: Node = get_node_or_null(equipment_path)
@onready var animation: Node = get_node_or_null(animation_path)
@onready var first_person: Node = get_node_or_null(first_person_path)
@onready var visual_state: Node = get_node_or_null(visual_state_path)

var _registered_meshes: Array[MeshInstance3D] = []
var _viewmodel: Node3D
var _viewmodel_base: Transform3D
var _active_weapon: Node3D


func _ready() -> void:
    if equipment != null:
        equipment.weapon_equipped.connect(_on_equipped)
        equipment.weapon_unequipped.connect(_on_unequipped)
        if equipment.current_weapon != null:
            _on_equipped(equipment.current_weapon)
    set_process(false)


func get_mount(socket_id: StringName) -> Node3D:
    if is_instance_valid(animation) and animation.has_method("get_socket"):
        return animation.call("get_socket", socket_id) as Node3D
    return null


func _on_equipped(weapon: Node3D) -> void:
    _clear_visuals()
    _active_weapon = weapon
    if not is_instance_valid(first_person) or not first_person.has_method("is_local_actor"):
        return
    if not bool(first_person.call("is_local_actor")):
        return
    for mesh in weapon.get_world_meshes():
        if first_person.call("register_world_visual", mesh):
            _registered_meshes.append(mesh)
    var definition: Resource = weapon.get("definition")
    var scene: PackedScene = definition.get("first_person_scene")
    if scene == null:
        return
    var candidate := scene.instantiate() as Node3D
    if candidate != null and first_person.call("register_first_person_visual", candidate):
        _viewmodel = candidate
        _viewmodel_base = candidate.transform
        set_process(true)
    elif candidate != null:
        candidate.queue_free()


func _on_unequipped(_weapon: Node3D) -> void:
    _clear_visuals()


func _process(_delta: float) -> void:
    if not is_instance_valid(_viewmodel) or not is_instance_valid(_active_weapon):
        set_process(false)
        return
    _viewmodel.transform = _viewmodel_base
    if not is_instance_valid(visual_state) or not visual_state.has_method("get_visual_action"):
        return
    var state: Dictionary = visual_state.call("get_visual_action")
    if state.is_empty():
        return
    var definition: Resource = _active_weapon.get("definition")
    for attack in _active_weapon.get_attack_definitions():
        if state.get("key", &"") == attack.get("animation_key"):
            var progress: float = clampf(float(state.get("progress", 0.0)), 0.0, 1.0)
            var degrees: Vector3 = definition.get("first_person_swing_degrees")
            _viewmodel.rotation_degrees += degrees * sin(progress * PI)
            break


func _clear_visuals() -> void:
    set_process(false)
    if is_instance_valid(first_person):
        for mesh in _registered_meshes:
            if is_instance_valid(mesh):
                first_person.call("unregister_world_visual", mesh)
        if is_instance_valid(_viewmodel):
            first_person.call("unregister_first_person_visual", _viewmodel)
    _registered_meshes.clear()
    _viewmodel = null
    _active_weapon = null


func _exit_tree() -> void:
    if is_instance_valid(equipment):
        if equipment.weapon_equipped.is_connected(_on_equipped):
            equipment.weapon_equipped.disconnect(_on_equipped)
        if equipment.weapon_unequipped.is_connected(_on_unequipped):
            equipment.weapon_unequipped.disconnect(_on_unequipped)
    _clear_visuals()
