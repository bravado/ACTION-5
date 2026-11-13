extends Control
## D09-03 Iron Reliquary: visual-only scene. It receives snapshots from
## reference_hud.gd; Health/Equipment/Combat/ViewManager own all game state.
## A single anchored layout is used by every view and viewport aspect ratio.

signal help_visibility_changed(open: bool)
signal view_requested(index: int)
signal settings_requested

const FRAME: StyleBoxFlat = preload("res://demo/ui/iron_frame.tres")
const IVORY := Color("#E9DFC9")
const GOLD := Color("#BA9A60")
const MUTED := Color("#A9A0A7")

var _gameplay_nodes: Array[Control] = []
var _health_bar: ProgressBar
var _hp_text: Label
var _weapon_icon: TextureRect
var _weapon_fallback: Label
var _weapon_title: Label
var _ammo_text: Label
var _secondary: Label
var _secondary_separator: HSeparator
var _objective: Label
var _view: Label
var _interaction: Label
var _interaction_panel: PanelContainer
var _notification: Label
var _notification_panel: PanelContainer
var _notice_timer: Timer
var _help_panel: PanelContainer
var _help_text: Label
var _gameplay_visible: bool = true
var _reticle: Label
var _reticle_requested: bool = false
var _health_footer: Label
var _health_critical: bool = false
var _player_state: String = ""


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _build_health()
    _build_equipment()
    _build_top()
    _build_interaction()
    _build_notification()
    _build_reticle()
    _build_help()
    _notice_timer = Timer.new()
    _notice_timer.one_shot = true
    _notice_timer.wait_time = 2.0
    add_child(_notice_timer)
    _notice_timer.timeout.connect(func() -> void: _notification_panel.hide())
    set_gameplay_visible(true)


## This method changes presentation alone, never actor input or simulation.
func set_gameplay_visible(value: bool) -> void:
    _gameplay_visible = value
    for node in _gameplay_nodes:
        node.visible = value
    _reticle.visible = value and _reticle_requested
    # Contextual hints and ephemeral notices also respect full hide.
    if value:
        _interaction_panel.visible = not _interaction.text.is_empty()
        _notification_panel.visible = not _notification.text.is_empty() and not _notice_timer.is_stopped()
    else:
        _interaction_panel.hide()
        _notification_panel.hide()


func is_gameplay_visible() -> bool:
    return _gameplay_visible


func is_help_open() -> bool:
    return _help_panel.visible


func set_help_open(value: bool) -> void:
    if _help_panel.visible == value:
        return
    _help_panel.visible = value
    help_visibility_changed.emit(value)


func set_help_text(value: String) -> void:
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
    if _health_critical:
        _health_footer.text = "LOW HEALTH   ·   H HUD / F6 HELP"
    else:
        _health_footer.text = _player_state if not _player_state.is_empty() \
            else "H · HUD    F6 · HELP"


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


func _panel(name: String, a_left: float, a_top: float, a_right: float,
        a_bottom: float, o_left: float, o_top: float, o_right: float,
        o_bottom: float) -> PanelContainer:
    var panel := PanelContainer.new()
    panel.name = name
    panel.anchor_left = a_left
    panel.anchor_top = a_top
    panel.anchor_right = a_right
    panel.anchor_bottom = a_bottom
    panel.offset_left = o_left
    panel.offset_top = o_top
    panel.offset_right = o_right
    panel.offset_bottom = o_bottom
    panel.add_theme_stylebox_override("panel", FRAME)
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(panel)
    return panel


func _label(value: String, size: int = 14, color: Color = IVORY) -> Label:
    var label := Label.new()
    label.text = value
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    return label


func _stack(parent: Control) -> VBoxContainer:
    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 4)
    stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(stack)
    return stack


func _build_health() -> void:
    var panel := _panel("HealthPanel", 0, 1, 0, 1, 24, -101, 307, -20)
    _gameplay_nodes.append(panel)
    var stack := _stack(panel)
    var row := HBoxContainer.new()
    stack.add_child(row)
    var title := _label("VITALITY", 13, GOLD)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(title)
    _hp_text = _label("100 / 100", 14)
    _hp_text.custom_minimum_size.x = 80
    _hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    _hp_text.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
    row.add_child(_hp_text)
    _health_bar = ProgressBar.new()
    _health_bar.custom_minimum_size = Vector2(0, 16)
    _health_bar.show_percentage = false
    var background := StyleBoxFlat.new()
    background.bg_color = Color("#0C0B12")
    _health_bar.add_theme_stylebox_override("background", background)
    var fill := StyleBoxFlat.new()
    fill.bg_color = Color("#A82F45")
    _health_bar.add_theme_stylebox_override("fill", fill)
    stack.add_child(_health_bar)
    _health_footer = _label("H · HUD    F6 · HELP", 11, MUTED)
    stack.add_child(_health_footer)


func _build_equipment() -> void:
    var panel := _panel("EquipmentPanel", 1, 1, 1, 1, -359, -119, -24, -20)
    _gameplay_nodes.append(panel)
    var stack := _stack(panel)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 12)
    stack.add_child(row)
    var icon_frame := PanelContainer.new()
    icon_frame.custom_minimum_size = Vector2(46, 46)
    icon_frame.add_theme_stylebox_override("panel", FRAME)
    row.add_child(icon_frame)
    var icon_box := CenterContainer.new()
    icon_frame.add_child(icon_box)
    _weapon_icon = TextureRect.new()
    _weapon_icon.custom_minimum_size = Vector2(32, 32)
    _weapon_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _weapon_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon_box.add_child(_weapon_icon)
    _weapon_fallback = _label("◆", 26, GOLD)
    _weapon_fallback.custom_minimum_size = Vector2(32, 32)
    _weapon_fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _weapon_fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _weapon_fallback.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
    icon_box.add_child(_weapon_fallback)
    var details := _stack(row)
    details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _weapon_title = _label("Unarmed", 17)
    details.add_child(_weapon_title)
    _ammo_text = _label("READY", 13, GOLD)
    details.add_child(_ammo_text)
    _secondary_separator = HSeparator.new()
    stack.add_child(_secondary_separator)
    _secondary = _label("", 12, MUTED)
    stack.add_child(_secondary)


func _build_top() -> void:
    var objective_panel := _panel("ObjectivePanel", 0, 0, 0, 0,
        24, 18, 353, 82)
    _gameplay_nodes.append(objective_panel)
    var stack := _stack(objective_panel)
    stack.add_child(_label("OBJECTIVE", 11, GOLD))
    _objective = _label("", 13)
    _objective.custom_minimum_size = Vector2(298, 30)
    _objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _objective.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
    stack.add_child(_objective)
    var view_panel := _panel("ViewPanel", 1, 0, 1, 0,
        -294, 18, -24, 67)
    _gameplay_nodes.append(view_panel)
    _view = _label("", 13, GOLD)
    _view.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    view_panel.add_child(_view)


func _build_interaction() -> void:
    _interaction_panel = _panel("InteractionPanel", 0.5, 1, 0.5, 1,
        -144, -181, 144, -135)
    _interaction = _label("", 14)
    _interaction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _interaction_panel.add_child(_interaction)
    _interaction_panel.hide()


func _build_notification() -> void:
    _notification_panel = _panel("NotificationPanel", 0.5, 0, 0.5, 0,
        -150, 88, 150, 127)
    _notification = _label("", 13, GOLD)
    _notification.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _notification_panel.add_child(_notification)
    _notification_panel.hide()


func _build_reticle() -> void:
    _reticle = _label("+", 24, GOLD)
    _reticle.name = "AimReticle"
    _reticle.anchor_left = 0.5
    _reticle.anchor_right = 0.5
    _reticle.anchor_top = 0.5
    _reticle.anchor_bottom = 0.5
    _reticle.offset_left = -9
    _reticle.offset_top = -15
    _reticle.offset_right = 9
    _reticle.offset_bottom = 15
    _reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    add_child(_reticle)
    _reticle.hide()


func _build_help() -> void:
    _help_panel = _panel("HelpPanel", 0.5, 0.5, 0.5, 0.5,
        -350, -248, 350, 248)
    _help_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    var layout := _stack(_help_panel)
    layout.mouse_filter = Control.MOUSE_FILTER_PASS
    layout.add_child(_label("IRON RELIQUARY  ·  CONTROLS  [F6 TO CLOSE]", 18, GOLD))
    var selector := HBoxContainer.new()
    selector.add_theme_constant_override("separation", 6)
    layout.add_child(selector)
    var titles := ["1 · SIDE", "2 · BEAT", "3 · ISO", "4 · FIRST", "5 · RETRO"]
    for i in range(titles.size()):
        var button := Button.new()
        button.text = titles[i]
        button.custom_minimum_size = Vector2(116, 36)
        button.add_theme_color_override("font_color", GOLD)
        button.add_theme_stylebox_override("normal", FRAME)
        button.pressed.connect(_request_view.bind(i))
        selector.add_child(button)
    var camera := Button.new()
    camera.text = "CAMERA SETTINGS [C]"
    camera.add_theme_color_override("font_color", GOLD)
    camera.pressed.connect(func() -> void: settings_requested.emit())
    layout.add_child(camera)
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.mouse_filter = Control.MOUSE_FILTER_STOP
    layout.add_child(scroll)
    _help_text = _label("", 14)
    _help_text.custom_minimum_size = Vector2(610, 0)
    _help_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    scroll.add_child(_help_text)
    _help_panel.hide()


func _request_view(index: int) -> void:
    view_requested.emit(index)
