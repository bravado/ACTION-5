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
## Optional weapon-authored direction overrides by view.
@export var view_facing_policies: Array[Resource] = []
@export var first_person_scene: PackedScene


func valid() -> bool:
    if weapon_id == &"" or socket_id == &"":
        return false
    var assigned_inputs: Dictionary = {}
    for attack in attacks:
        if attack == null or not attack.has_method("valid") or not attack.call("valid"):
            return false
        var input_action: StringName = attack.get("input_action")
        if input_action != &"":
            if assigned_inputs.has(input_action):
                return false
            assigned_inputs[input_action] = true
    return true
