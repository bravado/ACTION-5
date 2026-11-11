extends Node3D
## Dungeon-owned navigation fixture, shared by the D07 NPC regressions and
## the playable D08 persistent-world room. No duplicate encounter scene.
## Collision and AI pathing remain independent of camera presentation.

@onready var navigation_region: NavigationRegion3D = $NavigationRegion3D


func _ready() -> void:
    var mesh := NavigationMesh.new()
    # A ring of eight triangles leaves the central opaque collider out of
    # navigation; this is authored topology, not direct-to-target steering.
    mesh.vertices = PackedVector3Array([
        Vector3(-11, 0, -7), Vector3(11, 0, -7),
        Vector3(11, 0, 7), Vector3(-11, 0, 7),
        Vector3(-1.8, 0, -1.8), Vector3(1.8, 0, -1.8),
        Vector3(1.8, 0, 1.8), Vector3(-1.8, 0, 1.8)
    ])
    for quad in [
        [0, 1, 5, 4], [1, 2, 6, 5],
        [2, 3, 7, 6], [3, 0, 4, 7]
    ]:
        # Godot navigation polygons are clockwise when viewed from above.
        mesh.add_polygon(PackedInt32Array([quad[0], quad[1], quad[2]]))
        mesh.add_polygon(PackedInt32Array([quad[0], quad[2], quad[3]]))
    navigation_region.navigation_mesh = mesh
