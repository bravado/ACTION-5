extends RefCounted
## Assert imported joint/pose geometry for D05; compilation alone cannot
## tell whether a kick looks like a raised straight leg or a real chamber.

const ValidatorScript = preload("res://addons/action5/animation/model_validator.gd")
const CombatScript = preload("res://addons/action5/combat/combat_controller.gd")


## Godot re-samples glTF 7-pose clips on import (9/11 keys at 30 Hz).
## Test the pose at *authored normalized times*, not imported key indices.
func _bone_angle_x(animation: Animation, bone: String, fraction: float) -> float:
    for track in range(animation.get_track_count()):
        var path: NodePath = animation.track_get_path(track)
        if path.get_subname_count() < 1 or str(path.get_subname(0)) != bone:
            continue
        if animation.track_get_type(track) == Animation.TYPE_ROTATION_3D:
            var rotation: Quaternion = animation.rotation_track_interpolate(
                track, animation.length * fraction)
            return rotation.get_euler().x
    return NAN


func run_tests(level: Node3D, verify: Callable) -> void:
    var actor: Node3D = level.get_node("Player")
    var model: Node = actor.get_node("Visual/Model")
    var skeleton: Skeleton3D = ValidatorScript.find_skeleton(model)
    var clips: AnimationPlayer = ValidatorScript.find_animation_player(model)
    var combat: CombatScript = actor.get_node("CombatController") as CombatScript
    verify.call(skeleton != null and clips != null and combat != null,
        "D05 rig, imported clips and combat controller are available")
    if skeleton == null or clips == null or combat == null:
        return

    verify.call(skeleton.get_bone_count() >= 15,
        "Original rig has distinct skinned elbow and knee joints")
    for side in ["L", "R"]:
        var upper: int = skeleton.find_bone("UpperArm_" + side)
        var elbow: int = skeleton.find_bone("Elbow_" + side)
        var hand: int = skeleton.find_bone("Hand_" + side)
        verify.call(upper >= 0 and elbow >= 0 and hand >= 0
            and skeleton.get_bone_parent(elbow) == upper
            and skeleton.get_bone_parent(hand) == elbow,
            "Articulated %s arm is upper arm -> elbow -> hand" % side)

    var punch: Animation = clips.get_animation(&"punch")
    var kick: Animation = clips.get_animation(&"kick")
    verify.call(punch != null and kick != null,
        "Authored punch and kick clips import")
    if punch == null or kick == null:
        return
    verify.call(absf(punch.length - 0.25) < 0.005
        and absf(kick.length - 1.0 / 3.0) < 0.005,
        "Punch and kick use fast 0.25s and 0.33s motion, not old slow clips")
    verify.call(absf(punch.length - float(combat.get_attack(&"punch").total_ticks()) / 60.0) < 0.005
        and absf(kick.length - float(combat.get_attack(&"kick").total_ticks()) / 60.0) < 0.005,
        "Combat action lifetime matches the shorter authored animation, not vice versa")

    # The first phase folds the right elbow backwards; the next pushes a
    # properly jointed forearm forward at contact with a rotating shoulder.
    var windup_elbow: float = _bone_angle_x(punch, "Elbow_R", 1.0 / 6.0)
    var impact_elbow: float = _bone_angle_x(punch, "Elbow_R", 2.0 / 6.0)
    var impact_shoulder: float = _bone_angle_x(punch, "UpperArm_R", 2.0 / 6.0)
    var torso_twist: float = 0.0
    for track in range(punch.get_track_count()):
        var path: NodePath = punch.track_get_path(track)
        if path.get_subname_count() > 0 and str(path.get_subname(0)) == "Spine":
            if punch.track_get_type(track) == Animation.TYPE_ROTATION_3D:
                torso_twist = punch.rotation_track_interpolate(
                    track, punch.length * 2.0 / 6.0).get_euler().y
    verify.call(windup_elbow < -0.65 and impact_elbow > windup_elbow + 0.55
        and impact_shoulder > 0.95 and absf(torso_twist) > 0.08,
        "Punch elbow windup/extension with spine twist (windup=%.3f contact=%.3f shoulder=%.3f twist=%.3f)" % [
            windup_elbow, impact_elbow, impact_shoulder, torso_twist])
    # Forward is -Z: shoulder brings elbow forward, followed by hand.
    var strike_reach: float = -0.23 * sin(impact_shoulder) - 0.11 * sin(impact_shoulder + impact_elbow)
    verify.call(strike_reach < -0.29,
        "Jointed right-hand chain reaches forward, not just a rigid upper arm")
    verify.call(absf(_bone_angle_x(punch, "UpperArm_R", 1.0)) < 0.01
        and absf(_bone_angle_x(punch, "Elbow_R", 1.0)) < 0.01,
        "Punch resets the complete arm for subsequent actions")

    # Knee visibly leads foot: first raise the thigh while folding the shin
    # behind the knee, THEN extend the lower leg toward world -Z.
    var chamber_thigh: float = _bone_angle_x(kick, "Leg_R", 1.0 / 6.0)
    var chamber_knee: float = _bone_angle_x(kick, "Knee_R", 1.0 / 6.0)
    var strike_thigh: float = _bone_angle_x(kick, "Leg_R", 2.0 / 6.0)
    var strike_knee: float = _bone_angle_x(kick, "Knee_R", 2.0 / 6.0)
    verify.call(chamber_thigh > 0.75 and chamber_knee < -0.9
        and strike_thigh > 1.05 and strike_knee > chamber_knee + 0.55,
        "Kick knee chambers before foot extension (thigh=%.3f knee=%.3f contact thigh=%.3f knee=%.3f)" % [
            chamber_thigh, chamber_knee, strike_thigh, strike_knee])

    var chamber_z: float = -0.32 * sin(chamber_thigh) - 0.30 * sin(chamber_thigh + chamber_knee)
    var strike_z: float = -0.32 * sin(strike_thigh) - 0.30 * sin(strike_thigh + strike_knee)
    var chamber_y: float = -0.32 * cos(chamber_thigh) - 0.30 * cos(chamber_thigh + chamber_knee)
    var strike_y: float = -0.32 * cos(strike_thigh) - 0.30 * cos(strike_thigh + strike_knee)
    verify.call(chamber_z < -0.05 and strike_z < chamber_z - 0.25
        and strike_y > chamber_y + 0.15,
        "Actual articulated foot advances 25cm and rises 15cm after knee chamber")
    verify.call(_bone_angle_x(kick, "Foot_R", 2.0 / 6.0) < -0.45
        and absf(_bone_angle_x(kick, "Leg_R", 1.0)) < 0.01
        and absf(_bone_angle_x(kick, "Knee_R", 1.0)) < 0.01,
        "Kick ankle levels the toe and leg resets (foot=%.3f end thigh=%.3f end knee=%.3f)" % [
            _bone_angle_x(kick, "Foot_R", 2.0 / 6.0),
            _bone_angle_x(kick, "Leg_R", 1.0), _bone_angle_x(kick, "Knee_R", 1.0)])
