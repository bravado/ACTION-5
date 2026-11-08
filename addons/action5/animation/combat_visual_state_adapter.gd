extends Node
class_name Action5CombatVisualStateAdapter
## One-way adapter from gameplay action time to purely visual data.
## The FPS renderer depends only on get_visual_action(), not CombatController.
## Non-combat actions may replace this adapter with any Node implementing
## the same method. No camera/viewmode reference lives here.

const CombatScript = preload("res://addons/action5/combat/combat_controller.gd")

@export var combat_path: NodePath = ^"../CombatController"
@onready var combat: CombatScript = get_node_or_null(combat_path) as CombatScript


func get_visual_action() -> Dictionary:
    if not is_instance_valid(combat) or combat.current_attack == null:
        return {}
    var total: int = maxi(combat.current_attack.total_ticks(), 1)
    var action_key: StringName = combat.current_attack.visual_action_key
    if action_key == &"":
        action_key = combat.current_attack.animation_key
    return {
        "key": action_key,
        "progress": clampf(float(combat.elapsed_ticks) / float(total), 0.0, 1.0),
    }
