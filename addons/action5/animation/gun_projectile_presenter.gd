extends Node
class_name Action5GunProjectilePresenter
## Optional fire-event subscriber. It converts a resolved hitscan into a
## temporary world-space projectile without owning aiming, ammo or damage.
## No input, camera, view-mode, weapon type or CombatController dependency.

signal projectile_spawned(projectile: Node3D)

@export var gun_path: NodePath = ^".."
@export var muzzle_path: NodePath = ^"../Muzzle"
## Demo/diagnostic only; game visuals work with logging disabled.
@export var debug_events: bool = false
@export var projectile_scene: PackedScene = preload(
    "res://addons/action5/animation/projectile_visual.tscn"
)

var gun: Node
var muzzle: Node3D
var spawn_count: int = 0


## EquipmentController reparents the very same weapon from world to inventory
## and then to a hand socket. _ready() runs only once, but _enter_tree() runs
## on EACH reparent. Always restore the listener after the tree transition.
func _enter_tree() -> void:
    gun = get_node_or_null(gun_path)
    muzzle = get_node_or_null(muzzle_path) as Node3D
    if is_instance_valid(gun) and gun.has_signal("fired") \
            and not gun.fired.is_connected(_on_fired):
        gun.fired.connect(_on_fired)


func _on_fired(impact: Vector3, _hit_receiver: bool) -> void:
    if projectile_scene == null or not is_instance_valid(muzzle):
        return
    var projectile := projectile_scene.instantiate() as Node3D
    if projectile == null:
        return
    if not projectile.has_method("launch") \
            or not bool(projectile.call("launch", muzzle.global_position, impact)):
        projectile.free()
        return
    # Attach to the world, never to the weapon/actor: a fired visual
    # survives weapon disposal, enemy death, reparenting and camera changes.
    var stage: Node = get_tree().current_scene
    if not is_instance_valid(stage):
        stage = get_tree().root
    projectile.top_level = true
    stage.add_child(projectile)
    spawn_count += 1
    if debug_events:
        print("ACTION5_PROJECTILE_VISUAL_SPAWN from=", projectile.get("from_world"),
            " to=", projectile.get("to_world"))
    projectile_spawned.emit(projectile)


func _exit_tree() -> void:
    if is_instance_valid(gun) and gun.has_signal("fired")             and gun.fired.is_connected(_on_fired):
        gun.fired.disconnect(_on_fired)
    gun = null
    muzzle = null
