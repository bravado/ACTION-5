extends Node3D
class_name Action5FirstPersonWeaponViewmodel
## A render-only, camera-space hand + held weapon. Reuses authored D05
## shoulder/elbow/grip pose profiles without reading world skeleton bones.
## The Grip child is moved WITH the hand, never animated independently.
## World weapon/socket remains authoritative for hitboxes and shadows.

const ProfileScript = preload("res://addons/action5/animation/first_person_limb_profile.gd")
const GeometryScript = preload("res://addons/action5/animation/first_person_limb_geometry.gd")

@export var grip_profile: ProfileScript
## Optional additional authored poses, selected by visual_action_key.
## Without entries this behaves exactly like the original single-clip model.
@export var action_profiles: Array[Resource] = []
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
    # Backwards compatible single-profile rendering used by Shovel and
    # by authored viewmodels that do not have secondary visual actions.
    _apply_profile(grip_profile, progress)


## Visual-action key comes from the independent CombatVisualState snapshot.
## This only changes the camera-local arm/grip shape; damage, input, timing
## and the world weapon remain owned by their original components.
func apply_action_pose(action_key: StringName, progress: float) -> void:
    var selected: ProfileScript = grip_profile
    for candidate in action_profiles:
        var option := candidate as ProfileScript
        if option != null and option.animation_key == action_key and option.valid():
            selected = option
            break
    _apply_profile(selected, progress)


func _apply_profile(selected: ProfileScript, progress: float) -> void:
    if not is_instance_valid(arm) or not is_instance_valid(grip) or selected == null:
        return
    pose_progress = clampf(progress, 0.0, 1.0)
    # Reusing the same geometry preserves the single attached arm and Grip:
    # switching actions must not instantiate a second hand or weapon.
    arm.profile = selected
    arm.apply_pose(pose_progress)
    grip.transform = arm.extremity.transform
