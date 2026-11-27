extends Node3D
## Minimal native example; game-owned input, no demo or imported rig.
const Intent = preload("res://addons/action5/actor/move_intent.gd")
@onready var actor: CharacterBody3D = $Player
@onready var views: Node = $ViewManager


func _physics_process(_delta: float) -> void:
    var axes := Vector2(
        float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
        float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
    actor.call("apply_move_intent", Intent.new(axes, axes))


func _unhandled_key_input(event: InputEvent) -> void:
    if not event is InputEventKey or not event.pressed or event.echo:
        return
    if event.keycode >= KEY_1 and event.keycode <= KEY_5:
        views.call("switch_view", event.keycode - KEY_1)
