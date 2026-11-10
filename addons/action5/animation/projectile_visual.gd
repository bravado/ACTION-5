extends Node3D
class_name Action5ProjectileVisual
## A visible in-flight tracer, not a physics projectile. The authoritative
## hitscan ray already resolved its impact before this scene is instantiated.
## The render-only meshes have no collision shapes, damage or hit queries.

@export_range(5.0, 500.0, 5.0) var travel_speed: float = 80.0
## Short shots remain on screen long enough to perceive and capture in F4.
@export_range(0.02, 0.50, 0.01) var minimum_duration: float = 0.18
@export_range(0.05, 1.00, 0.01) var maximum_duration: float = 0.34
@export_range(0.1, 4.0, 0.1) var trail_length: float = 1.2
@export_range(0.005, 0.2, 0.005) var trail_radius: float = 0.045
@export_range(0.01, 0.3, 0.01) var tip_radius: float = 0.08
@export var projectile_color: Color = Color(1.0, 0.78, 0.27, 1.0)
## Gradient along the *visible* trail: bright at the muzzle-side tail
## and increasingly transparent toward its traveling tip.
@export_range(0.0, 12.0, 0.1) var trail_start_brightness: float = 4.0
@export_range(0.0, 12.0, 0.1) var trail_end_brightness: float = 0.3
@export_range(0.0, 1.0, 0.01) var trail_start_opacity: float = 0.95
@export_range(0.0, 1.0, 0.01) var trail_end_opacity: float = 0.0

const TRAIL_SHADER = preload("res://addons/action5/animation/projectile_trail.gdshader")

var from_world: Vector3 = Vector3.ZERO
var to_world: Vector3 = Vector3.ZERO
var progress: float = 0.0
var _elapsed: float = 0.0
var _duration: float = 0.0
var _tip: MeshInstance3D
var _trail: MeshInstance3D
var _tip_material: StandardMaterial3D
var _trail_material: ShaderMaterial


## Configure before adding to the tree. The endpoints remain fixed even if
## the shooter switches views, turns, runs, drops or frees the weapon.
## The emitting gun does not own this temporary visual after launch.
func launch(start: Vector3, impact: Vector3) -> bool:
    if not start.is_finite() or not impact.is_finite() \
            or start.distance_squared_to(impact) < 0.0001:
        return false
    from_world = start
    to_world = impact
    _elapsed = 0.0
    progress = 0.0
    _duration = clampf(
        start.distance_to(impact) / maxf(travel_speed, 0.01),
        minimum_duration, maxf(minimum_duration, maximum_duration)
    )
    return true


func _ready() -> void:
    if _duration <= 0.0:
        queue_free()
        return
    _tip_material = StandardMaterial3D.new()
    _tip_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _tip_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _tip_material.albedo_color = projectile_color
    _tip_material.emission_enabled = true
    _tip_material.emission = projectile_color
    _tip_material.emission_energy_multiplier = 2.5

    # Separate material: the CylinderMesh fades from its local -Y (tail,
    # muzzle side) to +Y (head, impact side). This never reads gameplay
    # state, camera orientation, world hitboxes or the weapon instance.
    _trail_material = ShaderMaterial.new()
    _trail_material.shader = TRAIL_SHADER
    _trail_material.set_shader_parameter("trail_color", projectile_color)
    _trail_material.set_shader_parameter("start_brightness", trail_start_brightness)
    _trail_material.set_shader_parameter("end_brightness", trail_end_brightness)
    _trail_material.set_shader_parameter("start_opacity", trail_start_opacity)
    _trail_material.set_shader_parameter("end_opacity", trail_end_opacity)

    var sphere := SphereMesh.new()
    sphere.radius = tip_radius
    sphere.height = tip_radius * 2.0
    _tip = MeshInstance3D.new()
    _tip.name = "VisibleProjectile"
    _tip.mesh = sphere
    _tip.material_override = _tip_material
    _tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(_tip)

    var cylinder := CylinderMesh.new()
    cylinder.top_radius = trail_radius
    cylinder.bottom_radius = trail_radius
    cylinder.height = 1.0
    _trail = MeshInstance3D.new()
    _trail.name = "VisibleTrail"
    _trail.mesh = cylinder
    _trail.material_override = _trail_material
    _trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(_trail)

    _update_geometry()


func _process(delta: float) -> void:
    _elapsed += delta
    progress = clampf(_elapsed / _duration, 0.0, 1.0)
    if progress >= 1.0:
        queue_free()
        return
    _update_geometry()


func _update_geometry() -> void:
    if not is_instance_valid(_tip) or not is_instance_valid(_trail):
        return
    # Both the lengthwise trail gradient and its remaining lifetime fade
    # are presentation-only. The physical hit already happened at launch.
    var remaining: float = 1.0 - progress
    _trail_material.set_shader_parameter("life_fade", remaining)
    _tip_material.emission_energy_multiplier = lerpf(2.5, 0.2, progress)
    _tip_material.albedo_color = Color(
        projectile_color.r, projectile_color.g, projectile_color.b,
        projectile_color.a * remaining
    )
    var direction: Vector3 = (to_world - from_world).normalized()
    var traveled: float = from_world.distance_to(to_world) * progress
    var tip: Vector3 = from_world + direction * traveled
    var tail: Vector3 = from_world + direction * maxf(0.0, traveled - trail_length)
    _tip.global_position = tip
    var segment: float = tip.distance_to(tail)
    _trail.visible = segment > 0.001
    if _trail.visible:
        # CylinderMesh points along local +Y. Rotate and scale ONLY the
        # transient visual; never move the real world muzzle or its ray.
        var orientation := Basis(Quaternion(Vector3.UP, direction))
        _trail.global_transform = Transform3D(
            orientation.scaled(Vector3(1.0, segment, 1.0)),
            (tip + tail) * 0.5
        )
