extends Resource
class_name Action5SkeletonProfile
## Import-profile mapping. Change this resource when replacing the .glb rig.
## Gameplay and the animation presenter never depend on source bone names.

@export var right_hand_bone: StringName = &"Hand_R"
@export var left_hand_bone: StringName = &"Hand_L"
@export var head_bone: StringName = &"Head"
## First animated upper-body bone. Descendants receive action overlays;
## the hips and legs remain driven by locomotion.
@export var upper_body_root_bone: StringName = &"Spine"
## Generic locomotion fallback: only Idle is universally required.
## Actions, reactions, equipment and extra locomotion clips belong to
## scene-specific profiles, never the shared skeleton contract.
@export var clip_map: Dictionary = {
    "idle": "idle",
    "walk": "walk",
    "run": "run",
}
@export var required_clips: PackedStringArray = PackedStringArray(["idle"])


func clip_name(key: StringName) -> StringName:
    return StringName(str(clip_map.get(str(key), "")))


func socket_bone(key: StringName) -> StringName:
    match key:
        &"right_hand":
            return right_hand_bone
        &"left_hand":
            return left_hand_bone
        &"head":
            return head_bone
    return &""
