extends "res://addons/action5/actor/moves/move.gd"
class_name Action5CrouchMove
## Example of an installable locomotion move with two presentation states.
## The same component is configured twice (idle/walking) in player.tscn.
## No branches are needed in Actor, Locomotion, MovementController or animation.

@export var walking_variant: bool = false
@export var idle_move_id: StringName = &"crouch"
@export var walk_move_id: StringName = &"crouch_walk"
@export_range(0.1, 8.0, 0.1) var crouch_speed: float = 2.2
@export_range(0.8, 2.0, 0.05) var crouch_height: float = 1.30
@export_range(0.0, 0.6, 0.01) var floor_grace_seconds: float = 0.25
@export var collider_path: NodePath = ^"CollisionShape3D"

var _collider: CollisionShape3D
var _standing_shape: CapsuleShape3D
var _standing_position: Vector3
var _just_entered: bool = false
var _airborne_seconds: float = 0.0


func _init() -> void:
    move_id = &"crouch"
    action_name = &"actor_crouch"
    default_key = KEY_CTRL
    default_gamepad_button = JOY_BUTTON_RIGHT_STICK
    priority = 30


func can_enter(ctx: ContextScript) -> bool:
    if not ctx.body.is_on_floor():
        return false
    # A second press while crouch-walking means STAND, not switch to idle.
    # The walking component handles the request after arbitration.
    if not walking_variant and ctx.intent != null and (
        ctx.intent.requested_moves.has(idle_move_id)
        and ctx.locomotion.move_controller.active_id == walk_move_id
    ):
        return false
    return true


func enter(ctx: ContextScript) -> void:
    _just_entered = true
    _airborne_seconds = 0.0
    _collider = ctx.body.get_node_or_null(collider_path) as CollisionShape3D
    if _collider == null or not _collider.shape is CapsuleShape3D:
        return
    _standing_shape = _collider.shape as CapsuleShape3D
    _standing_position = _collider.position
    # Duplicate the shape for this actor: never mutate a shared scene resource.
    var shortened := _standing_shape.duplicate() as CapsuleShape3D
    shortened.height = clampf(crouch_height, shortened.radius * 2.0, _standing_shape.height)
    _collider.shape = shortened
    # Keep the bottom of the collider in place as its top lowers.
    _collider.position.y -= (_standing_shape.height - shortened.height) * 0.5


func physics_update(ctx: ContextScript, _delta: float) -> void:
    if ctx.intent == null:
        return
    # The initial crouch request must not immediately undo its own entry.
    # The walking variant, however, is entered from the crouched stance,
    # so a new toggle on that same tick must be honored.
    if ctx.intent.requested_moves.has(idle_move_id) and (
        walking_variant or not _just_entered
    ):
        if _can_stand(ctx):
            ctx.finish_move()
            return
    _just_entered = false
    var movement: Vector2 = ctx.intent.world_move.limit_length(1.0)
    if bool(ctx.locomotion.get("side_lane_locked")):
        movement.y = 0.0
    ctx.request_horizontal_velocity(movement * crouch_speed)

    # Replacing the capsule or walking over a tiny step may briefly clear
    # is_on_floor() before floor snap recovers. A transient gap must not
    # cancel crouch, restore the tall collider or briefly play Airborne.
    if not ctx.body.is_on_floor():
        _airborne_seconds += ctx.delta
        if _airborne_seconds > floor_grace_seconds:
            ctx.finish_move()
        return
    _airborne_seconds = 0.0
    var moving: bool = movement.length_squared() > 0.01
    if moving != walking_variant:
        # A normal registered-move request; no custom FSM hook or animation
        # override. The active move ID maps to its own configured clip.
        ctx.locomotion.move_controller.request_move(
            walk_move_id if moving else idle_move_id
        )


func exit(_ctx: ContextScript) -> void:
    if is_instance_valid(_collider) and _standing_shape != null:
        _collider.shape = _standing_shape
        _collider.position = _standing_position
    _collider = null
    _standing_shape = null
    _just_entered = false
    _airborne_seconds = 0.0


func _can_stand(ctx: ContextScript) -> bool:
    if not is_instance_valid(_collider) or not _collider.shape is CapsuleShape3D:
        return true
    if _standing_shape == null:
        return true
    var current := _collider.shape as CapsuleShape3D
    var rise: float = _standing_shape.height - current.height
    if rise <= 0.001:
        return true
    # Probe ONLY the added headroom, not the existing floor contact.
    var probe := BoxShape3D.new()
    probe.size = Vector3(current.radius * 1.7, rise * 0.95, current.radius * 1.7)
    var query := PhysicsShapeQueryParameters3D.new()
    query.shape = probe
    query.transform = Transform3D(
        _collider.global_basis,
        _collider.global_position + _collider.global_basis.y * (current.height * 0.5 + rise * 0.5)
    )
    query.collision_mask = ctx.body.collision_mask
    query.exclude = [ctx.body.get_rid()]
    return ctx.body.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
