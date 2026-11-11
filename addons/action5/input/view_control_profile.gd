extends Resource
class_name Action5ViewControlProfile
## Declarative mapping of InputMap action names to view-local input roles.
## Pure data: does not read inputs or know about Actor, Camera, or Movement.
## view_mode -1 is a reusable fallback for all modes without an override.

@export_range(-1, 4, 1) var view_mode: int = -1
@export var move_left_action: StringName = &"move_left"
@export var move_right_action: StringName = &"move_right"
@export var move_up_action: StringName = &"move_up"
@export var move_down_action: StringName = &"move_down"
@export var vertical_movement: bool = true
## Additional directional actions (e.g. arrows in F1/F2/F3/F5).
@export var extra_left_action: StringName = &""
@export var extra_right_action: StringName = &""
## Optional yaw controls (e.g. arrows in F4); no Actor rotation here.
@export var turn_left_action: StringName = &""
@export var turn_right_action: StringName = &""
@export var jump_action: StringName = &"actor_jump"
@export var extra_jump_action: StringName = &""
## Optional hold-to-activate registered move; release requests its exit.
## Existing component-owned toggle actions remain independent.
@export var held_move_action: StringName = &""
@export var held_move_id: StringName = &""
@export var held_move_variants: Array[StringName] = []
