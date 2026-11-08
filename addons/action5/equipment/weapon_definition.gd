extends Resource
class_name Action5WeaponDefinition
## Immutable configuration shared between pickups and equipped instances.
## Never store ammo, cooldowns or equip state in this Resource.

@export var weapon_id: StringName = &""
@export var display_name: String = ""
@export var socket_id: StringName = &"right_hand"
@export var grip_position: Vector3 = Vector3.ZERO
@export var grip_rotation_degrees: Vector3 = Vector3.ZERO
@export var attacks: Array[Resource] = []
@export var first_person_scene: PackedScene


func valid() -> bool:
    if weapon_id == &"" or socket_id == &"":
        return false
    for attack in attacks:
        if attack == null or not attack.has_method("valid") or not attack.call("valid"):
            return false
    return true
