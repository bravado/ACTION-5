extends Node3D

const ViewManagerScript = preload("res://addons/action5/camera/view_manager.gd")
const ViewProfileScript = preload("res://addons/action5/camera/view_profile.gd")
const InputAdapterScript = preload("res://addons/action5/input/actor_input_adapter.gd")
const MoveControllerScript = preload("res://addons/action5/actor/moves/movement_controller.gd")
const MovementPolicyScript = preload("res://addons/action5/actor/movement_policy.gd")
## D03 reference scene: movement and facing live in reusable addon components.

@onready var _player: CharacterBody3D = $Player
@onready var _views: ViewManagerScript = $ViewManager
@onready var _input: InputAdapterScript = $ActorInput
@onready var _moves: MoveControllerScript = $Player/Locomotion/MovementController
@onready var _status: Label = $Hud/Status
@onready var _help: Label = $Hud/Help
@onready var _mode_buttons: HBoxContainer = $Hud/ModeButtons
@onready var _camera_settings: PanelContainer = $Hud/CameraSettings
@onready var _settings_toggle: Button = $Hud/SettingsToggle

func _ready() -> void:
    _views.view_changed.connect(_on_view_changed)
    _moves.move_changed.connect(_on_move_changed)
    _settings_toggle.pressed.connect(_toggle_camera_settings)
    # Settings can also be closed by its own Close button, not only C.
    _camera_settings.visibility_changed.connect(_on_camera_settings_visibility_changed)
    _input.set_enabled(not _camera_settings.visible)
    for i in range(5):
        var button := _mode_buttons.get_node("Mode" + str(i + 1)) as Button
        button.pressed.connect(_on_mode_button_pressed.bind(i))
    _on_view_changed(_views.current_profile, null)


## Kept as a stable D02 smoke-test hook; production input mapping is in addon.
func _map_demo_movement(axes: Vector2) -> Vector2:
    return MovementPolicyScript.to_world(
        axes, _views.current_profile.mode, _views.get_active_camera().global_basis
    )


func _on_mode_button_pressed(index: int) -> void:
    _views.switch_view(index)
    # Re-clicking an already selected view does not emit view_changed.
    _release_ui_focus()


func _toggle_camera_settings() -> void:
    _camera_settings.visible = not _camera_settings.visible
    if _camera_settings.visible:
        _camera_settings.call("refresh_controls")
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    _release_ui_focus()


func _on_camera_settings_visibility_changed() -> void:
    # This also handles the Close button inside the settings panel.
    _release_ui_focus()
    # Only the panel's UI gate is owned here; the adapter owns window focus.
    _input.set_enabled(not _camera_settings.visible)
    print("ACTION5_CAMERA_SETTINGS_VISIBLE ", "open" if _camera_settings.visible else "closed")


func _release_ui_focus() -> void:
    # Buttons must not intercept Space (actor_jump) after a mouse click or
    # when changing the view with number keys. Sliders remain keyboard-usable
    # while the settings panel is open, until a view switch/close.
    var focused: Control = get_viewport().gui_get_focus_owner()
    if focused != null:
        focused.release_focus()


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_C:
            _toggle_camera_settings()
            get_viewport().set_input_as_handled()


## Diagnostic display and CI log are generic: no checks for specific moves.
func _on_move_changed(previous: StringName, current: StringName) -> void:
    print("ACTION5_MOVE_CHANGED previous=%s current=%s" % [previous, current])
    if _views.current_profile != null:
        _refresh_status(_views.current_profile)


func _refresh_status(profile: ViewProfileScript) -> void:
    _status.text = "VIEW %d / 5  |  %s  |  Move: %s  |  Switches: %d  |  Delta: %.5f" % [
        _views.active_index + 1, profile.display_name,
        _moves.active_id, _views.switch_count, _views.last_position_delta
    ]


func _on_view_changed(current: ViewProfileScript, _previous: ViewProfileScript) -> void:
    if current == null:
        return
    # Remove stale GUI focus left by view buttons or camera sliders.
    _release_ui_focus()
    _refresh_status(current)
    for i in range(5):
        var button := _mode_buttons.get_node("Mode" + str(i + 1)) as Button
        button.disabled = i == _views.active_index
    _help.text = "ACTION-5 // D03 LOCOMOTION & FACING\n1–5: view | WASD/arrows: move | Space: jump | Shift: run | Alt: dodge | X: slide\n3/4: click to look, Esc: release | C: camera settings"
    var front_wall_mesh := get_node("SouthWall/MeshInstance3D") as MeshInstance3D
    front_wall_mesh.visible = (
        current.mode != ViewProfileScript.Mode.SIDE
        and current.mode != ViewProfileScript.Mode.BEATEMUP
    )
    if not current.is_orbit_mode():
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
