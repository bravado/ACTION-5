extends Node
class_name Action5ViewInput
## Raw camera selection input is kept separate from player movement/combat.
## Number row 1–6 is PRIMARY on native and web; F1–F6 is optional secondary.

@export var manager_path: NodePath = ^"../ViewManager"
@export var bind_number_keys: bool = true
@export var bind_function_keys: bool = true
@export var bind_controller_cycle: bool = true

var manager: Action5ViewManager


func _ready() -> void:
    manager = get_node_or_null(manager_path) as Action5ViewManager
    if manager == null:
        push_error("ACTION5: ViewInput needs a ViewManager")
        return
    _register_default_actions()


func _register_default_actions() -> void:
    for i in range(6):
        var action := StringName("view_" + str(i + 1))
        if not InputMap.has_action(action):
            InputMap.add_action(action)
        # Do not override user-defined mappings. Default actions added here are
        # editable from project input configuration or custom input UI.
        if InputMap.action_get_events(action).is_empty():
            if bind_number_keys:
                var number_key := InputEventKey.new()
                number_key.keycode = KEY_1 + i
                InputMap.action_add_event(action, number_key)
            if bind_function_keys:
                var function_key := InputEventKey.new()
                function_key.keycode = KEY_F1 + i
                InputMap.action_add_event(action, function_key)
    _register_cycle_action(&"view_previous", JOY_BUTTON_LEFT_SHOULDER)
    _register_cycle_action(&"view_next", JOY_BUTTON_RIGHT_SHOULDER)


func _register_cycle_action(action: StringName, button_id: int) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    if bind_controller_cycle and InputMap.action_get_events(action).is_empty():
        var joy := InputEventJoypadButton.new()
        joy.button_index = button_id
        InputMap.action_add_event(action, joy)


func _unhandled_input(event: InputEvent) -> void:
    if manager == null:
        return
    if event is InputEventKey and (not event.pressed or event.echo):
        return
    for i in range(6):
        if event.is_action_pressed("view_" + str(i + 1)):
            manager.switch_view(i)
            get_viewport().set_input_as_handled()
            return
    if event.is_action_pressed("view_previous"):
        manager.cycle_view(-1)
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("view_next"):
        manager.cycle_view(1)
        get_viewport().set_input_as_handled()
    elif event is InputEventMouseMotion:
        if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
            manager.camera_rig.apply_mouse_motion(event.relative)
    elif event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_LEFT and manager.current_profile.is_orbit_mode():
            Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    elif event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
