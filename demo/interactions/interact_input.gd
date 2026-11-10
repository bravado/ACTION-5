extends Node
## Demo-only spatial interaction resolver. Main already owns the E-key
## input boundary for pickups; it delegates here when no pickup claimed E.
## Actor, Door, Locomotion and Combat never poll raw input.

@export var actor_path: NodePath = ^"../Player"
## Only the encounter enables standalone E input. Main already owns E for
## pickups and delegates unclaimed presses to try_interact().
@export var handle_input: bool = false
@export var interactable_group: StringName = &"action5_interactable"

@onready var actor: Node3D = get_node_or_null(actor_path) as Node3D


func _unhandled_input(event: InputEvent) -> void:
    if not handle_input or not event is InputEventKey or not event.pressed \
            or event.echo or event.keycode != KEY_E:
        return
    if try_interact():
        get_viewport().set_input_as_handled()


func try_interact() -> bool:
    if not is_instance_valid(actor):
        return false
    var closest: Node3D
    var closest_distance: float = INF
    for candidate in get_tree().get_nodes_in_group(interactable_group):
        var item := candidate as Node3D
        # Group membership is global. Only interact with doors in this
        # adapter\'s world, never a second instanced level in the tree.
        if item == null or not get_parent().is_ancestor_of(item) \
                or not item.has_method("can_interact") \
                or not bool(item.call("can_interact", actor)):
            continue
        var distance: float = actor.global_position.distance_squared_to(item.global_position)
        if distance < closest_distance:
            closest_distance = distance
            closest = item
    return closest != null and bool(closest.call("interact", actor))
