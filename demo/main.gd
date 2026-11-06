extends Node3D

const ViewManagerScript = preload("res://addons/action5/camera/view_manager.gd")
const ViewProfileScript = preload("res://addons/action5/camera/view_profile.gd")
## D02 reference scene: character and world stay alive while camera profiles change.
## D03 will replace the temporary movement mapping with reusable locomotion intents.

@onready var _player: CharacterBody3D = $Player
@onready var _views: ViewManagerScript = $ViewManager
@onready var _status: Label = $Hud/Status
@onready var _help: Label = $Hud/Help
@onready var _mode_buttons: HBoxContainer = $Hud/ModeButtons


func _ready() -> void:
    _views.view_changed.connect(_on_view_changed)
    for i in range(6):
        var button := _mode_buttons.get_node("Mode" + str(i + 1)) as Button
        button.pressed.connect(_on_mode_button_pressed.bind(i))
    _on_view_changed(_views.current_profile, null)


func _process(_delta: float) -> void:
    var x := float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT))
    x -= float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
    var z := float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN))
    z -= float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
    var axes := Vector2(x, z).normalized()
    var movement := _map_demo_movement(axes)
    _player.call("set_move_intent", movement)


func _map_demo_movement(axes: Vector2) -> Vector2:
    var mode: ViewProfileScript.Mode = _views.current_profile.mode
    if mode == ViewProfileScript.Mode.SIDE:
        return Vector2(axes.x, 0.0)

    if mode == ViewProfileScript.Mode.BEATEMUP:
        return axes

    var camera_basis: Basis = _views.get_active_camera().global_basis
    var right := Vector3(camera_basis.x.x, 0.0, camera_basis.x.z).normalized()
    var forward := Vector3.ZERO
    if mode == ViewProfileScript.Mode.ISOMETRIC or mode == ViewProfileScript.Mode.RETRO_TOPDOWN:
        # Vertical overhead view must use screen-up; camera forward projects to zero.
        forward = Vector3(camera_basis.y.x, 0.0, camera_basis.y.z).normalized()
    else:
        # Third/first person use camera heading, even at level pitch.
        forward = Vector3(-camera_basis.z.x, 0.0, -camera_basis.z.z).normalized()
    var world_move: Vector3 = right * axes.x - forward * axes.y
    if world_move.length_squared() > 1.0:
        world_move = world_move.normalized()
    return Vector2(world_move.x, world_move.z)


func _on_mode_button_pressed(index: int) -> void:
    _views.switch_view(index)


func _on_view_changed(current: ViewProfileScript, _previous: ViewProfileScript) -> void:
    if current == null:
        return
    _status.text = "VIEW %d / 6  |  %s  |  Switches: %d  |  Position delta: %.5f" % [
        _views.active_index + 1, current.display_name, _views.switch_count, _views.last_position_delta
    ]
    for i in range(6):
        var button := _mode_buttons.get_node("Mode" + str(i + 1)) as Button
        button.disabled = i == _views.active_index
    _help.text = "ACTION-5  //  D02 SIX VIEW PROFILES\n1–6: switch camera  |  F1–F6: alternate  |  WASD/arrows: move\nF4/F5: click to look, Esc releases mouse  |  Controller shoulders: cycle"
    if not current.is_orbit_mode():
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
