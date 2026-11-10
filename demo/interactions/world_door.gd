extends Node3D
## State drives BOTH world collision and the navigation link. Visuals
## follow state; disabling/hiding a roof or changing views never opens it.

signal state_changed(open: bool, locked: bool)

@export var initially_open: bool = false
@export var locked: bool = false
@export var required_actor_group: StringName = &""
@export_enum("Restore previous", "Start fresh") var dungeon_entry_policy: int = 0
@export_enum("Restore previous", "Start fresh") var arena_entry_policy: int = 0
@export var collision_path: NodePath = ^"Body/CollisionShape3D"
@export var visual_path: NodePath = ^"DoorMesh"
@export var navigation_link_path: NodePath = ^"NavigationLink3D"

var open: bool = false
@onready var collision: CollisionShape3D = get_node_or_null(collision_path) as CollisionShape3D
@onready var visual: Node3D = get_node_or_null(visual_path) as Node3D
@onready var navigation_link: NavigationLink3D = get_node_or_null(navigation_link_path) as NavigationLink3D


func _ready() -> void:
    add_to_group("action5_interactable")
    set_open(initially_open and not locked)


func can_interact(actor: Node3D) -> bool:
    return is_instance_valid(actor) and not locked and         (required_actor_group == &"" or actor.is_in_group(required_actor_group))


func interact(actor: Node3D) -> bool:
    if not can_interact(actor):
        return false
    set_open(not open)
    return true


func set_open(value: bool) -> void:
    var next_value: bool = value and not locked
    open = next_value
    if is_instance_valid(collision):
        collision.set_deferred("disabled", open)
    if is_instance_valid(navigation_link):
        navigation_link.enabled = open
    if is_instance_valid(visual):
        visual.visible = not open
    state_changed.emit(open, locked)


func set_locked(value: bool) -> void:
    locked = value
    if locked:
        set_open(false)
    else:
        state_changed.emit(open, locked)
