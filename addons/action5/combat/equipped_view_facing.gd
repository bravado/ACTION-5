extends Node
class_name Action5EquippedViewFacing
## Same optional actor-local policy for melee headings and gun target selection.
const PolicyScript = preload("res://addons/action5/combat/view_facing_policy.gd")
@export var equipment_path: NodePath = ^"../Equipment"
@onready var equipment: Node = get_node_or_null(equipment_path)

func get_sectors(view_mode: int, fallback: int = 0) -> int:
    if not is_instance_valid(equipment):
        return fallback
    var weapon: Node = equipment.get("current_weapon") as Node
    if not is_instance_valid(weapon):
        return fallback
    var definition: Resource = weapon.get("definition") as Resource
    if definition == null:
        return fallback
    for candidate in definition.get("view_facing_policies"):
        var policy := candidate as PolicyScript
        if policy != null and policy.valid() and policy.view_mode == view_mode:
            return policy.sector_count
    return fallback
