extends Node3D
## Optional, weapon-local interaction port. The generic Interactor checks
## distance, active scene and actual physics LoS; Equipment owns inventory.
## Prefab children remain attached to authored, spawned and dropped weapons.

const WeaponScript = preload("res://addons/action5/equipment/weapon.gd")

@onready var weapon: WeaponScript = get_parent() as WeaponScript


func _ready() -> void:
    add_to_group("action5_interactable")


func can_interact(actor: Node3D) -> bool:
    if not is_instance_valid(actor) or not is_instance_valid(weapon) \
            or not weapon.is_inside_tree() or weapon.is_queued_for_deletion() \
            or not weapon.is_visible_in_tree():
        return false
    # The interaction adds visibility, but Equipment owns every gameplay
    # eligibility condition (capacity, range, owner, attack IDs, mount).
    var equipment: Node = actor.get_node_or_null("Equipment")
    return is_instance_valid(equipment) and equipment.has_method("can_pickup") \
        and bool(equipment.call("can_pickup", weapon))


func get_interaction_label(_actor: Node3D) -> String:
    var definition: Resource = weapon.definition if is_instance_valid(weapon) else null
    return "Pick up " + (str(definition.get("display_name")) if definition != null else "item")


func interact(actor: Node3D) -> bool:
    if not can_interact(actor):
        return false
    return bool(actor.get_node("Equipment").call("pickup", weapon))
