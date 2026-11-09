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

@onready var context_source: Node = get_node_or_null(context_source_path)


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
    var sectors: int = retro_gun_sectors * 4 if mode == ProfileScript.Mode.RETRO_TOPDOWN else 0
    var direction: Vector2 = AimScript.resolve_direction(
        context.get("world_aim"), context.get("facing_world"), mode, camera, sectors
    )
    return origin + Vector3(direction.x, 0.0, direction.y) * maximum_range
