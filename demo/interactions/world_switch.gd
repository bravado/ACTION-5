extends Node3D
## Independent second interactable archetype. The Interactor never imports
## this component, and scripted/NPC callers use the same interact(actor).
## An optional visual subscriber can observe the resulting state without
## controlling the interaction or the OmniLight3D.

signal state_changed(activated: bool)

@export var target_path: NodePath = ^"Light"
var activated: bool = false


func _ready() -> void:
    add_to_group("action5_interactable")


func can_interact(actor: Node3D) -> bool:
    return is_instance_valid(actor)


func interact(actor: Node3D) -> bool:
    if not can_interact(actor):
        return false
    activated = not activated
    var light := get_node_or_null(target_path) as Light3D
    if light != null:
        light.visible = activated
    state_changed.emit(activated)
    return true
