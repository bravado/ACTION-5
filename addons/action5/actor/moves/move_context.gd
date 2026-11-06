extends RefCounted
class_name Action5MoveContext
## Shared read-only actor/intent context plus one-tick movement commands.
## Only Action5Locomotion writes CharacterBody3D.velocity/move_and_slide.

var body: CharacterBody3D
var locomotion: Node
var intent: RefCounted
var delta: float = 0.0

var has_horizontal_override: bool = false
var horizontal_override: Vector2 = Vector2.ZERO
var move_finished: bool = false


func _init(character: CharacterBody3D, solver: Node) -> void:
    body = character
    locomotion = solver


func begin_tick(next_intent: RefCounted, physics_delta: float) -> void:
    intent = next_intent
    delta = physics_delta
    has_horizontal_override = false
    horizontal_override = Vector2.ZERO
    move_finished = false


func horizontal_speed() -> float:
    return Vector2(body.velocity.x, body.velocity.z).length()


## Move components submit commands; only the locomotion solver applies them.
func request_horizontal_velocity(velocity: Vector2) -> void:
    if not velocity.is_finite():
        return
    has_horizontal_override = true
    horizontal_override = velocity


## Ends the active move after the current physics tick; the controller then
## resolves the appropriate grounded/airborne fallback.
func finish_move() -> void:
    move_finished = true
