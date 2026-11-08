extends Resource
class_name Action5FirstPersonPoseKey
## An authored camera-space pose at a normalized action time (0..1).
## Positions are in metres relative to the viewmodel root; -Z is forward.
## These are view poses, never physics hitboxes or authoritative bone data.

@export_range(0.0, 1.0, 0.01) var time: float = 0.0
@export var shoulder: Vector3 = Vector3.ZERO
@export var joint: Vector3 = Vector3.ZERO
@export var extremity: Vector3 = Vector3.ZERO
@export var extremity_rotation: Vector3 = Vector3.ZERO


func valid() -> bool:
    return is_finite(time) and shoulder.is_finite() and joint.is_finite() \
        and extremity.is_finite() and extremity_rotation.is_finite() \
        and (joint - shoulder).length() > 0.06 \
        and (extremity - joint).length() > 0.06


func as_pose() -> Dictionary:
    return {
        "shoulder": shoulder,
        "joint": joint,
        "extremity": extremity,
        "extremity_rotation": extremity_rotation
    }
