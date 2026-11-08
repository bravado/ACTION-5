extends Node
class_name Action5EyeHeightPresenter
## Optional actor-local camera presentation. Observes move IDs only;
## movement abilities and the CameraRig never reference one another.

@export var movement_controller_path: NodePath = ^"../Locomotion/MovementController"
@export var eye_offset_path: NodePath = ^"../EyeOffset"
## Configure movement IDs as string keys and additive eye-height offsets.
## Unknown states use zero, so new movement types need no core changes.
@export var move_offsets: Dictionary = {}
@export_range(0.0, 30.0, 0.5) var follow_speed: float = 12.0

var target_offset_y: float = 0.0
var _controller: Node
var _eye_offset: Node3D
var _original_y: float = 0.0


func _init() -> void:
    # Update before CameraRig's default-priority visual _process.
    process_priority = -10


func _ready() -> void:
    _eye_offset = get_node_or_null(eye_offset_path) as Node3D
    if _eye_offset == null:
        push_warning("ACTION5: EyeHeightPresenter requires an EyeOffset Node3D")
        set_process(false)
        return
    _original_y = _eye_offset.position.y
    _controller = get_node_or_null(movement_controller_path)
    if _controller == null or not _controller.has_signal("move_changed"):
        push_warning("ACTION5: EyeHeightPresenter requires move_changed")
        set_process(false)
        return
    _controller.move_changed.connect(_on_move_changed)
    # Presenters attached to an already-moving actor must reflect its state.
    var active_id: StringName = _controller.get("active_id")
    target_offset_y = _offset_for(active_id)
    if not is_zero_approx(target_offset_y):
        _eye_offset.position.y = _original_y + target_offset_y


func _offset_for(id: StringName) -> float:
    var configured: Variant = move_offsets.get(str(id), move_offsets.get(id, 0.0))
    if configured is float or configured is int:
        return float(configured)
    return 0.0


func _on_move_changed(_previous: StringName, current: StringName) -> void:
    # Crouch idle -> crouch walk retains the same configured eye target.
    target_offset_y = _offset_for(current)


func _process(delta: float) -> void:
    if not is_instance_valid(_eye_offset):
        set_process(false)
        return
    var desired_y: float = _original_y + target_offset_y
    var alpha: float = 1.0 if follow_speed <= 0.0 else (
        1.0 - exp(-follow_speed * maxf(delta, 0.0))
    )
    _eye_offset.position.y = lerpf(_eye_offset.position.y, desired_y, alpha)


func _exit_tree() -> void:
    if is_instance_valid(_controller):
        var callback := Callable(self, "_on_move_changed")
        if _controller.move_changed.is_connected(callback):
            _controller.move_changed.disconnect(callback)
    if is_instance_valid(_eye_offset):
        _eye_offset.position.y = _original_y
    target_offset_y = 0.0
    _controller = null
    _eye_offset = null
