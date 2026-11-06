extends "res://addons/action5/actor/moves/move.gd"
## Jump/fall remain in the shared solver; this state reports airborne status.

func _init() -> void:
    move_id = &"airborne"


func can_enter(ctx: ContextScript) -> bool:
    return not ctx.body.is_on_floor()
