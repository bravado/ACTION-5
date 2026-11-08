extends RefCounted
class_name Action5ModelValidator
## Non-destructive validator for imported glTF/GLB actors. Use the same
## report for editor tooling, tests and the runtime fallback path.

const ProfileScript = preload("res://addons/action5/animation/skeleton_profile.gd")


static func find_skeleton(root: Node) -> Skeleton3D:
    if root is Skeleton3D:
        return root as Skeleton3D
    if root == null:
        return null
    for descendant in root.find_children("*", "Skeleton3D", true, false):
        return descendant as Skeleton3D
    return null


static func find_animation_player(root: Node) -> AnimationPlayer:
    if root is AnimationPlayer:
        return root as AnimationPlayer
    if root == null:
        return null
    for descendant in root.find_children("*", "AnimationPlayer", true, false):
        return descendant as AnimationPlayer
    return null


static func validate(root: Node, profile: ProfileScript) -> Dictionary:
    var errors: Array[String] = []
    var warnings: Array[String] = []
    if root == null or profile == null:
        errors.append("Model root and SkeletonProfile are required")
        return {"errors": errors, "warnings": warnings, "valid": false}

    var skeleton: Skeleton3D = find_skeleton(root)
    var player: AnimationPlayer = find_animation_player(root)
    if skeleton == null:
        errors.append("A Skeleton3D is required for skeletal animation")
    elif skeleton.get_bone_count() == 0:
        errors.append("Skeleton3D contains no bones")
    else:
        for socket in [&"right_hand", &"left_hand", &"head"]:
            var bone: StringName = profile.socket_bone(socket)
            if bone == &"" or skeleton.find_bone(str(bone)) < 0:
                warnings.append("Missing optional socket bone %s: %s" % [socket, bone])

    if player == null:
        errors.append("An AnimationPlayer with imported clips is required")
    else:
        for clip in profile.required_clips:
            var name: StringName = profile.clip_name(StringName(clip))
            if name == &"" or not player.has_animation(name):
                errors.append("Missing required clip %s mapped to %s" % [clip, name])
        for key in profile.clip_map.keys():
            var name: StringName = profile.clip_name(StringName(key))
            if name != &"" and not player.has_animation(name) and not profile.required_clips.has(str(key)):
                warnings.append("Optional clip %s mapped to %s is unavailable" % [key, name])

    return {"errors": errors, "warnings": warnings, "valid": errors.is_empty()}
