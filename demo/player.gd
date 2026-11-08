extends "res://addons/action5/actor/action_actor.gd"
## The D04 training prop remains in the demo for baseline rendering tests.
## Equipped D06 weapons temporarily replace it without changing addon code.

const FirstPersonScript = preload("res://addons/action5/animation/first_person_presenter.gd")

@export var world_tool_scene: PackedScene = preload("res://demo/assets/training_tool.tscn")

var _training_tool: MeshInstance3D
var _fps_presenter: FirstPersonScript


func _ready() -> void:
    var socket: Node3D = $AnimationPresenter.get_socket(&"right_hand")
    if socket == null or world_tool_scene == null:
        return
    _training_tool = world_tool_scene.instantiate() as MeshInstance3D
    if _training_tool == null:
        push_warning("ACTION5: demo training tool must be a MeshInstance3D")
        return
    socket.add_child(_training_tool)
    _fps_presenter = $FirstPersonPresenter as FirstPersonScript
    if _fps_presenter != null:
        _fps_presenter.register_world_visual(_training_tool)

    var equipment: Node = get_node_or_null("Equipment")
    if equipment != null:
        equipment.weapon_equipped.connect(_on_weapon_equipped)
        equipment.weapon_unequipped.connect(_on_weapon_unequipped)


func _on_weapon_equipped(_weapon: Node3D) -> void:
    if not is_instance_valid(_training_tool):
        return
    if is_instance_valid(_fps_presenter):
        _fps_presenter.unregister_world_visual(_training_tool)
    _training_tool.visible = false


func _on_weapon_unequipped(_weapon: Node3D) -> void:
    # In a swap the next weapon is equipped in the same event batch, so
    # avoid re-registering the prop and creating a transient shadow.
    call_deferred("_restore_training_tool")


func _restore_training_tool() -> void:
    if not is_instance_valid(_training_tool):
        return
    var equipment: Node = get_node_or_null("Equipment")
    if equipment != null and equipment.get("current_weapon") != null:
        return
    _training_tool.visible = true
    if is_instance_valid(_fps_presenter):
        _fps_presenter.register_world_visual(_training_tool)
