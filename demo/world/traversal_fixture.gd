extends Node3D
## D08 small physical traversal reference. Geometry deliberately includes
## an unsupported elevated gap, low step, narrow ledge and low overhang.
## No special traversal behavior is implemented in the world/actor core.

func _ready() -> void:
    _block("LowStep", Vector3(-7.5, 0.16, 6), Vector3(1.2, 0.32, 2.0))
    _block("GapStart", Vector3(-4.2, 0.92, 6), Vector3(1.8, 0.30, 2.0))
    _block("GapEnd", Vector3(-0.5, 0.92, 6), Vector3(1.8, 0.30, 2.0))
    _block("ThinLedge", Vector3(2.0, 1.15, 6), Vector3(0.35, 0.25, 4.0))
    _block("Overhang", Vector3(6.0, 2.12, 6), Vector3(2.5, 0.30, 2.5))
    _block("SteepFace", Vector3(8.0, 0.85, 5), Vector3(0.65, 1.7, 2.0))


func _block(label: String, center: Vector3, size: Vector3) -> void:
    var body := StaticBody3D.new()
    body.name = label
    body.position = center
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    collision.shape = shape
    body.add_child(collision)
    var mesh := MeshInstance3D.new()
    var geometry := BoxMesh.new()
    geometry.size = size
    mesh.mesh = geometry
    body.add_child(mesh)
    add_child(body)
