extends Node3D
## Optional, weapon-local interaction port. The generic Interactor checks
## distance, active scene and actual physics LoS; Equipment owns inventory.
## Prefab children remain attached to authored, spawned and dropped weapons.

@onready var weapon: Node3D = get_parent() as Node3D


func _ready() -> void:
    add_to_group("action5_interactable")


func can_interact(actor: Node3D) -> bool:
    return is_instance_valid(weapon) and weapon.is_inside_tree() \
        and not weapon.is_queued_for_deletion() and weapon.is_visible_in_tree() \
        and weapon.get("equipment_owner") == null and not bool(weapon.get("is_equipped")) \
        and is_instance_valid(actor) and _equipment_can_pickup(actor)


func _equipment_can_pickup(actor: Node3D) -> bool:
    var equipment: Node = actor.get_node_or_null("Equipment")
    return is_instance_valid(equipment) and equipment.has_method("can_pickup") \
        and bool(equipment.call("can_pickup", weapon))


func get_interaction_label(_actor: Node3D) -> String:
    var definition: Resource = weapon.get("definition") as Resource if is_instance_valid(weapon) else null
    return "Pick up " + (str(definition.get("display_name")) if definition != null else "item")


func interact(actor: Node3D) -> bool:
    if not can_interact(actor):
        return false
    return bool(actor.get_node("Equipment").call("pickup", weapon))
