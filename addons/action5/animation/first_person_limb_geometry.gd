extends Node3D
class_name Action5FirstPersonLimbGeometry
## Demo-only, replaceable viewmodel geometry. All dimensions are intentional
## camera-space metres and bounded radii; no world-skeleton scaling.
## Only renders poses. It knows nothing about Combat, locomotion or cameras.

const ProfileScript = preload("res://addons/action5/animation/first_person_limb_profile.gd")

var profile: ProfileScript
var upper: MeshInstance3D
var lower: MeshInstance3D
var extremity: MeshInstance3D
var current_pose: Dictionary = {}


func configure(config: ProfileScript) -> void:
    profile = config
    upper = _capsule("UpperLimb", config.limb_color)
    lower = _capsule("LowerLimb", config.limb_color)
    extremity = MeshInstance3D.new()
    extremity.name = "Extremity"
    var shape := BoxMesh.new()
    shape.size = config.extremity_size
    extremity.mesh = shape
    extremity.material_override = _material(config.extremity_color)
    add_child(upper)
    add_child(lower)
    add_child(extremity)
    apply_pose(0.0)


func apply_pose(progress: float) -> void:
    if profile == null:
        return
    current_pose = profile.sample(progress)
    if current_pose.is_empty():
        return
    _place_capsule(upper, current_pose["shoulder"], current_pose["joint"],
        profile.upper_radius)
    _place_capsule(lower, current_pose["joint"], current_pose["extremity"],
        profile.lower_radius)
    extremity.position = current_pose["extremity"]
    extremity.basis = Basis.from_euler(current_pose["extremity_rotation"])
    extremity.position += extremity.basis * profile.extremity_offset


func _place_capsule(mesh: MeshInstance3D, first: Vector3, second: Vector3, radius: float) -> void:
    var direction: Vector3 = second - first
    if direction.length_squared() < 0.00001:
        mesh.visible = false
        return
    mesh.visible = true
    mesh.position = (first + second) * 0.5
    mesh.quaternion = Quaternion(Vector3.UP, direction.normalized())
    # Base capsule radius 0.5, total height 2.0. Rounded ends replace the
    # original enormous, open circular cylinder caps seen in F4.
    mesh.scale = Vector3(2.0 * radius, direction.length() * 0.5, 2.0 * radius)


func _capsule(node_name: String, color: Color) -> MeshInstance3D:
    var visual := MeshInstance3D.new()
    visual.name = node_name
    var capsule := CapsuleMesh.new()
    capsule.radius = 0.5
    capsule.height = 2.0
    capsule.radial_segments = 16
    capsule.rings = 6
    visual.mesh = capsule
    visual.material_override = _material(color)
    return visual


func _material(color: Color) -> StandardMaterial3D:
    var result := StandardMaterial3D.new()
    result.albedo_color = color
    result.roughness = 0.82
    return result
