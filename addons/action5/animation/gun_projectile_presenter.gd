extends Node
class_name Action5GunProjectilePresenter
## Optional fire-event subscriber. It converts a resolved hitscan into a
## temporary world-space projectile without owning aiming, ammo or damage.
## No input, camera, view-mode, weapon type or CombatController dependency.

signal projectile_spawned(projectile: Node3D)

@export var gun_path: NodePath = ^".."
@export var muzzle_path: NodePath = ^"../Muzzle"
@export var projectile_scene: PackedScene = preload(
    "res://addons/action5/animation/projectile_visual.tscn"
)

@onready var gun: Node = get_node_or_null(gun_path)
@onready var muzzle: Node3D = get_node_or_null(muzzle_path) as Node3D
var spawn_count: int = 0


func _ready() -> void:
    if is_instance_valid(gun) and gun.has_signal("fired"):
        gun.fired.connect(_on_fired)


func _on_fired(impact: Vector3, _hit_receiver: bool) -> void:
    if projectile_scene == null or not is_instance_valid(muzzle):
        return
    var projectile := projectile_scene.instantiate() as Node3D
    if projectile == null:
        return
    if not projectile.has_method("launch")             or not bool(projectile.call("launch", muzzle.global_position, impact)):
        projectile.free()
        return
    # top_level prevents the animated hand, player motion and view switch
    # from dragging an already-fired tracer back toward the gun.
    projectile.top_level = true
    add_child(projectile)
    spawn_count += 1
    projectile_spawned.emit(projectile)


func _exit_tree() -> void:
    if is_instance_valid(gun) and gun.has_signal("fired")             and gun.fired.is_connected(_on_fired):
        gun.fired.disconnect(_on_fired)
