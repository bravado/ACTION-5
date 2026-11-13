extends Node3D
## The D09 objective is a scene-authored interactable, not a gameplay core
## rule. The existing Interactor supplies range, LoS and actor validation.

signal objective_changed
signal completed(actor: Node3D)

@export var player_path: NodePath = ^"../../Player"
@export var session_path: NodePath = ^"../../WorldSession"

@onready var player: Node3D = get_node_or_null(player_path) as Node3D
@onready var session: Node = get_node_or_null(session_path)
@onready var label: Label3D = $Label3D

var complete: bool = false


func _ready() -> void:
    for enemy in get_parent().get_children():
        if not enemy.is_in_group("action5_enemy"):
            continue
        var health: Node = enemy.get_node_or_null("Health")
        if is_instance_valid(health):
            health.died.connect(_on_enemy_died)
    _refresh_label()


func is_unlocked() -> bool:
    for enemy in get_parent().get_children():
        if not enemy.is_in_group("action5_enemy"):
            continue
        var health: Node = enemy.get_node_or_null("Health")
        if bool(enemy.get("alive")) and (not is_instance_valid(health)
                or float(health.get("current_health")) > 0.0):
            return false
    return true


func can_interact(actor: Node3D) -> bool:
    return not complete and actor == player and is_instance_valid(session) \
        and session.get("current_sector") == &"encounter" \
        and bool(actor.get("alive")) and is_unlocked()


func get_interaction_point(_actor: Node3D) -> Vector3:
    return global_position + Vector3(0, 1.0, 0)


func get_interaction_label(_actor: Node3D) -> String:
    return "Complete encounter"


func interact(actor: Node3D) -> bool:
    if not can_interact(actor):
        return false
    complete = true
    _refresh_label()
    objective_changed.emit()
    completed.emit(actor)
    return true


func _on_enemy_died(_source: Node) -> void:
    # Health emits died before all actor subscribers have processed it.
    call_deferred("_notify_objective")


func _notify_objective() -> void:
    if not is_inside_tree():
        return
    _refresh_label()
    objective_changed.emit()


func _refresh_label() -> void:
    if is_instance_valid(label):
        label.text = ("COMPLETE" if complete else
            "EXIT [E]" if is_unlocked() else "EXIT · DEFEAT ENEMIES")
