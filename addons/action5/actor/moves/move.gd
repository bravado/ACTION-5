extends Node
class_name Action5Move
## Extensible, exclusive locomotion move. Add a child component to Moves to
## register it; neither Action5Actor nor Action5Locomotion knows concrete moves.

const ContextScript = preload("res://addons/action5/actor/moves/move_context.gd")

@export var move_id: StringName = &""
@export var action_name: StringName = &""
@export var priority: int = 0
@export var default_key: int = 0
@export var default_gamepad_button: int = -1


func can_enter(_ctx: ContextScript) -> bool:
    return true


func enter(_ctx: ContextScript) -> void:
    pass


func physics_update(_ctx: ContextScript, _delta: float) -> void:
    pass


func can_exit(_ctx: ContextScript) -> bool:
    return true


func exit(_ctx: ContextScript) -> void:
    pass
