extends Node
## Optional E-key boundary. The replaceable actor-local Interactor handles
## target selection, physical range/LoS and permissions independently of
## this adapter or the player camera.

@export var actor_path: NodePath = ^"../Player"
@export var interactor_path: NodePath = ^"../Interactor"
@export var handle_input: bool = false

@onready var actor: Node3D = get_node_or_null(actor_path) as Node3D
@onready var interactor: Node = get_node_or_null(interactor_path)


func _unhandled_input(event: InputEvent) -> void:
    if not handle_input or not event is InputEventKey or not event.pressed             or event.echo or event.keycode != KEY_E:
        return
    if try_interact():
        get_viewport().set_input_as_handled()


func try_interact() -> bool:
    return is_instance_valid(actor) and is_instance_valid(interactor)         and bool(interactor.call("try_interact", actor))
