extends Node
class_name Action5WeaponCommandInputAdapter
## Optional generic command adapter. No weapon type, special attack button,
## or camera dependency. An equipped component supplies its own bindings.

@export var equipment_path: NodePath = ^"../Player/Equipment"
@export var context_source_path: NodePath = ^"../ActorInput"

@onready var equipment: Node = get_node_or_null(equipment_path)
@onready var context_source: Node = get_node_or_null(context_source_path)

var release_to_rearm: bool = false
var _last_weapon: Node


func _ready() -> void:
    process_physics_priority = -80


func _physics_process(_delta: float) -> void:
    var weapon: Node = equipment.get("current_weapon") as Node if is_instance_valid(equipment) else null
    if weapon != _last_weapon:
        _last_weapon = weapon
        release_to_rearm = true
        if is_instance_valid(weapon) and weapon.has_method("get_command_bindings"):
            for binding in weapon.call("get_command_bindings"):
                _register_binding(binding)
    if not is_instance_valid(weapon) or not weapon.has_method("request_weapon_command")             or not weapon.has_method("get_command_bindings"):
        return
    var context: RefCounted
    if is_instance_valid(context_source) and context_source.has_method("get_action_input_context"):
        context = context_source.call("get_action_input_context")
    if context == null or not bool(context.get("accepting_actions")):
        release_to_rearm = true
        return
    var commands: Array = weapon.call("get_command_bindings")
    if release_to_rearm:
        for binding in commands:
            if Input.is_action_pressed(binding.get("action", &"")):
                return
        release_to_rearm = false
        return
    for binding in commands:
        var action: StringName = binding.get("action", &"")
        if action != &"" and Input.is_action_just_pressed(action):
            weapon.call("request_weapon_command", action)
            break


func _register_binding(binding: Dictionary) -> void:
    var action: StringName = binding.get("action", &"")
    if action == &"":
        return
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    if not InputMap.action_get_events(action).is_empty():
        return
    var key: int = int(binding.get("key", 0))
    if key != 0:
        var event := InputEventKey.new()
        event.keycode = key
        InputMap.action_add_event(action, event)
    var button: int = int(binding.get("gamepad_button", -1))
    if button >= 0:
        var event := InputEventJoypadButton.new()
        event.button_index = button
        InputMap.action_add_event(action, event)


func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
        release_to_rearm = true
