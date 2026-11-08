extends Node3D
class_name Action5Weapon
## One physical weapon instance, whether lying in the world, stowed or held.
## The weapon owns its definition and any future per-instance behavior.
## There is never a second FPS-only gameplay weapon.

const DefinitionScript = preload("res://addons/action5/equipment/weapon_definition.gd")

@export var definition: DefinitionScript
var is_equipped: bool = false


func get_attack_definitions() -> Array[Resource]:
    return definition.attacks if definition != null else []


func get_world_meshes() -> Array[MeshInstance3D]:
    var result: Array[MeshInstance3D] = []
    for node in find_children("*", "MeshInstance3D", true, false):
        var mesh := node as MeshInstance3D
        if not mesh.is_queued_for_deletion() and (
            mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
        ):
            result.append(mesh)
    return result


## Only the equipped instance may request its own configured attack.
## No raw input, camera access or attack-name dispatch belongs here.
func request_action(index: int, direction: Vector2, combat: Node) -> bool:
    if not is_equipped or definition == null or index < 0 or index >= definition.attacks.size():
        return false
    if not is_instance_valid(combat) or not combat.has_method("request_attack"):
        return false
    if not direction.is_finite():
        return false
    var attack: Resource = definition.attacks[index]
    return bool(combat.call("request_attack", attack.get("attack_id"), direction))
