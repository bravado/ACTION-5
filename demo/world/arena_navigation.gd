extends NavigationRegion3D
## Minimal demonstration navigation on the arena floor. Combined with the
## dungeon's authored NavigationRegion3D and the shared door's conditional
## NavigationLink3D, NPCs can cross the SAME passage once E opens.
## Movement stays owned by the existing Action5AINavigation/Locomotion.
##
## Future arenas should bake a detailed NavMesh around static obstacles;
## this simple quad only proves that opening/closing a link is meaningful.

func _ready() -> void:
    var mesh := NavigationMesh.new()
    mesh.vertices = PackedVector3Array([
        Vector3(-13.0, 0, -8.0),
        Vector3(13.0, 0, -8.0),
        Vector3(13.0, 0, 8.0),
        Vector3(-13.0, 0, 8.0)
    ])
    mesh.add_polygon(PackedInt32Array([0, 1, 2]))
    mesh.add_polygon(PackedInt32Array([0, 2, 3]))
    navigation_mesh = mesh
