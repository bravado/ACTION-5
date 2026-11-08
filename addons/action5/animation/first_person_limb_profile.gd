extends Resource
class_name Action5FirstPersonLimbProfile
## An independently authored camera-space viewmodel clip. Not a bone mapping.
## The world Skeleton3D is still authoritative for world appearance/shadows;
## this resource frames the LOCAL player's view, separately from gameplay.
##
## New actions only add resources; the viewmodel presenter never branches
## on Punch, Kick, attack IDs, third-person bones or camera yaw.
const PoseKeyScript = preload("res://addons/action5/animation/first_person_pose_key.gd")

@export var animation_key: StringName = &""
@export var visible_at_rest: bool = false
@export var poses: Array[Resource] = []
## An optional artist-authored viewmodel scene implementing
## configure(profile) and apply_pose(progress). Omit for demo capsules.
@export var viewmodel_scene: PackedScene

@export_range(0.015, 0.15, 0.005) var upper_radius: float = 0.065
@export_range(0.015, 0.15, 0.005) var lower_radius: float = 0.055
@export var limb_color: Color = Color(0.12, 0.66, 0.76)
@export var extremity_color: Color = Color(0.82, 0.52, 0.31)
@export var extremity_size: Vector3 = Vector3(0.13, 0.12, 0.14)
@export var extremity_offset: Vector3 = Vector3.ZERO


func valid() -> bool:
    if animation_key == &"" or upper_radius <= 0.0 or lower_radius <= 0.0 \
        or extremity_size.x <= 0.0 or extremity_size.y <= 0.0 \
        or extremity_size.z <= 0.0 or poses.size() < 2:
        return false
    var previous: float = -0.1
    for resource in poses:
        var key: PoseKeyScript = resource as PoseKeyScript
        if key == null or not key.valid() or key.time <= previous:
            return false
        # Keep every demo pose away from the first-person near plane.
        if key.shoulder.z > -0.22 or key.joint.z > -0.22 \
            or key.extremity.z > -0.22:
            return false
        previous = key.time
    return absf((poses[0] as PoseKeyScript).time) < 0.0001 \
        and absf((poses[-1] as PoseKeyScript).time - 1.0) < 0.0001


## Pure interpolation: no shared Resource state changes at runtime.
## Progress is supplied by an external action clock, not an AnimationPlayer.
func sample(progress: float) -> Dictionary:
    if not valid():
        return {}
    var t: float = clampf(progress, 0.0, 1.0) if is_finite(progress) else 0.0
    var previous: PoseKeyScript = poses[0] as PoseKeyScript
    for i in range(1, poses.size()):
        var next: PoseKeyScript = poses[i] as PoseKeyScript
        if t <= next.time:
            var alpha: float = clampf((t - previous.time) / (next.time - previous.time), 0.0, 1.0)
            alpha = alpha * alpha * (3.0 - 2.0 * alpha)
            return {
                "shoulder": previous.shoulder.lerp(next.shoulder, alpha),
                "joint": previous.joint.lerp(next.joint, alpha),
                "extremity": previous.extremity.lerp(next.extremity, alpha),
                "extremity_rotation": previous.extremity_rotation.lerp(next.extremity_rotation, alpha),
            }
        previous = next
    return previous.as_pose()
