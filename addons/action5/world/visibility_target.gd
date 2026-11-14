extends Node
class_name Action5VisibilityTarget
## Attach as a child of any authored visual root: a PackedScene, nested GLB
## hierarchy, StaticBody3D, or a GridMap. Does not change physics/navigation.
## Each visual node should have only one target (one presentation owner).

@export var policy: Action5VisibilityPolicy
@export var visual_root_path: NodePath = ^".."
## Optional authored box collider for precise long-wall footprint distance.
## When absent, proximity uses MeshInstance3D bounds (e.g. Blender imports).
@export var proximity_shape_path: NodePath = ^"../CollisionShape3D"


func _enter_tree() -> void:
    add_to_group(&"action5_visibility_target")


func visuals() -> Array[Node3D]:
    var result: Array[Node3D] = []
    var root: Node = get_node_or_null(visual_root_path)
    if root != null:
        _collect_visuals(root, result)
    return result


func _collect_visuals(node: Node, result: Array[Node3D]) -> void:
    if node != self and node is Action5VisibilityTarget:
        return
    if node is MeshInstance3D or node is GridMap:
        result.append(node as Node3D)
    for child in node.get_children():
        _collect_visuals(child, result)


func horizontal_distance(point: Vector3, visual_nodes: Array[WeakRef]) -> float:
    var shape := get_node_or_null(proximity_shape_path) as CollisionShape3D
    if shape != null and shape.shape is BoxShape3D:
        var half: Vector3 = (shape.shape as BoxShape3D).size * 0.5
        var local: Vector3 = shape.to_local(point)
        var nearest: Vector3 = shape.to_global(Vector3(
            clampf(local.x, -half.x, half.x), local.y,
            clampf(local.z, -half.z, half.z)))
        return Vector2(nearest.x - point.x, nearest.z - point.z).length()
    var distance: float = INF
    for reference in visual_nodes:
        var mesh := reference.get_ref() as MeshInstance3D
        if mesh == null or mesh.mesh == null:
            continue
        var bounds: AABB = mesh.get_aabb()
        var local: Vector3 = mesh.to_local(point)
        var nearest: Vector3 = mesh.to_global(Vector3(
            clampf(local.x, bounds.position.x, bounds.end.x),
            local.y,
            clampf(local.z, bounds.position.z, bounds.end.z)))
        distance = minf(distance, Vector2(
            nearest.x - point.x, nearest.z - point.z).length())
    return distance
