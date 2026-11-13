extends Control
## Iron Reliquary's declarative scene owns layout; this presenter accepts
## read-only gameplay snapshots and emits only UI navigation requests.

signal help_visibility_changed(open: bool)
signal view_requested(index: int)
signal settings_requested

const FRAME: StyleBoxFlat = preload("res://demo/ui/iron_frame.tres")
const GOLD := Color("#BA9A60")

@onready var _health_panel: PanelContainer = $HealthPanel
@onready var _equip_panel: PanelContainer = $EquipmentPanel
@onready var _objective_panel: PanelContainer = $ObjectivePanel
@onready var _view_panel: PanelContainer = $ViewPanel
@onready var _health_bar: ProgressBar = $HealthPanel/Content/HealthBar
@onready var _hp_text: Label = $HealthPanel/Content/Row/HP
@onready var _health_footer: Label = $HealthPanel/Content/Footer
@onready var _weapon_icon: TextureRect = $EquipmentPanel/Content/Row/IconFrame/IconCenter/Icon
@onready var _weapon_fallback: Label = $EquipmentPanel/Content/Row/IconFrame/IconCenter/Fallback
@onready var _weapon_title: Label = $EquipmentPanel/Content/Row/Details/WeaponTitle
@onready var _ammo_text: Label = $EquipmentPanel/Content/Row/Details/AmmoText
@onready var _secondary: Label = $EquipmentPanel/Content/Secondary
@onready var _secondary_separator: HSeparator = $EquipmentPanel/Content/Separator
@onready var _objective: Label = $ObjectivePanel/Content/ObjectiveText
@onready var _view: Label = $ViewPanel/ViewText
@onready var _interaction_panel: PanelContainer = $InteractionPanel
@onready var _interaction: Label = $InteractionPanel/InteractionText
@onready var _notification_panel: PanelContainer = $NotificationPanel
@onready var _notification: Label = $NotificationPanel/NotificationText
@onready var _notice_timer: Timer = $NoticeTimer
@onready var _reticle: Label = $AimReticle
@onready var _help_panel: PanelContainer = $HelpPanel
@onready var _help_title: Label = $HelpPanel/Content/Title
@onready var _help_text: Label = $HelpPanel/Content/Scroll/HelpText
@onready var _view_selector: HBoxContainer = $HelpPanel/Content/ViewSelector
@onready var _camera_button: Button = $HelpPanel/Content/CameraSettings

var _gameplay_visible: bool = true
var _reticle_requested: bool = false
var _health_critical: bool = false
var _player_state: String = ""
var _input_hint: String = ""


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _notice_timer.timeout.connect(_notification_panel.hide)
    _camera_button.pressed.connect(func() -> void: settings_requested.emit())
    set_gameplay_visible(true)


## Presentation-only visibility. Menus and death/victory overlays are separate.
func set_gameplay_visible(value: bool) -> void:
    _gameplay_visible = value
    for panel in [_health_panel, _equip_panel, _objective_panel, _view_panel]:
        panel.visible = value
    _reticle.visible = value and _reticle_requested
    _interaction_panel.visible = value and not _interaction.text.is_empty()
    _notification_panel.visible = value and not _notification.text.is_empty() \
        and not _notice_timer.is_stopped()


func is_gameplay_visible() -> bool:
    return _gameplay_visible


func is_help_open() -> bool:
    return _help_panel.visible


func set_help_open(value: bool) -> void:
    if _help_panel.visible == value:
        return
    _help_panel.visible = value
    help_visibility_changed.emit(value)


func set_shortcut_hints(hud_hint: String, help_hint: String) -> void:
    _input_hint = "%s · HUD    %s · HELP" % [hud_hint, help_hint]
    _help_title.text = "IRON RELIQUARY  ·  CONTROLS  [%s TO CLOSE]" % help_hint
    _render_player_state()


func set_help_text(value: String) -> void:
    if _help_text.text != value:
        _help_text.text = value


func set_health(current: float, maximum: float) -> void:
    var max_hp: float = maxf(1.0, maximum)
    _health_bar.max_value = max_hp
    _health_bar.value = clampf(current, 0.0, max_hp)
    _hp_text.text = "%d / %d" % [ceili(current), ceili(maximum)]
    _health_critical = current <= max_hp * 0.25
    _health_bar.modulate = Color("#FFB0A9") if _health_critical else Color.WHITE
    _render_player_state()


func set_player_state(value: String) -> void:
    _player_state = value
    _render_player_state()


func _render_player_state() -> void:
    _health_footer.text = "LOW HEALTH · " + _input_hint if _health_critical else (
        _player_state if not _player_state.is_empty() else _input_hint
    )


func set_reticle(value: bool) -> void:
    _reticle_requested = value
    _reticle.visible = value and _gameplay_visible


func set_equipment(name: String, icon: Texture2D, ammo: Dictionary,
        secondary: String, swap_hint: String, actions: String) -> void:
    _weapon_title.text = name if not name.is_empty() else "Unarmed"
    _weapon_icon.texture = icon
    _weapon_icon.visible = icon != null
    _weapon_fallback.visible = icon == null
    if not ammo.is_empty():
        if bool(ammo.get("reloading", false)):
            _ammo_text.text = "RELOADING · %d ticks" % int(ammo.get("reload_left", 0))
        else:
            _ammo_text.text = "%02d / %02d" % [
                int(ammo.get("magazine", 0)), int(ammo.get("reserve", 0))
            ]
            if int(ammo.get("magazine", 0)) == 0:
                _ammo_text.text += " · EMPTY"
    else:
        _ammo_text.text = actions if not actions.is_empty() else "READY"
    _secondary.text = "%s  ·  %s to switch" % [secondary, swap_hint] \
        if not secondary.is_empty() and not swap_hint.is_empty() else ""
    _secondary.visible = not _secondary.text.is_empty()
    _secondary_separator.visible = _secondary.visible


func set_objective(value: String) -> void:
    _objective.text = value


func set_view(value: String) -> void:
    _view.text = value


func set_interaction(value: String) -> void:
    _interaction.text = value
    _interaction_panel.visible = _gameplay_visible and not value.is_empty()


func notify(value: String) -> void:
    _notification.text = value
    if _gameplay_visible:
        _notification_panel.show()
        _notice_timer.start()


## Button instances are the only dynamic part of the otherwise authored scene.
func set_view_choices(choices: Array[Dictionary]) -> void:
    for child in _view_selector.get_children():
        _view_selector.remove_child(child)
        child.queue_free()
    for choice in choices:
        var button := Button.new()
        button.text = str(choice.get("label", ""))
        button.custom_minimum_size = Vector2(116, 36)
        button.add_theme_color_override("font_color", GOLD)
        button.add_theme_stylebox_override("normal", FRAME)
        button.pressed.connect(_request_view.bind(int(choice.get("index", -1))))
        _view_selector.add_child(button)


func _request_view(index: int) -> void:
    view_requested.emit(index)
