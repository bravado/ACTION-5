extends Node
class_name Action5HealthActorAdapter
## Optional, actor-local integration. Health owns only HP, rules and events;
## this node translates its events into host lifecycle and motion commands.
## It is safe to omit for stationary targets or non-actor damage receivers.

const HealthScript = preload("res://addons/action5/combat/health.gd")

@export var health_path: NodePath = ^"../Health"
@export var actor_path: NodePath = ^".."
@export var locomotion_path: NodePath = ^"../Locomotion"

@onready var health: HealthScript = get_node_or_null(health_path) as HealthScript
## Duck-typed destinations: neither Health nor this bridge modifies a
## CharacterBody3D velocity or imports concrete actor/movement classes.
@onready var actor: Node = get_node_or_null(actor_path)
@onready var locomotion: Node = get_node_or_null(locomotion_path)


func _ready() -> void:
    if health == null:
        push_warning("ACTION5: HealthActorAdapter has no Health source")
        return
    health.knockback_requested.connect(_on_knockback_requested)
    health.died.connect(_on_died)


func _on_knockback_requested(world_velocity: Vector2, duration_ticks: int) -> void:
    if is_instance_valid(locomotion) and locomotion.has_method("apply_external_impulse"):
        locomotion.call("apply_external_impulse", world_velocity, duration_ticks)


func _on_died(_source: Node) -> void:
    if is_instance_valid(actor) and actor.has_method("set_alive"):
        actor.call("set_alive", false)


func _exit_tree() -> void:
    if not is_instance_valid(health):
        return
    if health.knockback_requested.is_connected(_on_knockback_requested):
        health.knockback_requested.disconnect(_on_knockback_requested)
    if health.died.is_connected(_on_died):
        health.died.disconnect(_on_died)
