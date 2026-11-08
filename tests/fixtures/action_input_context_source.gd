extends Node
## Test-only alternative to ActorInputAdapter. No actor, camera manager,
## movement or facing dependency. Combat consumes only the shared snapshot.

const ContextScript = preload("res://addons/action5/input/action_input_context.gd")

var snapshot: ContextScript = ContextScript.new()


func get_action_input_context() -> ContextScript:
    return snapshot
