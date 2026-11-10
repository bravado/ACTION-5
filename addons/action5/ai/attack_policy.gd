extends Node
class_name Action5AIAttackPolicy
## A configured action choice, not an attack clock. D05 owns startup/active/
## recovery and D06 owns magazine/reload state. Override this policy node or
## duplicate its scene for a third archetype; core actor never changes.

@export var attack_id: StringName = &"punch"
@export_range(0.1, 100.0, 0.1) var maximum_range: float = 1.5
@export_range(0.0, 100.0, 0.1) var minimum_range: float = 0.0
@export var requires_equipment: bool = false
@export_range(-1, 7, 1) var equipment_action_index: int = -1


func in_range(distance: float) -> bool:
    return distance >= minimum_range and distance <= maximum_range


func request_action(combat: Node, equipment: Node, direction: Vector2) -> bool:
    if not is_instance_valid(combat) or not combat.has_method("request_attack") \
            or not direction.is_finite():
        return false
    # No AI-specific action timeline or buffering. The existing D05 request
    # port rejects conflicting same-tick calls, and snapshots this heading.
    if combat.get("current_attack") != null:
        return false
    var weapon: Node = null
    if is_instance_valid(equipment):
        weapon = equipment.get("current_weapon") as Node
    if requires_equipment and not is_instance_valid(weapon):
        return false
    if is_instance_valid(weapon) and weapon.has_method("get_ammo_status"):
        var ammo: Dictionary = weapon.call("get_ammo_status")
        if bool(ammo.get("reloading", false)):
            return false
        if int(ammo.get("magazine", 0)) == 0:
            if int(ammo.get("reserve", 0)) > 0 and weapon.has_method("get_command_bindings"):
                var commands: Array[Dictionary] = weapon.call("get_command_bindings")
                if not commands.is_empty() and weapon.has_method("request_weapon_command"):
                    weapon.call("request_weapon_command", commands[0].get("action", &""))
            return false
    if equipment_action_index >= 0:
        if not is_instance_valid(weapon) or not is_instance_valid(equipment) \
                or not equipment.has_method("request_equipped_action"):
            return false
        var definitions: Array[Resource] = weapon.call("get_attack_definitions")
        if equipment_action_index >= definitions.size() \
                or definitions[equipment_action_index].get("attack_id") != attack_id:
            return false
        return bool(equipment.call("request_equipped_action", equipment_action_index, direction))
    return bool(combat.call("request_attack", attack_id, direction))
