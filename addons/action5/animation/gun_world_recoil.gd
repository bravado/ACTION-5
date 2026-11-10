extends Node3D
class_name Action5GunWorldRecoil
## Render-only recoil pivot; physical Muzzle stays a sibling.
@export var gun_path: NodePath = ^".."
@export var kick_distance: float = 0.08
@export var settle_ticks: int = 8
@onready var gun: Node = get_node_or_null(gun_path)
var remaining: int = 0
var rest: Vector3

func _ready() -> void:
    rest = position
    if is_instance_valid(gun):
        gun.fired.connect(_on_fired)

func _on_fired(_impact: Vector3, _hit: bool) -> void:
    remaining = settle_ticks

func _physics_process(_delta: float) -> void:
    if remaining > 0:
        position = rest + Vector3(0, 0, kick_distance * float(remaining) / float(settle_ticks))
        remaining -= 1
    elif position != rest:
        position = rest
