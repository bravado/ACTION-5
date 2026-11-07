extends Node
class_name Action5MovementController
## Automatically registers child Action5Move components. It dispatches one
## exclusive move at a time and knows no concrete move types.

const MoveScript = preload("res://addons/action5/actor/moves/move.gd")
const ContextScript = preload("res://addons/action5/actor/moves/move_context.gd")
const IntentScript = preload("res://addons/action5/actor/move_intent.gd")

signal move_changed(previous: StringName, current: StringName)
signal move_registered(move: Node)

@export var grounded_move: StringName = &"grounded"
@export var airborne_move: StringName = &"airborne"

@onready var moves_root: Node = $Moves
var active_move: MoveScript
var active_id: StringName = &""

var _registry: Dictionary = {}
var _context: ContextScript
var _ready_for_moves: bool = false


func _ready() -> void:
    var body: CharacterBody3D = get_parent().get_parent() as CharacterBody3D
    if body == null:
        push_error("ACTION5: MovementController must live under Locomotion inside CharacterBody3D")
        return
    _context = ContextScript.new(body, get_parent())
    _ready_for_moves = true
    for child in moves_root.get_children():
        if child is MoveScript:
            register_move(child as MoveScript)


func register_move(move: MoveScript) -> bool:
    if move == null or move.move_id == &"":
        push_warning("ACTION5: Move component must declare move_id")
        return false
    if get_move(move.move_id) != null:
        push_warning("ACTION5: Duplicate move_id: " + str(move.move_id))
        return false
    _registry[move.move_id] = move
    move_registered.emit(move)
    return true


## Runtime extension: add a new component with no Actor/solver edits.
func add_move(move: MoveScript) -> bool:
    if move == null or not _ready_for_moves or move.move_id == &"":
        return false
    # Reject duplicates BEFORE adding a child; failed extensions leave the
    # scene unchanged rather than creating orphan, unregistered move nodes.
    if get_move(move.move_id) != null:
        return false
    if move.get_parent() != null and move.get_parent() != moves_root:
        return false
    if move.get_parent() == null:
        moves_root.add_child(move)
    return register_move(move)


func get_moves() -> Array[MoveScript]:
    var result: Array[MoveScript] = []
    for move in _registry.values():
        if is_instance_valid(move):
            result.append(move)
    return result


func get_move(id: StringName) -> MoveScript:
    if not _registry.has(id):
        return null
    var move: MoveScript = _registry[id]
    if not is_instance_valid(move):
        _registry.erase(id)
        return null
    return move


func request_move(id: StringName, intent: IntentScript = null) -> bool:
    _invalidate_removed_active_move()
    var next: MoveScript = get_move(id)
    if next == null or next == active_move:
        return false
    if _context == null:
        return false
    _context.intent = intent if intent != null else get_parent().get("desired")
    if not next.can_enter(_context):
        return false
    if active_move != null:
        if next.priority < active_move.priority or not active_move.can_exit(_context):
            return false
    _transition(next)
    return true


func tick(intent: IntentScript, delta: float) -> ContextScript:
    _invalidate_removed_active_move()
    _context.begin_tick(intent, delta)
    _resolve_default()
    if active_move != null:
        active_move.physics_update(_context, delta)
    if _context.move_finished:
        _resolve_default(true)
    return _context


func _resolve_default(force: bool = false) -> void:
    # Only grounded/airborne states auto-transition. Action bindings are
    # optional metadata and must not control how long a move remains active.
    if not force and active_move != null and active_id != grounded_move and active_id != airborne_move:
        return
    var fallback_id: StringName = grounded_move if _context.body.is_on_floor() else airborne_move
    var fallback: MoveScript = get_move(fallback_id)
    if fallback == null or fallback == active_move or not fallback.can_enter(_context):
        return
    _transition(fallback)


func _transition(next: MoveScript) -> void:
    var old: StringName = active_id
    if active_move != null:
        active_move.exit(_context)
    active_move = next
    active_id = next.move_id
    next.enter(_context)
    move_changed.emit(old, active_id)


## A live game can remove a move node without leaving a dangling FSM state.
func _invalidate_removed_active_move() -> void:
    if active_move != null and not is_instance_valid(active_move):
        var old: StringName = active_id
        active_move = null
        active_id = &""
        move_changed.emit(old, &"")


func cancel() -> void:
    if active_move != null and _context != null:
        active_move.exit(_context)
    var previous: StringName = active_id
    active_move = null
    active_id = &""
    if previous != &"":
        move_changed.emit(previous, &"")
