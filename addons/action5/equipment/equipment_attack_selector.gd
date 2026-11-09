extends Node
class_name Action5EquipmentAttackSelector
## Per-input action selection, independent of equipment lifecycle or input.
## A weapon's AttackDefinition.input_action explicitly claims an InputMap
## action (actor_punch, actor_kick or another configured action). Unclaimed
## actions retain the ordinary unarmed definition. No weapon-ID branches.

@export var equipment_path: NodePath = ^"../Equipment"

@onready var equipment: Node = get_node_or_null(equipment_path)


func get_attack_for_input(input_action: StringName, fallback: Resource) -> Resource:
    if not is_instance_valid(equipment):
        return fallback
    var weapon: Node = equipment.get("current_weapon") as Node
    if not is_instance_valid(weapon) or not weapon.has_method("get_attack_for_input"):
        return fallback
    var assigned: Resource = weapon.call("get_attack_for_input", input_action) as Resource
    return assigned if assigned != null else fallback
