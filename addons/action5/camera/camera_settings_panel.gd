extends PanelContainer
class_name Action5CameraSettingsPanel
## Reusable in-game camera tuning controls, independent of demo actors.
## Changes are per-profile Resources; only user:// overrides are persisted.

const ViewManagerScript = preload("res://addons/action5/camera/view_manager.gd")
const ViewProfileScript = preload("res://addons/action5/camera/view_profile.gd")

const FIELDS = [
    {"key": "orthographic_size", "label": "Zoom", "min": 4.0, "max": 28.0, "step": 0.25},
    {"key": "fixed_height", "label": "Camera height", "min": 1.0, "max": 14.0, "step": 0.25},
    {"key": "fixed_distance", "label": "Camera depth", "min": 5.0, "max": 22.0, "step": 0.25},
    {"key": "chase_distance", "label": "Follow distance", "min": 1.5, "max": 9.0, "step": 0.1},
    {"key": "pitch", "label": "Overhead angle", "min": 0.0, "max": 70.0, "step": 1.0},
    {"key": "shoulder_offset", "label": "Shoulder offset", "min": -1.5, "max": 1.5, "step": 0.05},
    {"key": "shoulder_lift", "label": "Shoulder height", "min": 0.0, "max": 2.0, "step": 0.05},
    {"key": "aim_ahead", "label": "Look ahead", "min": 0.0, "max": 5.0, "step": 0.1},
    {"key": "field_of_view", "label": "Field of view", "min": 45.0, "max": 105.0, "step": 1.0},
    {"key": "eye_height", "label": "Eye height", "min": 0.7, "max": 2.2, "step": 0.05},
    {"key": "follow_speed", "label": "Follow speed", "min": 0.0, "max": 24.0, "step": 0.5},
]

@export var manager_path: NodePath = ^"../../ViewManager"
@export var save_user_settings: bool = true
@export var preferences_path: String = "user://action5_camera_settings.cfg"

var _manager: ViewManagerScript
var _defaults: Array[Dictionary] = []
var _rows: Dictionary = {}
var _title: Label
var _reset: Button


func _ready() -> void:
    _manager = get_node_or_null(manager_path) as ViewManagerScript
    if _manager == null:
        push_error("ACTION5: CameraSettingsPanel needs a ViewManager")
        return
    for profile in _manager.profiles:
        var values: Dictionary = {}
        for field in FIELDS:
            var key: String = field["key"]
            values[key] = _get_value(profile, key)
        _defaults.append(values)
    _load_preferences()
    _build_panel()
    _manager.view_changed.connect(_on_view_changed)
    refresh_controls()
    hide()


func _build_panel() -> void:
    custom_minimum_size = Vector2(338.0, 0.0)
    mouse_filter = Control.MOUSE_FILTER_STOP
    var outer := VBoxContainer.new()
    outer.add_theme_constant_override("separation", 9)
    add_child(outer)

    _title = Label.new()
    _title.add_theme_font_size_override("font_size", 20)
    outer.add_child(_title)

    var hint := Label.new()
    hint.text = "Live changes · saved for each camera"
    outer.add_child(hint)

    for field in FIELDS:
        var key: String = field["key"]
        var row := HBoxContainer.new()
        row.name = "Row_" + key
        row.add_theme_constant_override("separation", 6)
        outer.add_child(row)
        var name_label := Label.new()
        name_label.text = field["label"]
        name_label.custom_minimum_size.x = 116.0
        row.add_child(name_label)

        var slider := HSlider.new()
        slider.name = "Slider"
        slider.custom_minimum_size.x = 130.0
        slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        slider.min_value = float(field["min"])
        slider.max_value = float(field["max"])
        slider.step = float(field["step"])
        row.add_child(slider)

        var number := Label.new()
        number.custom_minimum_size.x = 51.0
        number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        row.add_child(number)
        slider.value_changed.connect(_on_slider_changed.bind(key))
        _rows[key] = {"row": row, "slider": slider, "number": number}

    var buttons := HBoxContainer.new()
    outer.add_child(buttons)
    _reset = Button.new()
    _reset.name = "ResetCamera"
    _reset.text = "Reset this camera"
    _reset.pressed.connect(reset_current_camera)
    buttons.add_child(_reset)

    var close := Button.new()
    close.name = "CloseSettings"
    close.text = "Close"
    close.pressed.connect(hide)
    buttons.add_child(close)


func _field_visible(key: String, profile: ViewProfileScript) -> bool:
    match key:
        "orthographic_size":
            return profile.orthographic
        "fixed_height", "fixed_distance":
            return profile.mode == ViewProfileScript.Mode.BEATEMUP
        "chase_distance", "pitch", "shoulder_offset", "shoulder_lift", "aim_ahead":
            return profile.mode == ViewProfileScript.Mode.THIRD_PERSON
        "field_of_view":
            return profile.mode == ViewProfileScript.Mode.THIRD_PERSON or profile.mode == ViewProfileScript.Mode.FIRST_PERSON
        "eye_height":
            return profile.mode == ViewProfileScript.Mode.FIRST_PERSON
        "follow_speed":
            return profile.mode != ViewProfileScript.Mode.FIRST_PERSON
    return false


func _get_value(profile: ViewProfileScript, key: String) -> float:
    match key:
        "fixed_height":
            return profile.fixed_offset.y
        "fixed_distance":
            return profile.fixed_offset.z
        "pitch":
            return profile.default_pitch_degrees
        _:
            return float(profile.get(key))


func _write_value(profile: ViewProfileScript, key: String, value: float) -> void:
    match key:
        "fixed_height":
            profile.fixed_offset.y = value
        "fixed_distance":
            profile.fixed_offset.z = value
        "pitch":
            profile.default_pitch_degrees = value
        _:
            profile.set(key, value)


func _field(key: String) -> Dictionary:
    for field in FIELDS:
        if field["key"] == key:
            return field
    return {}


func _clamped(key: String, value: float) -> float:
    var spec: Dictionary = _field(key)
    if spec.is_empty():
        return value
    return clampf(value, float(spec["min"]), float(spec["max"]))


## Public method useful for external UI or gamepad option menus.
func set_current_value(key: String, value: float) -> bool:
    if _manager == null or _field(key).is_empty():
        return false
    var profile: ViewProfileScript = _manager.current_profile
    if profile == null or not _field_visible(key, profile):
        return false
    if not is_finite(value):
        return false
    var safe: float = _clamped(key, value)
    _write_value(profile, key, safe)
    _manager.camera_rig.refresh_settings(key == "pitch")
    _save_preferences()
    refresh_controls()
    return true


func _on_slider_changed(value: float, key: String) -> void:
    set_current_value(key, value)


func _on_view_changed(_current: ViewProfileScript, _previous: ViewProfileScript) -> void:
    refresh_controls()


func refresh_controls() -> void:
    if _manager == null or _manager.current_profile == null or _title == null:
        return
    var profile: ViewProfileScript = _manager.current_profile
    _title.text = "%d / 6 · %s" % [_manager.active_index + 1, profile.display_name]
    for field in FIELDS:
        var key: String = field["key"]
        var row_data: Dictionary = _rows[key]
        var row: HBoxContainer = row_data["row"]
        row.visible = _field_visible(key, profile)
        var val: float = _get_value(profile, key)
        var slider: HSlider = row_data["slider"]
        slider.set_value_no_signal(val)
        var number: Label = row_data["number"]
        number.text = "%.2f" % val


func reset_current_camera() -> void:
    if _manager == null or _manager.active_index < 0:
        return
    var profile: ViewProfileScript = _manager.current_profile
    var values: Dictionary = _defaults[_manager.active_index]
    for field in FIELDS:
        var key: String = field["key"]
        _write_value(profile, key, float(values[key]))
    _manager.camera_rig.refresh_settings(true)
    _save_preferences()
    refresh_controls()


func _load_preferences() -> void:
    if not save_user_settings:
        return
    var config := ConfigFile.new()
    if config.load(preferences_path) != OK:
        return
    for i in range(_manager.profiles.size()):
        var section := "view_%d" % (i + 1)
        var profile: ViewProfileScript = _manager.profiles[i]
        for field in FIELDS:
            var key: String = field["key"]
            if config.has_section_key(section, key):
                var raw: Variant = config.get_value(section, key)
                if raw is float or raw is int:
                    _write_value(profile, key, _clamped(key, float(raw)))
    _manager.camera_rig.refresh_settings()


func _save_preferences() -> void:
    if not save_user_settings:
        return
    var config := ConfigFile.new()
    for i in range(_manager.profiles.size()):
        var section := "view_%d" % (i + 1)
        var profile: ViewProfileScript = _manager.profiles[i]
        for field in FIELDS:
            var key: String = field["key"]
            config.set_value(section, key, _get_value(profile, key))
    if config.save(preferences_path) != OK:
        push_warning("ACTION5: could not save camera preferences: " + preferences_path)
