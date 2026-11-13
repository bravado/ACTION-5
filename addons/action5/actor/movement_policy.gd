extends RefCounted
class_name Action5MovementPolicy
## Pure camera-axis mapping. Physical velocity and raw input are handled elsewhere.

const ViewProfileScript = preload("res://addons/action5/camera/view_profile.gd")
const EPSILON_SQ: float = 0.000001


static func to_world(axes: Vector2, mode: int, camera_basis: Basis) -> Vector2:
    if not axes.is_finite():
        return Vector2.ZERO
    var sanitized: Vector2 = axes.limit_length(1.0)
    if mode == ViewProfileScript.Mode.SIDE:
        return Vector2(sanitized.x, 0.0)
    if mode == ViewProfileScript.Mode.BEAT_EM_UP:
        return sanitized

    # Camera screen-right always supplies the lateral axis.
    var lateral := Vector2(camera_basis.x.x, camera_basis.x.z)
    if lateral.length_squared() <= EPSILON_SQ:
        lateral = Vector2.RIGHT
    else:
        lateral = lateral.normalized()

    var forward: Vector2
    if mode == ViewProfileScript.Mode.TOP_DOWN:
        # At exact vertical pitch camera-forward projects to zero.
        # Camera screen-up points toward world -Z in the top-down profile.
        forward = Vector2(camera_basis.y.x, camera_basis.y.z)
    elif mode == ViewProfileScript.Mode.ISOMETRIC:
        # Screen-up is stable at the wide isometric view, but can shrink
        # near a level over-the-shoulder camera. Fallback to camera heading.
        forward = Vector2(camera_basis.y.x, camera_basis.y.z)
        if forward.length_squared() <= EPSILON_SQ:
            forward = Vector2(-camera_basis.z.x, -camera_basis.z.z)
    else:
        # First-person: use heading even when camera is looking up/down.
        forward = Vector2(-camera_basis.z.x, -camera_basis.z.z)

    if forward.length_squared() <= EPSILON_SQ:
        forward = Vector2(0.0, -1.0)
    else:
        forward = forward.normalized()
    var projected: Vector2 = lateral * sanitized.x - forward * sanitized.y
    return projected.limit_length(1.0) if projected.is_finite() else Vector2.ZERO


static func quantize_facing(direction: Vector2, sectors: int) -> Vector2:
    if not direction.is_finite() or direction.length_squared() <= EPSILON_SQ:
        return Vector2.ZERO
    if sectors < 2:
        return direction.normalized()
    var step: float = TAU / float(sectors)
    var angle: float = roundf(direction.angle() / step) * step
    return Vector2.RIGHT.rotated(angle).normalized()


static func choose_facing(
    move_world: Vector2,
    aim_world: Vector2,
    view_mode: int,
    top_down_sectors: int = 8
) -> Vector2:
    var desired: Vector2 = aim_world if aim_world.length_squared() > EPSILON_SQ else move_world
    if desired.length_squared() <= EPSILON_SQ:
        return Vector2.ZERO
    if view_mode == ViewProfileScript.Mode.SIDE:
        return Vector2(signf(desired.x), 0.0) if absf(desired.x) > 0.01 else Vector2.ZERO
    if view_mode == ViewProfileScript.Mode.TOP_DOWN:
        return quantize_facing(desired, top_down_sectors)
    return desired.normalized()
