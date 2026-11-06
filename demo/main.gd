extends Node3D

const ViewManagerScript = preload("res://addons/action5/camera/view_manager.gd")
const ViewProfileScript = preload("res://addons/action5/camera/view_profile.gd")
const InputAdapterScript = preload("res://addons/action5/input/actor_input_adapter.gd")
## D03 reference scene: movement and facing live in reusable addon components.

@onready var _player: CharacterBody3D = $Player
@onready var _views: ViewManagerScript = $ViewManager
@onready var _input: InputAdapterScript = $ActorInput
@onready var _status: Label = $Hud/Status
@onready var _help: Label = $Hud/Help
@onready var _mode_buttons: HBoxContainer = $Hud/ModeButtons
@onready var _camera_settings: PanelContainer = $Hud/CameraSettings
@onready var _settings_toggle: Button = $Hud/SettingsToggle

var _has_window_focus: bool = true


func _ready() -> void:
    _views.view_changed.connect(_on_view_changed)
    _settings_toggle.pressed.connect(_toggle_camera_settings)
    for i in range(5):
        var button := _mode_buttons.get_node("Mode" + str(i + 1)) as Button
        button.pressed.connect(_on_mode_button_pressed.bind(i))
    _on_view_changed(_views.current_profile, null)


func _process(_delta: float) -> void:
    if not _has_window_focus or _camera_settings.visible:
        _input.set_enabled(false)
    elif not _input.enabled:
        _input.set_enabled(true)


func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
        _has_window_focus = false
        if is_instance_valid(_input):
            _input.set_enabled(false)
    elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
        _has_window_focus = true
        if is_instance_valid(_input) and not _camera_settings.visible:
            _input.set_enabled(true)


func _on_mode_button_pressed(index: int) -> void:
    _views.switch_view(index)


func _toggle_camera_settings() -> void:
    _camera_settings.visible = not _camera_settings.visible
    if _camera_settings.visible:
        _camera_settings.call("refresh_controls")
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    _input.set_enabled(not _camera_settings.visible and _has_window_focus)


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_C:
            _toggle_camera_settings()
            get_viewport().set_input_as_handled()


func _on_view_changed(current: ViewProfileScript, _previous: ViewProfileScript) -> void:
    if current == null:
        return
    _status.text = "VIEW %d / 5  |  %s  |  Switches: %d  |  Position delta: %.5f" % [
        _views.active_index + 1, current.display_name, _views.switch_count, _views.last_position_delta
    ]
    for i in range(5):
        var button := _mode_buttons.get_node("Mode" + str(i + 1)) as Button
        button.disabled = i == _views.active_index
    _help.text = "ACTION-5 // D03 LOCOMOTION & FACING\n1–5: view | WASD/arrows: move | Space: jump | Shift: run | Alt: dodge\n3/4: click to look, Esc: release | C: camera settings"
    var front_wall_mesh := get_node("SouthWall/MeshInstance3D") as MeshInstance3D
    front_wall_mesh.visible = (
        current.mode != ViewProfileScript.Mode.SIDE
        and current.mode != ViewProfileScript.Mode.BEATEMUP
    )
    if not current.is_orbit_mode():
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
