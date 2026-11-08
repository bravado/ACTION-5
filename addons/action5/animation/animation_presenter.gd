extends Node
class_name Action5AnimationPresenter
## Presentation-only composition: locomotion, upper-body actions and full-body
## overrides use independent AnimationTree playbacks. Gameplay owns durations,
## move eligibility, attack windows and collision; no combat logic lives here.

const ProfileScript = preload("res://addons/action5/animation/skeleton_profile.gd")
const ValidatorScript = preload("res://addons/action5/animation/model_validator.gd")
const MoveControllerScript = preload("res://addons/action5/actor/moves/movement_controller.gd")

signal animation_changed(clip_key: StringName)
signal upper_body_animation_changed(clip_key: StringName)

@export var model_path: NodePath = ^"../Visual/Model"
@export var profile: ProfileScript = preload("res://addons/action5/animation/default_skeleton_profile.tres")
@export_range(0.01, 3.0, 0.01) var idle_speed_threshold: float = 0.15
@export_range(0.1, 12.0, 0.1) var run_speed_threshold: float = 6.0

var actor: CharacterBody3D
var move_controller: MoveControllerScript
var model: Node
var skeleton: Skeleton3D
var animation_player: AnimationPlayer
var animation_tree: AnimationTree
## Compatibility alias: currently dominant full-body or base playback.
var playback: AnimationNodeStateMachinePlayback
var base_playback: AnimationNodeStateMachinePlayback
var upper_body_playback: AnimationNodeStateMachinePlayback
var full_body_playback: AnimationNodeStateMachinePlayback
var base_clip: StringName = &""
var upper_body_clip: StringName = &""
## Explicit full-body visual (legacy set_action_visual API).
var action_clip: StringName = &""
## Currently dominant full-body/base clip; upper-body overlays are independent.
var current_clip: StringName = &""
var validation: Dictionary = {}
var upper_body_filter_paths: Array[NodePath] = []
var _sockets: Dictionary = {}
var _available_clips: Dictionary = {}


func _ready() -> void:
    actor = get_parent() as CharacterBody3D
    model = get_node_or_null(model_path)
    if actor == null or model == null or profile == null:
        push_warning("ACTION5: AnimationPresenter requires a model and SkeletonProfile")
        set_physics_process(false)
        return
    validation = ValidatorScript.validate(model, profile)
    if not bool(validation.get("valid", false)):
        push_warning("ACTION5: Animation model validation failed: " + str(validation["errors"]))
        set_physics_process(false)
        return

    skeleton = ValidatorScript.find_skeleton(model)
    animation_player = ValidatorScript.find_animation_player(model)
    move_controller = actor.get_node_or_null("Locomotion/MovementController") as MoveControllerScript
    _create_sockets()
    _create_animation_tree()
    if animation_tree == null:
        set_physics_process(false)


func _create_sockets() -> void:
    for key in [&"right_hand", &"left_hand", &"head"]:
        var name: StringName = profile.socket_bone(key)
        var socket: Node3D
        if name != &"" and skeleton.find_bone(str(name)) >= 0:
            var attachment := BoneAttachment3D.new()
            attachment.name = "Socket_" + str(key)
            skeleton.add_child(attachment)
            attachment.bone_name = str(name)
            socket = attachment
        else:
            # Missing optional bones leave a stable attachment for equipment.
            socket = Node3D.new()
            socket.name = "FallbackSocket_" + str(key)
            skeleton.add_child(socket)
        _sockets[key] = socket


func get_socket(key: StringName) -> Node3D:
    var socket: Node3D = _sockets.get(key)
    return socket if is_instance_valid(socket) else null


func _create_animation_tree() -> void:
    var available: Array[StringName] = []
    for key in profile.clip_map.keys():
        var id: StringName = StringName(key)
        var name: StringName = profile.clip_name(id)
        if name == &"" or not animation_player.has_animation(name):
            continue
        available.append(id)
        _available_clips[id] = true
    if not _available_clips.has(&"idle"):
        push_warning("ACTION5: Animation presenter requires an idle clip")
        return

    # Three independent playheads: movement continues while actions play.
    # UpperBodyBlend filters only the profile's upper-body bone tracks; a
    # separate FullBodyBlend can temporarily replace the complete pose.
    var root := AnimationNodeBlendTree.new()
    root.add_node(&"Base", _create_machine(available))
    root.add_node(&"Upper", _create_machine(available))
    root.add_node(&"Full", _create_machine(available))
    var upper_mix := AnimationNodeBlend2.new()
    upper_mix.sync = true
    upper_mix.filter_enabled = true
    _configure_upper_filter(upper_mix)
    var full_mix := AnimationNodeBlend2.new()
    full_mix.sync = true
    root.add_node(&"UpperBodyBlend", upper_mix)
    root.add_node(&"FullBodyBlend", full_mix)
    root.connect_node(&"UpperBodyBlend", 0, &"Base")
    root.connect_node(&"UpperBodyBlend", 1, &"Upper")
    root.connect_node(&"FullBodyBlend", 0, &"UpperBodyBlend")
    root.connect_node(&"FullBodyBlend", 1, &"Full")
    root.connect_node(&"output", 0, &"FullBodyBlend")

    animation_tree = AnimationTree.new()
    animation_tree.name = "Action5AnimationTree"
    add_child(animation_tree)
    animation_tree.anim_player = animation_tree.get_path_to(animation_player)
    animation_tree.tree_root = root
    animation_tree.active = true
    base_playback = animation_tree.get("parameters/Base/playback") as AnimationNodeStateMachinePlayback
    upper_body_playback = animation_tree.get("parameters/Upper/playback") as AnimationNodeStateMachinePlayback
    full_body_playback = animation_tree.get("parameters/Full/playback") as AnimationNodeStateMachinePlayback
    if base_playback == null or upper_body_playback == null or full_body_playback == null:
        push_warning("ACTION5: AnimationTree channel playback initialization failed")
        animation_tree.active = false
        set_physics_process(false)
        return

    base_playback.start(&"idle")
    upper_body_playback.start(&"idle")
    full_body_playback.start(&"idle")
    animation_tree.set("parameters/UpperBodyBlend/blend_amount", 0.0)
    animation_tree.set("parameters/FullBodyBlend/blend_amount", 0.0)
    playback = base_playback
    base_clip = &"idle"
    current_clip = &"idle"


func _create_machine(available: Array[StringName]) -> AnimationNodeStateMachine:
    var machine := AnimationNodeStateMachine.new()
    for id in available:
        var name: StringName = profile.clip_name(id)
        var clip: Animation = animation_player.get_animation(name)
        var node := AnimationNodeAnimation.new()
        node.animation = name
        if id in [&"idle", &"walk", &"run"]:
            # Do not mutate imported/shared Animation resources (NPC-safe).
            node.use_custom_timeline = true
            node.timeline_length = clip.length
            node.loop_mode = Animation.LOOP_LINEAR
        machine.add_node(id, node)
    for source in available:
        for target in available:
            if source == target:
                continue
            var transition := AnimationNodeStateMachineTransition.new()
            transition.xfade_time = 0.08
            machine.add_transition(source, target, transition)
    machine.add_transition(&"Start", &"idle", AnimationNodeStateMachineTransition.new())
    return machine


func _configure_upper_filter(mix: AnimationNodeBlend2) -> void:
    var root_bone: int = skeleton.find_bone(str(profile.upper_body_root_bone))
    if root_bone < 0:
        push_warning("ACTION5: Missing upper-body root bone: " + str(profile.upper_body_root_bone))
        return
    # Use exact imported animation paths, not guessed Skeleton3D node paths.
    # This supports differently named rigs through SkeletonProfile alone.
    for key in _available_clips.keys():
        var clip: Animation = animation_player.get_animation(profile.clip_name(key))
        for i in range(clip.get_track_count()):
            var path: NodePath = clip.track_get_path(i)
            if path.get_subname_count() == 0:
                continue
            var bone_index: int = skeleton.find_bone(str(path.get_subname(0)))
            if bone_index < 0 or not _is_descendant_bone(bone_index, root_bone):
                continue
            if not upper_body_filter_paths.has(path):
                upper_body_filter_paths.append(path)
                mix.set_filter_path(path, true)
    if upper_body_filter_paths.is_empty():
        push_warning("ACTION5: No upper-body animation tracks mapped; overlay channel disabled")


func _is_descendant_bone(index: int, ancestor: int) -> bool:
    var bone: int = index
    while bone >= 0:
        if bone == ancestor:
            return true
        bone = skeleton.get_bone_parent(bone)
    return false


## Only clips installed in each state machine can be requested.
func _has_clip(key: StringName) -> bool:
    return _available_clips.has(key)


## Full-body visual override. This channel never changes physical movement.
## D05 owns timing and calls clear_action_visual() when its action completes.
func set_action_visual(key: StringName) -> bool:
    if key == &"":
        clear_action_visual()
        return true
    if full_body_playback == null or not _has_clip(key):
        return false
    if action_clip == key:
        return true
    if action_clip == &"":
        full_body_playback.start(key)
    else:
        full_body_playback.travel(key)
    action_clip = key
    animation_tree.set("parameters/FullBodyBlend/blend_amount", 1.0)
    playback = full_body_playback
    _set_current_clip(key)
    return true


func clear_action_visual() -> void:
    if action_clip == &"":
        return
    action_clip = &""
    if animation_tree != null:
        animation_tree.set("parameters/FullBodyBlend/blend_amount", 0.0)
    playback = base_playback
    _set_current_clip(base_clip)


## Explicit API for a full-body action, e.g. Jump Kick or Roll Dodge.
func set_full_body_action(key: StringName) -> bool:
    return set_action_visual(key)


func clear_full_body_action() -> void:
    clear_action_visual()


## Independent upper-body action, e.g. Run+Reload or Jump+Shoot. The upper
## overlay only drives tracks under profile.upper_body_root_bone.
func set_upper_body_action(key: StringName) -> bool:
    if key == &"":
        clear_upper_body_action()
        return true
    if upper_body_playback == null or upper_body_filter_paths.is_empty() or not _has_clip(key):
        return false
    if upper_body_clip == key:
        return true
    if upper_body_clip == &"":
        upper_body_playback.start(key)
    else:
        upper_body_playback.travel(key)
    upper_body_clip = key
    animation_tree.set("parameters/UpperBodyBlend/blend_amount", 1.0)
    upper_body_animation_changed.emit(key)
    return true


func clear_upper_body_action() -> void:
    if upper_body_clip == &"":
        return
    upper_body_clip = &""
    if animation_tree != null:
        animation_tree.set("parameters/UpperBodyBlend/blend_amount", 0.0)
    upper_body_animation_changed.emit(&"")


func _physics_process(_delta: float) -> void:
    if base_playback == null or actor == null:
        return
    var desired: StringName = _resolve_movement_visual()
    if desired != base_clip and _has_clip(desired):
        base_playback.travel(desired)
        base_clip = desired
    if action_clip == &"":
        _set_current_clip(base_clip)


func _set_current_clip(key: StringName) -> void:
    if current_clip == key:
        return
    current_clip = key
    animation_changed.emit(key)


## Keep gameplay decisions in the locomotion FSM; observe its active move
## and physical grounded/airborne state, without coupling to move classes.
func _resolve_movement_visual() -> StringName:
    var move_id: StringName = move_controller.active_id if move_controller != null else &""
    if move_controller != null and move_id != &"" and (
        move_id != move_controller.grounded_move
        and move_id != move_controller.airborne_move
    ):
        return move_id if _has_clip(move_id) else &"idle"

    if not actor.is_on_floor():
        if actor.velocity.y > 0.05 and _has_clip(&"jump"):
            return &"jump"
        if actor.velocity.y < -0.05 and _has_clip(&"fall"):
            return &"fall"
        return &"airborne" if _has_clip(&"airborne") else &"idle"

    var speed: float = Vector2(actor.velocity.x, actor.velocity.z).length()
    if speed <= idle_speed_threshold:
        return &"idle"
    if speed > run_speed_threshold and _has_clip(&"run"):
        return &"run"
    if _has_clip(&"walk"):
        return &"walk"
    return &"run" if _has_clip(&"run") else &"idle"
