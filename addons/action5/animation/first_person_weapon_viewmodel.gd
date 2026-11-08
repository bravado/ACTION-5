extends Node3D
class_name Action5FirstPersonWeaponViewmodel
## A render-only, camera-space hand + held weapon. Reuses authored D05
## shoulder/elbow/grip pose profiles without reading world skeleton bones.
## The Grip child is moved WITH the hand, never animated independently.
## World weapon/socket remains authoritative for hitboxes and shadows.

const ProfileScript = preload("res://addons/action5/animation/first_person_limb_profile.gd")
const GeometryScript = preload("res://addons/action5/animation/first_person_limb_geometry.gd")

@export var grip_profile: ProfileScript
@export var grip_path: NodePath = ^"Grip"

var arm: GeometryScript
var grip: Node3D
var pose_progress: float = 0.0


func _ready() -> void:
    grip = get_node_or_null(grip_path) as Node3D
    if grip == null or grip_profile == null or not grip_profile.valid():
        push_warning("ACTION5: first-person weapon viewmodel needs a valid authored grip")
        return
    arm = GeometryScript.new()
    arm.name = "EquippedArm"
    add_child(arm)
    arm.configure(grip_profile)
    apply_pose(0.0)


func apply_pose(progress: float) -> void:
    if not is_instance_valid(arm) or not is_instance_valid(grip):
        return
    pose_progress = clampf(progress, 0.0, 1.0)
    arm.apply_pose(pose_progress)
    grip.transform = arm.extremity.transform
