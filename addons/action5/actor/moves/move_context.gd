extends RefCounted
class_name Action5MoveContext
## Shared read-only actor/intent context plus one-tick movement commands.
## Only Action5Locomotion writes CharacterBody3D.velocity/move_and_slide.

const IntentScript = preload("res://addons/action5/actor/move_intent.gd")

var body: CharacterBody3D
var locomotion: Node
var intent: IntentScript
var delta: float = 0.0

var has_horizontal_override: bool = false
var horizontal_override: Vector2 = Vector2.ZERO
var has_vertical_override: bool = false
var vertical_override: float = 0.0
var gravity_scale: float = 1.0
var move_finished: bool = false


func _init(character: CharacterBody3D, solver: Node) -> void:
    body = character
    locomotion = solver


func begin_tick(next_intent: IntentScript, physics_delta: float) -> void:
    intent = next_intent
    delta = physics_delta
    has_horizontal_override = false
    horizontal_override = Vector2.ZERO
    has_vertical_override = false
    vertical_override = 0.0
    gravity_scale = 1.0
    move_finished = false


func horizontal_speed() -> float:
    return Vector2(body.velocity.x, body.velocity.z).length()


## Move components submit commands; only the locomotion solver applies them.
func request_horizontal_velocity(velocity: Vector2) -> void:
    if not velocity.is_finite():
        return
    has_horizontal_override = true
    horizontal_override = velocity


## Optional vertical commands support climbing, swimming, lifts and
## wall-running without changing the player or central physics implementation.
func request_vertical_velocity(velocity_y: float) -> void:
    if is_nan(velocity_y) or is_inf(velocity_y):
        return
    has_vertical_override = true
    vertical_override = velocity_y


func request_gravity_scale(scale: float) -> void:
    if is_nan(scale) or is_inf(scale):
        return
    gravity_scale = clampf(scale, 0.0, 4.0)


## Ends the active move after the current physics tick; the controller then
## resolves the appropriate grounded/airborne fallback.
func finish_move() -> void:
    move_finished = true
