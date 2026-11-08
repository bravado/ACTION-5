extends Node
class_name Action5Health
## Damage, team, invulnerability, block and death are independent of rendering.

signal health_changed(value: float, previous: float)
signal damaged(amount: float, source: Node)
signal died(source: Node)
## Optional subscribers decide how a hit moves or disables their host.
## Health itself never assumes an actor, a movement solver or a node layout.
signal knockback_requested(world_velocity: Vector2, duration_ticks: int)

@export_range(1.0, 10000.0, 1.0) var max_health: float = 100.0
@export var team_id: int = 0
@export var immune: bool = false
@export var blocking: bool = false
@export_range(0, 120, 1) var invulnerability_ticks_after_hit: int = 0

var current_health: float = 0.0
var invulnerability_left: int = 0
var stagger_left: int = 0


func _ready() -> void:
    current_health = max_health


func _physics_process(_delta: float) -> void:
    if invulnerability_left > 0:
        invulnerability_left -= 1
    if stagger_left > 0:
        stagger_left -= 1


## Override for directional shields, resistances or other gameplay hooks.
func can_receive_hit(_source: Node, _attack: Resource) -> bool:
    return current_health > 0.0 and not immune and not blocking \
        and invulnerability_left == 0


func take_hit(
    amount: float, source: Node, attack: Resource,
    direction: Vector2, knockback_speed: float, knockback_ticks: int,
    stagger_ticks: int = 0
) -> bool:
    if amount < 0.0 or not can_receive_hit(source, attack):
        return false
    var previous: float = current_health
    current_health = maxf(0.0, current_health - amount)
    invulnerability_left = invulnerability_ticks_after_hit
    stagger_left = maxi(stagger_left, stagger_ticks)
    health_changed.emit(current_health, previous)
    damaged.emit(amount, source)
    if current_health <= 0.0:
        died.emit(source)
    elif knockback_speed > 0.0 and knockback_ticks > 0 and direction.is_finite() \
            and direction.length_squared() > 0.001:
        knockback_requested.emit(direction.normalized() * knockback_speed, knockback_ticks)
    return true


func heal(amount: float) -> void:
    if current_health <= 0.0 or amount <= 0.0:
        return
    var previous: float = current_health
    current_health = minf(max_health, current_health + amount)
    health_changed.emit(current_health, previous)
