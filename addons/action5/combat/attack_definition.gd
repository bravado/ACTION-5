extends Resource
class_name Action5AttackDefinition
## Immutable attack configuration. A combat instance owns every mutable tick,
## buffer and hit-deduplication state; never store those on shared Resources.

@export var attack_id: StringName = &""
@export var input_action: StringName = &""
@export var default_key: int = 0
@export var default_gamepad_button: int = -1
## Optional mouse default; -1 = none. No game action is special-cased.
@export_range(-1, 9, 1) var default_mouse_button: int = -1
@export_range(0, 120, 1) var startup_ticks: int = 4
@export_range(1, 120, 1) var active_ticks: int = 3
@export_range(0, 120, 1) var recovery_ticks: int = 10
@export_range(0.0, 200.0, 0.5) var damage: float = 10.0
## False when a separate effect subscriber (e.g. a ranged muzzle tracer)
## resolves hits. D05 still owns action timing, but never emits phantom
## melee damage for an externally resolved action.
@export var use_melee_hit_query: bool = true
@export var hitbox_size: Vector3 = Vector3(1.0, 1.0, 0.9)
@export_range(0.0, 4.0, 0.05) var hitbox_forward: float = 0.85
@export_range(0.0, 3.0, 0.05) var hitbox_height: float = 1.0
@export var animation_key: StringName = &""
## Optional independent camera-local action identity. If unset, the
## F4 visual source uses animation_key for backwards-compatible D05
## unarmed poses; world clips can differ from authored viewmodel clips.
@export var visual_action_key: StringName = &""
@export_enum("Upper body", "Full body") var animation_channel: int = 0
@export_enum("Free", "4-way", "8-way") var facing_sectors: int = 0
@export var allow_friendly_fire: bool = false
@export_range(0, 120, 1) var stagger_ticks: int = 8
@export_range(0.0, 30.0, 0.5) var knockback_speed: float = 3.0
@export_range(0, 60, 1) var knockback_ticks: int = 8


func valid() -> bool:
    return attack_id != &"" and active_ticks > 0 and hitbox_size.x > 0.0 \
        and hitbox_size.y > 0.0 and hitbox_size.z > 0.0 and damage >= 0.0


func total_ticks() -> int:
    return startup_ticks + active_ticks + recovery_ticks
