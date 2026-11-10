extends Node
class_name Action5AINavigation
## Reads NavigationAgent3D's world-space waypoints; never sets body velocity.
## The actor's existing Locomotion owns all physical movement.

@export var agent_path: NodePath = ^"../NavigationAgent3D"
@export_range(0.1, 5.0, 0.1) var retarget_distance: float = 0.5

@onready var agent: NavigationAgent3D = get_node_or_null(agent_path) as NavigationAgent3D
var _has_destination: bool = false
var _destination: Vector3 = Vector3.ZERO


func direction_to(actor: Node3D, destination: Vector3, stop_range: float) -> Vector2:
    if not is_instance_valid(agent) or not is_instance_valid(actor) \
            or not destination.is_finite():
        return Vector2.ZERO
    var difference: Vector3 = destination - actor.global_position
    var planar := Vector2(difference.x, difference.z)
    if planar.length() <= stop_range:
        return Vector2.ZERO
    # Navigation maps are synchronized after the first physics tick. Never
    # steer directly through walls when a map is missing/not yet ready.
    if NavigationServer3D.map_get_iteration_id(agent.get_navigation_map()) == 0:
        return Vector2.ZERO
    if not _has_destination or _destination.distance_to(destination) > retarget_distance:
        _destination = destination
        _has_destination = true
        agent.target_position = destination
    # Must be called each physics tick while navigating, even if waypoints
    # have not changed. Its return value is a point, not a body velocity.
    var waypoint: Vector3 = agent.get_next_path_position()
    if agent.get_current_navigation_path().is_empty():
        return Vector2.ZERO
    var direction := Vector2(waypoint.x - actor.global_position.x,
        waypoint.z - actor.global_position.z)
    return direction.normalized() if direction.length_squared() > 0.01 else Vector2.ZERO


func reset() -> void:
    _has_destination = false
