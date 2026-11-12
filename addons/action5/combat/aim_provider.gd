extends Node
class_name Action5AimProvider
## Independent 3D aim conversion; never modifies locomotion or the camera.
const ViewProfileScript = preload("res://addons/action5/camera/view_profile.gd")
const PolicyScript = preload("res://addons/action5/actor/movement_policy.gd")

static func resolve_direction(
    world_aim: Vector2, facing: Vector2, mode: int,
    camera: Camera3D = null, sectors: int = 0
) -> Vector2:
    var result: Vector2 = world_aim
    if not result.is_finite():
        result = Vector2.ZERO
    if result.length_squared() < 0.001 and mode == ViewProfileScript.Mode.FIRST_PERSON and camera != null:
        var forward: Vector3 = -camera.global_basis.z
        result = Vector2(forward.x, forward.z)
    if result.length_squared() < 0.001:
        result = facing if facing.is_finite() else Vector2.ZERO
    if result.length_squared() < 0.001:
        result = Vector2(0.0, -1.0)
    result = result.normalized()
    if mode == ViewProfileScript.Mode.RETRO_TOPDOWN and sectors >= 2:
        var step: float = TAU / float(sectors)
        result = Vector2.RIGHT.rotated(roundf(result.angle() / step) * step).normalized()
    return result


## Full 3D ray, not the X/Z locomotion projection. D06 will independently
## verify muzzle obstruction after resolving the camera target.
static func camera_ray(camera: Camera3D) -> Dictionary:
    if camera == null:
        return {}
    var center: Vector2 = camera.get_viewport().get_visible_rect().size * 0.5
    return {
        "origin": camera.project_ray_origin(center),
        "direction": camera.project_ray_normal(center).normalized()
    }


static func camera_target(
    camera: Camera3D, max_distance: float = 100.0,
    collision_mask: int = 1, exclude: Array[RID] = []
) -> Vector3:
    var ray: Dictionary = camera_ray(camera)
    if ray.is_empty():
        return Vector3.ZERO
    var origin: Vector3 = ray["origin"]
    var endpoint: Vector3 = origin + ray["direction"] * max_distance
    var params := PhysicsRayQueryParameters3D.create(origin, endpoint, collision_mask, exclude)
    var hit: Dictionary = camera.get_world_3d().direct_space_state.intersect_ray(params)
    return hit.get("position", endpoint)
