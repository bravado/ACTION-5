extends Node3D
## Explicit remote connection: one generic component, two destinations.
## Marker: move the same player elsewhere within the existing world.
## PackedScene: load a detached environment and move that same player to
## its arrival Marker3D. This component never opens a physical barrier,
## changes camera mode, touches inventory or calls change_scene_to_packed.

@export var location_manager_path: NodePath = ^"../LocationManager"
@export_enum("Marker in world", "Detached PackedScene") var destination_mode: int = 0
@export var destination_marker_path: NodePath
@export var destination_scene: PackedScene
@export var arrival_marker_path: NodePath = ^"Arrival"

@onready var manager: Node = get_node_or_null(location_manager_path)


func _ready() -> void:
    add_to_group("action5_interactable")


func can_interact(actor: Node3D) -> bool:
    if not is_instance_valid(manager) or not manager.has_method("can_travel") \
            or not bool(manager.call("can_travel", actor)):
        return false
    if destination_mode == 0:
        return get_node_or_null(destination_marker_path) is Marker3D
    return destination_scene != null and not destination_scene.resource_path.is_empty()


func interact(actor: Node3D) -> bool:
    if not can_interact(actor):
        return false
    if destination_mode == 0:
        return bool(manager.call("travel_to_marker", actor,
            get_node(destination_marker_path) as Marker3D))
    return bool(manager.call("travel_to_scene", actor,
        destination_scene, arrival_marker_path))
