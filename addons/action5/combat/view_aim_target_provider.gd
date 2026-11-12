extends Node
class_name Action5ViewAimTargetProvider
## View-specific translation from D05 ActionInputContext to a world point.
## Never changes MovementIntent or the actor's physical heading. Gun sees only
## get_world_target(origin, range, excludes), not view enums or cameras.

const AimScript = preload("res://addons/action5/combat/aim_provider.gd")
const ProfileScript = preload("res://addons/action5/camera/view_profile.gd")

@export var context_source_path: NodePath = ^"../../ActorInput"
@export_flags_3d_physics var camera_target_mask: int = 3
@export_enum("Free", "4-way", "8-way") var retro_gun_sectors: int = 2
## F1 orthographic rays travel into screen depth, not left/right along the
## side-scroller plane. Use a separate upper-torso-height horizontal sight ray.
## This is a target-selection port only: Gun still casts from the world muzzle.
@export_range(0.2, 2.0, 0.05) var side_center_height: float = 1.25
@export var side_aim_anchor_path: NodePath = ^".."
@export var direction_policy_path: NodePath = ^""

@onready var context_source: Node = get_node_or_null(context_source_path)
@onready var direction_policy: Node = get_node_or_null(direction_policy_path)


func get_world_target(origin: Vector3, maximum_range: float, exclude: Array[RID]) -> Vector3:
    if not is_instance_valid(context_source) or not context_source.has_method("get_action_input_context"):
        return origin
    var context: RefCounted = context_source.call("get_action_input_context")
    if context == null or not context.get("accepting_actions"):
        return origin
    var mode: int = int(context.get("view_mode"))
    var camera: Camera3D = context.get("camera") as Camera3D
    if mode == ProfileScript.Mode.FIRST_PERSON and is_instance_valid(camera):
        var ray := AimScript.camera_ray(camera)
        if ray.is_empty():
            return origin
        var start: Vector3 = ray["origin"]
        var end: Vector3 = start + ray["direction"] * maximum_range
        var query := PhysicsRayQueryParameters3D.create(start, end, camera_target_mask, exclude)
        query.collide_with_areas = true
        var hit: Dictionary = camera.get_world_3d().direct_space_state.intersect_ray(query)
        return hit.get("position", end)
    if mode == ProfileScript.Mode.SIDE and is_instance_valid(camera):
        return _side_center_target(context, camera, origin, maximum_range, exclude)
    var sectors: int = retro_gun_sectors * 4 if mode == ProfileScript.Mode.RETRO_TOPDOWN else 0
    var direction: Vector2 = AimScript.resolve_direction(
        context.get("world_aim"), context.get("facing_world"), mode, camera, sectors
    )
    return origin + Vector3(direction.x, 0.0, direction.y) * maximum_range


## Orthographic side-view center-line selection. A ray through the literal
## viewport center travels along -Z and cannot aim at an enemy left/right of
## the actor. Instead aim along the physical 2D combat lane at target-body
## center height. The muzzle still decides whether a shot can actually hit;
## selection here NEVER applies damage or tunnels past a nearby obstruction.
func _side_center_target(context: RefCounted, camera: Camera3D,
        origin: Vector3, maximum_range: float, exclude: Array[RID]) -> Vector3:
    var actor := get_node_or_null(side_aim_anchor_path) as Node3D
    if actor == null or maximum_range <= 0.0:
        return origin
    var world_aim: Vector2 = context.get("world_aim")
    var facing: Vector2 = context.get("facing_world")
    var horizontal: float = world_aim.x if absf(world_aim.x) > 0.01 else facing.x
    # F1 has only two directions. Entering it from a neutral F4 pose should
    # still allow firing in a predictable direction without moving first.
    if absf(horizontal) <= 0.01:
        horizontal = 1.0
    var begin: Vector3 = actor.global_position + Vector3.UP * side_center_height
    var finish: Vector3 = begin + Vector3.RIGHT * signf(horizontal) * maximum_range
    var params := PhysicsRayQueryParameters3D.create(
        begin, finish, camera_target_mask, exclude
    )
    params.collide_with_areas = true
    params.collide_with_bodies = true
    var selected: Dictionary = camera.get_world_3d().direct_space_state.intersect_ray(params)
    return selected.get("position", finish)
