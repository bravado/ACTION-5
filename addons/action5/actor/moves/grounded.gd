extends "res://addons/action5/actor/moves/move.gd"
## Ordinary grounded movement is solved by Action5Locomotion.

func can_enter(ctx: ContextScript) -> bool:
    return ctx.body.is_on_floor()
