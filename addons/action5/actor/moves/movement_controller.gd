extends Node
class_name Action5MovementController
## Automatically registers child Action5Move components. It dispatches one
## exclusive move at a time and knows no concrete move types.

const MoveScript = preload("res://addons/action5/actor/moves/move.gd")
const ContextScript = preload("res://addons/action5/actor/moves/move_context.gd")
const IntentScript = preload("res://addons/action5/actor/move_intent.gd")

signal move_changed(previous: StringName, current: StringName)
signal move_registered(move: Node)
signal move_unregistered(move_id: StringName)

@export var grounded_move: StringName = &"grounded"
@export var airborne_move: StringName = &"airborne"

@onready var moves_root: Node = $Moves
var active_move: MoveScript
var active_id: StringName = &""

var _registry: Dictionary = {}
var _pending_requests: Array[StringName] = []
var _context: ContextScript
var _ready_for_moves: bool = false


func _ready() -> void:
    var body: CharacterBody3D = get_parent().get_parent() as CharacterBody3D
    if body == null:
        push_error("ACTION5: MovementController must live under Locomotion inside CharacterBody3D")
        return
    _context = ContextScript.new(body, get_parent())
    # Track the scene-tree lifecycle, not only object validity: remove_child()
    # leaves a perfectly valid Node that must no longer be an active move.
    moves_root.child_entered_tree.connect(_on_move_added)
    moves_root.child_exiting_tree.connect(_on_move_removed)
    _ready_for_moves = true
    for child in moves_root.get_children():
        _on_move_added(child)


func _on_move_added(child: Node) -> void:
    if child is MoveScript:
        register_move(child as MoveScript)


func _on_move_removed(child: Node) -> void:
    if not child is MoveScript:
        return
    # Look up by instance: a component's move_id may have changed after
    # registration, but its original registry entry must still be removed.
    for id in _registry.keys():
        if _registry[id] == child:
            unregister_move(id)
            return


func register_move(move: MoveScript) -> bool:
    if not is_instance_valid(move) or move.move_id == &"" or move.is_queued_for_deletion():
        push_warning("ACTION5: Move component must declare a valid move_id")
        return false
    if move.get_parent() != moves_root:
        push_warning("ACTION5: Registered moves must be children of Moves")
        return false
    if get_move(move.move_id) != null:
        push_warning("ACTION5: Duplicate move_id: " + str(move.move_id))
        return false
    _registry[move.move_id] = move
    move_registered.emit(move)
    return true


## Remove a registered ability without requiring its Node to be freed.
## Re-registering the same node is explicit; removing the child also
## unregisters it automatically.
func unregister_move(id: StringName) -> bool:
    if not _registry.has(id):
        return false
    _registry.erase(id)
    _pending_requests.erase(id)
    if active_id == id:
        if is_instance_valid(active_move) and _context != null:
            active_move.exit(_context)
        active_move = null
        active_id = &""
        move_changed.emit(id, &"")
    move_unregistered.emit(id)
    return true


## Runtime extension: add a new component with no Actor/solver edits.
func add_move(move: MoveScript) -> bool:
    if not is_instance_valid(move) or not _ready_for_moves or move.move_id == &"":
        return false
    if move.is_queued_for_deletion() or get_move(move.move_id) != null:
        return false
    # Reject duplicates BEFORE adding a child; failed extensions leave the
    # scene unchanged rather than creating orphan, unregistered move nodes.
    if move.get_parent() != null and move.get_parent() != moves_root:
        return false
    if move.get_parent() == null:
        moves_root.add_child(move)
        # child_entered_tree registers it exactly once.
        return get_move(move.move_id) == move
    return register_move(move)


func get_moves() -> Array[MoveScript]:
    var result: Array[MoveScript] = []
    for id in _registry.keys():
        var move: MoveScript = get_move(id)
        if move != null:
            result.append(move)
    return result


func get_move(id: StringName) -> MoveScript:
    if not _registry.has(id):
        return null
    var move: MoveScript = _registry[id]
    if not is_instance_valid(move):
        unregister_move(id)
        return null
    if move.get_parent() != moves_root or move.is_queued_for_deletion():
        unregister_move(id)
        return null
    return move


## Requests are accepted now, but eligibility and transitions are resolved
## in the next physics tick with a freshly initialized command context.
func request_move(id: StringName) -> bool:
    if _context == null or get_move(id) == null:
        return false
    if not _pending_requests.has(id):
        _pending_requests.append(id)
    return true


func tick(intent: IntentScript, delta: float) -> ContextScript:
    if active_move != null:
        get_move(active_id)  # Prune an unexpectedly detached or freed component.
    _context.begin_tick(intent, delta)

    # Drain once. Resolve all requests BEFORE changing states, so simultaneous
    # actions never produce intermediate enter/exit or move_changed events.
    # Requests queued during a transition are handled on the following tick.
    var requested: Array[StringName] = _pending_requests
    _pending_requests = []
    var winner: MoveScript = _select_requested_move(requested)
    if winner != null:
        _transition(winner)
    else:
        _resolve_default()

    if active_move != null:
        active_move.physics_update(_context, delta)
    if _context.move_finished:
        _resolve_default(true)
    return _context


## Choose one eligible request: highest priority, then lexicographically
## smallest registered move ID for ties. Neither input nor registration order
## affects the outcome. Losing requests are consumed without state changes.
func _select_requested_move(requested: Array[StringName]) -> MoveScript:
    var winner: MoveScript
    var winner_id: StringName = &""
    for id in requested:
        var candidate: MoveScript = get_move(id)
        if candidate == null or candidate == active_move:
            continue
        if active_move != null and candidate.priority < active_move.priority:
            continue
        if not candidate.can_enter(_context):
            continue
        if winner == null or candidate.priority > winner.priority or (
            candidate.priority == winner.priority and str(id) < str(winner_id)
        ):
            winner = candidate
            winner_id = id

    if winner != null and active_move != null and not active_move.can_exit(_context):
        return null
    return winner


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


func cancel() -> void:
    _pending_requests.clear()
    if active_move != null and _context != null:
        active_move.exit(_context)
    var previous: StringName = active_id
    active_move = null
    active_id = &""
    if previous != &"":
        move_changed.emit(previous, &"")
