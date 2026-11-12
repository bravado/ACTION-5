extends Node
class_name Action5ActorInputAdapter
## Convert remappable input to camera-relative world-plane intents.
## Does not own the actor physics nor camera, and does not read input in actors.

const IntentScript = preload("res://addons/action5/actor/move_intent.gd")
const ActionContextScript = preload("res://addons/action5/input/action_input_context.gd")
const MoveScript = preload("res://addons/action5/actor/moves/move.gd")
const MovementPolicyScript = preload("res://addons/action5/actor/movement_policy.gd")
const ActorScript = preload("res://addons/action5/actor/action_actor.gd")
const ViewManagerScript = preload("res://addons/action5/camera/view_manager.gd")
const ViewProfileScript = preload("res://addons/action5/camera/view_profile.gd")
const ControlProfileScript = preload("res://addons/action5/input/view_control_profile.gd")
const DefaultControls = preload("res://addons/action5/input/profiles/default.tres")
const SideControls = preload("res://addons/action5/input/profiles/side.tres")
const FirstPersonControls = preload("res://addons/action5/input/profiles/first_person.tres")

@export var actor_path: NodePath = ^"../Player"
@export var view_manager_path: NodePath = ^"../ViewManager"
@export_range(0.0, 0.95, 0.05) var move_deadzone: float = 0.20
@export_range(0.0, 0.95, 0.05) var aim_deadzone: float = 0.28
@export_enum("4-way", "8-way") var retro_facing: int = 1
@export var independent_aim_enabled: bool = true
## Optional equipped/view facing provider, shared with CombatInput and Gun aim.
@export var direction_policy_path: NodePath = ^""
## F4-only keyboard turning. Turn actions are remappable independently of A/D.
@export_range(30.0, 360.0, 5.0) var first_person_turn_speed: float = 135.0
## Editing or adding a mapping requires only a Resource, not a new view branch.
@export var default_controls: ControlProfileScript = DefaultControls
@export var view_controls: Array[ControlProfileScript] = [
    SideControls, FirstPersonControls
]

@onready var actor: ActorScript = get_node_or_null(actor_path) as ActorScript
@onready var views: ViewManagerScript = get_node_or_null(view_manager_path) as ViewManagerScript

var enabled: bool = true
var focus_active: bool = true
var require_neutral: bool = false
# Entering F4 alone is not an aiming command that turns the actor.
var _first_person_entry_look_revision: int = 0
## Track ONLY hold-move requests initiated by this adapter. A move activated
## by a different binding (e.g. Ctrl toggle) must not be released by S.
var _held_move_requested: bool = false
var _held_move_id: StringName = &""
var _held_move_variants: Array[StringName] = []


func _ready() -> void:
    # Sample raw input before the actor's default-priority locomotion tick,
    # even when the adapter appears after Player in the scene tree.
    process_physics_priority = -100
    if actor == null or views == null:
        push_error("ACTION5: ActorInputAdapter requires Action5Actor and ViewManager")
        set_physics_process(false)
        return
    _register_default_actions()
    var controller := actor.locomotion.move_controller
    for move in controller.get_moves():
        _register_move_action(move)
    controller.move_registered.connect(_register_move_action)
    views.view_changed.connect(_on_view_changed)
    Input.joy_connection_changed.connect(_on_joy_connection_changed)
    if views.current_profile != null:
        _on_view_changed(views.current_profile, null)


func _physics_process(_delta: float) -> void:
    if actor == null or views == null:
        return
    # UI/focus transitions and actor setters already clear stale input once;
    # do not cancel the actor's movement FSM every blocked physics tick.
    if not enabled or not focus_active or not actor.alive or not actor.controls_enabled:
        return

    var controls: ControlProfileScript = get_active_controls()
    var axes: Vector2 = get_movement_axes()
    var aim_axes := Input.get_vector(&"aim_left", &"aim_right", &"aim_up", &"aim_down", aim_deadzone)
    var turn_axis: float = _axis(controls.turn_left_action, controls.turn_right_action)
    if require_neutral:
        if axes.length_squared() > 0.001 or aim_axes.length_squared() > 0.001 \
                or absf(turn_axis) > 0.001 \
                or _pressed(controls.extra_jump_action) \
                or _pressed(controls.held_move_action):
            clear_input()
            return
        require_neutral = false

    # Yaw is a replaceable camera look port, not an Actor/Combat branch.
    if absf(turn_axis) > 0.001:
        views.camera_rig.apply_yaw_delta(
            -turn_axis * deg_to_rad(first_person_turn_speed) * _delta
        )

    var jump: bool = _just_pressed(controls.jump_action) \
        or _just_pressed(controls.extra_jump_action)
    var command: IntentScript = compose_intent(
        axes, aim_axes, jump, Input.is_action_pressed(&"actor_run")
    )
    _apply_held_move(controls, command)
    actor.apply_move_intent(command)


## A Resource selects action names per view; the InputMap remains global and
## remappable, while gameplay sees the same camera-independent MoveIntent.
func get_active_controls() -> ControlProfileScript:
    var mode: int = views.current_profile.mode if is_instance_valid(views) \
        and views.current_profile != null else -1
    for profile in view_controls:
        if profile != null and profile.view_mode == mode:
            return profile
    return default_controls


func get_movement_axes() -> Vector2:
    var controls: ControlProfileScript = get_active_controls()
    if controls == null:
        return Vector2.ZERO
    var axes: Vector2
    if controls.vertical_movement:
        axes = Input.get_vector(
            controls.move_left_action, controls.move_right_action,
            controls.move_up_action, controls.move_down_action, move_deadzone
        )
    else:
        # Prevent S/Down (now crouch) from reducing horizontal speed via
        # Input.get_vector()'s diagonal normalization.
        axes = Vector2(Input.get_axis(controls.move_left_action,
            controls.move_right_action), 0.0)
    axes.x = clampf(axes.x + _axis(controls.extra_left_action,
        controls.extra_right_action), -1.0, 1.0)
    return axes.limit_length(1.0)


func _pressed(action: StringName) -> bool:
    return action != &"" and InputMap.has_action(action) \
        and Input.is_action_pressed(action)


func _just_pressed(action: StringName) -> bool:
    return action != &"" and InputMap.has_action(action) \
        and Input.is_action_just_pressed(action)


func _axis(left: StringName, right: StringName) -> float:
    # Blank actions mean an unassigned role; don't query invalid InputMap names.
    return (_action_strength(right) - _action_strength(left))


func _action_strength(action: StringName) -> float:
    return Input.get_action_strength(action) if action != &"" \
        and InputMap.has_action(action) else 0.0


func _held_move_active() -> bool:
    if not is_instance_valid(actor) or not is_instance_valid(actor.locomotion):
        return false
    return _held_move_variants.has(actor.locomotion.move_controller.active_id)


func _apply_held_move(controls: ControlProfileScript, intent: IntentScript) -> void:
    var wants_hold: bool = controls.held_move_id != &"" \
        and _pressed(controls.held_move_action)
    if wants_hold:
        # Another component's toggle stance is not owned by this hold.
        if not _held_move_requested:
            if _held_move_variants.has(actor.locomotion.move_controller.active_id):
                return
            _held_move_id = controls.held_move_id
            _held_move_variants = controls.held_move_variants.duplicate()
        if not _held_move_active():
            intent.request_move(_held_move_id)
            _held_move_requested = true
    elif _held_move_requested:
        if _held_move_active():
            # Request every tick until a blocked headroom probe can stand.
            intent.request_move(_held_move_id)
        else:
            _reset_held_move()


func _reset_held_move() -> void:
    _held_move_requested = false
    _held_move_id = &""
    _held_move_variants.clear()


func compose_intent(
    axes: Vector2,
    aim_axes: Vector2 = Vector2.ZERO,
    jump: bool = false,
    running: bool = false
) -> IntentScript:
    var mode: int = views.current_profile.mode
    var basis: Basis = views.get_active_camera().global_basis
    var movement := MovementPolicyScript.to_world(axes, mode, basis)
    var aim: Vector2 = Vector2.ZERO
    if independent_aim_enabled and aim_axes.length_squared() > 0.001:
        aim = MovementPolicyScript.to_world(aim_axes, mode, basis)
    # In F4, explicit movement or mouse look may orient the body to the
    # camera. A view switch with neutral input must not silently turn it.
    if mode == ViewProfileScript.Mode.FIRST_PERSON and aim.length_squared() < 0.001 and (
        movement.length_squared() > 0.001
        or views.camera_rig.look_input_revision != _first_person_entry_look_revision
    ):
        aim = MovementPolicyScript.to_world(Vector2(0.0, -1.0), mode, basis)
    var sectors: int = 4 if retro_facing == 0 else 8
    var facing := MovementPolicyScript.choose_facing(movement, aim, mode, sectors)
    var intent: IntentScript = IntentScript.new(movement, facing, aim)
    intent.jump_pressed = jump
    intent.running = running
    # Every move component declares its own action. New moves can be
    # installed without adding a new branch, boolean or key here.
    for move in actor.locomotion.move_controller.get_moves():
        if move.action_name != &"" and Input.is_action_just_pressed(move.action_name):
            intent.request_move(move.move_id)
    return intent


## Stable, read-only input context for independent actions and abilities.
## This is the sole adapter authorized to translate movement/facing details
## into a reusable snapshot; external features never traverse actor internals.
func get_action_input_context() -> ActionContextScript:
    if not is_instance_valid(actor) or not is_instance_valid(views) \
            or views.current_profile == null:
        return ActionContextScript.new()
    var intent: IntentScript = actor.locomotion.desired if is_instance_valid(actor.locomotion) else null
    return ActionContextScript.new(
        enabled and focus_active and not require_neutral
            and actor.alive and actor.controls_enabled,
        intent.aim_world if intent != null else Vector2.ZERO,
        actor.facing.facing_world if is_instance_valid(actor.facing) else Vector2.ZERO,
        views.current_profile.mode,
        views.get_active_camera()
    )


func clear_input() -> void:
    _reset_held_move()
    if is_instance_valid(actor):
        actor.clear_motion()


## The demo controls only this UI gate; window focus belongs to this adapter.
## Repeated calls must not re-cancel pending moves or AI-supplied intents.
func set_enabled(value: bool) -> void:
    if enabled == value:
        return
    enabled = value
    if not enabled:
        clear_input()


func _on_view_changed(current: ViewProfileScript, _previous: ViewProfileScript) -> void:
    if actor == null:
        return
    if current.mode == ViewProfileScript.Mode.FIRST_PERSON:
        _first_person_entry_look_revision = views.camera_rig.look_input_revision
    if current.mode == ViewProfileScript.Mode.SIDE:
        actor.enter_side_view()
    else:
        actor.exit_side_view()


func _on_joy_connection_changed(_device: int, connected: bool) -> void:
    if not connected:
        require_neutral = true
        clear_input()


func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
        focus_active = false
        require_neutral = true
        clear_input()
    elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
        focus_active = true


func _register_default_actions() -> void:
    _ensure(&"move_left", [KEY_A], JOY_AXIS_LEFT_X, -1.0)
    _ensure(&"move_right", [KEY_D], JOY_AXIS_LEFT_X, 1.0)
    _ensure_button(&"actor_turn_left", [KEY_LEFT], -1)
    _ensure_button(&"actor_turn_right", [KEY_RIGHT], -1)
    _ensure(&"move_up", [KEY_W, KEY_UP], JOY_AXIS_LEFT_Y, -1.0)
    _ensure(&"move_down", [KEY_S, KEY_DOWN], JOY_AXIS_LEFT_Y, 1.0)
    _ensure(&"aim_left", [], JOY_AXIS_RIGHT_X, -1.0)
    _ensure(&"aim_right", [], JOY_AXIS_RIGHT_X, 1.0)
    _ensure(&"aim_up", [], JOY_AXIS_RIGHT_Y, -1.0)
    _ensure(&"aim_down", [], JOY_AXIS_RIGHT_Y, 1.0)
    _ensure_button(&"actor_jump", [KEY_SPACE], JOY_BUTTON_A)
    _ensure_button(&"actor_run", [KEY_SHIFT], JOY_BUTTON_LEFT_STICK)


## Components own their input defaults. Existing user InputMap bindings win.
## Also runs when a move component is added at runtime.
func _register_move_action(move: MoveScript) -> void:
    if move == null or move.action_name == &"":
        return
    if not InputMap.has_action(move.action_name):
        InputMap.add_action(move.action_name)
    if not InputMap.action_get_events(move.action_name).is_empty():
        return
    if move.default_key != 0:
        var keyboard := InputEventKey.new()
        keyboard.keycode = move.default_key
        InputMap.action_add_event(move.action_name, keyboard)
    if move.default_gamepad_button >= 0:
        var gamepad := InputEventJoypadButton.new()
        gamepad.button_index = move.default_gamepad_button
        InputMap.action_add_event(move.action_name, gamepad)


func _ensure(action: StringName, keys: Array, joy_axis: int, axis_value: float) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action, 0.2)
    if not InputMap.action_get_events(action).is_empty():
        return
    for key in keys:
        var ev := InputEventKey.new()
        ev.keycode = key
        InputMap.action_add_event(action, ev)
    var motion := InputEventJoypadMotion.new()
    motion.axis = joy_axis
    motion.axis_value = axis_value
    InputMap.action_add_event(action, motion)


func _ensure_button(action: StringName, keys: Array, button: int) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    if not InputMap.action_get_events(action).is_empty():
        return
    for key in keys:
        var ev := InputEventKey.new()
        ev.keycode = key
        InputMap.action_add_event(action, ev)
    if button >= 0:
        var joy := InputEventJoypadButton.new()
        joy.button_index = button
        InputMap.action_add_event(action, joy)
