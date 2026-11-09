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
    var definition: Resource = weapon.get("definition")
    var scene: PackedScene = definition.get("first_person_scene")
    # Only cull the world weapon once a usable camera-local replacement
    # exists. Without one, keep its normal world mesh and unarmed F4 hand
    # visible instead of rendering an empty/weaponless first-person view.
    if scene == null:
        return
    var created: Node = scene.instantiate()
    var candidate := created as Node3D
    if candidate == null or not candidate.has_method("apply_pose"):
        if created != null:
            created.queue_free()
        push_warning("ACTION5: F4 weapon scene needs Node3D + apply_pose(); using world fallback")
        return
    if not bool(first_person.call("register_first_person_visual", candidate)):
        candidate.queue_free()
        return
    _viewmodel = candidate
    for world_mesh in weapon.call("get_world_meshes"):
        var mesh := world_mesh as MeshInstance3D
        if mesh == null or not bool(first_person.call("register_world_visual", mesh)):
            push_warning("ACTION5: world weapon visual registration failed; using world fallback")
            _clear_visuals()
            return
        _registered_meshes.append(mesh)
    set_process(true)


func _on_unequipped(_weapon: Node3D) -> void:
    _clear_visuals()


## Each authored viewmodel positions hand, forearm and weapon as a single
## gripped pose, driven by the D05 action clock (not by a new timer).
func _process(_delta: float) -> void:
    refresh_presentation()


func show_unarmed_limbs() -> bool:
    # Backwards-compatible idle gate for other F4 presentation consumers.
    return not is_instance_valid(_viewmodel)


func show_unarmed_limb(action_key: StringName) -> bool:
    # A held weapon hides only the idle hand and its own visual action.
    # Unclaimed actions (such as the ordinary Kick) stay visible in F4.
    if not is_instance_valid(_viewmodel):
        return true
    if action_key == &"" or not is_instance_valid(_active_weapon):
        return false
    var state: Dictionary = {}
    if is_instance_valid(visual_state) and visual_state.has_method("get_visual_action"):
        state = visual_state.call("get_visual_action")
    # Action identity, when provided, resolves even a weapon that shares
    # the exact same animation key as an unassigned Punch/Kick.
    if state.has("action_id"):
        var action_id: StringName = state.get("action_id", &"")
        for attack in _active_weapon.call("get_attack_definitions"):
            if attack.get("attack_id") == action_id:
                return false
        return true
    # Older visual sources expose only {key, progress}; keep their
    # authored-visual-key fallback without importing CombatController.
    for attack in _active_weapon.call("get_attack_definitions"):
        var key: StringName = attack.get("visual_action_key")
        if key == &"":
            key = attack.get("animation_key")
        if action_key == key:
            return false
    return true


func refresh_presentation() -> void:
    if not is_instance_valid(_viewmodel) or not is_instance_valid(_active_weapon):
        set_process(false)
        return
    if not _viewmodel.has_method("apply_pose"):
        return
    var progress: float = 0.0
    if is_instance_valid(visual_state) and visual_state.has_method("get_visual_action"):
        var state: Dictionary = visual_state.call("get_visual_action")
        for attack in _active_weapon.call("get_attack_definitions"):
            var key: StringName = attack.get("visual_action_key")
            if key == &"":
                key = attack.get("animation_key")
            if state.get("key", &"") == key:
                progress = clampf(float(state.get("progress", 0.0)), 0.0, 1.0)
                break
    _viewmodel.call("apply_pose", progress)


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
