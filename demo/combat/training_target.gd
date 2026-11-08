extends Node3D
## Demo-only feedback: reusable Health/Combat components never need HUD logic.

const HealthScript = preload("res://addons/action5/combat/health.gd")

@onready var health: HealthScript = $Health
@onready var visual: MeshInstance3D = $Visual
@onready var label: Label3D = $HealthLabel

var flash_left: float = 0.0
var material: StandardMaterial3D
var normal_color: Color


func _ready() -> void:
    # Unique material per target: one dummy hit must not recolor another.
    material = visual.get_active_material(0).duplicate() as StandardMaterial3D
    visual.material_override = material
    normal_color = material.albedo_color
    health.health_changed.connect(_on_health_changed)
    _on_health_changed(health.current_health, health.current_health)


func _on_health_changed(current: float, previous: float) -> void:
    label.text = "%d HP" % ceili(current)
    if current < previous:
        flash_left = 0.2
    if current <= 0.0:
        label.text = "DOWN"


func _process(delta: float) -> void:
    flash_left = maxf(0.0, flash_left - delta)
    if health.current_health <= 0.0:
        material.albedo_color = Color(0.22, 0.22, 0.22)
    elif flash_left > 0.0:
        material.albedo_color = normal_color.lerp(Color(1.0, 0.88, 0.3), flash_left / 0.2)
    else:
        material.albedo_color = normal_color
