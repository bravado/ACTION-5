extends Node3D
## Camera-independent, physically authoritative opening. A normal door can
## hide its panel when opened; a two-sided world passage keeps its frame
## visible and hides only its barrier. This component knows nothing about
## sectors, teleporting, input, actors' inventories or camera modes.

signal state_changed(open: bool, locked: bool)

@export var initially_open: bool = false
@export var locked: bool = false
@export var required_actor_group: StringName = &""
@export var collision_path: NodePath = ^"Body/CollisionShape3D"
@export var visual_path: NodePath = ^"DoorMesh"
@export var navigation_link_path: NodePath = ^"NavigationLink3D"
@export var barrier_visual_path: NodePath
## Preserve an opening's visible frame independently of the barrier.
@export var keep_visual_when_open: bool = false

var open: bool = false
@onready var collision: CollisionShape3D = get_node_or_null(collision_path) as CollisionShape3D
@onready var visual: Node3D = get_node_or_null(visual_path) as Node3D
@onready var navigation_link: NavigationLink3D = get_node_or_null(navigation_link_path) as NavigationLink3D
@onready var barrier_visual: Node3D = get_node_or_null(barrier_visual_path) as Node3D


func _ready() -> void:
    add_to_group("action5_interactable")
    set_open(initially_open and not locked)


func can_interact(actor: Node3D) -> bool:
    return is_instance_valid(actor) and not locked and (
        required_actor_group == &"" or actor.is_in_group(required_actor_group)
    )


func interact(actor: Node3D) -> bool:
    if not can_interact(actor):
        return false
    set_open(not open)
    return true


func set_open(value: bool) -> void:
    open = value and not locked
    if is_instance_valid(collision):
        collision.set_deferred("disabled", open)
    if is_instance_valid(navigation_link):
        navigation_link.enabled = open
    if is_instance_valid(visual):
        visual.visible = keep_visual_when_open or not open
    if is_instance_valid(barrier_visual):
        barrier_visual.visible = not open
    state_changed.emit(open, locked)


func set_locked(value: bool) -> void:
    locked = value
    if locked:
        set_open(false)
    else:
        state_changed.emit(open, locked)
