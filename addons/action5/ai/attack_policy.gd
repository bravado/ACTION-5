extends Node
class_name Action5AIAttackPolicy
## Attack choice only. D05 owns attack time, D06 owns reload time.
## Resolve equipment by its configured attack ID, never an array position.

@export var attack_id: StringName = &"punch"
@export_range(0.1, 100.0, 0.1) var maximum_range: float = 1.5
@export_range(0.0, 100.0, 0.1) var minimum_range: float = 0.0
@export var requires_equipment: bool = false
@export var reload_command: StringName = &""


func in_range(distance: float) -> bool:
    return distance >= minimum_range and distance <= maximum_range


func request_action(combat: Node, equipment: Node, direction: Vector2) -> bool:
    if not is_instance_valid(combat) or not combat.has_method("request_attack") \
            or not direction.is_finite():
        return false
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
        if int(ammo.get("magazine", 0)) <= 0:
            if int(ammo.get("reserve", 0)) > 0 and reload_command != &"" \
                    and weapon.has_method("request_weapon_command"):
                weapon.call("request_weapon_command", reload_command)
            return false

    if not requires_equipment:
        return bool(combat.call("request_attack", attack_id, direction))
    if not is_instance_valid(weapon) or not is_instance_valid(equipment) \
            or not weapon.has_method("get_attack_definitions") \
            or not equipment.has_method("request_equipped_action"):
        return false
    var definitions: Array[Resource] = weapon.call("get_attack_definitions")
    for index in range(definitions.size()):
        if definitions[index] != null and definitions[index].get("attack_id") == attack_id:
            return bool(equipment.call("request_equipped_action", index, direction))
    return false
