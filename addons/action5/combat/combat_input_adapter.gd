extends Node
class_name Action5CombatInputAdapter
## Raw combat input only; actor, locomotion and movement input stay generic.
const CombatScript = preload("res://addons/action5/combat/combat_controller.gd")
const AimScript = preload("res://addons/action5/combat/aim_provider.gd")
const ActionContextScript = preload("res://addons/action5/input/action_input_context.gd")

@export var combat_path: NodePath = ^"../Player/CombatController"
@export var context_source_path: NodePath = ^"../ActorInput"

@onready var combat: CombatScript = get_node_or_null(combat_path) as CombatScript
## Duck-typed provider implementing get_action_input_context().
## May be replaced by a test stub or another local input source at runtime.
@onready var context_source: Node = get_node_or_null(context_source_path)

var release_to_rearm: bool = false
# InputMap sees mouse events even when GUI consumes them. Only an event
# reaching unhandled input may start a mouse attack.
var _unhandled_mouse_edges: Dictionary = {}
var _pressed_mouse_edges: Dictionary = {}


func _input(event: InputEvent) -> void:
    # Capture the original press before GUI routing, including short
    # press+release clicks completed within a single physics tick.
    if combat == null or not (event is InputEventMouseButton):
        return
    var mouse := event as InputEventMouseButton
    if not mouse.pressed:
        return
    for attack in combat.get_attacks():
        if attack.input_action != &"" and mouse.is_action_pressed(attack.input_action):
            _pressed_mouse_edges[attack.input_action] = true


func _unhandled_input(event: InputEvent) -> void:
    if combat == null or not (event is InputEventMouseButton):
        return
    var mouse := event as InputEventMouseButton
    if not mouse.pressed:
        return
    for attack in combat.get_attacks():
        if attack.input_action != &"" and mouse.is_action_pressed(attack.input_action):
            _unhandled_mouse_edges[attack.input_action] = true


func _ready() -> void:
    process_physics_priority = -90
    if combat == null or not is_instance_valid(context_source) \
            or not context_source.has_method("get_action_input_context"):
        push_error("ACTION5: CombatInputAdapter needs CombatController and an ActionInputContext provider")
        set_physics_process(false)
        return
    for attack in combat.get_attacks():
        register_action(attack)
    combat.attack_registered.connect(register_action)


func _physics_process(_delta: float) -> void:
    # Consume all mouse press edges each tick, including while blocked,
    # so stale UI clicks never replay when gameplay resumes.
    var mouse_edges: Dictionary = _unhandled_mouse_edges
    var pressed_mouse_edges: Dictionary = _pressed_mouse_edges
    _unhandled_mouse_edges = {}
    _pressed_mouse_edges = {}
    if combat == null or combat.body == null:
        return
    # A missing/invalid context fails closed, preserving the release gate.
    # No lookups of Actor/Locomotion/Facing/ViewManager internals here.
    var context: ActionContextScript
    if is_instance_valid(context_source) and context_source.has_method("get_action_input_context"):
        context = context_source.call("get_action_input_context") as ActionContextScript
    var blocked: bool = context == null or not context.accepting_actions
    if blocked:
        release_to_rearm = true
        return
    if release_to_rearm:
        if not all_buttons_released():
            return
        release_to_rearm = false
        return
    for attack in combat.get_attacks():
        if attack.input_action == &"" or not Input.is_action_just_pressed(attack.input_action):
            continue
        if pressed_mouse_edges.has(attack.input_action) and not mouse_edges.has(attack.input_action):
            continue
        var direction: Vector2 = AimScript.resolve_direction(
            context.world_aim, context.facing_world,
            context.view_mode, context.camera,
            4 if attack.facing_sectors == 1 else (8 if attack.facing_sectors == 2 else 0)
        )
        combat.request_attack(attack.attack_id, direction)
        break


func all_buttons_released() -> bool:
    for attack in combat.get_attacks():
        if attack.input_action != &"" and Input.is_action_pressed(attack.input_action):
            return false
    return true


func register_action(attack: Resource) -> void:
    var action: StringName = attack.get("input_action")
    if action == &"":
        return
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    if not InputMap.action_get_events(action).is_empty():
        return
    var key: int = attack.get("default_key")
    if key != 0:
        var event := InputEventKey.new()
        event.keycode = key
        InputMap.action_add_event(action, event)
    var button: int = attack.get("default_gamepad_button")
    if button >= 0:
        var joy := InputEventJoypadButton.new()
        joy.button_index = button
        InputMap.action_add_event(action, joy)
    var mouse_button: int = attack.get("default_mouse_button")
    if mouse_button > 0:
        var mouse := InputEventMouseButton.new()
        mouse.button_index = mouse_button
        InputMap.action_add_event(action, mouse)


func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
        release_to_rearm = true
