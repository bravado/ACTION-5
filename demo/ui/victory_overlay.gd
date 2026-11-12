extends CanvasLayer
## Demo-only outcome screen. No new game state, persistence or actor clone.

@export var exit_path: NodePath = ^"../EncounterSector/ExitTerminal"
@export var session_path: NodePath = ^"../WorldSession"
@export var input_path: NodePath = ^"../ActorInput"

@onready var screen: Control = $Screen
@onready var restart_button: Button = $Screen/Center/Panel/Content/RestartButton
@onready var session: Node = get_node_or_null(session_path)
@onready var input_adapter: Node = get_node_or_null(input_path)

var _exit: Node


func _ready() -> void:
    screen.hide()
    restart_button.pressed.connect(restart)
    if is_instance_valid(session):
        session.sector_changed.connect(_on_sector_changed)
    _sync_exit()


func _sync_exit() -> void:
    var next_exit: Node = get_node_or_null(exit_path)
    if is_instance_valid(_exit) and _exit.has_signal("completed") \
            and _exit.is_connected("completed", _on_completed):
        _exit.disconnect("completed", _on_completed)
    _exit = next_exit
    if is_instance_valid(_exit) and _exit.has_signal("completed"):
        _exit.connect("completed", _on_completed)


func _on_sector_changed(_previous: StringName, _current: StringName) -> void:
    _sync_exit()


func _on_completed(_actor: Node3D) -> void:
    if screen.visible:
        return
    screen.show()
    if is_instance_valid(input_adapter) and input_adapter.has_method("set_enabled"):
        input_adapter.call("set_enabled", false)
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    restart_button.grab_focus()


func restart() -> void:
    if not screen.visible:
        return
    if get_tree().current_scene != null:
        var result: Error = get_tree().reload_current_scene()
        if result != OK:
            push_error("ACTION5: Restart could not reload the current scene (%d)" % result)


func _exit_tree() -> void:
    if is_instance_valid(_exit) and _exit.has_signal("completed") \
            and _exit.is_connected("completed", _on_completed):
        _exit.disconnect("completed", _on_completed)
    if is_instance_valid(session) and session.sector_changed.is_connected(_on_sector_changed):
        session.sector_changed.disconnect(_on_sector_changed)
