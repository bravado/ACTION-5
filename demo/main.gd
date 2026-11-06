extends Node3D
## D01 demonstration only; key input never enters the reusable addon/actor.
## D02 introduces ViewManager, camera profiles and intent adapters.

@onready var _player: CharacterBody3D = $Player
@onready var _camera: Camera3D = $Camera3D


func _ready() -> void:
    _camera.look_at(Vector3(0.0, 0.6, 0.0), Vector3.UP)


func _process(_delta: float) -> void:
    var x := float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT))
    x -= float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
    var z := float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN))
    z -= float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
    _player.call("set_move_intent", Vector2(x, z).normalized())
