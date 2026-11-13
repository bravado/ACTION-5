extends Node

class_name Action5ViewInput

const ViewManagerScript = preload("res://addons/action5/camera/view_manager.gd")
## Raw camera selection input is kept separate from player movement/combat.
## Number row 1–5 is PRIMARY on native and web; F1–F5 is optional secondary.

@export var manager_path: NodePath = ^"../ViewManager"
@export var bind_number_keys: bool = true
@export var bind_function_keys: bool = true
@export var bind_controller_cycle: bool = true
## Optional zero-based profile index for each view_1..view_5 shortcut.
## Empty preserves identity order for every existing addon consumer.
@export var shortcut_profile_indices: PackedInt32Array = PackedInt32Array()

var manager: ViewManagerScript
## Capturing the pointer may generate one synthetic warp-motion event in
## WebGL2/desktop. Never interpret that event as player mouse look.
var _ignore_capture_warp: bool = false
## Pointer-lock changes can emit several synthetic browser recenter events,
## not just one. Ignore initial motion briefly and reject large warp spikes
## during the capture transition, without affecting normal mouse look.
var _capture_started_ms: int = -1


func _ready() -> void:
    manager = get_node_or_null(manager_path) as ViewManagerScript
    if manager == null:
        push_error("ACTION5: ViewInput needs a ViewManager")
        return
    if not _shortcut_mapping_valid():
        push_error("ACTION5: shortcut_profile_indices must be a permutation of 0..4")
        shortcut_profile_indices = PackedInt32Array()
    _register_default_actions()


func _shortcut_mapping_valid() -> bool:
    if shortcut_profile_indices.is_empty():
        return true
    if shortcut_profile_indices.size() != 5:
        return false
    var seen := {}
    for index in shortcut_profile_indices:
        if index < 0 or index >= manager.profiles.size() or seen.has(index):
            return false
        seen[index] = true
    return true


## Numeric shortcut slot is 0-based; view_1 maps slot 0, etc.
func profile_index_for_shortcut(slot: int) -> int:
    if manager == null or slot < 0 or slot >= manager.profiles.size():
        return -1
    return slot if shortcut_profile_indices.is_empty() else shortcut_profile_indices[slot]


func shortcut_for_profile_index(index: int) -> int:
    if manager == null:
        return -1
    for slot in range(manager.profiles.size()):
        if profile_index_for_shortcut(slot) == index:
            return slot
    return -1


func _register_default_actions() -> void:
    for i in range(5):
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
    for i in range(5):
        if event.is_action_pressed("view_" + str(i + 1)):
            manager.switch_view(profile_index_for_shortcut(i))
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
            # Browser pointer-lock may emit viewport-sized recenter deltas
            # long after capture (including after clicks or resize). These
            # are not real mouse movement and must never rotate the camera.
            if OS.has_feature("web"):
                var viewport_size: Vector2 = get_viewport().get_visible_rect().size
                if viewport_size.x > 0.0 and viewport_size.y > 0.0 and (
                    absf(event.relative.x) >= viewport_size.x * 0.45 or
                    absf(event.relative.y) >= viewport_size.y * 0.45
                ):
                    return
            if _ignore_capture_warp:
                _ignore_capture_warp = false
                return
            if _capture_started_ms >= 0:
                var elapsed_ms: int = Time.get_ticks_msec() - _capture_started_ms
                if elapsed_ms < 180 or (
                    elapsed_ms < 650 and event.relative.length_squared() > 1024.0
                ):
                    return
                if elapsed_ms >= 650:
                    _capture_started_ms = -1
            manager.camera_rig.apply_mouse_motion(event.relative)
    elif event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_LEFT and manager.current_profile.is_orbit_mode():
            if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
                # A first click may both attack and lock the pointer. The
                # browser-generated recenter motion must not rotate the
                # camera before the following deliberate mouse movement.
                _ignore_capture_warp = true
                _capture_started_ms = Time.get_ticks_msec()
                Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    elif event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
        _ignore_capture_warp = false
        _capture_started_ms = -1
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
        _ignore_capture_warp = false
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
