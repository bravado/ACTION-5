extends Node
class_name Action5EquipmentAttackSelector
## Input-to-action policy, separate from combat execution and inventory.
## Both attack buttons select equipped action slots. A one-action weapon
## serves either button; a two-action weapon may configure an alternate.
## No equipment/weapon ID branching is allowed in CombatInputAdapter.

@export var equipment_path: NodePath = ^"../Equipment"
@export var input_actions: Array[StringName] = [&"actor_punch", &"actor_kick"]

@onready var equipment: Node = get_node_or_null(equipment_path)


func get_attack_for_input(input_action: StringName, fallback: Resource) -> Resource:
    if not is_instance_valid(equipment):
        return fallback
    var index: int = input_actions.find(input_action)
    if index < 0:
        return fallback
    var weapon: Node = equipment.get("current_weapon") as Node
    if not is_instance_valid(weapon):
        return fallback
    if not weapon.has_method("get_attack_definitions"):
        return null
    var attacks: Array = weapon.call("get_attack_definitions")
    if attacks.is_empty():
        # An equipped but non-attacking item must not leak an unarmed hit.
        return null
    return attacks[mini(index, attacks.size() - 1)] as Resource
