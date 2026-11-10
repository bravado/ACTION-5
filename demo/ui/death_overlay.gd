extends CanvasLayer
## Read-only Health observer. Restart acts on the current SceneTree scene;
## Health, Actor, Combat and Camera know nothing about this UI.

const HealthScript = preload("res://addons/action5/combat/health.gd")

@export var health_path: NodePath = ^"../Player/Health"

@onready var screen: Control = $Screen
@onready var restart_button: Button = $Screen/Center/Panel/Content/RestartButton

var health: HealthScript


func _ready() -> void:
    screen.hide()
    restart_button.pressed.connect(restart)
    health = get_node_or_null(health_path) as HealthScript
    if health == null:
        push_warning("ACTION5: DeathOverlay needs a player Health node")
        return
    health.died.connect(_on_died)
    if health.current_health <= 0.0:
        _on_died(null)


func _on_died(_source: Node) -> void:
    if screen.visible:
        return
    screen.show()
    # First-person mouse capture must not trap the restart button.
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
    if is_instance_valid(health) and health.died.is_connected(_on_died):
        health.died.disconnect(_on_died)
