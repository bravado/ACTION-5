extends CharacterBody3D
class_name Action5Actor
## A single authoritative actor. Raw keyboard/mouse/gamepad input stays outside.

const IntentScript = preload("res://addons/action5/actor/move_intent.gd")
const LocomotionScript = preload("res://addons/action5/actor/locomotion.gd")
const FacingScript = preload("res://addons/action5/actor/facing_presenter.gd")

@onready var locomotion: LocomotionScript = $Locomotion
@onready var facing: FacingScript = $Visual

var alive: bool = true
var controls_enabled: bool = true


func apply_move_intent(intent: IntentScript) -> void:
    if not alive or not controls_enabled or intent == null:
        locomotion.stop()
        return
    locomotion.apply_intent(intent)
    var facing_direction: Vector2 = intent.face_world
    if facing_direction.length_squared() > 0.001:
        facing.set_facing(facing_direction)


## Compatibility with D01/D02 tests or an external non-input-driven AI actor.
func set_move_intent(world_direction: Vector2) -> void:
    var command: IntentScript = IntentScript.new(world_direction, world_direction)
    apply_move_intent(command)


func enter_side_view() -> void:
    locomotion.lock_side_lane()


func exit_side_view() -> void:
    locomotion.unlock_side_lane()


func set_controls_enabled(next_enabled: bool) -> void:
    controls_enabled = next_enabled
    locomotion.set_enabled(alive and controls_enabled)


func set_alive(next_alive: bool) -> void:
    alive = next_alive
    locomotion.set_enabled(alive and controls_enabled)


func clear_motion() -> void:
    locomotion.stop()
