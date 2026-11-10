extends Node
## Scene-local input adapter for E / Q / G. One actor's Equipment owns every
## inventory mutation; the input layer never knows weapon types. Standalone
## encounters and persistent-world demos share the same input boundary.

@export var actor_path: NodePath = ^"../Player"
@export var interaction_path: NodePath = ^"../InteractionInput"
@export var handle_input: bool = true
@export var include_pickup: bool = true

@onready var actor: Node3D = get_node_or_null(actor_path) as Node3D
@onready var interaction: Node = get_node_or_null(interaction_path)


func _unhandled_input(event: InputEvent) -> void:
    if not handle_input or not event is InputEventKey or not event.pressed             or event.echo:
        return
    if try_key(event.keycode):
        get_viewport().set_input_as_handled()


func try_key(keycode: Key) -> bool:
    if not is_instance_valid(actor) or not bool(actor.get("alive")):
        return false
    var equipment: Node = actor.get_node_or_null("Equipment")
    if equipment == null:
        return false
    match keycode:
        KEY_E:
            if include_pickup and _pickup_closest(equipment):
                return true
            return interaction != null and interaction.has_method("try_interact")                 and bool(interaction.call("try_interact"))
        KEY_Q:
            return bool(equipment.call("swap_next"))
        KEY_G:
            return bool(equipment.call("drop_current"))
    return false


func _pickup_closest(equipment: Node) -> bool:
    var world: Node = actor.get_parent()
    var closest: Node3D
    var limit: float = float(equipment.get("pickup_radius"))
    for entry in get_tree().get_nodes_in_group(&"action5_weapon_pickup"):
        var weapon := entry as Node3D
        if weapon == null or not world.is_ancestor_of(weapon)                 or bool(weapon.get("is_equipped"))                 or weapon.get("equipment_owner") != null:
            continue
        var distance: float = weapon.global_position.distance_to(actor.global_position)
        if distance <= limit:
            limit = distance
            closest = weapon
    return closest != null and bool(equipment.call("pickup", closest))
