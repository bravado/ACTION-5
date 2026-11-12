extends Node
## Demo-only visual-origin adapter. The hitscan and damage still originate
## from the physical Gun/Muzzle; only the temporary projectile is recentered.
## The F4 viewmodel keeps ownership of its camera-local visual muzzle.
const ViewProfileScript = preload("res://addons/action5/camera/view_profile.gd")

@export var view_manager_path: NodePath = ^"../../ViewManager"
@export var first_person_visual_path: NodePath = ^"../EquipmentVisualAdapter"

@onready var views: Node = get_node_or_null(view_manager_path)
@onready var first_person_visual: Node = get_node_or_null(first_person_visual_path)


func get_projectile_visual_origin(weapon: Node3D, world_muzzle: Vector3) -> Vector3:
    if not is_instance_valid(weapon) or not world_muzzle.is_finite():
        return world_muzzle
    var actor := get_parent() as Node3D
    var owner: Node = weapon.get("equipment_owner") as Node
    if actor != null and is_instance_valid(owner) and owner.get_parent() == actor \
            and is_instance_valid(views) and views.get("current_profile") != null \
            and int(views.get("current_profile").get("mode")) == ViewProfileScript.Mode.RETRO_TOPDOWN:
        # Screen-horizontal center is the actor's X/Z center in the fixed
        # overhead projection. Retain the real muzzle's height for the tracer.
        return Vector3(actor.global_position.x, world_muzzle.y, actor.global_position.z)
    if is_instance_valid(first_person_visual) \
            and first_person_visual.has_method("get_projectile_visual_origin"):
        return first_person_visual.call("get_projectile_visual_origin", weapon, world_muzzle)
    return world_muzzle
