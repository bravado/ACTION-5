extends Node
## Demo-only configuration of an enemy's starting weapon. Equipment owns
## the instance after pickup; no AI-specific inventory, attack or ammo state.

@export var weapon_scene: PackedScene


func _ready() -> void:
    call_deferred("_equip_initial_weapon")


func _equip_initial_weapon() -> void:
    var actor := get_parent() as Node3D
    var equipment := actor.get_node_or_null("Equipment") if is_instance_valid(actor) else null
    if weapon_scene == null or not is_instance_valid(equipment):
        return
    var weapon := weapon_scene.instantiate() as Node3D
    if weapon == null:
        return
    # A normal world pickup is the only allowed ownership transfer.
    var parent := actor.get_parent() as Node3D
    if parent == null:
        weapon.free()
        return
    parent.add_child(weapon)
    weapon.global_position = actor.global_position
    if not bool(equipment.call("pickup", weapon)):
        weapon.queue_free()
